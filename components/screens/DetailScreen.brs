' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' DetailScreen — filme: poster/backdrop/descrição + "Assistir"/"Escolher stream"
' (emitem playRequested/streamsRequested com playItemId; MainScene orquestra o resto).
' Série: temporadas (LabelList) + episódios (MarkupGrid) via meta.videos (contratos 05/09);
' episódio escolhido → itemId tt:s:e (addFields guardou season/episode no SelectSeason).
' Info do row item aparece imediatamente; meta enriquece quando MetaTask responde.

sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.metaInfo = m.top.findNode("metaInfo")
    m.description = m.top.findNode("description")
    m.playButton = m.top.findNode("play")
    m.pickButton = m.top.findNode("pick")
    m.seasons = m.top.findNode("seasons")
    m.episodes = m.top.findNode("episodes")
    m.item = invalid
    m.grouped = invalid
    m.currentEpisode = invalid
    m.episodeId = ""
    m.playButton.observeField("buttonSelected", "OnPlaySelected")
    m.pickButton.observeField("buttonSelected", "OnPickSelected")
    m.seasons.observeField("itemFocused", "OnSeasonFocused")
    m.seasons.observeField("itemSelected", "OnSeasonSelected")
    m.episodes.observeField("itemSelected", "OnEpisodeSelected")
    m.top.observeField("itemJson", "OnItemSet")
    m.top.observeField("metaJson", "OnMetaSet")
end sub

sub OnItemSet()
    item = parseJson(m.top.itemJson)
    if item = invalid then
        return
    end if
    m.item = item
    m.episodeId = ""
    m.currentEpisode = invalid
    uri = item.background
    if uri = "" then
        uri = item.poster
    end if
    m.backdrop.uri = uri
    m.poster.uri = item.poster
    m.title.text = item.name
    m.metaInfo.text = BuildDetailMeta(item)
    m.description.text = item.description
    m.seasons.visible = false
    m.episodes.visible = false
    m.playButton.visible = (item.type = "movie")
    m.pickButton.visible = (item.type = "movie")
    if item.type = "movie" then
        m.playButton.setFocus(true)
    end if
end sub

sub OnMetaSet()
    meta = parseJson(m.top.metaJson)
    if meta = invalid then
        return
    end if
    if meta.doesExist("background") and meta.background <> invalid and meta.background <> "" then
        m.backdrop.uri = meta.background
    end if
    if meta.doesExist("description") and meta.description <> invalid and meta.description <> "" then
        m.description.text = meta.description
    end if
    if m.item = invalid or m.item.type <> "movie" then
        if meta.doesExist("videos") and meta.videos <> invalid and meta.videos.count() > 0 then
            m.grouped = GroupEpisodesBySeason(meta.videos)
            content = createObject("roSGNode", "ContentNode")
            for each s in m.grouped.seasons
                node = content.createChild("ContentNode")
                node.title = "Temporada " + s.toStr()
            end for
            m.seasons.content = content
            m.seasons.visible = true
            m.episodes.visible = true
            m.playButton.visible = false
            m.pickButton.visible = false
            SelectSeason(0)
        end if
    end if
end sub

sub SelectSeason(index as integer)
    if m.grouped = invalid then
        return
    end if
    if index < 0 or index >= m.grouped.seasons.count() then
        return
    end if
    sk = m.grouped.seasons[index].toStr()
    eps = m.grouped.bySeason[sk]
    content = createObject("roSGNode", "ContentNode")
    for each ep in eps
        node = content.createChild("ContentNode")
        node.title = ep.name
        thumb = ""
        if ep.doesExist("thumbnail") and ep.thumbnail <> invalid then
            thumb = ep.thumbnail
        end if
        node.hdPosterUrl = thumb
        node.addFields({ season: ep.season, episode: ep.episode })
    end for
    m.episodes.content = content
    m.seasons.jumpToItem = index
    m.seasons.setFocus(true)
end sub

sub OnSeasonFocused()
    idx = m.seasons.itemFocused
    if idx = invalid or idx < 0 then
        return
    end if
    SelectSeason(idx)
end sub

sub OnSeasonSelected()
    idx = m.seasons.itemSelected
    if idx = invalid or idx < 0 then
        return
    end if
    SelectSeason(idx)
end sub

sub OnEpisodeSelected()
    ' MarkupGrid.itemSelected é INT (índice flat) e o content é flat (raiz→itens)
    idx = m.episodes.itemSelected
    if idx = invalid or idx < 0 then
        return
    end if
    ep = m.episodes.content.getChild(idx)
    if ep = invalid then
        return
    end if
    m.currentEpisode = ep
    ' itemId do episódio: addFields guardou season/episode (SelectSeason);
    ' o id do item pai é a SÉRIE (ttXXX) — o play real precisa do tt:s:e.
    m.episodeId = m.item.id + ":" + ep.getField("season").toStr() + ":" + ep.getField("episode").toStr()
    OnPlaySelected()
end sub

sub OnPlaySelected()
    if m.episodeId <> "" then
        m.top.playItemId = m.episodeId
    else if m.item <> invalid then
        m.top.playItemId = m.item.id
    end if
    m.top.playRequested = not m.top.playRequested
end sub

sub OnPickSelected()
    m.top.streamsRequested = not m.top.streamsRequested
end sub
