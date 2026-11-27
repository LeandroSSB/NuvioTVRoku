' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' Config — backend do NuvioTVRoku (spec §3.2).
' Default: backend oficial. Override self-host: Settings (M4) grava backend_url via
' SessionWrite no MainScene (só depois de PROBE bem-sucedido — Config nunca escreve).
' Trocar backend exige re-login.

function getBackendUrl() as string
    reg = createObject("roRegistrySection", "nuvio")
    if reg.exists("backend_url")
        return reg.read("backend_url")
    end if
    return "https://api.nuvio.tv"
end function

' Resolve a publishable key (anon Supabase) via /.well-known/nuvio.
' Retorna "" em falha. M0: chamada síncrona (esqueleto). M1: mover para task node.
function resolvePublishableKey(backendUrl as string) as string
    transfer = createObject("roUrlTransfer")
    transfer.setUrl(backendUrl + "/.well-known/nuvio")
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    body = transfer.getToString()
    if body = invalid or body = ""
        return ""
    end if
    json = parseJson(body)
    if json = invalid or not json.doesExist("publishable_key")
        return ""
    end if
    return json.publishable_key
end function
