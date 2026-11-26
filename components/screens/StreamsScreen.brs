' NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
' StreamsScreen — picker de streams (nome + formato). Índice emitido = posição na
' LISTA (que é a streamsJson filtrada — AVI não chega até aqui).

sub init()
    m.list = m.top.findNode("streamList")
    m.list.observeField("itemSelected", "OnListSelected")
    m.count = 0
end sub

sub OnStreamsSet()
    streams = parseJson(m.top.streamsJson)
    if streams = invalid or type(streams) <> "roArray" then
        return
    end if
    m.count = streams.count()
    content = createObject("roSGNode", "ContentNode")
    for each s in streams
        node = content.createChild("ContentNode")
        node.title = s.name + "  [" + s.format + "]"
    end for
    m.list.content = content
    m.list.setFocus(true)
end sub

sub OnListSelected()
    idx = m.list.itemSelected
    if idx <> invalid and idx >= 0 and idx < m.count then
        m.top.streamPicked = idx
    end if
end sub
