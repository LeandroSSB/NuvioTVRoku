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
    m.searchScreen = invalid
    m.searchTask = invalid
    m.detailFromSearch = false
    m.streams = []
    m.streamIndex = 0
    m.currentItem = invalid
    m.subsJson = ""
    m.streamTask = invalid
    m.subsTask = invalid
    m.playerScreen = invalid
    m.streamsScreen = invalid
    m.currentPlayItemId = ""
    m.pendingStreamsMode = ""
    m.playGeneration = 0
    m.streamTaskGeneration = 0
    m.progressRows = []
    m.progressTask = invalid
    m.progressMode = ""
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
    if m.profileScreen = invalid then
        m.profileScreen = createObject("roSGNode", "ProfileScreen")
        m.profileScreen.observeField("profileSelected", "OnProfileSelected")
    end if
    m.profileScreen.profilesJson = profilesJson
    ShowScreen(m.profileScreen)
    m.bootSpinner.visible = false
end sub

sub OnProfileSelected()
    profileId = m.profileScreen.profileSelected
    m.profileScreen.profileSelected = 0
    if profileId <= 0 then
        return
    end if
    SessionSaveActiveProfileId(profileId)
    ShowHome(profileId)
end sub

sub ShowHome(profileId as integer)
    if m.homeScreen = invalid then
        m.homeScreen = createObject("roSGNode", "HomeScreen")
        m.homeScreen.observeField("itemSelected", "OnItemSelected")
        m.homeScreen.observeField("searchRequested", "OnHomeSearchRequested")
    end if
    ShowScreen(m.homeScreen)
    m.bootSpinner.visible = true
    if m.homeTask = invalid then
        m.homeTask = createObject("roSGNode", "CatalogTask")
        m.homeTask.observeField("success", "OnHomeLoaded")
        m.homeTask.observeField("error", "OnHomeError")
    end if
    m.homeTask.profileId = profileId
    m.homeTask.control = "STOP"
    m.homeTask.control = "RUN"
    ' M3: sync de progresso em background — as rows da home não esperam por ele;
    ' a row CW aparece quando o enrich termina (spinner NÃO é gateado aqui).
    StartProgressPull()
end sub

sub OnHomeLoaded()
    m.bootSpinner.visible = false
    if m.homeTask.success then
        m.homeScreen.addonsJson = m.homeTask.addonsJson
        m.homeScreen.initialRowsJson = m.homeTask.rowsJson
        m.homeScreen.pendingJson = m.homeTask.pendingJson
    end if
end sub

sub OnHomeError()
    m.bootSpinner.visible = false
    err = m.homeTask.error
    if err = "session_expired" then
        SessionClearSession()
        StartSessionTask("boot")
        return
    end if
    m.homeScreen.error = err
end sub

' ---------- busca (M4) ----------

' Home → SearchScreen (create-once; botão Buscar togglea searchRequested e o
' handler consome+reseta — reabertura volta a disparar)
sub OnHomeSearchRequested()
    if not m.homeScreen.searchRequested then return
    m.homeScreen.searchRequested = false
    ShowSearch()
end sub

sub ShowSearch()
    if m.searchScreen = invalid then
        m.searchScreen = createObject("roSGNode", "SearchScreen")
        m.searchScreen.observeField("querySubmitted", "OnSearchSubmitted")
        m.searchScreen.observeField("itemSelected", "OnSearchItemSelected")
    end if
    ShowScreen(m.searchScreen)
end sub

sub OnSearchSubmitted()
    if not m.searchScreen.querySubmitted then return
    query = m.searchScreen.query
    m.searchScreen.querySubmitted = false
    if query = "" then
        return
    end if
    m.bootSpinner.visible = true
    if m.searchTask = invalid then
        m.searchTask = createObject("roSGNode", "SearchTask")
        m.searchTask.observeField("success", "OnSearchLoaded")
        m.searchTask.observeField("error", "OnSearchError")
    end if
    m.searchTask.query = query
    m.searchTask.control = "STOP"
    m.searchTask.control = "RUN"
end sub

sub OnSearchLoaded()
    m.bootSpinner.visible = false
    if m.searchTask.success then
        m.searchScreen.resultsJson = m.searchTask.resultsJson
    end if
end sub

sub OnSearchError()
    m.bootSpinner.visible = false
    if m.searchTask.error = "" then return
    err = m.searchTask.error
    if err = "session_expired" then
        SessionClearSession()
        StartSessionTask("boot")
        return
    end if
    m.searchScreen.error = err
end sub

' Seleção na grade de resultados → MESMA transição de Detail do OnItemSelected
' (linhas duplicadas de propósito — repo não fatora; m.detailFromSearch guarda a
' origem para o back do Detail voltar à busca)
sub OnSearchItemSelected()
    itemJson = m.searchScreen.itemSelected
    if itemJson = invalid or itemJson = "" then
        return
    end if
    m.searchScreen.itemSelected = ""
    if m.detailScreen = invalid then
        m.detailScreen = createObject("roSGNode", "DetailScreen")
        m.detailScreen.observeField("playRequested", "OnPlayRequested")
        m.detailScreen.observeField("streamsRequested", "OnStreamsRequested")
    end if
    m.detailScreen.itemJson = itemJson
    m.detailScreen.metaJson = ""
    m.detailFromSearch = true
    ShowScreen(m.detailScreen)
    m.bootSpinner.visible = true
    if m.metaTask = invalid then
        m.metaTask = createObject("roSGNode", "MetaTask")
        m.metaTask.observeField("success", "OnMetaLoaded")
        m.metaTask.observeField("error", "OnMetaError")
    end if
    m.currentItem = parseJson(itemJson)
    m.metaTask.addonsJson = m.homeScreen.addonsJson
    m.metaTask.metaType = m.currentItem.type
    m.metaTask.metaId = m.currentItem.id
    m.metaTask.control = "STOP"
    m.metaTask.control = "RUN"
end sub

sub OnItemSelected()
    itemJson = m.homeScreen.itemSelected
    if itemJson = invalid or itemJson = "" then
        return
    end if
    m.homeScreen.itemSelected = ""
    m.detailFromSearch = false
    if m.detailScreen = invalid then
        m.detailScreen = createObject("roSGNode", "DetailScreen")
        m.detailScreen.observeField("playRequested", "OnPlayRequested")
        m.detailScreen.observeField("streamsRequested", "OnStreamsRequested")
    end if
    m.detailScreen.itemJson = itemJson
    m.detailScreen.metaJson = ""
    ShowScreen(m.detailScreen)
    m.bootSpinner.visible = true
    if m.metaTask = invalid then
        m.metaTask = createObject("roSGNode", "MetaTask")
        m.metaTask.observeField("success", "OnMetaLoaded")
        m.metaTask.observeField("error", "OnMetaError")
    end if
    m.currentItem = parseJson(itemJson)
    m.metaTask.addonsJson = m.homeScreen.addonsJson
    m.metaTask.metaType = m.currentItem.type
    m.metaTask.metaId = m.currentItem.id
    m.metaTask.control = "STOP"
    m.metaTask.control = "RUN"
end sub

sub OnMetaLoaded()
    m.bootSpinner.visible = false
    if m.metaTask.success then
        m.detailScreen.metaJson = m.metaTask.metaJson
    end if
end sub

sub OnMetaError()
    m.bootSpinner.visible = false
    ' sem meta: detail fica só com os dados do row item (spec §4 — não bloquear)
end sub

' ---------- player (M2) ----------

sub StartPlay(index as integer)
    if m.streams = invalid or index >= m.streams.count() then
        ' Detail/StreamsScreen não têm field "error" — roteia pra home como nos
        ' demais erros (evita setar field inexistente no node corrente).
        ShowScreen(m.homeScreen)
        m.homeScreen.error = "Sem stream reproduzível para este item."
        return
    end if
    m.streamIndex = index
    if m.playerScreen = invalid then
        m.playerScreen = createObject("roSGNode", "PlayerScreen")
        m.playerScreen.observeField("playFailed", "OnPlayFailed")
        m.playerScreen.observeField("playFinished", "OnPlayFinished")
        m.playerScreen.observeField("exitRequested", "OnPlayerExit")
        m.playerScreen.observeField("progressPing", "OnProgressPing")
    end if
    ' reset dos out-bools + streamJson="" antes de re-injetar: garante que OnStreamSet
    ' dispare ("" → json muda o campo) mesmo em replay do mesmo item.
    m.playerScreen.playFinished = false
    m.playerScreen.playFailed = false
    m.playerScreen.exitRequested = false
    m.playerScreen.streamJson = ""
    m.playerScreen.itemId = m.currentPlayItemId
    ' resume prefere a posição do SERVIDOR (cache m.progressRows do pull M3 — ainda []
    ' até a Task 5 popular); sem row no servidor (ou 0) → fallback Registry local (M2)
    serverPos = ProgressFindPosition(m.progressRows, m.currentPlayItemId)
    if serverPos <= 0 then
        serverPos = ResumeGetPosition(m.currentPlayItemId)
    end if
    m.playerScreen.resumeSeconds = serverPos
    ' play novo começa SEM legendas até o SubsTask do item corrente responder
    ' (evita legendas do item anterior vazarem no novo)
    m.subsJson = ""
    m.playerScreen.subsJson = m.subsJson
    m.playerScreen.streamJson = FormatJson(m.streams[index])
    ShowScreen(m.playerScreen)
    StartSubsTask()
end sub

sub StartSubsTask()
    if m.subsTask = invalid then
        m.subsTask = createObject("roSGNode", "SubsTask")
        m.subsTask.observeField("success", "OnSubsLoaded")
    end if
    m.subsTask.subType = m.currentItem.type
    m.subsTask.subId = m.currentPlayItemId
    m.pendingSubsId = m.currentPlayItemId
    m.subsTask.control = "STOP"
    m.subsTask.control = "RUN"
end sub

sub OnSubsLoaded()
    if m.pendingSubsId <> m.currentPlayItemId then
        return
    end if
    if m.playerScreen <> invalid and m.subsTask.success then
        m.subsJson = m.subsTask.subsJson
        m.playerScreen.subsJson = m.subsJson
    end if
end sub

sub OnPlayFailed()
    if not m.playerScreen.playFailed then return
    nextIndex = m.streamIndex + 1
    if nextIndex < m.streams.count() then
        ' spec §4: direct-play falhou → próxima stream (mesma tela, re-injetada).
        ' Reset do playFailed DEPOIS de StartPlay: observers em main-thread disparam
        ' síncronos — reset antes re-entraria no handler e dispararia retry duplo.
        StartPlay(nextIndex)
        m.playerScreen.playFailed = false
    else
        m.currentScreen = m.playerScreen
        m.top.removeChild(m.playerScreen)
        ShowScreen(m.homeScreen)
        m.homeScreen.error = "Falha ao reproduzir todas as streams."
    end if
end sub

sub OnPlayFinished()
    if not m.playerScreen.playFinished then return
    ShowScreen(m.detailScreen)
end sub

sub OnPlayerExit()
    if not m.playerScreen.exitRequested then return
    ShowScreen(m.detailScreen)
end sub

' ---------- progress sync (M3) ----------

sub OnProgressPing()
    ping = parseJson(m.playerScreen.progressPing)
    ' position <= 0 NÃO vai pro servidor: upsert zeraria a row (lose resume cross-device)
    if ping = invalid or ping.position = invalid or ping.position <= 0 or m.currentItem = invalid then
        return
    end if
    StartProgressPush(m.currentPlayItemId, m.currentItem.type, ping.position, ping.duration)
end sub

sub StartProgressPush(itemId as string, contentType as string, posSeconds as integer, durSeconds as integer)
    if m.progressTask = invalid then
        m.progressTask = createObject("roSGNode", "ProgressTask")
        m.progressTask.observeField("error", "OnProgressPushError")
        ' success também observado: o MESMO node pode ter sido criado pelo pull/cw
        ' da home (e vice-versa o push reusa o node do pull — observers são os dois)
        m.progressTask.observeField("success", "OnProgressTaskSuccess")
    end if
    m.progressTask.mode = "push"
    m.progressTask.progressRowJson = FormatJson(ProgressToServerRow(itemId, contentType, posSeconds, durSeconds))
    ' classifica o success do push como no-op no OnProgressTaskSuccess — o node é
    ' compartilhado com pull/cw e um success de push não pode cair no branch "cw"
    ' (double-prepend) nem no "pull" (re-chain) de um ciclo anterior
    m.progressMode = "push"
    m.progressTask.control = "STOP"
    m.progressTask.control = "RUN"
end sub

sub OnProgressPushError()
    ' silencioso por design: sync falhou → próximo ping tenta de novo (Registry local é o fallback)
end sub

' pull → cw em DOIS estágios no mesmo task node: o pull popula o cache de resume
' (m.progressRows para o StartPlay pref-servidor) e o cw enriquece para a row da
' home. OnProgressTaskSuccess faz o split por m.progressMode.
sub StartProgressPull()
    if m.progressTask = invalid then
        m.progressTask = createObject("roSGNode", "ProgressTask")
        m.progressTask.observeField("success", "OnProgressTaskSuccess")
        m.progressTask.observeField("error", "OnProgressPushError")
    end if
    m.progressTask.mode = "pull"
    m.progressTask.control = "STOP"
    m.progressTask.control = "RUN"
    m.progressMode = "pull"
end sub

sub OnProgressTaskSuccess()
    if not m.progressTask.success then
        return
    end if
    if m.progressMode = "pull" then
        rows = parseJson(m.progressTask.rowsJson)
        if rows <> invalid and type(rows) = "roArray" then
            m.progressRows = rows
        end if
        ' segundo estágio: enriquecer e pedir o prepend
        m.progressTask.mode = "cw"
        m.progressTask.control = "STOP"
        m.progressTask.control = "RUN"
        m.progressMode = "cw"
    else if m.progressMode = "cw" and m.progressTask.rowsJson <> "" and m.currentScreen <> invalid and m.currentScreen.isSameNode(m.homeScreen) then
        m.homeScreen.prependRowJson = m.progressTask.rowsJson
    else if m.progressMode = "push" then
        ' mantém o cache de resume fresco: replay pós-back usa a posição recém-empurrada
        pushed = parseJson(m.progressTask.progressRowJson)
        if pushed <> invalid and pushed.doesExist("progress_key") then
            found = false
            for i = 0 to m.progressRows.count() - 1
                if m.progressRows[i].doesExist("progress_key") and m.progressRows[i].progress_key = pushed.progress_key then
                    m.progressRows[i] = pushed
                    found = true
                    exit for
                end if
            end for
            if not found then
                m.progressRows.unshift(pushed)
            end if
        end if
    end if
end sub

function ProgressFindPosition(rows as object, itemId as string) as integer
    if rows = invalid then
        return 0
    end if
    key = ProgressBuildKey(itemId)
    for each r in rows
        if r.doesExist("progress_key") and r.progress_key = key then
            if r.doesExist("position") and r.position <> invalid then
                return ProgressMsToSeconds(r.position)
            end if
        end if
    end for
    return 0
end function

' ---------- streams (M2) ----------

sub OnPlayRequested()
    if not m.detailScreen.playRequested then return
    itemId = m.detailScreen.playItemId
    m.detailScreen.playRequested = false
    if itemId = "" then
        return
    end if
    m.pendingStreamsMode = ""
    StartStreamTask(m.currentItem.type, itemId)
end sub

' picker só p/ filme (stream de série sem episódio não é contrato congelado — T-judgment 1)
sub OnStreamsRequested()
    if not m.detailScreen.streamsRequested then return
    m.detailScreen.streamsRequested = false
    m.pendingStreamsMode = "pick"
    StartStreamTask(m.currentItem.type, m.currentItem.id)
end sub

sub StartStreamTask(stype as string, sid as string)
    ' guarda o id REALMENTE tocado (episódio = tt:s:e) — resume/legendas/player usam ele
    m.currentPlayItemId = sid
    m.bootSpinner.visible = true
    if m.streamTask = invalid then
        m.streamTask = createObject("roSGNode", "StreamTask")
        m.streamTask.observeField("success", "OnStreamsLoaded")
        m.streamTask.observeField("error", "OnStreamsError")
    end if
    m.streamTask.streamType = stype
    m.streamTask.streamId = sid
    m.playGeneration = m.playGeneration + 1
    m.streamTaskGeneration = m.playGeneration
    m.streamTask.control = "STOP"
    m.streamTask.control = "RUN"
end sub

sub OnStreamsLoaded()
    if m.streamTaskGeneration <> m.playGeneration then return
    ' guard antes do spinner: StreamTask zera success no início do execute — o fire
    ' espúrio (false) não deve apagar o spinner nem seguir adiante.
    if not m.streamTask.success then
        return
    end if
    m.bootSpinner.visible = false
    m.streams = parseJson(m.streamTask.streamsJson)
    if m.pendingStreamsMode = "pick" then
        m.pendingStreamsMode = ""
        ShowStreams()
    else
        StartPlay(0)
    end if
end sub

sub OnStreamsError()
    if m.streamTask.error = "" then return
    if m.streamTaskGeneration <> m.playGeneration then return
    m.bootSpinner.visible = false
    err = m.streamTask.error
    if err = "" then
        err = "Falha ao carregar as streams."
    end if
    if err = "session_expired" then
        SessionClearSession()
        StartSessionTask("boot")
        return
    end if
    ' Detail não tem campo de erro — o caminho de erro volta pra Home com mensagem visível
    ShowScreen(m.homeScreen)
    m.homeScreen.error = TranslateAuthError(err)
end sub

sub ShowStreams()
    ' recreate a cada abertura: node fresco garante itemSelected/streamPicked zerados
    ' (mesma classe de deadness do itemSelected do M1); ""→json segue o marker do StartPlay.
    m.streamsScreen = createObject("roSGNode", "StreamsScreen")
    m.streamsScreen.observeField("streamPicked", "OnStreamPicked")
    m.streamsScreen.streamsJson = ""
    m.streamsScreen.streamsJson = m.streamTask.streamsJson
    ShowScreen(m.streamsScreen)
end sub

sub OnStreamPicked()
    StartPlay(m.streamsScreen.streamPicked)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "back" and m.currentScreen <> invalid then
        name = m.currentScreen.subtype()
        if name = "StreamsScreen" and m.detailScreen <> invalid then
            ShowScreen(m.detailScreen)
            return true
        end if
        if name = "DetailScreen" and m.homeScreen <> invalid then
            ' back invalida qualquer fetch de streams em voo (orphaned-task guard)
            m.playGeneration = m.playGeneration + 1
            ' back do Detail volta à ORIGEM: busca (M4) ou home
            if m.detailFromSearch and m.searchScreen <> invalid then
                ShowScreen(m.searchScreen)
            else
                ShowScreen(m.homeScreen)
            end if
            return true
        end if
        if name = "SearchScreen" and m.homeScreen <> invalid then
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
