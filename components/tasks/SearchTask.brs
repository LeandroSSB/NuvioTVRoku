' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' SearchTask — busca Stremio PATH-form (contrato 13): addons POR PERFIL → manifests →
' catálogos com extra "search" (HasSearchExtra — zero hardcode) → /catalog/{type}/{id}/
' search={q}.json (extras são PATH segment — ?search= é ignorado pelos addons).
' Máx 3 addons (não serializar demais); dedupe por id; cap 30. Zero resultados NÃO é
' erro: sucesso com items [] — a SearchScreen mostra "Sem resultados". Erro só quando
' o fetch da tabela addons falha (ou sessão/well-known).

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
    RunSearch(anonKey, accessToken)
end sub

sub RunSearch(anonKey as string, accessToken as string)
    url = getBackendUrl() + "/rest/v1/addons?select=name,url&profile_id=eq." + SessionRead("active_profile_id") + "&enabled=eq.true&order=sort_order.asc"
    resp = HttpGetJson(url, AuthBearerHeaders(anonKey, accessToken))
    if not resp.ok or resp.json = invalid or type(resp.json) <> "roArray" then
        m.top.error = resp.error
        return
    end if
    addons = BuildAddonList(resp.json)
    if addons.count() > 3 then
        capped = []
        for i = 0 to 2
            capped.push(addons[i])
        end for
        addons = capped
    end if
    items = []
    seen = { }
    for each addon in addons
        mResp = HttpGetJson(addon.manifestUrl, { })
        manifest = ParseManifest(mResp.json)
        if manifest.catalogs.count() > 0 then
            baseUrl = AddonBaseUrl(addon.manifestUrl)
            for each cat in manifest.catalogs
                if items.count() < 30 and HasSearchExtra(cat) and (cat.type = "movie" or cat.type = "series") then
                    sResp = HttpGetJson(SearchCatalogUrl(baseUrl, cat.type, cat.id, m.top.query), { })
                    if sResp.ok and sResp.json <> invalid and sResp.json.doesExist("metas") and sResp.json.metas <> invalid then
                        for each meta in sResp.json.metas
                            item = ParseCatalogItem(meta)
                            if item.id <> "" and not seen.doesExist(item.id) then
                                seen[item.id] = true
                                items.push(item)
                            end if
                            if items.count() >= 30 then
                                exit for
                            end if
                        end for
                    end if
                end if
                if items.count() >= 30 then
                    exit for
                end if
            end for
        end if
        if items.count() >= 30 then
            exit for
        end if
    end for
    m.top.resultsJson = FormatJson(items)
    m.top.success = true
end sub
