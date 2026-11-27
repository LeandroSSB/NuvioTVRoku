' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' SettingsScreen — opções do app (M4, spec §3.2): LabelList vertical de 4 itens
' (forma AddonsScreen — itemSelected INT flat). item 0 abre o SUB-MODO de edição
' do backend (editMode setado pelo MainScene → Keyboard + Salvar; Salvar lê o
' texto e emite backendUrl + toggle backendSubmitted — o MainScene valida e
' persiste); item 1 "Testar conexão" roteia via itemSelected (MainScene roda o
' SettingsTask e devolve o resultado em testSuccess/error → statusLabel);
' itens 2/3 emitem toggles PRÓPRIOS (rememberToggled/logoutRequested — mecânica
' AuthScreen: MainScene consome e RESETA). Labels dinâmicos ("Servidor: <url>",
' "Lembrar último perfil: ON/OFF") são reconstruídos quando o MainScene injeta
' backendUrl/rememberEnabled — o Registry é a fonte da verdade, não a tela.

sub init()
    m.list = m.top.findNode("settingsList")
    m.listGroup = m.top.findNode("listGroup")
    m.editGroup = m.top.findNode("editGroup")
    m.keyboard = m.top.findNode("urlKeyboard")
    m.editBox = m.keyboard.textEditBox
    m.saveButton = m.top.findNode("saveButton")
    m.statusLabel = m.top.findNode("statusLabel")
    m.list.observeField("itemSelected", "OnListSelected")
    m.saveButton.observeField("buttonSelected", "OnSavePressed")
    BuildOptions()
end sub

' Content da lista — chamado no init e a cada label dinâmico que muda
sub BuildOptions()
    remember = "OFF"
    if m.top.rememberEnabled then
        remember = "ON"
    end if
    content = createObject("roSGNode", "ContentNode")
    serverItem = content.createChild("ContentNode")
    serverItem.title = "Servidor: " + m.top.backendUrl
    testItem = content.createChild("ContentNode")
    testItem.title = "Testar conexão"
    rememberItem = content.createChild("ContentNode")
    rememberItem.title = "Lembrar último perfil: " + remember
    logoutItem = content.createChild("ContentNode")
    logoutItem.title = "Sair da conta"
    m.list.content = content
end sub

' itemSelected do LabelList é INT (flat por firmware) — roteia SÓ os itens sem
' toggle próprio (0 = edição do backend, 1 = testar conexão); 2/3 seguem pelos
' toggles rememberToggled/logoutRequested (o MainScene reseta ambos após consumir)
sub OnListSelected()
    idx = m.list.itemSelected
    if idx = invalid or idx < 0 or idx > 3 then
        return
    end if
    if idx = 2 then
        m.top.rememberToggled = not m.top.rememberToggled
    else if idx = 3 then
        m.top.logoutRequested = not m.top.logoutRequested
    else
        m.top.itemSelected = idx
    end if
end sub

' URL injetada (corrente pelo MainScene, digitada pelo Salvar) → label do item 0
sub OnBackendUrlSet()
    BuildOptions()
end sub

sub OnRememberChange()
    BuildOptions()
    ' reatribuir o content devolve o foco ao item 0 — volta pro item do toggle
    m.list.focusedIndex = 2
end sub

' Sub-modo edição: lista sai, Keyboard + Salvar entram (prefill com a URL corrente).
' Focus DEPOIS do ShowScreen do MainScene — o handler roda por último e o foco
' fica onde o sub-modo pede, não onde o ShowScreen deixou.
sub OnEditModeSet()
    m.statusLabel.text = ""
    if m.top.editMode then
        m.editBox.text = m.top.backendUrl
        m.listGroup.visible = false
        m.editGroup.visible = true
        m.keyboard.setFocus(true)
    else
        m.editGroup.visible = false
        m.listGroup.visible = true
        m.list.setFocus(true)
    end if
end sub

' Salvar: lê o Keyboard → backendUrl out + toggle backendSubmitted (o MainScene
' reseta — salvar de novo a MESMA URL dispara de novo; lição M2 wave-3)
sub OnSavePressed()
    m.top.backendUrl = m.editBox.text.trim()
    m.top.backendSubmitted = not m.top.backendSubmitted
end sub

' Resultado do teste (MainScene): feedback VERDE no statusLabel. Reset-after-
' handling — o próximo teste dispara de novo (padrão dos bools M2/M3).
sub OnTestSuccessSet()
    if not m.top.testSuccess then
        return
    end if
    m.top.testSuccess = false
    m.statusLabel.text = "Conectado ao backend"
    m.statusLabel.color = "0x8BC34A"
end sub

sub OnErrorSet()
    m.statusLabel.text = m.top.error
    m.statusLabel.color = "0xE57373"
end sub

' Back no sub-modo edição volta à LISTA (consome o back); fora dele o back é do
' MainScene (SettingsScreen → Home). Pattern onKeyEvent do PlayerScreen.
function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "back" and m.top.editMode then
        m.top.editMode = false
        return true
    end if
    return false
end function
