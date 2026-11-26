' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' MetaTask — meta do Detail com FALLBACK entre addons (contrato 09):
' o 1º addon com resource "meta" pode não entregar meta real — itera até um entregar.
' Série exige videos não-vazio; filme exige meta.name. Anime tenta "anime" e "series".
' Meta é fetch público (URL-token): SEM Bearer.

sub init()
    HttpInit()
end sub

sub execute()
    m.top.success = false
    m.top.error = ""
    addons = parseJson(m.top.addonsJson)
    if addons = invalid or type(addons) <> "roArray" then
        m.top.error = "no_meta_addon"
        return
    end if
    ' animes são séries no protocolo Stremio — tenta o tipo do item e o alias
    wantedTypes = [m.top.metaType]
    if m.top.metaType = "anime" then
        wantedTypes.push("series")
    end if
    for each addon in addons
        if addon.hasMeta = true and addon.baseUrl <> invalid and addon.baseUrl.len() > 0 then
            for each wType in wantedTypes
                if SupportsType(addon.types, wType) then
                    url = addon.baseUrl + "/meta/" + wType + "/" + m.top.metaId + ".json"
                    resp = HttpGetJson(url, { })
                    meta = invalid
                    if resp.ok and resp.json <> invalid and resp.json.doesExist("meta") then
                        meta = resp.json.meta
                    end if
                    if meta <> invalid then
                        if wType = "series" or wType = "anime" then
                            if meta.doesExist("videos") and meta.videos <> invalid and meta.videos.count() > 0 then
                                m.top.metaJson = FormatJson(meta)
                                m.top.success = true
                                return
                            end if
                        else
                            if meta.doesExist("name") and meta.name <> invalid then
                                m.top.metaJson = FormatJson(meta)
                                m.top.success = true
                                return
                            end if
                        end if
                    end if
                end if
            end for
        end if
    end for
    m.top.error = "no_meta_found"
end sub
