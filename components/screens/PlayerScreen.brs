' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' PlayerScreen — Video node nativo (spec §3.4): url+streamFormat no content node,
' legendas sidecar SRT via SubtitleTracks (contrato 11) com auto-select "por"
' (subtitleTrack = TrackName), fallback por erro (state "error" + errorCode -5 =
' unsupported media → MainScene avança stream), resume: seek inicial + save periódico
' (Timer 15s em playing; pause/back salvam; finished limpa). Back = salva posição +
' exitRequested. M3: progressPing (JSON {position,duration} em segundos) emitido no
' fire do timer, no paused e no back — MainScene observa e faz push ao servidor.

sub init()
    m.video = m.top.findNode("player")
    m.video.observeField("state", "OnPlayerState")
    ' streamJson/subsJson usam os onChange declarados no XML — observeField duplicado
    ' dispararia o handler duas vezes por mudança.
    m.saveTimer = m.top.findNode("saveTimer")
    m.saveTimer.observeField("fire", "OnSaveTimer")
    m.subTracks = []
    m.subTrackName = ""
end sub

sub OnStreamSet()
    ' "" = marker do reset em StartPlay — payload legítimo nunca é vazio
    if m.top.streamJson = "" then
        return
    end if
    stream = parseJson(m.top.streamJson)
    if stream = invalid or stream.url = "" then
        m.top.playFailed = true
        return
    end if
    ' limpa tracks do item anterior — StartPlay sempre roda StartSubsTask em seguida
    m.subTracks = []
    m.subTrackName = ""
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
        m.saveTimer.control = "stop"
        m.top.playFailed = true
        return
    end if
    if state = "finished" then
        m.saveTimer.control = "stop"
        ResumeClear(m.top.itemId)
        m.top.playFinished = true
        return
    end if
    if state = "playing" then
        m.saveTimer.control = "start"
        if m.subTrackName <> "" then
            m.video.subtitleTrack = m.subTrackName
        end if
    else if state = "paused" or state = "buffering" or state = "stopping" or state = "stopped" then
        if state = "paused" and m.top.itemId <> "" then
            ResumeSavePosition(m.top.itemId, m.video.position)
            EmitProgressPing()
        end if
    end if
end sub

sub OnSaveTimer()
    if m.video.state = "playing" and m.top.itemId <> "" then
        ResumeSavePosition(m.top.itemId, m.video.position)
        EmitProgressPing()
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "back" then
        m.saveTimer.control = "stop"
        seconds = m.video.position
        if seconds > 0 and m.top.itemId <> "" then
            ResumeSavePosition(m.top.itemId, seconds)
        end if
        ' ping ANTES do video stop — depois dele o position zera e o push perderia a posição
        EmitProgressPing()
        m.video.control = "stop"
        m.top.exitRequested = true
        return true
    end if
    return false
end function

' Ping p/ o MainScene (push M3): JSON {position, duration} em segundos do Video node.
sub EmitProgressPing()
    ping = { position: m.video.position, duration: m.video.duration }
    m.top.progressPing = FormatJson(ping)
end sub
