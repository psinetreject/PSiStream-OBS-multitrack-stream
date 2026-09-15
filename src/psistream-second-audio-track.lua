--
--  Second audio track for any streaming service.
--
--  Copyright (C) 2020 by RatWithAShotgun
--  Modified in 2026 by PSiStream LLC. Changes are listed below.
--
--  Derived from OBS-multitrack-stream:
--  https://github.com/ratwithacompiler/OBS-multitrack-stream
--
--  This program is free software; you can redistribute it and/or
--  modify it under the terms of the GNU General Public License
--  as published by the Free Software Foundation; either version 2
--  of the License, or (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--
--  CHANGES FROM THE ORIGINAL (2026, PSiStream LLC)
--    * Logs through script_log so output appears in the Script Log, not stdout.
--    * Reports the output id and reads the encoder back, to see whether the
--      multitrack path kept it.
--    * Holds one encoder reference for the script's lifetime. The original
--      re-fetched by name on every update, which leaks a reference each time,
--      and it cannot simply release it because obs_output_set_audio_encoder does
--      not take its own reference.
--    * Fixes get_encoder() being called with no argument on the active-output
--      path, where it always returned nil.
--    * Makes the settings table local; it was a global.
--

obs = obslua

local g_track = 2       -- OBS audio track (1-6) carrying the clean mix
local g_bitrate = 160
local g_enabled = true
local g_encoder = nil   -- held for the script's lifetime; see note above

local ENCODER_NAME = "PSISTREAM_SECOND_AUDIO_V1"

local function log(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    obs.script_log(obs.LOG_INFO, ok and msg or fmt)
end

local function warn(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    obs.script_log(obs.LOG_WARNING, ok and msg or fmt)
end

-- release_encoder drops our reference. Only safe when the encoder is not
-- currently attached to a live output.
local function release_encoder()
    if g_encoder ~= nil then
        obs.obs_encoder_release(g_encoder)
        g_encoder = nil
    end
end

local function build_encoder(track)
    release_encoder()

    local audio = obs.obs_get_audio()
    if audio == nil then
        warn("no OBS audio context; cannot create an encoder")
        return nil
    end

    -- mixer_idx is zero-based: OBS "Track 2" is index 1.
    local enc = obs.obs_audio_encoder_create("ffmpeg_aac", ENCODER_NAME, nil, track - 1, nil)
    if enc == nil then
        warn("failed to create the AAC encoder for track %d", track)
        return nil
    end

    local settings = obs.obs_data_create()
    obs.obs_data_set_int(settings, "bitrate", g_bitrate)
    obs.obs_encoder_update(enc, settings)
    obs.obs_data_release(settings)

    obs.obs_encoder_set_audio(enc, audio)
    g_encoder = enc
    log("created encoder on OBS track %d at %d kbps", track, g_bitrate)
    return enc
end

local function attach(output)
    if output == nil then
        warn("no streaming output to attach to")
        return
    end

    local out_id = obs.obs_output_get_id(output) or "?"
    log("streaming output id = %s", out_id)
    -- Under Enhanced Broadcasting this is NOT rtmp_output. Seeing which one it
    -- is tells us whether the multitrack path is in play at all.

    if not g_enabled then
        log("disabled; clearing any second track")
        obs.obs_output_set_audio_encoder(output, nil, 1)
        return
    end

    if obs.obs_output_active(output) then
        warn("output already active; a second track can only be attached before it starts")
        return
    end

    local enc = build_encoder(g_track)
    if enc == nil then
        obs.obs_output_set_audio_encoder(output, nil, 1)
        return
    end

    -- Index 1 is the second audio track on the output. Note this does NOT take a
    -- reference, which is why g_encoder holds ours.
    obs.obs_output_set_audio_encoder(output, enc, 1)

    -- Read it back. If the multitrack path ignores or overwrites index 1, this is
    -- where it shows, before a single frame is sent.
    local check = obs.obs_output_get_audio_encoder(output, 1)
    if check == nil then
        warn("attached, but index 1 reads back EMPTY: this output rejected the second track")
    else
        log("attached: index 1 now holds %s", obs.obs_encoder_get_name(check) or "?")
    end
end

local function on_event(event)
    if event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTING then
        local output = obs.obs_frontend_get_streaming_output()
        attach(output)
        obs.obs_output_release(output)
    elseif event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPED then
        local output = obs.obs_frontend_get_streaming_output()
        if output ~= nil then
            obs.obs_output_set_audio_encoder(output, nil, 1)
            obs.obs_output_release(output)
        end
        release_encoder()
    end
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, "enabled", "Enabled")
    obs.obs_properties_add_int(props, "audio_track", "Clean-mix audio track (1-6)", 1, 6, 1)
    obs.obs_properties_add_int(props, "bitrate", "Bitrate (kbps)", 60, 320, 1)
    return props
end

function script_description()
    return [[<b>PSiStream: second audio track for any service</b><br><br>
Sends a second audio track alongside your stream, the way Twitch's VOD Track option does,
but for any service including a named one such as PSiStream. OBS hides that option unless
the service is called "Twitch"; the restriction is in the settings screen, not in the
streaming code, so this attaches the track directly.<br><br>
Pick the track carrying your music-free mix. Track 1 is your main stream audio, so Track 2
is the usual choice. Set which sources feed it under Edit, then Advanced Audio Properties.<br><br>
<b>Must be enabled before you start streaming.</b> Changes do not apply to a live stream.<br><br>
Check the Script Log after going live: it reports the output type and whether the track was
accepted. Under Enhanced Broadcasting OBS uses a different output, and whether it keeps the
second track is exactly what this is here to find out.]]
end

function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "enabled", true)
    obs.obs_data_set_default_int(settings, "audio_track", 2)
    obs.obs_data_set_default_int(settings, "bitrate", 160)
end

function script_update(settings)
    g_enabled = obs.obs_data_get_bool(settings, "enabled")
    g_bitrate = obs.obs_data_get_int(settings, "bitrate")
    local track = obs.obs_data_get_int(settings, "audio_track")
    if track and track >= 1 and track <= 6 then
        g_track = track
    end
    log("settings: enabled=%s track=%d bitrate=%d", tostring(g_enabled), g_track, g_bitrate)
end

function script_load(settings)
    obs.obs_frontend_add_event_callback(on_event)
end

function script_unload()
    release_encoder()
end
