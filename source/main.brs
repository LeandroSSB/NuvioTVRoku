sub main()
    screen = createObject("roSGScreen")
    m.port = createObject("roMessagePort")
    screen.setMessagePort(m.port)
    scene = screen.createScene("MainScene")
    screen.show()
    while true
        msg = wait(0, m.port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed()
            exit while
        end if
    end while
end sub
