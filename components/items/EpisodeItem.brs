' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' EpisodeItem — thumbnail + "SxE" + nome do episódio (ContentNode.hdPosterUrl/title).

sub OnContentSet()
    c = m.top.itemContent
    if c = invalid then
        return
    end if
    m.thumb = m.top.findNode("thumb")
    m.code = m.top.findNode("code")
    m.name = m.top.findNode("name")
    m.thumb.uri = c.hdPosterUrl
    m.code.text = "S" + c.getField("season").toStr() + "E" + c.getField("episode").toStr()
    m.name.text = c.title
end sub

sub OnFocusChanged()
    if m.name = invalid or m.code = invalid then return
    if m.top.focusPercent > 0.5 then
        m.name.opacity = 1.0
        m.code.opacity = 1.0
    else
        m.name.opacity = 0.6
        m.code.opacity = 0.7
    end if
end sub
