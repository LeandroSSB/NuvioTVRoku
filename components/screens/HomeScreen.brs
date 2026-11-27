' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' HomeScreen — rows de catálogo (um row por catálogo de addon, spec §3.5 M1).
' Rows sem conteúdo (pending) fazem lazy-load no foco via CatalogTask próprio.
' Mapeamento seleção→dados: AA paralelo m.rowsData (evita campos dinâmicos no ContentNode).

sub init()
    m.rowsData = []
    m.pending = { }
    m.rowList = m.top.findNode("rows")
    m.spinner = m.top.findNode("spinner")
    m.errorLabel = m.top.findNode("errorLabel")
    m.rowList.observeField("rowItemFocused", "OnRowFocused")
    m.rowList.observeField("rowItemSelected", "OnRowItemSelected")
    m.searchButton = m.top.findNode("searchButton")
    m.searchButton.observeField("buttonSelected", "OnSearchPressed")
    m.libraryButton = m.top.findNode("libraryButton")
    m.libraryButton.observeField("buttonSelected", "OnLibraryPressed")
    m.addonsButton = m.top.findNode("addonsButton")
    m.addonsButton.observeField("buttonSelected", "OnAddonsPressed")
    m.configButton = m.top.findNode("configButton")
    m.configButton.observeField("buttonSelected", "OnConfigPressed")
    m.top.observeField("initialRowsJson", "OnInitialRows")
    m.rowTask = createObject("roSGNode", "CatalogTask")
    m.rowTask.observeField("success", "OnRowLoaded")
    m.rowTask.observeField("error", "OnRowTaskError")
end sub

sub OnInitialRows()
    rows = parseJson(m.top.initialRowsJson)
    pending = parseJson(m.top.pendingJson)
    if rows = invalid or type(rows) <> "roArray" then
        m.spinner.visible = false
        return
    end if
    m.rowsData = rows
    labels = []
    i = 0
    while i < 40
        labels.push(true)
        i = i + 1
    end while
    m.rowList.showRowLabel = labels
    RebuildRowsContent()
    m.pending = { }
    if pending <> invalid and type(pending) = "roArray" then
        for each p in pending
            m.pending[p.rowIndex.toStr()] = p.catalogUrl
        end for
    end if
    m.spinner.visible = false
end sub

sub AppendItem(rowNode as object, item as object)
    node = rowNode.createChild("ContentNode")
    node.title = item.name
    node.hdPosterUrl = item.poster
    node.addFields({ imdbRating: item.imdbRating })
end sub

sub OnRowFocused()
    if m.pending = invalid then
        return
    end if
    info = m.rowList.rowItemFocused
    if type(info) <> "roArray" or info.count() < 1 then
        return
    end if
    key = info[0].toStr()
    if m.pending.doesExist(key) then
        m.rowTask.catalogUrl = m.pending[key]
        m.rowTask.rowIndex = info[0]
        m.rowTask.mode = "row"
        m.currentFetchKey = key
        m.currentFetchUrl = m.pending[key]
        m.rowTask.control = "STOP"
        m.rowTask.control = "RUN"
        m.pending.delete(key)
    end if
end sub

sub OnRowTaskError()
    if m.rowTask.error = "" then
        return
    end if
    if m.currentFetchKey <> invalid and m.currentFetchUrl <> invalid and m.currentFetchKey <> "" then
        m.pending[m.currentFetchKey] = m.currentFetchUrl
    end if
end sub

sub OnRowLoaded()
    if not m.rowTask.success then
        return
    end if
    rowIdx = m.rowTask.rowIndex
    content = m.rowList.content
    if content = invalid or rowIdx >= content.getChildCount() then
        return
    end if
    if rowIdx >= m.rowsData.count() then
        return
    end if
    if m.rowsData[rowIdx].catalogUrl <> m.rowTask.catalogUrl then
        return
    end if
    items = parseJson(m.rowTask.itemsJson)
    if items = invalid or type(items) <> "roArray" then
        return
    end if
    m.rowsData[rowIdx].items = items
    rowNode = content.getChild(rowIdx)
    for each item in items
        AppendItem(rowNode, item)
    end for
end sub

sub OnRowItemSelected()
    sel = m.rowList.rowItemSelected
    if type(sel) <> "roArray" or sel.count() <> 2 then
        return
    end if
    rowIdx = sel[0]
    itemIdx = sel[1]
    if rowIdx < m.rowsData.count() then
        items = m.rowsData[rowIdx].items
        if itemIdx < items.count() then
            m.top.itemSelected = FormatJson(items[itemIdx])
        end if
    end if
end sub

' M3: row "Continuar assistindo" chega pronta do ProgressTask (mode="cw") e entra
' na posição 0 REBUILDANDO o content: newRows = [cw] + antigos; o pending map
' shifta +1 (os catálogos agora são as rows 1..n) para o lazy-load no foco
' continuar acertando. Re-atribuir o content devolve o foco para a row 0 (a CW)
' — comportamento aceitável de TV. Re-prepend (re-seleção de perfil) SUBSTITUI
' a row CW existente em vez de empilhar duplicata (sem shift de pending).
sub OnPrependRow()
    cw = parseJson(m.top.prependRowJson)
    if cw = invalid or type(cw) <> "roArray" or cw.count() = 0 then
        return
    end if
    if m.rowList.content = invalid then
        return
    end if
    cwRow = cw[0]
    if m.rowsData.count() > 0 and m.rowsData[0].title = "Continuar assistindo" then
        ' substitui a row CW existente (re-seleção de perfil não empilha duplicatas)
        m.rowsData[0] = cwRow
        RebuildRowsContent()
        return
    end if
    shifted = { }
    for each k in m.pending.keys()
        shifted[(k.toInt() + 1).toStr()] = m.pending[k]
    end for
    m.pending = shifted
    newRows = [cw[0]]
    for each row in m.rowsData
        newRows.push(row)
    end for
    m.rowsData = newRows
    RebuildRowsContent()
end sub

' Content das rows construído a partir do m.rowsData — caminho único usado por
' OnInitialRows (build inicial), OnPrependRow (insert CW) e pelo replace-path
' do dedupe (CW no índice 0 trocada sem shiftar pending).
sub RebuildRowsContent()
    content = createObject("roSGNode", "ContentNode")
    for each row in m.rowsData
        rowNode = content.createChild("ContentNode")
        rowNode.title = row.title
        for each item in row.items
            AppendItem(rowNode, item)
        end for
    end for
    m.rowList.content = content
end sub

sub OnErrorSet()
    m.errorLabel.text = m.top.error
    m.spinner.visible = false
end sub

' M4: botão Buscar → toggle searchRequested (mecânica AuthScreen); o MainScene
' consome e RESETA o toggle — re-busca/abertura repetida dispara de novo (lição M2 wave-3)
sub OnSearchPressed()
    m.top.searchRequested = not m.top.searchRequested
end sub

' M4: botão Biblioteca → toggle libraryRequested, mesma mecânica do Buscar
sub OnLibraryPressed()
    m.top.libraryRequested = not m.top.libraryRequested
end sub

' M4: botão Addons → toggle addonsRequested, mesma mecânica do Buscar/Biblioteca
sub OnAddonsPressed()
    m.top.addonsRequested = not m.top.addonsRequested
end sub

' M4: botão Config → toggle configRequested, mesma mecânica das demais entradas
sub OnConfigPressed()
    m.top.configRequested = not m.top.configRequested
end sub
