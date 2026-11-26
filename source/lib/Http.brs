' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' Http — helpers de rede para uso DENTRO de task nodes (nunca no UI thread, spec §3.1).
' Padrão assíncrono roUrlTransfer + port do task; resposta congelada na forma
' {ok, code, body, json, error} — os contratos curl 01–09 são a referência dos JSONs.

function HttpInit()
    m.httpPort = createObject("roMessagePort")
    return true
end function

function HttpNewTransfer() as object
    tx = createObject("roUrlTransfer")
    tx.setCertificatesFile("common:/certs/ca-bundle.crt")
    tx.initClientCertificates()
    tx.retainBodyOnError(true)
    tx.enableCookies()
    return tx
end function

function HttpApplyHeaders(tx as object, headers as object)
    if headers = invalid then return invalid
    for each key in headers
        tx.addHeader(key, headers[key])
    end for
end function

function HttpGetJson(url as string, headers as object) as object
    tx = HttpNewTransfer()
    tx.setUrl(url)
    HttpApplyHeaders(tx, headers)
    tx.setMessagePort(m.httpPort)
    tx.asyncGetToString()
    return HttpWaitResponse(tx)
end function

function HttpPostJson(url as string, headers as object, body as string) as object
    tx = HttpNewTransfer()
    tx.setUrl(url)
    HttpApplyHeaders(tx, headers)
    tx.setMessagePort(m.httpPort)
    tx.asyncPostFromString(body)
    return HttpWaitResponse(tx)
end function

function HttpWaitResponse(tx as object, timeoutMs = 30000 as integer) as object
    result = { ok: false, code: 0, body: "", json: invalid, error: "no_response" }
    msg = wait(timeoutMs, m.httpPort)
    if type(msg) = "roUrlEvent" and msg.getSourceIdentity() = tx.getIdentity() then
        ' roUrlEvent.kTypeTransferComplete = 1
        if msg.getInt(0) = 1 then
            result.code = msg.getResponseCode()
            result.body = msg.getString()
            if result.code >= 200 and result.code < 300 then
                result.ok = true
                result.error = ""
            end if
            if result.body.len() > 0 then
                result.json = parseJson(result.body)
            end if
            if not result.ok then
                result.error = "http_" + result.code.toStr()
            end if
        else
            result.error = "transfer_failed"
        end if
    else if type(msg) = "roUrlEvent" then
        ' evento órfão de transferência antiga (timeout anterior) — descarta e continua esperando a nossa
        return HttpWaitResponse(tx, timeoutMs)
    else
        tx.asyncCancel()
        result.error = "timeout"
    end if
    return result
end function
