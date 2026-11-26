' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' ProfileItem — tile colorido (avatar_color_hex) + inicial + nome.

sub OnContentSet()
    c = m.top.itemContent
    if c = invalid then
        return
    end if
    m.tile = m.top.findNode("tile")
    m.initial = m.top.findNode("initial")
    m.name = m.top.findNode("name")
    m.tile.color = c.getField("profileColor")
    m.initial.text = c.getField("initial")
    m.name.text = c.title
end sub

sub OnFocusChanged()
    if m.top.focusPercent > 0.5 then
        m.tile.opacity = 1.0
        m.name.opacity = 1.0
    else
        m.tile.opacity = 0.65
        m.name.opacity = 0.65
    end if
end sub
