' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' LibraryTask — biblioteca M4 (library_items). pull: GET order=added_at.desc (RLS)
' → ParseLibraryRows → itemsJson. add/remove via RPCs de sync da tabela
' (sondagem 27/11, conta sub): o POST ?on_conflict=user_id,profile_id,content_id do
' plano NÃO existe (42P10 — a tabela não tem essa unique constraint) e o
' X-HTTP-Method-Override: DELETE é IGNORADO (400 PGRST102 — PostgREST vê POST/insert);
' roUrlTransfer não envia DELETE. sync_push_library_items VALIDADO ao vivo (204,
' snapshot gravado + dedupe por user/profile/content). sync_delete_library_items
' existe e autentica, mas p_keys=[content_id] não deletou em NENHUMA forma testada
' (no-op silencioso 204) — shape não documentada; device-phase revisa (o remove
' vira erro só se o RPC recusar; no-op passa como sucesso).

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
    if m.top.mode = "add" then
        RunAdd(anonKey, accessToken)
    else if m.top.mode = "remove" then
        RunRemove(anonKey, accessToken)
    else
        RunPull(anonKey, accessToken)
    end if
end sub

sub RunPull(anonKey as string, accessToken as string)
    url = getBackendUrl() + "/rest/v1/library_items?select=content_id,content_type,name,poster,background,description,genres,imdb_rating,release_info,poster_shape&profile_id=eq." + SessionRead("active_profile_id") + "&order=added_at.desc&limit=50"
    resp = HttpGetJson(url, AuthBearerHeaders(anonKey, accessToken))
    if not resp.ok or resp.json = invalid or type(resp.json) <> "roArray" then
        m.top.error = resp.error
        return
    end if
    m.top.itemsJson = FormatJson(ParseLibraryRows(resp.json))
    m.top.success = true
end sub

sub RunAdd(anonKey as string, accessToken as string)
    userId = SessionRead("user_id")
    if userId = "" then
        m.top.error = "no_user_id"
        return
    end if
    profileIdStr = SessionRead("active_profile_id")
    if profileIdStr = "" then
        m.top.error = "no_profile_id"
        return
    end if
    row = parseJson(m.top.rowJson)
    if row = invalid then
        m.top.error = "invalid_row"
        return
    end if
    row.user_id = userId
    payload = { p_items: [row], p_profile_id: profileIdStr.toInt(), p_origin_client_id: "nuviotvroku" }
    resp = HttpPostJson(getBackendUrl() + "/rest/v1/rpc/sync_push_library_items", AuthBearerHeaders(anonKey, accessToken), FormatJson(payload))
    if not resp.ok then
        m.top.error = resp.error
        return
    end if
    m.top.success = true
end sub

sub RunRemove(anonKey as string, accessToken as string)
    profileIdStr = SessionRead("active_profile_id")
    if profileIdStr = "" then
        m.top.error = "no_profile_id"
        return
    end if
    row = parseJson(m.top.rowJson)
    if row = invalid or not row.doesExist("content_id") or row.content_id = "" then
        m.top.error = "invalid_row"
        return
    end if
    payload = { p_keys: [row.content_id], p_profile_id: profileIdStr.toInt() }
    resp = HttpPostJson(getBackendUrl() + "/rest/v1/rpc/sync_delete_library_items", AuthBearerHeaders(anonKey, accessToken), FormatJson(payload))
    if not resp.ok then
        m.top.error = resp.error
        return
    end if
    m.top.success = true
end sub
