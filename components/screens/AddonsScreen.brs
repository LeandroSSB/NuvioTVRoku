' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' AddonsScreen — addons do perfil (M4): LabelList "name  [on|off]" (forma do
' StreamsScreen — texto puro, sem poster). addonsJson são as rows CRUS do
' ProgressTask mode="addons" (id/name/url/enabled/profile_id), injetadas pelo
' MainScene; lista vazia NÃO é erro ("Nenhum addon", como na Biblioteca).
' Toggle emite toggleRequested (índice da row — itemSelected de list é INT flat);
' o MainScene consome+RESETA o campo (-1) e re-injeta após o re-pull — sem o
' reset um 2º toggle na MESMA row não dispararia (field int sem mudança).

sub init()
    m.rows = []
    m.list = m.top.findNode("addonsList")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.errorLabel = m.top.findNode("errorLabel")
    m.list.observeField("itemSelected", "OnListSelected")
end sub

sub OnAddonsJson()
    m.errorLabel.text = ""
    rows = parseJson(m.top.addonsJson)
    if rows = invalid or type(rows) <> "roArray" or rows.count() = 0 then
        m.rows = []
        m.list.content = invalid
        m.emptyLabel.visible = true
        return
    end if
    m.emptyLabel.visible = false
    m.rows = rows
    content = createObject("roSGNode", "ContentNode")
    for each row in rows
        node = content.createChild("ContentNode")
        state = "off"
        if row.enabled = true then
            state = "on"
        end if
        ' guard: row sem name quebraria a concatenação (type mismatch trava o script)
        if row.name = invalid then return
        node.title = row.name + "  [" + state + "]"
    end for
    m.list.content = content
end sub

' itemSelected do LabelList é INT (flat por firmware) — índice direto em m.rows
sub OnListSelected()
    idx = m.list.itemSelected
    if idx <> invalid and idx >= 0 and idx < m.rows.count() then
        m.top.toggleRequested = idx
    end if
end sub

sub OnErrorSet()
    m.errorLabel.text = m.top.error
    m.emptyLabel.visible = false
end sub
