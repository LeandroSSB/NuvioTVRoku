' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' Addons — normalização de URLs da tabela `addons` e descoberta de manifests.
' A tabela mistura 3 formas de URL (contratos 03/04/06/09): base pura (OpenSubtitles),
' <base>/manifest.json (maioria), e manifest completo .json (ex.: Nuvio Catalog
' <base>/<token>.json). Dedupe por manifestUrl — o M0 dedupava a união de perfis;
' o app real consulta POR PERFIL (profile_id=eq.N) e mantém o dedupe defensivo.

function NormalizeAddonUrl(url as string) as string
    if url.len() = 0 then
        return ""
    end if
    if url.right(14) = "/manifest.json" then
        return url
    end if
    if url.right(5) = ".json" then
        ' forma completa (<base>/<token>.json) já É o manifest
        return url
    end if
    return url + "/manifest.json"
end function

function AddonBaseUrl(manifestUrl as string) as string
    if manifestUrl.right(14) = "/manifest.json" then
        return manifestUrl.left(manifestUrl.len() - 14)
    end if
    if manifestUrl.right(5) = ".json" then
        ' base = diretório do manifest completo
        i = manifestUrl.len() - 1
        while i > 0 and manifestUrl.mid(i, 1) <> "/"
            i = i - 1
        end while
        if i > 0 then
            return manifestUrl.left(i)
        end if
    end if
    return manifestUrl
end function

function BuildAddonList(addonsJson as object) as object
    result = []
    seen = { }
    for each row in addonsJson
        if row.doesExist("url") and row.url <> invalid and row.url.len() > 0 then
            manifestUrl = NormalizeAddonUrl(row.url)
            if not seen.doesExist(manifestUrl) then
                seen[manifestUrl] = true
                entry = { name: "", manifestUrl: manifestUrl }
                if row.doesExist("name") and row.name <> invalid then
                    entry.name = row.name
                end if
                result.push(entry)
            end if
        end if
    end for
    return result
end function

function SupportsType(types as object, wanted as string) as boolean
    for each t in types
        if t = wanted then
            return true
        end if
    end for
    return false
end function
