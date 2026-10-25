# movoa-r

Unlimited AI video generator with sound: on paid plans the tenth take of a shot costs what the first did, and your first clip is free to make right now. This is the official R SDK for [Movoa](https://movoa.ai/?utm_source=r-universe&utm_medium=package): make [text to video](https://movoa.ai/video/text-to-video) and [photo to video](https://movoa.ai/video/photo-to-video) clips from R code on your own Movoa account, and every clip comes back as [AI video with audio](https://movoa.ai/video/ai-video-with-audio).

```r
library(movoa)

clip <- movoa_generate_video("a lighthouse in a storm, waves crashing, distant thunder")
clip # URL of the finished MP4
```

One call submits the run, waits for it and returns the URL of the finished file.

## Install

```r
install.packages("movoa", repos = c("https://hanshs474.r-universe.dev", "https://cloud.r-project.org"))
```

Imports `curl` and `jsonlite`.

## API key

Create a key at [movoa.ai/settings/apikeys](https://movoa.ai/settings/apikeys), then pass it as `api_key = "sk-..."` or set it:

```bash
export MOVOA_API_KEY=sk-...
```

Runs cost credits on your Movoa account, at the prices on https://movoa.ai/pricing. A run made here is queued and stored like one made on the site, so it shows up in your Movoa library too.

## Models and options

The default model is `minimax-h3` (6 seconds, 480p, 16:9). Sound is always on. Options go to the model as-is:

```r
# Seedance 2.5: 10 seconds, vertical
movoa_generate_video("a street drummer in the rain, handheld", "seedance-2-5",
                     duration = 10, aspect_ratio = "9:16")

# MiniMax H3 at 768p
movoa_generate_video("a koi pond seen from above, petals falling", duration = 8, resolution = "768p")
```

Named arguments in `...` go to the model as options.

| model | what it is | options (default) |
|---|---|---|
| `minimax-h3` | MiniMax H3, the default | `duration` 4, 5, 6, 8, 10, 15 (6) · `resolution` 480p, 768p (480p) · `aspect_ratio` 16:9, 9:16, 1:1 (16:9) |
| `veo-3-1-fast` | Veo 3.1 Fast, see [Veo 3](https://movoa.ai/video/google-veo-3) | `duration` 8 · `resolution` 720p · `aspect_ratio` 16:9, 9:16 (photo to video: 16:9) |
| `seedance-2-5` | [Seedance 2.5](https://movoa.ai/video/seedance-2-5) | `duration` 5, 10, 15, 20, 25, 30 (5) · `resolution` 480p, 720p · `aspect_ratio` 16:9, 9:16, 1:1 |
| `seedance-2` | Seedance 2.0 | `duration` 4, 6, 8, 10 (6) · `resolution` 480p, 720p · `aspect_ratio` |
| `seedance-2-fast` | Seedance 2.0 Fast | same as `seedance-2` |
| `seedance-2-mini` | Seedance 2.0 Mini | same as `seedance-2` |

## Photo to video

Pass a public https image URL and it becomes the first frame; the prompt then describes the motion. This is the same [photo to video](https://movoa.ai/video/photo-to-video) flow as on the site:

```r
movoa_generate_video("the camera slowly orbits the statue",
                     image_url = "https://example.com/statue.jpg")
```

## Submit now, collect later

```r
id <- movoa_submit("a fox trotting through fresh snow")
run <- movoa_status(id)   # run$status: pending | processing | success | failed | canceled
run$videos[[1]]           # set once it succeeded
movoa_credits()
```

`movoa_generate_video()` checks the run every 10 seconds and waits up to 30 minutes, since a run can sit in a queue; change that with `poll_seconds` and `timeout_seconds`. `movoa_wait(id)` waits for a run you submitted earlier.

## Errors worth catching

Every failure signals a condition that inherits `movoa_error`, with a class that says what to do next:

- `movoa_auth`: no key, or the key is wrong or deleted; create one at [movoa.ai/settings/apikeys](https://movoa.ai/settings/apikeys)
- `movoa_rejected`: the content filter refused the prompt, or the account is cooling down after a refusal; reword rather than retry
- `movoa_quota`: not enough credits left on the account for this run
- `movoa_plan`: this model or quality needs a plan, or the account has not bought credits yet
- `movoa_busy`: another generation on this account is still running; wait for it, then submit again
- `movoa_failed`: the run was accepted and then failed or was canceled; the service's error message comes with it
- `movoa_timeout`: the wait ran out; the run may still finish, so look it up later by its task id

Anything else (a network failure, a 5xx) is `movoa_other` with the service's message.

## License

MIT. Made by [Movoa](https://movoa.ai/?utm_source=r-universe&utm_medium=package).
