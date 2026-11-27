' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' StreamTask — fetch de streams do AIOStreams do perfil (contrato 10) + parse +
' filtro AVI + resolução do formato desconhecido para "mp4" (fallback por erro no
' player). Streams de addons são públicos por URL-token: SEM Bearer no stream/*;
' addons table COM Bearer.

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
    url = getBackendUrl() + "/rest/v1/addons?select=name,url&profile_id=eq." + SessionRead("active_profile_id") + "&enabled=eq.true&order=sort_order.asc"
    resp = HttpGetJson(url, AuthBearerHeaders(anonKey, accessToken))
    if not resp.ok or resp.json = invalid or type(resp.json) <> "roArray" then
        m.top.error = resp.error
        if m.top.error = "" then
            m.top.error = "addons_invalid_response"
        end if
        return
    end if
    for each addon in BuildAddonList(resp.json)
        ' manifest via cache de sessão (Cache.brs) — só cacheia 2xx + json:
        ' falha transitória não fixa manifest vazio pela sessão
        manifest = CacheGetManifest(addon.manifestUrl)
        if manifest = invalid then
            mResp = HttpGetJson(addon.manifestUrl, { })
            manifest = ParseManifest(mResp.json)
            if mResp.ok and mResp.json <> invalid then
                CacheSetManifest(addon.manifestUrl, manifest)
            end if
        end if
        if manifest.hasStream = true and (SupportsType(manifest.types, m.top.streamType) or manifest.types.count() = 0) then
            baseUrl = AddonBaseUrl(addon.manifestUrl)
            sResp = HttpGetJson(baseUrl + "/stream/" + m.top.streamType + "/" + m.top.streamId + ".json", { })
            if sResp.ok and sResp.json <> invalid and sResp.json.doesExist("streams") and sResp.json.streams <> invalid then
                parsed = ParseStreams(sResp.json.streams)
                playable = FilterPlayable(parsed)
                if playable.count() > 0 then
                    for each s in playable
                        if s.format = "" then
                            s.format = "mp4"
                        end if
                    end for
                    m.top.streamsJson = FormatJson(playable)
                    m.top.success = true
                    return
                end if
            end if
        end if
    end for
    m.top.error = "no_playable_streams"
end sub
