' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' DetailScreen — filme: poster/backdrop/descrição + botão stub (player = M2).
' Série: temporadas (LabelList) + episódios (MarkupGrid) via meta.videos (contratos 05/09).
' Info do row item aparece imediatamente; meta enriquece quando MetaTask responde.

sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.metaInfo = m.top.findNode("metaInfo")
    m.description = m.top.findNode("description")
    m.playButton = m.top.findNode("play")
    m.seasons = m.top.findNode("seasons")
    m.episodes = m.top.findNode("episodes")
    m.item = invalid
    m.grouped = invalid
    m.stubDialog = invalid
    m.playButton.observeField("buttonSelected", "OnPlaySelected")
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
    ShowStubDialog()
end sub

sub OnPlaySelected()
    ShowStubDialog()
end sub

sub ShowStubDialog()
    if m.stubDialog <> invalid then
        return
    end if
    m.stubDialog = createObject("roSGNode", "Dialog")
    m.stubDialog.title = "Player no M2"
    m.stubDialog.message = "Streams, legendas e player chegam no próximo milestone."
    m.stubDialog.observeField("wasClosed", "OnStubClosed")
    m.top.appendChild(m.stubDialog)
end sub

sub OnStubClosed()
    if m.stubDialog <> invalid then
        m.top.removeChild(m.stubDialog)
        m.stubDialog = invalid
    end if
end sub
