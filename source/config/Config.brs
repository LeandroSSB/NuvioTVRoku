' Config — backend do NuvioTVRoku (spec §3.2).
' Default: backend oficial. Override self-host: setBackendUrl() (Settings, M4) —
' persistido em roRegistrySection "nuvio". Trocar backend exige re-login.

function getAppVersion() as string
    return "0.1.0"
end function

function getBackendUrl() as string
    reg = createObject("roRegistrySection", "nuvio")
    if reg.exists("backend_url")
        return reg.read("backend_url")
    end if
    return "https://api.nuvio.tv"
end function

sub setBackendUrl(url as string)
    reg = createObject("roRegistrySection", "nuvio")
    reg.write("backend_url", url)
    reg.flush()
end sub

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
