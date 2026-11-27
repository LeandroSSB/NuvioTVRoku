' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' LibraryScreen — biblioteca (M4): MarkupGrid PosterItem com os itens do pull
' (LibraryTask). itemsJson injetado pelo MainScene; grid vazio → Label "Biblioteca
' vazia" (vazio NÃO é erro). itemSelected JSON out (índice grid 2D → flat por
' firmware — mesma mecânica do SearchScreen).

sub init()
    m.items = []
    m.grid = m.top.findNode("grid")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.errorLabel = m.top.findNode("errorLabel")
    m.grid.observeField("itemSelected", "OnGridSelected")
end sub

sub OnItemsJson()
    m.errorLabel.text = ""
    items = parseJson(m.top.itemsJson)
    if items = invalid or type(items) <> "roArray" or items.count() = 0 then
        m.items = []
        m.grid.content = invalid
        m.emptyLabel.visible = true
        return
    end if
    m.emptyLabel.visible = false
    m.items = items
    content = createObject("roSGNode", "ContentNode")
    for each item in items
        node = content.createChild("ContentNode")
        node.title = item.name
        node.hdPosterUrl = item.poster
        node.addFields({ imdbRating: item.imdbRating })
    end for
    m.grid.content = content
end sub

' itemSelected: forma varia por firmware ([row,col] | [row] | int) — handler agnóstico
' igual ao SearchScreen; content é flat, índice linear cai direto no m.items.
sub OnGridSelected()
    sel = m.grid.itemSelected
    idx = -1
    if type(sel) = "roArray" and sel.count() = 2 then
        idx = sel[0] * m.grid.numColumns + sel[1]
    else if type(sel) = "roArray" and sel.count() = 1 then
        idx = sel[0]
    else if sel <> invalid and type(sel) <> "roArray" then
        idx = sel
    end if
    if idx >= 0 and idx < m.items.count() then
        m.top.itemSelected = FormatJson(m.items[idx])
    end if
end sub

sub OnErrorSet()
    m.errorLabel.text = m.top.error
    m.emptyLabel.visible = false
end sub
