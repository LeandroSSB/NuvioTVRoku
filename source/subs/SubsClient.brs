' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' SubsClient — legendas via addons com resource "subtitles" (contrato 11):
' {subtitles:[{id,url,lang}]}, arquivo SRT (nativo sidecar Roku). O perfil pode não
' ter addon de legendas (perfil 1 do usuário) → {ok:false, error:"no_subs_found",
' tracks:[]} — NÃO bloqueia o play (spec §4). Language usa o código ISO-639-2 do addon.

function SUB_LANG_PRIORITY(lang as string) as integer
    if lang = "por" or lang = "pob" then
        return 0
    end if
    if lang = "eng" then
        return 1
    end if
    return 2
end function

sub SUB_SORT_TRACKS(tracks as object)
    n = tracks.count()
    for i = 1 to n - 1
        key = tracks[i]
        j = i - 1
        while j >= 0 and SUB_LANG_PRIORITY(tracks[j].Language) > SUB_LANG_PRIORITY(key.Language)
            tracks[j + 1] = tracks[j]
            j = j - 1
        end while
        tracks[j + 1] = key
    end for
end sub

function FetchSubtitleTracks(anonKey as string, accessToken as string, itemType as string, itemId as string) as object
    result = { ok: false, error: "", tracks: [] }
    url = getBackendUrl() + "/rest/v1/addons?select=name,url&profile_id=eq." + SessionRead("active_profile_id") + "&enabled=eq.true&order=sort_order.asc"
    if SessionRead("active_profile_id") = "" then
        result.error = "no_profile"
        return result
    end if
    resp = HttpGetJson(url, AuthBearerHeaders(anonKey, accessToken))
    if not resp.ok or resp.json = invalid or type(resp.json) <> "roArray" then
        result.error = "addons_failed"
        return result
    end if
    for each addon in BuildAddonList(resp.json)
        mResp = HttpGetJson(addon.manifestUrl, { })
        manifest = ParseManifest(mResp.json)
        if manifest.types <> invalid and (SupportsType(manifest.types, itemType) or manifest.types.count() = 0) then
            if manifest.hasSubtitles = true then
                baseUrl = AddonBaseUrl(addon.manifestUrl)
                sResp = HttpGetJson(baseUrl + "/subtitles/" + itemType + "/" + itemId + ".json", { })
                if sResp.ok and sResp.json <> invalid and sResp.json.doesExist("subtitles") and sResp.json.subtitles <> invalid then
                    for each subtitle in sResp.json.subtitles
                        if subtitle.doesExist("url") and subtitle.url <> invalid and subtitle.url <> "" then
                            lang = ""
                            if subtitle.doesExist("lang") and subtitle.lang <> invalid then
                                lang = subtitle.lang
                            end if
                            desc = addon.name + " (" + lang + ")"
                            result.tracks.push({ TrackName: subtitle.url, Language: lang, Description: desc })
                        end if
                    end for
                    if result.tracks.count() > 0 then
                        SUB_SORT_TRACKS(result.tracks)
                        result.ok = true
                        return result
                    end if
                end if
            end if
        end if
    end for
    result.error = "no_subs_found"
    return result
end function
