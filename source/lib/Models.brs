' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' Models — parsers do protocolo Stremio + helpers de apresentação.
' Formas congeladas nos contratos 04 (catalog), 05 (meta série), 09 (walk completo).

function ParseManifest(manifest as object) as object
    out = { types: [], catalogs: [], hasMeta: false, hasStream: false, hasSubtitles: false }
    if manifest = invalid then
        return out
    end if
    if manifest.doesExist("types") and type(manifest.types) = "roArray" then
        out.types = manifest.types
    end if
    if manifest.doesExist("catalogs") and type(manifest.catalogs) = "roArray" then
        for each cat in manifest.catalogs
            if cat.doesExist("id") and cat.doesExist("type") then
                name = ""
                if cat.doesExist("name") and cat.name <> invalid then
                    name = cat.name
                end if
                entry = { type: cat.type, id: cat.id, name: name }
                ' M4: extras seguem com o catálogo (HasSearchExtra — busca path-form);
                ' ausente/fora de forma → campo não existe (aditivo, consumidores M1–M3 intatos)
                if cat.doesExist("extra") and type(cat.extra) = "roArray" then
                    entry.extra = cat.extra
                end if
                out.catalogs.push(entry)
            end if
        end for
    end if
    if manifest.doesExist("resources") and type(manifest.resources) = "roArray" then
        for each res in manifest.resources
            resName = res
            if type(res) = "roAssociativeArray" and res.doesExist("name") then
                resName = res.name
            end if
            if resName = "meta" then
                out.hasMeta = true
            end if
            if resName = "stream" then
                out.hasStream = true
            end if
            if resName = "subtitles" then
                out.hasSubtitles = true
            end if
        end for
    end if
    return out
end function

function ParseCatalogItem(meta as object) as object
    item = { id: "", name: "", poster: "", background: "", type: "movie",
             releaseInfo: "", imdbRating: "", description: "" }
    if meta.doesExist("id") and meta.id <> invalid then
        item.id = meta.id
    end if
    if meta.doesExist("name") and meta.name <> invalid then
        item.name = meta.name
    end if
    if meta.doesExist("poster") and meta.poster <> invalid then
        item.poster = meta.poster
    end if
    if meta.doesExist("background") and meta.background <> invalid then
        item.background = meta.background
    end if
    if meta.doesExist("type") and meta.type <> invalid then
        item.type = meta.type
    end if
    if meta.doesExist("releaseInfo") and meta.releaseInfo <> invalid then
        item.releaseInfo = meta.releaseInfo
    end if
    if meta.doesExist("imdbRating") and meta.imdbRating <> invalid then
        item.imdbRating = meta.imdbRating
    end if
    if meta.doesExist("description") and meta.description <> invalid then
        item.description = meta.description
    end if
    return item
end function

function GroupEpisodesBySeason(videos as object) as object
    seasonsMap = { }
    for each v in videos
        if v.doesExist("season") and v.doesExist("episode") and v.doesExist("id") then
            sk = v.season.toStr()
            if not seasonsMap.doesExist(sk) then
                seasonsMap[sk] = []
            end if
            seasonsMap[sk].push(v)
        end if
    end for
    nums = []
    for each k in seasonsMap.keys()
        nums.push(k.toInt())
    end for
    SortInts(nums)
    bySeason = { }
    for each n in nums
        eps = seasonsMap[n.toStr()]
        SortEpisodesByNumber(eps)
        bySeason[n.toStr()] = eps
    end for
    return { seasons: nums, bySeason: bySeason }
end function

' insertion sort — evita depender de sortWith (API maior risco; dispositivo valida depois)
sub SortInts(arr as object)
    n = arr.count()
    for i = 1 to n - 1
        key = arr[i]
        j = i - 1
        while j >= 0 and arr[j] > key
            arr[j + 1] = arr[j]
            j = j - 1
        end while
        arr[j + 1] = key
    end for
end sub

sub SortEpisodesByNumber(eps as object)
    n = eps.count()
    for i = 1 to n - 1
        key = eps[i]
        j = i - 1
        while j >= 0 and eps[j].episode > key.episode
            eps[j + 1] = eps[j]
            j = j - 1
        end while
        eps[j + 1] = key
    end for
end sub

function ColorToRoku(hexColor as string) as string
    ' "#00F8F8" → "0x00F8F8FF" (SceneGraph exige RGBA)
    if hexColor.len() = 7 and hexColor.left(1) = "#" then
        return "0x" + hexColor.mid(1, 6) + "FF"
    end if
    return "0x1E88E5FF"
end function

function BuildDetailMeta(item as object) as string
    parts = ""
    if item.releaseInfo <> invalid and item.releaseInfo.len() > 0 then
        parts = item.releaseInfo
    end if
    if item.imdbRating <> invalid and item.imdbRating.len() > 0 then
        if parts <> "" then
            parts = parts + "  ·  "
        end if
        parts = parts + "IMDb " + item.imdbRating
    end if
    return parts
end function
