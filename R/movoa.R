movoa_default_base <- "https://movoa.ai"
movoa_keys_url <- "https://movoa.ai/settings/apikeys"
movoa_key_hint <- paste("Create a key at", movoa_keys_url, "and set MOVOA_API_KEY.")

movoa_base <- function() {
  b <- getOption("movoa.base_url", Sys.getenv("MOVOA_BASE_URL"))
  if (!nzchar(b)) b <- movoa_default_base
  sub("/+$", "", b)
}

# Every failure carries a class to branch on: movoa_auth, movoa_rejected, movoa_quota,
# movoa_plan, movoa_busy, movoa_failed, movoa_timeout, movoa_other; all inherit movoa_error.
movoa_stop <- function(kind, msg, status = NA_integer_, ...) {
  stop(structure(class = c(paste0("movoa_", kind), "movoa_error", "error", "condition"),
                 list(message = paste("movoa:", msg), call = NULL, status = status, ...)))
}

# movoa.ai answers almost every refusal as HTTP 200 with a non-zero code and a
# data.reason, so the status code alone reads a refusal as success.
movoa_check <- function(status, body) {
  if (status == 401) {
    msg <- if (is.list(body) && is.character(body$message)) body$message else paste("Invalid API key.", movoa_key_hint)
    movoa_stop("auth", msg, status)
  }
  if (!is.list(body)) movoa_stop("other", paste0("movoa.ai returned a non-JSON response (HTTP ", status, ")"), status)
  code <- if (is.numeric(body$code)) as.integer(body$code) else NA_integer_
  if (identical(code, 0L)) return(body$data)
  msg <- if (is.character(body$message)) body$message else paste0("request failed (HTTP ", status, ")")
  if (code %in% c(-2L, -3L)) movoa_stop("rejected", msg, status)
  reason <- if (is.list(body$data) && is.character(body$data$reason)) body$data$reason else NA_character_
  if (identical(reason, "insufficient_credits")) movoa_stop("quota", msg, status, reason = reason)
  if (identical(reason, "plan_required")) movoa_stop("plan", msg, status, reason = reason)
  if (identical(reason, "concurrency")) movoa_stop("busy", msg, status, reason = reason)
  if (grepl("no auth", tolower(msg), fixed = TRUE)) movoa_stop("auth", paste0(msg, ". ", movoa_key_hint), status)
  movoa_stop("other", msg, status, reason = reason)
}

# POST a JSON body; returns list(status, body). Replaceable in tests via `post =`.
movoa_post <- function(path, body, key) {
  h <- new_handle()
  handle_setheaders(h, "Content-Type" = "application/json", Authorization = paste("Bearer", key),
                    "User-Agent" = "movoa-r/0.1.0")
  json <- if (length(body)) toJSON(body, auto_unbox = TRUE) else "{}"
  handle_setopt(h, timeout = 60, postfields = json)
  res <- tryCatch(curl_fetch_memory(paste0(movoa_base(), path), handle = h),
                  error = function(e) movoa_stop("other", paste("Could not reach movoa.ai:", conditionMessage(e))))
  parsed <- tryCatch(fromJSON(rawToChar(res$content), simplifyVector = FALSE), error = function(e) NULL)
  list(status = res$status_code, body = parsed)
}

movoa_key <- function(api_key) {
  key <- if (!is.null(api_key) && nzchar(api_key)) api_key else Sys.getenv("MOVOA_API_KEY")
  key <- trimws(key)
  if (!nzchar(key)) movoa_stop("auth", paste("No API key set.", movoa_key_hint))
  key
}

movoa_call <- function(path, body, api_key, post) {
  r <- post(path, body, movoa_key(api_key))
  movoa_check(r$status, r$body)
}

#' @export
movoa_submit <- function(prompt, model = "minimax-h3", image_url = NULL, ..., api_key = NULL,
                         post = movoa_post) {
  if (!is.character(prompt) || !nzchar(trimws(prompt))) stop("prompt is required")
  options <- list(...)
  options$sound <- TRUE
  i2v <- !is.null(image_url) && nzchar(image_url)
  if (i2v) options$image_input <- list(image_url)
  body <- list(provider = "auto", # the service routes by model; this only has to be non-empty
               mediaType = "video", model = model,
               scene = if (i2v) "image-to-video" else "text-to-video",
               prompt = prompt, options = options)
  d <- movoa_call("/api/ai/generate", body, api_key, post)
  if (is.null(d$id)) movoa_stop("other", "movoa.ai accepted the run but returned no id")
  as.character(d$id)
}

#' @export
movoa_status <- function(id, api_key = NULL, post = movoa_post) {
  movoa_call("/api/ai/query", list(taskId = id), api_key, post)
}

#' @export
movoa_credits <- function(api_key = NULL, post = movoa_post) {
  d <- movoa_call("/api/user/get-user-credits", list(), api_key, post)
  if (!is.numeric(d$remainingCredits)) movoa_stop("other", "movoa.ai returned no credit balance")
  as.integer(d$remainingCredits)
}

#' @export
movoa_wait <- function(id, api_key = NULL, poll_seconds = 10, timeout_seconds = 1800, post = movoa_post) {
  deadline <- Sys.time() + timeout_seconds
  repeat {
    d <- tryCatch(movoa_status(id, api_key, post), movoa_other = function(e) NULL) # only a dropped poll is retried
    if (!is.null(d)) {
      url <- if (length(d$videos)) d$videos[[1]] else NULL
      if (identical(d$status, "success") && !is.null(url)) return(d)
      if (d$status %in% c("success", "failed", "canceled")) {
        why <- if (!is.null(d$errorMessage)) paste0(": ", d$errorMessage) else if (is.null(url)) " with no video" else ""
        movoa_stop("failed", paste0("run ", id, " ", d$status, why), task_id = id,
                   error_message = d$errorMessage, failure_kind = d$failureKind)
      }
    }
    if (Sys.time() + poll_seconds > deadline) {
      movoa_stop("timeout", paste0("run ", id, " is still generating; check it later with movoa_status(\"", id, "\")"),
                 task_id = id)
    }
    Sys.sleep(poll_seconds)
  }
}

#' @export
movoa_generate_video <- function(prompt, model = "minimax-h3", image_url = NULL, ..., api_key = NULL,
                                 poll_seconds = 10, timeout_seconds = 1800, post = movoa_post) {
  id <- movoa_submit(prompt, model, image_url, ..., api_key = api_key, post = post)
  movoa_wait(id, api_key, poll_seconds, timeout_seconds, post)$videos[[1]]
}
