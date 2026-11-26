' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' Streams — parse do contrato 10 ({streams:[{url,name,description,behaviorHints.filename}]})
' e deteção de StreamFormat p/ o Video node. AVI é marcado (Roku não reproduz) e
' filtrado; desconhecido → "" (caller decide o default "mp4" com fallback por erro,
' spec §4: direct-play falhou → próxima stream).

function DetectStreamFormat(url as string, filenameHint as string) as string
    sources = [url, filenameHint]
    for each src in sources
        if src <> invalid and src.len() > 0 then
            lower = LCase(src)
            if StreamTailMatches(lower, ".mkv") or StreamTailMatches(lower, ".mk3d") or StreamTailMatches(lower, ".mka") or StreamTailMatches(lower, ".mks") then
                return "mkv"
            end if
            if StreamTailMatches(lower, ".mp4") or StreamTailMatches(lower, ".m4v") or StreamTailMatches(lower, ".mov") then
                return "mp4"
            end if
            if StreamTailMatches(lower, ".m3u8") then
                return "hls"
            end if
            if StreamTailMatches(lower, ".avi") then
                return "avi"
            end if
        end if
    end for
    return ""
end function

' match de sufixo tolerante a query string: "?..." cortado antes de comparar
' (inStr é 0-based, mid é 1-based — por isso o +1 na janela)
function StreamTailMatches(lowerSrc as string, ext as string) as boolean
    if lowerSrc.right(ext.len()) = ext then
        return true
    end if
    q = lowerSrc.inStr("?")
    if q >= ext.len() and lowerSrc.mid(q - ext.len() + 1, ext.len()) = ext then
        return true
    end if
    return false
end function

function ParseStreams(streamsJson as object) as object
    result = []
    for each s in streamsJson
        url = ""
        if s.doesExist("url") and s.url <> invalid then
            url = s.url
        end if
        if url <> "" then
            name = ""
            if s.doesExist("name") and s.name <> invalid then
                name = s.name
            end if
            description = ""
            if s.doesExist("description") and s.description <> invalid then
                description = s.description
            end if
            hint = ""
            if s.doesExist("behaviorHints") and s.behaviorHints <> invalid and s.behaviorHints.doesExist("filename") and s.behaviorHints.filename <> invalid then
                hint = s.behaviorHints.filename
            end if
            result.push({ name: name, description: description, url: url, format: DetectStreamFormat(url, hint) })
        end if
    end for
    return result
end function

function FilterPlayable(streams as object) as object
    result = []
    for each s in streams
        if s.format <> "avi" and s.url <> "" then
            result.push(s)
        end if
    end for
    return result
end function
