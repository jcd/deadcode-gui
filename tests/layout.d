module tests.layout;

import core.time;
import deadcode.core.coreevents;
import deadcode.core.event;
import deadcode.gui.event;
import deadcode.gui.keycode;
import deadcode.test;

import tests.mocks;

/*
unittest
{
    auto es = new MockGUIEventSource();
    ctx.set!MainEventSource(es);

    auto ev = CoreEvents.create!QuitEvent();
    auto evJSON = serializeEvent(ev);
    writeln(evJSON);

    enum testEvents =  q"EOD
        KeyPressedEvent {"code":48,"timestamp":{},"name":"KeyPressedEvent","modifiers":0,"unicodeChar":65,"used":false,"windowID":1}
        QuitEvent {"name":"QuitEvent","used":false,"timestamp":{}}
EOD";
    es.loadTestEvents(testEvents.splitLines());

    auto fs = new FileManager();
    auto g = new GUI(es, new OpenGLSystem(), fs);
    auto w = g.createWindow();
    w.show();
    g.tick(); 

    //w.layout = new VerticalLayout();

    if (environment.get("GUITEST_WAIT") is null)
    {
        import core.thread;
        Thread.sleep(dur!"seconds"(2));
    }
    else
    {
        import std.stdio;
        stdin.readln();
    }
}
*/

unittest
{
    new class Fixture {
        override void test()
        {
            enum testEvents =  q"EOD
                KeyPressedEvent {"code":48,"timestamp":{},"name":"KeyPressedEvent","modifiers":0,"unicodeChar":65,"used":false,"windowID":1}
                QuitEvent {"name":"QuitEvent","used":false,"timestamp":{}}
EOD";
            
            eventSource.loadTestEvents(testEvents.splitLines());

            window.show();
            gui.tick(); 
            //w.layout = new VerticalLayout();
        }
    };
}

unittest
{
    new class Fixture {
        override void test()
        {
            enum testEvents =  q"EOD
                KeyPressedEvent {"code":48,"timestamp":{},"name":"KeyPressedEvent","modifiers":0,"unicodeChar":65,"used":false,"windowID":1}
                QuitEvent {"name":"QuitEvent","used":false,"timestamp":{}}
EOD";
            // push!KeyPressedEvent(1, KeyMod.none, KeyCode.space, ' ');
            push!KeyPressedEvent(1, KeyMod.none, KKTMP.SDLK_SPACE, ' ');
            push!QuitEvent();

           // eventSource.loadTestEvents(testEvents.splitLines());

            window.show();
            gui.tick(); 
            //w.layout = new VerticalLayout();
        }
    };
}
