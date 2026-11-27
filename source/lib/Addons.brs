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

' M4 (contrato 13): catálogo suporta busca? O manifest declara extras no catálogo
' ({ extra: [{ name: "search" }] }) — zero hardcode de id de addon.
function HasSearchExtra(catalog as object) as boolean
    if catalog = invalid or not catalog.doesExist("extra") or catalog.extra = invalid then
        return false
    end if
    for each e in catalog.extra
        ' guard: extra codificado como string não contém array de objetos — aborta
        if type(e) <> "roAssociativeArray" then exit for
        if e.doesExist("name") and e.name = "search" then
            return true
        end if
    end for
    return false
end function

' Percent-encoder com semântica encodeURIComponent p/ valores de extra PATH (contrato 13).
' Byte a byte (len()/mid() percorrem BYTES em BrightScript — UTF-8 sai correto):
' só os unreserved de RFC 3986 passam; todo o resto vira %XX. O global EncodeUriComponent
' do plano não é conhecido do toolchain (lint BS1140) — encoder local roda em qualquer firmware.
function UrlPathEncode(value as string) as string
    if value.len() = 0 then
        return ""
    end if
    hexChars = "0123456789ABCDEF"
    out = ""
    for i = 1 to value.len()
        ch = value.mid(i, 1)
        code = Asc(ch)
        if (code >= 97 and code <= 122) or (code >= 65 and code <= 90) or (code >= 48 and code <= 57) or code = 45 or code = 46 or code = 95 or code = 126 then
            out = out + ch
        else
            out = out + "%" + hexChars.mid(code \ 16 + 1, 1) + hexChars.mid(code mod 16 + 1, 1)
        end if
    end for
    return out
end function

' Extras Stremio são PATH segments (query ?search= é IGNORADO pelos addons — contrato 13):
' /catalog/{type}/{id}/search={query}.json com o valor URL-encodado.
function SearchCatalogUrl(baseUrl as string, catalogType as string, catalogId as string, query as string) as string
    return baseUrl + "/catalog/" + catalogType + "/" + catalogId + "/search=" + UrlPathEncode(query) + ".json"
end function
