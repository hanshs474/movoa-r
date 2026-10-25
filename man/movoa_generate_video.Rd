\name{movoa_generate_video}
\alias{movoa_generate_video}
\title{Generate a video with sound on Movoa}
\usage{
movoa_generate_video(prompt, model = "minimax-h3", image_url = NULL, ..., api_key = NULL,
  poll_seconds = 10, timeout_seconds = 1800, post = movoa_post)
}
\arguments{
\item{prompt}{What to film. For photo to video, the motion.}
\item{model}{Model id: "minimax-h3" (default), "veo-3-1-fast", "seedance-2-5", "seedance-2", "seedance-2-fast" or "seedance-2-mini".}
\item{image_url}{A public https image to use as the first frame (photo to video); \code{NULL} for text to video.}
\item{...}{Model options passed through as-is, e.g. \code{duration = 8}, \code{resolution = "768p"}, \code{aspect_ratio = "9:16"}.}
\item{api_key}{Key from \url{https://movoa.ai/settings/apikeys}; defaults to the MOVOA_API_KEY environment variable.}
\item{poll_seconds}{How often the run is polled.}
\item{timeout_seconds}{Deadline for the whole call.}
\item{post}{The HTTP function; replaceable in tests.}
}
\value{The URL of the finished clip.}
\description{Submits one run on Movoa (\url{https://movoa.ai}), waits for it and returns the clip URL.
Runs cost credits on your Movoa account, at the prices on \url{https://movoa.ai/pricing}.
Failures signal a condition of class \code{movoa_auth}, \code{movoa_rejected}, \code{movoa_quota},
\code{movoa_plan}, \code{movoa_busy}, \code{movoa_failed}, \code{movoa_timeout} or \code{movoa_other},
all inheriting \code{movoa_error}.}
\examples{
\dontrun{
movoa_generate_video("a lighthouse in a storm, waves crashing, thunder", duration = 8)
movoa_generate_video("the statue turns its head", image_url = "https://example.com/statue.jpg")
}
}
