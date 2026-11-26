' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' AuthScreen — login e-mail/senha (padrão SELF_HOSTED, spec §3.2).
' Password usa textEditBox.secureMode (mascara caracteres — sample oficial do Roku).

sub init()
    m.emailKeyboard = m.top.findNode("emailKeyboard")
    m.passKeyboard = m.top.findNode("passKeyboard")
    m.emailBox = m.emailKeyboard.textEditBox
    m.passBox = m.passKeyboard.textEditBox
    m.passBox.secureMode = true
    m.emailBox.hintText = "e-mail"
    m.passBox.hintText = "senha"
    m.signInButton = m.top.findNode("signInButton")
    m.signInButton.observeField("buttonSelected", "OnSignIn")
    m.errorLabel = m.top.findNode("error")
end sub

sub OnSignIn()
    email = m.emailBox.text.trim()
    pass = m.passBox.text
    if email.len() = 0 or pass.len() = 0 then
        m.top.error = "Preencha e-mail e senha."
        return
    end if
    m.top.error = ""
    m.top.email = email
    m.top.password = pass
    m.top.signInRequested = not m.top.signInRequested
end sub

sub OnErrorSet()
    m.errorLabel.text = m.top.error
end sub
