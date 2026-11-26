' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' Resume local (spec §3.4): posição por item em roRegistrySection "nuvio".
' Keys: res_<itemId> com ":"→"_" (registry key não aceita ":") — ex. res_tt0944947_1_1.
' Persistido só até M3 (watch-progress sync no backend assume o "continuar assistindo").

function ResumeKey(itemId as string) as string
    key = ""
    for i = 1 to itemId.len()
        ch = itemId.mid(i - 1, 1)
        if ch = ":" then
            key = key + "_"
        else
            key = key + ch
        end if
    end for
    return "res_" + key
end function

function ResumeGetPosition(itemId as string) as integer
    v = SessionRead(ResumeKey(itemId))
    if v = "" then
        return 0
    end if
    return v.toInt()
end function

function ResumeSavePosition(itemId as string, seconds as integer) as boolean
    if itemId = "" or seconds <= 0 then
        return false
    end if
    return SessionWrite(ResumeKey(itemId), seconds.toStr())
end function

function ResumeClear(itemId as string) as boolean
    return SessionDeleteKey(ResumeKey(itemId))
end function
