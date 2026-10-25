library(movoa)
queue <- list(); calls <- list()
fake <- function(path, body, key) {
  calls[[length(calls) + 1]] <<- list(path = path, body = body, key = key)
  r <- queue[[1]]; if (length(queue) > 1) queue <<- queue[-1]; r
}
ok <- function(x) list(status = 200L, body = list(code = 0L, message = "ok", data = x))

# text to video: submit -> queued -> success
queue <- list(ok(list(id = "t1", status = "pending")),
              ok(list(id = "t1", status = "processing", queued = TRUE, queueEta = 60L)),
              ok(list(id = "t1", status = "success", videos = list("https://cdn.movoa.ai/v.mp4"))))
url <- movoa_generate_video("a fox in snow", api_key = "sk-test", poll_seconds = 0, post = fake)
b <- calls[[1]]$body
stopifnot(url == "https://cdn.movoa.ai/v.mp4", calls[[1]]$path == "/api/ai/generate", calls[[1]]$key == "sk-test",
          b$provider == "auto", b$mediaType == "video", b$model == "minimax-h3", b$scene == "text-to-video",
          identical(b$options, list(sound = TRUE)),
          calls[[2]]$path == "/api/ai/query", calls[[2]]$body$taskId == "t1", length(calls) == 3)
stopifnot(identical(as.character(jsonlite::toJSON(b$options, auto_unbox = TRUE)), "{\"sound\":true}"))

# photo to video, options through ...
calls <- list(); queue <- list(ok(list(id = "t2", status = "pending")))
stopifnot(movoa_submit("the statue turns", "seedance-2-5", "https://x/y.jpg", duration = 10, aspect_ratio = "9:16",
                       api_key = "sk-test", post = fake) == "t2")
b <- calls[[1]]$body
stopifnot(b$scene == "image-to-video", b$model == "seedance-2-5", b$options$duration == 10,
          b$options$aspect_ratio == "9:16", isTRUE(b$options$sound),
          as.character(jsonlite::toJSON(b$options$image_input, auto_unbox = TRUE)) == "[\"https://x/y.jpg\"]")

queue <- list(ok(list(id = "t3", status = "processing", queued = TRUE, queueEta = 120L)))
d <- movoa_status("t3", api_key = "sk-test", post = fake)
stopifnot(d$status == "processing", isTRUE(d$queued), d$queueEta == 120)
queue <- list(ok(list(remainingCredits = 42L)))
stopifnot(identical(movoa_credits(api_key = "sk-test", post = fake), 42L))

queue <- list(ok(list(id = "t4", status = "failed", errorMessage = "provider down", failureKind = "upstream")))
e <- tryCatch(movoa_wait("t4", api_key = "sk-test", poll_seconds = 0, post = fake), movoa_error = function(e) e)
stopifnot(inherits(e, "movoa_failed"), e$task_id == "t4", e$error_message == "provider down",
          grepl("provider down", conditionMessage(e)))
queue <- list(ok(list(id = "t5", status = "canceled")))
e <- tryCatch(movoa_wait("t5", api_key = "sk-test", poll_seconds = 0, post = fake), movoa_error = function(e) e)
stopifnot(inherits(e, "movoa_failed"), e$task_id == "t5")
queue <- list(ok(list(id = "t6", status = "processing", queued = TRUE, queueEta = 60L)))
e <- tryCatch(movoa_wait("t6", api_key = "sk-test", poll_seconds = 0.005, timeout_seconds = 0.001, post = fake),
              movoa_error = function(e) e)
stopifnot(inherits(e, "movoa_timeout"), e$task_id == "t6")

cases <- list(list(401L, list(code = -1L, message = "Invalid API key. Create one at https://movoa.ai/settings/apikeys", data = list(reason = "invalid_api_key")), "auth"),
              list(200L, list(code = -1L, message = "insufficient credits", data = list(reason = "insufficient_credits")), "quota"),
              list(200L, list(code = -1L, message = "This model or quality needs a plan.", data = list(reason = "plan_required")), "plan"),
              list(200L, list(code = -1L, message = "busy", data = list(reason = "concurrency")), "busy"),
              list(200L, list(code = -2L, message = "blocked"), "rejected"),
              list(200L, list(code = -3L, message = "cooldown"), "rejected"),
              list(200L, list(code = -1L, message = "generation failed, please try again"), "other"),
              list(502L, NULL, "other"))
for (c in cases) {
  queue <- list(list(status = c[[1]], body = c[[2]]))
  e <- tryCatch(movoa_submit("x", api_key = "sk-test", post = fake), movoa_error = function(e) e)
  stopifnot(inherits(e, paste0("movoa_", c[[3]])), e$status == c[[1]])
}

queue <- list(list(status = 200L, body = list(code = -1L, message = "no auth, please sign in")))
e <- tryCatch(movoa_credits(api_key = "sk-test", post = fake), movoa_error = function(e) e)
stopifnot(inherits(e, "movoa_auth"), grepl("/settings/apikeys", conditionMessage(e)))

Sys.unsetenv("MOVOA_API_KEY")
calls <- list()
e <- tryCatch(movoa_credits(post = fake), movoa_error = function(e) e)
stopifnot(inherits(e, "movoa_auth"), length(calls) == 0)

if (nzchar(Sys.getenv("MOVOA_LIVE"))) {
  n <- movoa_credits()
  stopifnot(is.integer(n))
  e <- tryCatch(movoa_submit("live check", api_key = "sk-wrong-key"), movoa_error = function(e) e)
  stopifnot(inherits(e, "movoa_auth"), e$status == 401)
  cat("live ok: credits read, wrong key -> movoa_auth\n")
}
cat("all tests passed\n")
