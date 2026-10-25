\name{movoa_submit}
\alias{movoa_submit}
\alias{movoa_status}
\alias{movoa_wait}
\alias{movoa_credits}
\title{Submit a run, look it up, wait for it, read your credits}
\usage{
movoa_submit(prompt, model = "minimax-h3", image_url = NULL, ..., api_key = NULL, post = movoa_post)
movoa_status(id, api_key = NULL, post = movoa_post)
movoa_wait(id, api_key = NULL, poll_seconds = 10, timeout_seconds = 1800, post = movoa_post)
movoa_credits(api_key = NULL, post = movoa_post)
}
\arguments{
\item{prompt}{What to film.}
\item{model}{Model id, as in \code{\link{movoa_generate_video}}.}
\item{image_url}{A public https image to use as the first frame, or \code{NULL}.}
\item{...}{Model options passed through as-is.}
\item{id}{The id returned by \code{movoa_submit}.}
\item{api_key}{Key from \url{https://movoa.ai/settings/apikeys}; defaults to MOVOA_API_KEY.}
\item{poll_seconds}{How often the run is polled.}
\item{timeout_seconds}{Deadline for the wait.}
\item{post}{The HTTP function; replaceable in tests.}
}
\value{\code{movoa_submit}: the run id. \code{movoa_status} and \code{movoa_wait}: a list with \code{id},
\code{status} ("pending", "processing", "success", "failed" or "canceled"), \code{videos} once it succeeded,
\code{errorMessage} and \code{failureKind} when it failed, \code{queued} and \code{queueEta} (seconds) while queued.
\code{movoa_credits}: remaining credits as an integer.}
\description{Lower-level calls for submitting now and collecting later.}
\examples{
\dontrun{
id <- movoa_submit("a fox trotting through fresh snow")
movoa_status(id)$status
movoa_credits()
}
}
