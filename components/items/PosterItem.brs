' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' PosterItem — item de row: poster + nome + nota IMDb (ContentNode.hdPosterUrl/title).

sub OnContentSet()
    c = m.top.itemContent
    if c = invalid then
        return
    end if
    m.poster = m.top.findNode("poster")
    m.name = m.top.findNode("name")
    m.rating = m.top.findNode("rating")
    m.poster.uri = c.hdPosterUrl
    m.name.text = c.title
    m.rating.text = c.getField("imdbRating")
end sub

sub OnFocusChanged()
    if m.top.focusPercent > 0.5 then
        m.name.opacity = 1.0
    else
        m.name.opacity = 0.6
    end if
end sub
