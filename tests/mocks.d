module tests.mocks;

import std.concurrency;
import std.process : environment;
import std.stdio;

import core.time;
import deadcode.core.coreevents;
import deadcode.core.ctx;
import deadcode.core.event;
import deadcode.core.eventsource;
import deadcode.core.log;
import deadcode.gui.event;
import deadcode.test;
import deadcode.util.queue;

import deadcode.gui.gui;
import deadcode.gui.window;
import deadcode.graphics;
import deadcode.io.iomanager;


shared static this()
{
    //mgr = new EventManager();
    //mgr.activateRegistrantBySystemName("GUI");
    //mgr.activateRegistrantBySystemName("Core");

    auto l = new Log();
    l.onAllMessages.connectTo((string msg, LogLevel l) {
        import std.stdio;
        writeln("LOG: ", l, " ", msg);
    });
    ctx.set(l);
}

T deserializeEvent(T)(T ev, JSONValue json)
{
    import tests.jsonserialized.deserialization;
    ev.deserializeFromJSONValue(json);
    return ev;
}

private Event parseEvent(string serializedEvent)
{
    import stdx.data.json;

    import std.string;    
    auto eventName = serializedEvent.munch("^ ");
    serializedEvent.munch(" ");
    auto json = toJSONValue(serializedEvent);
    auto event = GUIEvents.deserialize!deserializeEvent(eventName, json);
    if (event is null)
        event = CoreEvents.deserialize!deserializeEvent(eventName, json);
    if (event is null)
        writeln("parseEvent to null: ", json);
    return event;
}

string serializeEvent(T)(T e)
{
    import tests.jsonserialized.deserialization;

    JSONValue js = e.serializeToJSONValue();
    return T.stringof ~ " " ~ js.toJSON!(GeneratorOptions.compact);
}

class MockGUIEventSource : MainEventSource
{
	private Tid _mainTid;
    shared GrowableCircularQueue!(shared(Event)) _testEvents;

    this()
	{
        super(new SystemTimer());
	    _mainTid = thisTid();
        _testEvents = new typeof(_testEvents)();
    }

    package void loadTestEvents(R)(R lines) if (!is(R == string))
    {
        foreach (l; lines)
        {
            l = l.strip();
            if (l.length != 0)
                _testEvents.push(cast(shared) l.idup.parseEvent());
        }
    }
    
    package void loadTestEvents(string path)
    {
        auto f = File(path, "r");
        loadTestEvents(f.byLine());
    }

    package void pushTestEvent(shared(Event) e)
    {
        _testEvents.push(e);
    }

    private Event popNextTestEvent()
    {
        auto e = _testEvents.front();
        _testEvents.popFront();
        return cast(Event)e;
    }

	// A timeout should always put a TimeoutEvent on the queue
	protected override Event poll(Duration timeout_)
	{
		static import std.algorithm;

		long timeoutMiliseconds = timeout_.total!"msecs"();
		
        MonoTime currTime = MonoTime.currTime;
        MonoTime endTime = currTime + timeout_;
		Duration noDuration = dur!"seconds"(0);
        bool timedOut = true;

        Event ev = null;

        if (!_testEvents.empty)
        {
            ev = popNextTestEvent();
            return ev;
        }
		while (endTime > currTime)
		{
			import deadcode.core.log;
		    bool breakLoop = false;
            string eventFilePath = null;

            if (!_testEvents.empty)
            {
                ev = popNextTestEvent();
                return ev;
            }

            timedOut = receiveTimeout(endTime - currTime, 
                            (bool) { breakLoop = true; },
                            (string eventFile) { eventFilePath = eventFile; });
            
            if (eventFilePath !is null)
                loadTestEvents(eventFilePath);

			if (breakLoop)
            {
                return null; // Custom event is only send to break the poll loop when an Event is pushed on a queue directly
            }
            /*
			switch(e.type) {
				case SDL_MOUSEMOTION:
					ev = GUIEvents.create!MouseMoveEvent(
						e.motion.windowID, e.motion.which, cast(KeyMod)SDL_GetModState(),
						Vec2f(e.motion.x, e.motion.y), Vec2f(e.motion.xrel, e.motion.yrel),
						cast(MouseButtonFlag)e.motion.state);
					break;
				case SDL_MOUSEBUTTONDOWN:
					ev = GUIEvents.create!MousePressedEvent(
						e.button.windowID, e.button.which, cast(KeyMod)SDL_GetModState(),
						Vec2f(e.button.x, e.button.y), e.button.button, cast(MouseButtonFlag)e.motion.state);
					break;
				case SDL_MOUSEBUTTONUP:
					ev = GUIEvents.create!MouseReleasedEvent(
						e.button.windowID, e.button.which, cast(KeyMod)SDL_GetModState(),
						Vec2f(e.button.x, e.button.y), e.button.button, cast(MouseButtonFlag)e.motion.state);
					break;
				case SDL_MOUSEWHEEL:
					ev = GUIEvents.create!MouseWheelEvent(
						e.wheel.windowID, e.wheel.which, cast(KeyMod)SDL_GetModState(),
						Vec2f(e.wheel.x, e.wheel.y), e.wheel.direction == SDL_MOUSEWHEEL_FLIPPED);
					break;
				case SDL_KEYDOWN:
					static import core.stdc.string;
					dchar ch = SDL_GetKeyName(e.key.keysym.sym)[0..core.stdc.string.strlen(SDL_GetKeyName(e.key.keysym.sym))].front;
					ev = GUIEvents.create!KeyPressedEvent(
						e.key.windowID, cast(KeyMod)SDL_GetModState(), e.key.keysym.sym, ch);
					break;
				case SDL_KEYUP:
					static import core.stdc.string;
					dchar ch = SDL_GetKeyName(e.key.keysym.sym)[0..core.stdc.string.strlen(SDL_GetKeyName(e.key.keysym.sym))].front;
					ev = GUIEvents.create!KeyReleasedEvent(
						e.key.windowID, cast(KeyMod)SDL_GetModState(), e.key.keysym.sym, ch);
					break;
				case SDL_TEXTINPUT:
					char[] ch = cast(char[])e.text.text;
					ev = GUIEvents.create!TextEvent(
						e.text.windowID, cast(KeyMod)SDL_GetModState(), ch.front);
					break;
				case SDL_TEXTEDITING:
					break; // include chars while entering a unicode char. Where TEXTINPUT will get the uncode char itself.
				case SDL_WINDOWEVENT:
					switch (e.window.event)
					{
						case SDL_WINDOWEVENT_RESIZED:
							// We will always get SDL_WINDOWEVENT_SIZE_CHANGED before this event. This
							// event is only called if the changed size is caused by an external event such
							// as user window resize or window manager
							break;
						case SDL_WINDOWEVENT_SIZE_CHANGED:
							// SHIT! the size set here was the old window.size... be careful about recursive _dirtySize when fixing this!
							ev = GUIEvents.create!WindowResizedEvent(
								e.window.windowID, Vec2f(e.window.data1, e.window.data2));
							break;
						case SDL_WINDOWEVENT_FOCUS_GAINED:
							ev = GUIEvents.create!WindowFocussedEvent(e.window.windowID);
							break;
						case SDL_WINDOWEVENT_FOCUS_LOST:
							ev = GUIEvents.create!WindowUnfocussedEvent(e.window.windowID);
							break;
						default:
							break;
					}
					break;
				case SDL_SYSWMEVENT:
					version (Windows)
					{
						import win32.winuser;
						if (e.syswm.msg.msg.win.msg == WM_NCMOUSEMOVE)
						{
							auto lp = e.syswm.msg.msg.win.lParam;
							auto lplow = lp & 0XFFFF;
							auto lphigh = (lp >> 16) & 0xFFFF;
							auto xPos = (cast(int) cast(short)lplow);
							auto yPos = (cast(int) cast(short)lphigh);
							ev = GUIEvents.create!MouseMoveEvent(0, 0, cast(KeyMod)SDL_GetModState(),
																 Vec2f(xPos, yPos), Vec2f(0,0),
																 cast(MouseButtonFlag)0);
						}
					}
					break;
				case SDL_DROPFILE:
					import std.c.string;
					auto file = e.drop.file[0..strlen(e.drop.file)].idup;
					auto keyMod = cast(KeyMod)SDL_GetModState();
					ev = GUIEvents.create!DropFile(file, keyMod);
					// TODO FIX: SDL_free(e.drop.file);
					break;
				case SDL_QUIT:
					ev = CoreEvents.create!QuitEvent();
					break;
				default:
					break;
			}
            */
            currTime = MonoTime.currTime;
        }

        return ev;
	}
    
	// Called by other threads that just called put(event) on 
	// us in order to wake us up and handle the event.
	protected override void signalEventQueuedByOtherThread()
	{
		_mainTid.send(true);
	}
}


class Fixture
{

    package
    {
        MockGUIEventSource eventSource;
        GUI gui;
        FileManager fileManager;
        Window window;
        static OpenGLSystem graphicsSystem;
    }

    this()
    {
        if (graphicsSystem is null)
            graphicsSystem = new OpenGLSystem();
        eventSource = new MockGUIEventSource();
        scope (exit) destroy(eventSource);

        fileManager = new FileManager();
        scope (exit) destroy(fileManager);

        gui = new GUI(eventSource, graphicsSystem, fileManager);
        scope (exit) destroy(gui);

        window = gui.createWindow();
        scope (exit) destroy(window);

        test();

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

    abstract void test();

    E push(E : GUIEvent, Args...)(Args args)
    {
        auto ev = GUIEvents.create!E(args);
        return ev;
    }

    E push(E : QuitEvent)()
    {
        auto ev = CoreEvents.create!E();
        return ev;
    }

    E push(E : TimeoutEvent, Args...)(Args args)
    {
        auto ev = CoreEvents.create!E(args);
        return ev;
    }

    /*
    private void run()
    {
        auto ev = CoreEvents.create!QuitEvent();
        auto evJSON = serializeEvent(ev);
        writeln(evJSON);

        enum testEvents =  q"EOD
            KeyPressedEvent {"code":48,"timestamp":{},"name":"KeyPressedEvent","modifiers":0,"unicodeChar":65,"used":false,"windowID":1}
            QuitEvent {"name":"QuitEvent","used":false,"timestamp":{}}
            EOD";
        
        _eventSource.loadTestEvents(testEvents.splitLines());

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
}

//mixin template Test(alias Func, Fixture)
//{
//    unittest
//    {
//        Fixture!Func().run();
//    }
//}
