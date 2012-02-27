--[==========================================================================[
 airplay.lua: HTTP AirPlay target support module for VLC
--[==========================================================================[
 Copyright (C) 2012 the VideoLAN team and authors
 $Id$

 Authors: Brendon Justin <brendonjustin@gmail.com>

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.

 The AirPlay protocol and the strings APPLETV_SERVER_INFO and PLAYBACK_INFO
 are based on and copied from, respectively, code in Airplayer:
 https://github.com/PascalW/Airplayer
--]==========================================================================]

--[==========================================================================[
Configuration options:
 * none (port must be passed as a command-line argument to VLC)
--]==========================================================================]

-- Lua modules
require "common"
require "string"

-- TODO: use these
local mimes = {
    biplist = "application/x-apple-binary-plist",
    plist = "text/x-apple-plist+xml",
}

local APPLETV_SERVER_INFO = [[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>deviceid</key>
<string>58:55:CA:06:BD:9E</string>
<key>features</key>
<integer>119</integer>
<key>model</key>
<string>AppleTV2,1</string>
<key>protovers</key>
<string>1.0</string>
<key>srcvers</key>
<string>101.10</string>
</dict>
</plist>]]

PLAYBACK_INFO = [[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>duration</key>
<real>%f</real>
<key>loadedTimeRanges</key>
<array>
    <dict>
        <key>duration</key>
        <real>%f</real>
        <key>start</key>
        <real>0.0</real>
    </dict>
</array>
<key>playbackBufferEmpty</key>
<true/>
<key>playbackBufferFull</key>
<false/>
<key>playbackLikelyToKeepUp</key>
<true/>
<key>position</key>
<real>%f</real>
<key>rate</key>
<real>%d</real>
<key>readyToPlay</key>
<true/>
<key>seekableTimeRanges</key>
<array>
    <dict>
        <key>duration</key>
        <real>%f</real>
        <key>start</key>
        <real>0.0</real>
    </dict>
</array>
</dict>
</plist>]]

-- POST
function callback_reverse(data, url, request, type, addr, host)
    vlc.msg.dbg("callback_reverse")

    --  Requests don't seem to finish without the content-length header
    --  and some placeholder text
    return [[Status: 101
Upgrade: PTTH/1.0
Connection: Upgrade
Content-Length: 18

Placeholder text.
]]
end

-- POST
function callback_play(data, url, request, type, in_var, addr, host)
    vlc.msg.dbg("callback_play")
    if in_var then
        vlc.msg.dbg("in_var: "..in_var)
        local i, j = string.find(in_var, "Location: ")
        local k = string.find(in_var, "Start")
        local playback_url = string.sub(in_var, j+1, k-2)
        i, j = string.find(in_var, "Position: ")
        local start_time = string.sub(in_var, j+1)

        vlc.playlist.add({{path=vlc.strings.make_uri(playback_url)}})

        local input = vlc.object.input()
        if input then
            vlc.var.set(input, "position", start_time)
        end
    end

    return [[Status: 200
Content-Length: 18

Placeholder text.
]]
end

-- POST
-- GET
-- type 2 is get, type 4 is post
function callback_scrub(data, url, request, type, in_var, addr, host)
    if type and type == 2 then
        vlc.msg.dbg("callback_scrub (GET)")
    elseif type == 4 then
        vlc.msg.dbg("callback_scrub (POST)")
    end
    
    local scrub_body = nil

    if type == 2 then
        -- GET
        scrub_body = [[duration: %f
position: %f
]]
        local input = vlc.object.input()

        if input then
            local duration = nil
            local position = nil

            duration = vlc.var.get(input,"length")
            if not duration then
                vlc.msg.dbg("duration nil")
                duration = 0
            else
                vlc.msg.dbg("duration: "..duration)
            end

            position = vlc.var.get(input,"time")
            if not position then
                vlc.msg.dbg("position nil")
                position = 0
            else
                vlc.msg.dbg("position: "..position)
            end

            scrub_body = string.format(scrub_body, duration, position)
            
            return [[Content-Length: ]]..string.len(scrub_body)..[[


]]..scrub_body..[[

]]
        end
    elseif type == 4 then
        -- POST
        local position = nil
        request = string.gsub(request, "position=", "")
        position = tonumber(request)
        common.seek(math.floor(position))
    end

    return [[Status: 200
Content-Length: 18

Placeholder text.
]]
end

-- POST
function callback_rate(data, url, request, type, in_var, addr, host)
    vlc.msg.dbg("callback_rate")

    if request then
        rate_string = string.gsub(request, "value=", "")
        rate = tonumber(rate_string)
        
        if rate == 0 then
            vlc.playlist.pause()
        else
            vlc.playlist.play()
        end
    end

    return [[Status: 200
Content-Length: 18

Placeholder text.
]]
end

-- PUT
-- Note that this doesn't work yet
function callback_photo(data, url, request, type, in_var, addr, host)
    vlc.msg.dbg("callback_photo, ignored (unsupported)")

    if type == 5 then
        if in_var then
            vlc.msg.dbg("in_var: "..in_var)
        end
    end

    return [[Status: 200
Content-Length: 18

Placeholder text.
]]
end

-- POST
-- GET
-- type 2 is get, type 4 is post
function callback_authorize(data, url, request, type, in_var, addr, host)
    vlc.msg.warn("Trying to play DRM protected video, currently unsupported.")

    if type == 2 then
        vlc.msg.dbg("callback_authorize (GET), ignored (unsupported)")
    elseif type == 4 then
        vlc.msg.dbg("callback_authorize (POST), ignored (unsupported)")
    end

    return [[Status: 200
Content-Length: 18

Placeholder text.
]]
end

-- GET
function callback_server_info(data, url, request, type, addr, host)
    vlc.msg.dbg("callback_server_info")

    return [[Content-Type: text/x-apple-plist+xml
Content-Length: ]]..string.len(APPLETV_SERVER_INFO)..[[


]]..APPLETV_SERVER_INFO..[[

]]
end

-- GET
function callback_slideshow_features(data, url, request, type, in_var, addr, host)
    vlc.msg.dbg("callback_slideshow_features")

    return [[Status: 200
Content-Length: 18

Placeholder text.
]]
end

-- GET
-- Note that this doesn't set the scrub position on the device properly
function callback_playback_info(data, url, request, type, in_var, addr, host)
    vlc.msg.dbg("callback_playback_info")

    local info_string = ""
    local duration =  0
    local position = 0
    local playing = 0

    local input = vlc.object.input()

    if input then
        duration = vlc.var.get(input,"length")
        if not duration then
            duration = 0
        else
            vlc.msg.dbg("duration: "..duration)
        end

        position = vlc.var.get(input,"time")
        if not position then
            position = 0
        else
            vlc.msg.dbg("position: "..position)
        end
    end

    if vlc.playlist.status() == "playing" then
        playing = 1
    else
        playing = 0
    end

    info_string = string.format(PLAYBACK_INFO, duration, duration, position, playing, duration)

    return [[Content-Type: text/x-apple-plist+xml
Content-Length: ]]..string.len(info_string)..[[


]]..info_string..[[

]]
end

-- POST
function callback_stop(data, url, request, type, in_var, addr, host)
    vlc.msg.dbg("callback_stop")
    vlc.playlist.stop()

    return [[Status: 200
Content-Length: 18

Placeholder text.
]]
end

if config then
    if config.host then
        vlc.msg.err("\""..config.host.."\" HTTP host ignored")
        local port = string.match(config.host, ":(%d+)[^]]*$")
        vlc.msg.info("Pass --http-host=IP "..(port and "and --http-port="..port.." " or "").."on the command line instead.")
    end
end

--  Start broadcasting AirPlay support via Bonjour/Avahi
bc = vlc.airplay_bonjour()
h = vlc.httpd()

local reverse = h:handler("/reverse",nil,nil,nil,callback_reverse,nil)
local play = h:handler("/play",nil,nil,nil,callback_play,nil)
local scrub = h:handler("/scrub",nil,nil,nil,callback_scrub,nil)
local rate = h:handler("/rate",nil,nil,nil,callback_rate,nil)
local photo = h:handler("/photo",nil,nil,nil,callback_photo,nil)
local authorize = h:handler("/authorize",nil,nil,nil,callback_authorize,nil)
local srv_info = h:handler("/server-info",nil,nil,nil,callback_server_info,nil)
local slideshow_fts = h:handler("/slideshow-features",nil,nil,nil,callback_slideshow_features,nil)
local playback_info = h:handler("/playback-info",nil,nil,nil,callback_playback_info,nil)
local stop = h:handler("/stop",nil,nil,nil,callback_stop,nil)

while not vlc.misc.lock_and_wait() do end -- everything happens in callbacks
