' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' SessionTask — login (password grant) OU boot (refresh grant) + fetch de perfis.
' Contratos 02/07/08. Em boot com refresh morto: limpa sessão → app pede login.

sub init()
    HttpInit()
end sub

sub execute()
    m.top.success = false
    anonKey = ResolveAnonKey(getBackendUrl())
    if anonKey = "" then
        m.top.error = "well_known_failed"
        return
    end if
    auth = invalid
    if m.top.mode = "boot" then
        auth = AuthRefresh(anonKey, SessionGetRefreshToken())
        if not auth.ok then
            SessionClearSession()
            m.top.error = "session_expired"
            return
        end if
    else
        auth = AuthLogin(anonKey, m.top.email, m.top.password)
        if not auth.ok then
            m.top.error = auth.error
            return
        end if
    end if
    SessionSaveTokens(auth.refreshToken)
    profiles = FetchProfiles(anonKey, auth.accessToken)
    if profiles = invalid then
        m.top.error = "profiles_failed"
        return
    end if
    if profiles.count() = 0 then
        m.top.error = "profiles_empty"
        return
    end if
    m.top.profilesJson = FormatJson(profiles)
    m.top.success = true
end sub
