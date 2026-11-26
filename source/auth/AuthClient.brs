' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' AuthClient — well-known + GoTrue (login/refresh) + perfis PostgREST.
' Só executa dentro de task nodes (depende de Http.brs). Contratos: 01, 02, 07, 08.

function AuthHeaders(anonKey as string) as object
    return { "apikey": anonKey, "Content-Type": "application/json" }
end function

function AuthBearerHeaders(anonKey as string, accessToken as string) as object
    headers = AuthHeaders(anonKey)
    headers["Authorization"] = "Bearer " + accessToken
    return headers
end function

function ResolveAnonKey(backendUrl as string) as string
    ' cache por backend — trocar backend invalida (spec §3.2)
    if SessionRead("anon_key_backend") = backendUrl then
        cached = SessionRead("anon_key")
        if cached <> "" then
            return cached
        end if
    end if
    resp = HttpGetJson(backendUrl + "/.well-known/nuvio", { })
    if not resp.ok or resp.json = invalid then
        return ""
    end if
    if resp.json.doesExist("publishable_key") then
        key = resp.json.publishable_key
        SessionWrite("anon_key", key)
        SessionWrite("anon_key_backend", backendUrl)
        return key
    end if
    return ""
end function

function AuthLogin(anonKey as string, email as string, password as string) as object
    body = FormatJson({ email: email, password: password })
    resp = HttpPostJson(getBackendUrl() + "/auth/v1/token?grant_type=password", AuthHeaders(anonKey), body)
    if not resp.ok or resp.json = invalid then
        err = resp.error
        if resp.json <> invalid and resp.json.doesExist("error_description") then
            err = err + ": " + resp.json.error_description
        end if
        return { ok: false, error: err, accessToken: "", refreshToken: "" }
    end if
    if resp.json.doesExist("access_token") and resp.json.doesExist("refresh_token") then
        return { ok: true, error: "", accessToken: resp.json.access_token, refreshToken: resp.json.refresh_token }
    end if
    return { ok: false, error: "invalid_login_response", accessToken: "", refreshToken: "" }
end function

function AuthRefresh(anonKey as string, refreshToken as string) as object
    body = FormatJson({ refresh_token: refreshToken })
    resp = HttpPostJson(getBackendUrl() + "/auth/v1/token?grant_type=refresh_token", AuthHeaders(anonKey), body)
    if not resp.ok or resp.json = invalid then
        return { ok: false, error: resp.error, accessToken: "", refreshToken: "" }
    end if
    if resp.json.doesExist("access_token") then
        ' GoTrue pode rotacionar o refresh_token (contrato 08) — SEMPRE sobrescreve o salvo
        newRefresh = refreshToken
        if resp.json.doesExist("refresh_token") and resp.json.refresh_token <> invalid then
            newRefresh = resp.json.refresh_token
        end if
        return { ok: true, error: "", accessToken: resp.json.access_token, refreshToken: newRefresh }
    end if
    return { ok: false, error: "invalid_refresh_response", accessToken: "", refreshToken: "" }
end function

function RefreshAccessToken(anonKey as string, refreshToken as string) as string
    if refreshToken = "" then
        return ""
    end if
    result = AuthRefresh(anonKey, refreshToken)
    if result.ok then
        SessionSaveTokens(result.refreshToken)
        return result.accessToken
    end if
    return ""
end function

function FetchProfiles(anonKey as string, accessToken as string) as object
    url = getBackendUrl() + "/rest/v1/profiles?select=profile_id,name,avatar_color_hex,pin_enabled&order=profile_index.asc"
    resp = HttpGetJson(url, AuthBearerHeaders(anonKey, accessToken))
    if not resp.ok or resp.json = invalid or type(resp.json) <> "roArray" then
        return invalid
    end if
    return resp.json
end function
