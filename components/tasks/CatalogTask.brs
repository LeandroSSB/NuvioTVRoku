' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' CatalogTask — pipeline Home (contrato 09): addons POR PERFIL → manifests → catálogos.
' mode="home": descobre addons do perfil, monta rows (eager: 2 primeiros catálogos por
' addon) e lista pendentes p/ lazy-load no foco. mode="row": fetch de 1 catálogo pendente.
' Catálogos Stremio são públicos por URL-token: fetch SEM Bearer. Addons table: COM Bearer.

sub init()
    HttpInit()
end sub

sub execute()
    m.top.success = false
    m.top.error = ""
    if m.top.mode = "row" then
        RunRowFetch()
    else
        RunHomeFetch()
    end if
end sub

sub RunHomeFetch()
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
    url = getBackendUrl() + "/rest/v1/addons?select=profile_id,name,url,enabled&profile_id=eq." + m.top.profileId.toStr() + "&enabled=eq.true&order=sort_order.asc"
    resp = HttpGetJson(url, AuthBearerHeaders(anonKey, accessToken))
    if not resp.ok or resp.json = invalid or type(resp.json) <> "roArray" then
        m.top.error = resp.error
        return
    end if
    addons = BuildAddonList(resp.json)
    rows = []
    pending = []
    addonsOut = []
    rowIndex = 0
    EAGER_PER_ADDON = 2
    MAX_ROWS = 40
    for each addon in addons
        if rowIndex < MAX_ROWS then
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
            if manifest.catalogs.count() > 0 then
                baseUrl = AddonBaseUrl(addon.manifestUrl)
                addonsOut.push({ name: addon.name, baseUrl: baseUrl, types: manifest.types, hasMeta: manifest.hasMeta })
                eagerCount = 0
                for each cat in manifest.catalogs
                    if rowIndex < MAX_ROWS and (cat.type = "movie" or cat.type = "series" or cat.type = "anime") then
                        catUrl = baseUrl + "/catalog/" + cat.type + "/" + cat.id + ".json?skip=0"
                        title = addon.name + " — " + cat.name
                        if eagerCount < EAGER_PER_ADDON then
                            rows.push({ title: title, catalogUrl: catUrl, fetched: true, items: FetchCatalogItems(catUrl) })
                        else
                            pending.push({ rowIndex: rowIndex, title: title, catalogUrl: catUrl })
                            rows.push({ title: title, catalogUrl: catUrl, fetched: false, items: [] })
                        end if
                        rowIndex = rowIndex + 1
                        eagerCount = eagerCount + 1
                    end if
                end for
            end if
        end if
    end for
    if rows.count() = 0 then
        m.top.error = "no_catalogs"
        return
    end if
    m.top.rowsJson = FormatJson(rows)
    m.top.pendingJson = FormatJson(pending)
    m.top.addonsJson = FormatJson(addonsOut)
    m.top.success = true
end sub

sub RunRowFetch()
    items = FetchCatalogItems(m.top.catalogUrl)
    m.top.itemsJson = FormatJson(items)
    m.top.success = true
end sub

function FetchCatalogItems(catUrl as string) as object
    resp = HttpGetJson(catUrl, { })
    items = []
    if resp.ok and resp.json <> invalid and resp.json.doesExist("metas") and resp.json.metas <> invalid then
        for each meta in resp.json.metas
            items.push(ParseCatalogItem(meta))
            if items.count() >= 20 then
                exit for
            end if
        end for
    end if
    return items
end function
