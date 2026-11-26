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
    m.top.observeField("initialRowsJson", "OnInitialRows")
    m.rowTask = createObject("roSGNode", "CatalogTask")
    m.rowTask.observeField("success", "OnRowLoaded")
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
    content = createObject("roSGNode", "ContentNode")
    for each row in rows
        rowNode = content.createChild("ContentNode")
        rowNode.title = row.title
        for each item in row.items
            AppendItem(rowNode, item)
        end for
    end for
    m.pending = { }
    if pending <> invalid and type(pending) = "roArray" then
        for each p in pending
            m.pending[p.rowIndex.toStr()] = p.catalogUrl
        end for
    end if
    m.rowList.content = content
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
        m.rowTask.control = "STOP"
        m.rowTask.control = "RUN"
        m.pending.delete(key)
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

sub OnErrorSet()
    m.errorLabel.text = m.top.error
    m.spinner.visible = false
end sub
