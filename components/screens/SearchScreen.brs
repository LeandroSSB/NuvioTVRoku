' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' SearchScreen — busca (M4): Keyboard + Button "Buscar" → toggle querySubmitted
' (mesma mecânica toggle/observer do AuthScreen; o MainScene consome e RESETA o
' toggle — lição M2 wave-3). resultsJson injetado pelo MainScene → MarkupGrid
' PosterItem (itemSelected JSON out; índice grid 2D → flat por firmware — lição M2).
' Grid vazio → Label "Sem resultados" (zero resultados NÃO é erro — SearchTask).

sub init()
    m.results = []
    m.keyboard = m.top.findNode("searchKeyboard")
    m.searchBox = m.keyboard.textEditBox
    m.searchBox.hintText = "título do filme ou série"
    m.resultsGrid = m.top.findNode("results")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.errorLabel = m.top.findNode("errorLabel")
    m.searchButton = m.top.findNode("searchButton")
    m.searchButton.observeField("buttonSelected", "OnSearchPressed")
    m.resultsGrid.observeField("itemSelected", "OnGridSelected")
end sub

sub OnSearchPressed()
    q = m.searchBox.text.trim()
    if q.len() = 0 then
        return
    end if
    m.top.query = q
    m.top.querySubmitted = not m.top.querySubmitted
end sub

sub OnResultsJson()
    m.errorLabel.text = ""
    items = parseJson(m.top.resultsJson)
    if items = invalid or type(items) <> "roArray" or items.count() = 0 then
        m.results = []
        m.resultsGrid.content = invalid
        m.emptyLabel.visible = true
        return
    end if
    m.emptyLabel.visible = false
    m.results = items
    content = createObject("roSGNode", "ContentNode")
    for each item in items
        node = content.createChild("ContentNode")
        node.title = item.name
        node.hdPosterUrl = item.poster
        node.addFields({ imdbRating: item.imdbRating })
    end for
    m.resultsGrid.content = content
end sub

' itemSelected: forma varia por firmware ([row,col] | [row] | int) — handler agnóstico
' igual ao ProfileScreen; content é flat, índice linear cai direto no m.results.
sub OnGridSelected()
    sel = m.resultsGrid.itemSelected
    idx = -1
    if type(sel) = "roArray" and sel.count() = 2 then
        idx = sel[0] * m.resultsGrid.numColumns + sel[1]
    else if type(sel) = "roArray" and sel.count() = 1 then
        idx = sel[0]
    else if sel <> invalid and type(sel) <> "roArray" then
        idx = sel
    end if
    if idx >= 0 and idx < m.results.count() then
        m.top.itemSelected = FormatJson(m.results[idx])
    end if
end sub

sub OnErrorSet()
    m.errorLabel.text = m.top.error
    m.emptyLabel.visible = false
end sub
