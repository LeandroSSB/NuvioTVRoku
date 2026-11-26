' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' ProgressTask — sync M3 (contrato 12). pull: GET order=last_watched.desc (RLS)
' + ProgressFilterContinue. cw: pull + enriquecimento meta (walk de addons com
' fallback — mecânica do MetaTask) → row "Continuar assistindo" da home.
' push: POST merge-duplicates COM user_id do Registry
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
    else if m.top.mode = "cw" then
        RunContinueWatching(anonKey, accessToken)
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

' row CW da home: pull (top 24) → filtro → top 8 → meta walk (fallback entre addons,
' mesma mecânica do MetaTask). Ids que nenhuma meta aceita são PULADOS (contrato 12).
' Saída em rowsJson NO FORMATO DE ROW do HomeScreen; progresso não vai no item —
' o resume é por itemId no StartPlay.
sub RunContinueWatching(anonKey as string, accessToken as string)
    url = getBackendUrl() + "/rest/v1/watch_progress?select=content_id,content_type,position,duration,progress_key,last_watched&profile_id=eq." + SessionRead("active_profile_id") + "&order=last_watched.desc&limit=24"
    resp = HttpGetJson(url, AuthBearerHeaders(anonKey, accessToken))
    if not resp.ok or resp.json = invalid or type(resp.json) <> "roArray" then
        m.top.error = resp.error
        return
    end if
    rows = ProgressFilterContinue(resp.json)
    if rows.count() = 0 then
        m.top.rowsJson = ""
        m.top.success = true
        return
    end if
    if rows.count() > 8 then
        keep = []
        for i = 0 to 7
            keep.push(rows[i])
        end for
        rows = keep
    end if
    ' descobre os addons com resource "meta" (manifest público — SEM Bearer, igual MetaTask)
    metaAddons = []
    addonsUrl = getBackendUrl() + "/rest/v1/addons?select=name,url&profile_id=eq." + SessionRead("active_profile_id") + "&enabled=eq.true&order=sort_order.asc"
    aResp = HttpGetJson(addonsUrl, AuthBearerHeaders(anonKey, accessToken))
    if aResp.ok and aResp.json <> invalid and type(aResp.json) = "roArray" then
        for each addon in BuildAddonList(aResp.json)
            mResp = HttpGetJson(addon.manifestUrl, { })
            manifest = ParseManifest(mResp.json)
            if manifest.hasMeta = true then
                metaAddons.push({ baseUrl: AddonBaseUrl(addon.manifestUrl), types: manifest.types })
            end if
        end for
    end if
    items = []
    for each row in rows
        meta = ProgressFetchMeta(metaAddons, row.content_id, row.content_type)
        if meta <> invalid then
            item = ParseCatalogItem(meta)
            item.id = row.content_id
            item.type = row.content_type
            items.push(item)
        end if
        if items.count() >= 8 then
            exit for
        end if
    end for
    if items.count() = 0 then
        m.top.rowsJson = ""
        m.top.success = true
        return
    end if
    cw = [{ title: "Continuar assistindo", items: items }]
    m.top.rowsJson = FormatJson(cw)
    m.top.success = true
end sub

' tenta os meta addons em ordem até um entregar. Série e filme exigem O MESMO aqui
' (meta com name não-invalid): a row CW só precisa de poster/título — os videos que
' o MetaTask exige para série ficam para o Detail.
function ProgressFetchMeta(metaAddons as object, contentId as string, contentType as string) as object
    for each addon in metaAddons
        if SupportsType(addon.types, contentType) or addon.types.count() = 0 then
            resp = HttpGetJson(addon.baseUrl + "/meta/" + contentType + "/" + contentId + ".json", { })
            if resp.ok and resp.json <> invalid and resp.json.doesExist("meta") and resp.json.meta <> invalid then
                meta = resp.json.meta
                if meta.doesExist("name") and meta.name <> invalid then
                    return meta
                end if
            end if
        end if
    end for
    return invalid
end function
