' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' Session — sessão persistida no roRegistrySection "nuvio" (spec §3.2).
' Persistimos APENAS refresh_token (access token expira em 2h e é re-obtido por grant
' refresh). Trocar backend = logout + re-login (M4 cuida do UI de logout).

function SessionRead(key as string) as string
    reg = createObject("roRegistrySection", "nuvio")
    if reg.exists(key) then
        return reg.read(key)
    end if
    return ""
end function

function SessionWrite(key as string, value as string) as boolean
    reg = createObject("roRegistrySection", "nuvio")
    ok = reg.write(key, value)
    reg.flush()
    return ok
end function

function SessionDeleteKey(key as string) as boolean
    reg = createObject("roRegistrySection", "nuvio")
    if reg.exists(key) then
        reg.delete(key)
    end if
    reg.flush()
    return true
end function

function SessionGetRefreshToken() as string
    return SessionRead("refresh_token")
end function

function SessionSaveTokens(refreshToken as string) as boolean
    return SessionWrite("refresh_token", refreshToken)
end function

function SessionGetActiveProfileId() as integer
    v = SessionRead("active_profile_id")
    if v <> "" then
        return v.toInt()
    end if
    return 0
end function

function SessionSaveActiveProfileId(profileId as integer) as boolean
    return SessionWrite("active_profile_id", profileId.toStr())
end function

' Apaga só dados de sessão — backend_url/anon_key permanecem (re-login não perde config).
function SessionClearSession() as boolean
    SessionDeleteKey("refresh_token")
    SessionDeleteKey("active_profile_id")
    return true
end function
