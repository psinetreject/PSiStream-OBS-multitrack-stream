# Second audio track for any streaming service

An OBS script that sends a second audio track alongside your stream, the way Twitch's
"VOD Track" option does, but for any service.

This is a fork of [OBS-multitrack-stream](https://github.com/ratwithacompiler/OBS-multitrack-stream)
by RatWithAShotgun, updated for current OBS and generalised past Twitch.

## Why it exists

OBS has a built-in VOD track, but the checkbox only appears when the selected service is
literally named "Twitch", or when the service is Custom and a hidden user-config flag
(`EnableCustomServerVodTrack`) is set. That gate lives in the settings screen
(`UpdateVodTrackSetting` in `frontend/settings/OBSBasicSettings_Stream.cpp`), not in the
streaming code: `obs_output_set_audio_encoder` has no idea which service you are using.

So any service that is listed in OBS by name, rather than configured as Custom, loses the
option. This script attaches the encoder directly and gives it back.

The practical use is a music-free mix. Put your music on its own source, exclude it from
one OBS track, and send that track as the second one so a destination that mutes copyrighted
audio has something clean to fall back on.

## Status

The plain RTMP path is straightforward: the script attaches an AAC encoder at output audio
index 1 before the stream starts.

Enhanced Broadcasting is the open question. In that mode OBS does not use the ordinary RTMP
output, it uses a multitrack video output that builds its own audio configuration, and
whether an encoder attached here survives that path is not yet confirmed. The script logs
the output id and reads index 1 back after attaching, so you can see the answer in the
Script Log rather than guess. If you run it that way, the log lines are the thing to report.

If OBS already offers you the VOD Track checkbox, use that instead and leave this script
disabled. Running both means the script overwrites what OBS set up, which is not a
combination this has been built for.

## Installation

1. Download [`psistream-second-audio-track.lua`](https://raw.githubusercontent.com/psinetreject/PSiStream-OBS-multitrack-stream/master/src/psistream-second-audio-track.lua)
   (right click, save as) and put it somewhere it will stay. If the file is moved or renamed
   after you add it, OBS drops it and you have to add it again.
2. In OBS, go to `Tools` then `Scripts`.
3. Click the `+` button at the bottom left and select the file.
4. The script settings appear on the right.

Requires an OBS build with Lua scripting. Written against OBS 32.2, using only the obslua
frontend and encoder calls, which have been stable for many releases.

## Settings

| Setting | Default | Notes |
|---|---|---|
| Enabled | on | Turn it off to leave the second track alone entirely. |
| Clean-mix audio track (1-6) | 2 | The OBS track carrying the mix you want sent as the second track. Track 1 is your main stream audio, so 2 is the usual choice. |
| Bitrate (kbps) | 160 | 60 to 320. 160 matches the OBS default for streams. |

**It has to be enabled before you go live.** The track is attached as the stream starts, and
nothing you change during a live stream takes effect until the next one.

## Choosing what goes on the track

Anything you want to exclude has to be its own source in OBS. If game, browser and music
audio all arrive through a single Desktop Audio Capture, OBS has nothing to separate.

Open `Edit` then `Advanced Audio Properties` and untick the sources you want left off your
chosen track. Untick "Active Sources Only" so sources from other scenes are not hidden from
the list.

The original project's README has worked examples for splitting audio with Voicemeeter, a
GoXLR, or a two PC setup with NDI, and they all still apply:
[upstream Readme](https://github.com/ratwithacompiler/OBS-multitrack-stream#readme).

## Checking that it worked

Open `Tools` then `Scripts` and look at the Script Log. Going live should give you the
output id, then either the name of the encoder sitting at index 1, or a warning that index 1
read back empty, which means that output refused the second track.

## Credit and license

Original work copyright (C) 2020 by RatWithAShotgun,
[OBS-multitrack-stream](https://github.com/ratwithacompiler/OBS-multitrack-stream).
Modified in 2026 by PSiStream LLC. The changes are listed at the top of the script.

GPL-2.0-or-later, the same license as the original. See [LICENSE](LICENSE).
