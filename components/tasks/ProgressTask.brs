' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' ProgressTask — sync M3 (contrato 12). pull: GET order=last_watched.desc (RLS)
' + ProgressFilterContinue. push: POST merge-duplicates COM user_id do Registry
' (sem user_id → "no_user_id" SEM HTTP). Só roda com sessão viva.

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
    if m.top.mode = "push" then
        RunPush(anonKey, accessToken)
    else
        RunPull(anonKey, accessToken)
    end if
end sub

sub RunPull(anonKey as string, accessToken as string)
    url = getBackendUrl() + "/rest/v1/watch_progress?select=content_id,content_type,season,episode,position,duration,progress_key,video_id,last_watched&profile_id=eq." + SessionRead("active_profile_id") + "&order=last_watched.desc&limit=50"
    resp = HttpGetJson(url, AuthBearerHeaders(anonKey, accessToken))
    if not resp.ok or resp.json = invalid or type(resp.json) <> "roArray" then
        m.top.error = resp.error
        return
    end if
    m.top.rowsJson = FormatJson(ProgressFilterContinue(resp.json))
    m.top.success = true
end sub

sub RunPush(anonKey as string, accessToken as string)
    userId = SessionRead("user_id")
    if userId = "" then
        m.top.error = "no_user_id"
        return
    end if
    row = parseJson(m.top.progressRowJson)
    if row = invalid then
        m.top.error = "invalid_row"
        return
    end if
    row.user_id = userId
    row.profile_id = SessionRead("active_profile_id").toInt()
    body = FormatJson(row)
    tx = HttpNewTransfer()
    ' on_conflict congela o upsert na unique key (user_id,profile_id,progress_key) —
    ' sem ele o merge-duplicates do PostgREST aplica a chave default (id da tabela)
    tx.setUrl(getBackendUrl() + "/rest/v1/watch_progress?on_conflict=user_id,profile_id,progress_key")
    tx.addHeader("apikey", anonKey)
    tx.addHeader("Authorization", "Bearer " + accessToken)
    tx.addHeader("Content-Type", "application/json")
    tx.addHeader("Prefer", "resolution=merge-duplicates")
    tx.setMessagePort(m.httpPort)
    tx.asyncPostFromString(body)
    resp = HttpWaitResponse(tx)
    if not resp.ok then
        m.top.error = resp.error
        return
    end if
    m.top.success = true
end sub
