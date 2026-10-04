' MainScene — tela raiz do esqueleto M0 (versão + backend configurado).
sub init()
    title = m.top.findNode("title")
    detail = m.top.findNode("detail")
    title.text = "Nuvio TV (Roku)"
    detail.text = "v" + getAppVersion() + chr(10) + "backend: " + getBackendUrl() + chr(10) + "M0 skeleton — aguardando telas do M1"
end sub
