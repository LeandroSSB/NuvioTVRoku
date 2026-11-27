' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' Library — snapshot de library_items (contrato 13 + sondagem 27/11). Row = meta
' snapshot rico SEM enrich (name/poster/background/description/genres/imdb_rating/
' release_info/poster_shape/addon_base_url — nulls permitidos no servidor).
' ParseLibraryRows devolve itens na MESMA forma de ParseCatalogItem (id, name, poster,
' background, type, releaseInfo, imdbRating, description) que a UI consome.

function BuildLibraryRow(item as object, profileId as integer) as object
    row = { content_id: "", content_type: "movie", name: "", poster: "", background: "",
            description: "", genres: "", imdb_rating: "", release_info: "",
            poster_shape: "poster", addon_base_url: "", profile_id: profileId }
    if item = invalid then
        return row
    end if
    if item.doesExist("id") and item.id <> invalid then
        row.content_id = item.id
    end if
    if item.doesExist("type") and item.type <> invalid then
        row.content_type = item.type
    end if
    if item.doesExist("name") and item.name <> invalid then
        row.name = item.name
    end if
    if item.doesExist("poster") and item.poster <> invalid then
        row.poster = item.poster
    end if
    if item.doesExist("background") and item.background <> invalid then
        row.background = item.background
    end if
    if item.doesExist("description") and item.description <> invalid then
        row.description = item.description
    end if
    if item.doesExist("genres") and item.genres <> invalid and type(item.genres) = "roString" then
        row.genres = item.genres
    end if
    if item.doesExist("imdbRating") and item.imdbRating <> invalid then
        row.imdb_rating = item.imdbRating
    end if
    if item.doesExist("releaseInfo") and item.releaseInfo <> invalid then
        row.release_info = item.releaseInfo
    end if
    return row
end function

' row do servidor → item de grid. imdb_rating chega NUMBER (jsonb) → toStr() — o
' PosterItem renderiza o campo num Label (string). Rows sem content_id são puladas
' (id vazio não abre Detail). Campos null do snapshot caem no default "".
function ParseLibraryRows(rows as object) as object
    items = []
    if rows = invalid or type(rows) <> "roArray" then
        return items
    end if
    for each row in rows
        if row <> invalid and row.doesExist("content_id") and row.content_id <> invalid and row.content_id <> "" then
            item = { id: row.content_id, name: "", poster: "", background: "",
                     type: "movie", releaseInfo: "", imdbRating: "", description: "" }
            if row.doesExist("name") and row.name <> invalid then
                item.name = row.name
            end if
            if row.doesExist("poster") and row.poster <> invalid then
                item.poster = row.poster
            end if
            if row.doesExist("background") and row.background <> invalid then
                item.background = row.background
            end if
            if row.doesExist("content_type") and row.content_type <> invalid then
                item.type = row.content_type
            end if
            if row.doesExist("release_info") and row.release_info <> invalid then
                item.releaseInfo = row.release_info
            end if
            if row.doesExist("imdb_rating") and row.imdb_rating <> invalid then
                item.imdbRating = row.imdb_rating.toStr()
            end if
            if row.doesExist("description") and row.description <> invalid then
                item.description = row.description
            end if
            items.push(item)
        end if
    end for
    return items
end function
