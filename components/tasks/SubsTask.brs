' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' SubsTask — wrapper do SubsClient; sucesso com tracks vazio é válido (perfil sem
' addon de legendas): o JSON carrega ok/error para o PlayerScreen decidir.

sub init()
    HttpInit()
end sub

sub execute()
    m.top.success = false
    m.top.error = ""
    anonKey = ResolveAnonKey(getBackendUrl())
    if anonKey = "" then
        m.top.error = "well_known_failed"
        return
    end if
    accessToken = RefreshAccessToken(anonKey, SessionGetRefreshToken())
    if accessToken = "" then
        m.top.error = "session_expired"
        return
    end if
    result = FetchSubtitleTracks(anonKey, accessToken, m.top.subType, m.top.subId)
    m.top.subsJson = FormatJson(result)
    m.top.success = true
end sub
