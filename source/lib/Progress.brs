' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' Progress — helpers do sync M3 (contrato 12). Servidor em MILESegundos + epoch ms;
' Video node em segundos. progress_key/video_id espelham o mobile: série
' ttXXX_sXeY / video_id ttXXX:s:e; filme ttXXX / ttXXX.

function ProgressIsEpisode(itemId as string) as boolean
    ' qualquer id com ≥2 ":" tem episódio no final (kitsu:50697:1:1 também)
    q1 = -1
    q2 = -1
    for i = itemId.len() - 1 to 0 step -1
        if itemId.right(itemId.len() - i).left(1) = ":" then
            if q2 = -1 then
                q2 = i
            else
                q1 = i
                exit for
            end if
        end if
    end for
    return q1 <> -1
end function

' inStrRev NÃO existe no ifStringOps (roString só tem Instr, 0-based, -1 se não
' achar — docs Roku + emulador brs). Loop manual de trás pra frente no padrão
' de Addons.brs AddonBaseUrl; devolve índice 0-based do último ":" ou -1 se não
' houver. Scan só com right/left — mid tem base ambígua entre fontes (docs/brs:
' 0-based; revisão final M2 assumiu 1-based).
function ProgressLastColon(itemId as string) as integer
    i = itemId.len() - 1
    while i >= 0
        if itemId.right(itemId.len() - i).left(1) = ":" then
            return i
        end if
        i = i - 1
    end while
    return -1
end function

function ProgressBuildKey(itemId as string) as string
    if not ProgressIsEpisode(itemId) then
        return itemId
    end if
    ' split nos DOIS ÚLTIMOS ":" (kitsu:50697:1:1 → content_id "kitsu:50697",
    ' igual ao mobile — server data 26/11). Extração só com right/left:
    ' right(...).left(q2-q1-1) ≡ mid(q1+1, q2-q1-1) e right(...) ≡ mid(q2+1).
    q2 = ProgressLastColon(itemId)
    q1 = ProgressLastColon(itemId.left(q2))
    season = itemId.right(itemId.len() - q1 - 1).left(q2 - q1 - 1)
    episode = itemId.right(itemId.len() - q2 - 1)
    return itemId.left(q1) + "_s" + season + "e" + episode
end function

function ProgressBuildVideoId(itemId as string) as string
    return itemId
end function

function ProgressSecondsToMs(seconds as integer) as integer
    return seconds * 1000
end function

function ProgressMsToSeconds(ms as integer) as integer
    return ms \ 1000
end function

function ProgressFilterContinue(rows as object) as object
    result = []
    for each r in rows
        ' "pos" é palavra reservada do BrightScript (lint BS1045/BS1147) — posMs
        posMs = 0
        dur = 0
        if r.doesExist("position") and r.position <> invalid then
            posMs = r.position
        end if
        if r.doesExist("duration") and r.duration <> invalid then
            dur = r.duration
        end if
        if posMs > 0 and dur > 0 and posMs < dur * 0.95 then
            result.push(r)
        end if
    end for
    return result
end function

function ProgressToServerRow(itemId as string, contentType as string, positionSeconds as integer, durationSeconds as integer) as object
    row = { content_id: itemId, content_type: contentType, season: invalid, episode: invalid,
            position: ProgressSecondsToMs(positionSeconds), duration: ProgressSecondsToMs(durationSeconds),
            progress_key: ProgressBuildKey(itemId), video_id: ProgressBuildVideoId(itemId),
            last_watched: CreateObject("roDateTime").AsSecondsIntervalSince1970() * 1000& }
    if ProgressIsEpisode(itemId) then
        q2 = ProgressLastColon(itemId)
        q1 = ProgressLastColon(itemId.left(q2))
        row.content_id = itemId.left(q1)
        row.season = itemId.right(itemId.len() - q1 - 1).left(q2 - q1 - 1).toInt()
        row.episode = itemId.right(itemId.len() - q2 - 1).toInt()
    end if
    return row
end function
