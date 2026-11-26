' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' ProfileScreen — seleção de perfil (contrato 07). Avatar = cor + inicial (corte M1).

sub init()
    m.profiles = []
    m.grid = m.top.findNode("profileGrid")
    ' itemSelected: forma pode variar por firmware ([row,col] | [row] | int) — handler agnóstico
    m.grid.observeField("itemSelected", "OnGridSelected")
end sub

sub OnProfilesSet()
    data = parseJson(m.top.profilesJson)
    if data = invalid or type(data) <> "roArray" then
        return
    end if
    m.profiles = data
    content = createObject("roSGNode", "ContentNode")
    for each p in data
        node = content.createChild("ContentNode")
        node.title = p.name
        color = "#1E88E5"
        if p.doesExist("avatar_color_hex") and p.avatar_color_hex <> invalid then
            color = p.avatar_color_hex
        end if
        initial = "?"
        if p.name <> invalid and p.name.len() > 0 then
            initial = p.name.left(1).upper()
        end if
        node.addFields({ profileColor: ColorToRoku(color), initial: initial })
    end for
    m.grid.content = content
end sub

sub OnGridSelected()
    sel = m.grid.itemSelected
    idx = -1
    if type(sel) = "roArray" and sel.count() = 2 then
        ' grid 2D: [row, col] → índice linear no content flat (numColumns do XML)
        idx = sel[0] * m.grid.numColumns + sel[1]
    else if type(sel) = "roArray" and sel.count() = 1 then
        idx = sel[0]
    else if sel <> invalid and type(sel) <> "roArray" then
        ' alguns firmwares emitem int
        idx = sel
    end if
    if idx >= 0 and idx < m.profiles.count() then
        m.top.profileSelected = m.profiles[idx].profile_id
    end if
end sub
