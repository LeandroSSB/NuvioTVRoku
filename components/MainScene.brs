' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' MainScene — router do app (spec §3.1): boot → (login | perfis) → home → detail.
' Orquestra os task nodes e troca screens filhos cacheados. Fluxo de boot espelha o
' AuthManager do NuvioTV: refresh token salvo → grant refresh; inválido → re-login.

sub init()
    m.currentScreen = invalid
    m.sessionTask = invalid
    m.homeTask = invalid
    m.metaTask = invalid
    m.authScreen = invalid
    m.profileScreen = invalid
    m.homeScreen = invalid
    m.detailScreen = invalid
    m.bootSpinner = m.top.findNode("bootSpinner")
    if SessionGetRefreshToken() <> "" then
        StartSessionTask("boot")
    else
        m.bootSpinner.visible = false
        ShowAuth()
    end if
end sub

' ---------- router ----------

sub ShowScreen(target as object)
    if target = invalid then
        return
    end if
    if m.currentScreen <> invalid then
        if m.currentScreen.isSameNode(target) then
            return
        end if
        m.top.removeChild(m.currentScreen)
    end if
    m.currentScreen = target
    m.top.appendChild(target)
    target.setFocus(true)
end sub

sub ShowAuth()
    if m.authScreen = invalid then
        m.authScreen = createObject("roSGNode", "AuthScreen")
        m.authScreen.observeField("signInRequested", "OnSignInRequested")
    end if
    ShowScreen(m.authScreen)
end sub

sub ShowProfiles(profilesJson as string)
    ' Task 10 cria ProfileScreen aqui
    m.bootSpinner.visible = false
end sub

sub ShowHome(profileId as integer)
    ' Task 11 cria HomeScreen aqui
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "back" and m.currentScreen <> invalid then
        name = m.currentScreen.subtype()
        if name = "DetailScreen" and m.homeScreen <> invalid then
            ShowScreen(m.homeScreen)
            return true
        end if
        if name = "HomeScreen" and m.profileScreen <> invalid then
            ShowScreen(m.profileScreen)
            return true
        end if
        ' ProfileScreen: false → Roku mostra o diálogo nativo de saída
    end if
    return false
end function

' ---------- sessão ----------

sub StartSessionTask(mode as string, email = "" as string, password = "" as string)
    m.bootSpinner.visible = true
    if m.sessionTask = invalid then
        m.sessionTask = createObject("roSGNode", "SessionTask")
        m.sessionTask.observeField("success", "OnSessionSuccess")
        m.sessionTask.observeField("error", "OnSessionError")
    end if
    m.sessionTask.email = email
    m.sessionTask.password = password
    m.sessionTask.success = false
    m.sessionTask.error = ""
    m.sessionTask.mode = mode
    m.sessionTask.control = "STOP"
    m.sessionTask.control = "RUN"
end sub

sub OnSessionSuccess()
    if not m.sessionTask.success then
        return
    end if
    m.bootSpinner.visible = false
    ShowProfiles(m.sessionTask.profilesJson)
end sub

sub OnSessionError()
    m.bootSpinner.visible = false
    ShowAuth()
    m.authScreen.error = TranslateAuthError(m.sessionTask.error)
end sub

function TranslateAuthError(err as string) as string
    if err = "session_expired" then
        return ""
    end if
    if err = "well_known_failed" then
        return "Backend inacessível — verifique a URL do servidor."
    end if
    if err = "timeout" then
        return "Sem resposta do servidor (timeout)."
    end if
    if err = "profiles_failed" then
        return "Não foi possível carregar os perfis — erro do servidor."
    end if
    if err = "profiles_empty" then
        return "Nenhum perfil nesta conta."
    end if
    if err.inStr("http_400") = 0 then
        return "E-mail ou senha incorretos."
    end if
    if err.inStr("http_") = 0 then
        return "Erro do servidor (" + err + ")."
    end if
    return err
end function

sub OnSignInRequested()
    StartSessionTask("login", m.authScreen.email, m.authScreen.password)
end sub
