' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' PlayerScreen — Video node nativo (spec §3.4): url+streamFormat no content node,
' legendas sidecar SRT via SubtitleTracks (contrato 11) com auto-select "por"
' (subtitleTrack = TrackName), fallback por erro (state "error" + errorCode -5 =
' unsupported media → MainScene avança stream), resume seek inicial (T7 liga o loop
' periódico). Back = salva posição + exitRequested.

sub init()
    m.video = m.top.findNode("player")
    m.video.observeField("state", "OnPlayerState")
    m.top.observeField("streamJson", "OnStreamSet")
    m.top.observeField("subsJson", "OnSubsSet")
    m.subTracks = []
    m.subTrackName = ""
end sub

sub OnStreamSet()
    stream = parseJson(m.top.streamJson)
    if stream = invalid or stream.url = "" then
        m.top.playFailed = true
        return
    end if
    content = createObject("roSGNode", "ContentNode")
    content.url = stream.url
    content.streamFormat = stream.format
    if m.subTracks.count() > 0 then
        content.SubtitleTracks = m.subTracks
    end if
    m.video.content = content
    if m.top.resumeSeconds > 0 then
        m.video.seek = m.top.resumeSeconds
    end if
    m.video.control = "play"
    m.video.setFocus(true)
end sub

sub OnSubsSet()
    subs = parseJson(m.top.subsJson)
    if subs = invalid or subs.tracks = invalid or subs.tracks.count() = 0 then
        return
    end if
    m.subTracks = subs.tracks
    m.subTrackName = m.subTracks[0].TrackName
    content = m.video.content
    if content <> invalid then
        content.SubtitleTracks = m.subTracks
        ' (re)set do content re-renderiza; re-aplica o play state corrente
        if m.video.state = "paused" or m.video.state = "buffering" or m.video.state = "playing" then
            m.video.subtitleTrack = m.subTrackName
        end if
    end if
end sub

sub OnPlayerState()
    state = m.video.state
    if state = "error" then
        m.top.playFailed = true
        return
    end if
    if state = "finished" then
        ResumeClear(m.top.itemId)
        m.top.playFinished = true
        return
    end if
    if state = "playing" and m.subTrackName <> "" then
        m.video.subtitleTrack = m.subTrackName
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "back" then
        seconds = m.video.position
        if seconds > 0 and m.top.itemId <> "" then
            ResumeSavePosition(m.top.itemId, seconds)
        end if
        m.video.control = "stop"
        m.top.exitRequested = true
        return true
    end if
    return false
end function
