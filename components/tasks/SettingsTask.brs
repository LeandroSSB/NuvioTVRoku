' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' SettingsTask — teste de conexão + probe de backend novo (M4, spec §3.2).
' mode="test": GET /.well-known/nuvio do backend CORRENTE (getBackendUrl() — testa
' o que está configurado, sem input). mode="probe": GET /.well-known/nuvio da
' probeUrl (backend digitado no Settings) — o MainScene SÓ persiste backend_url se
' o probe responder (nada de brick por URL errada). GET público (sem Bearer/sessão):
' roda mesmo com sessão morta — "session_expired" não existe aqui. Sucesso exige
' resposta 2xx com publishable_key (a mesma forma que o ResolveAnonKey M1 aceita).
' Erros seguem o vocabulário do Http.brs (http_XXX/timeout/transfer_failed) +
' well_known_failed para resposta sem chave.

sub init()
    HttpInit()
end sub

sub execute()
    m.top.success = false
    m.top.error = ""
    if m.top.mode <> "test" and m.top.mode <> "probe" then
        m.top.error = "invalid_mode"
        return
    end if
    targetUrl = getBackendUrl()
    if m.top.mode = "probe" then
        targetUrl = m.top.probeUrl
    end if
    resp = HttpGetJson(targetUrl + "/.well-known/nuvio", { })
    if resp.ok and resp.json <> invalid and resp.json.doesExist("publishable_key") then
        m.top.success = true
        return
    end if
    ' 2xx sem publishable_key (HttpWaitResponse zera o error em 2xx) → não é backend Nuvio
    if resp.error = "" then
        m.top.error = "well_known_failed"
        return
    end if
    m.top.error = resp.error
end sub
