module deadcode.gui.application;

import core.time;

import deadcode.animation.timer;
import deadcode.core.event : Event;
import deadcode.core.eventsource : MainEventSource, ITimer;
import deadcode.core.signals;
import deadcode.gui.gui : GUI;
import deadcode.gui.locations;
import deadcode.gui.resources.generic : GenericResource, GenericResourceManager;
import deadcode.gui.style.stylesheet;
import deadcode.gui.style.manager;
import deadcode.gui.window;
import deadcode.io.iomanager : FileManager;

class Application
{
    private
    {
        GUI _gui;
        GenericResource _sessionData;
        bool _running;
    }

    final @property
    {
        FileManager fileManager() { return _gui.fileManager; }
        MainEventSource eventSource() { return _gui.eventSource; };
        ITimer timer() { return _gui.eventSource.timer; };
        LocationsManager locationsManager() { return _gui.locationsManager; }
        StyleSheetManager styleSheetManager() { return _gui.styleSheetManager; }
		GenericResourceManager genericResourceManager() { return _gui.genericResourceManager; }
    }
    
    // (double timeSinceAppStart, double deltaTime)
    mixin Signal!(double, double) onUpdate;
    mixin Signal!Event onEvent;
    mixin Signal!() onStart;
    mixin Signal!() onStop;

    this(MainEventSource mainEventSource)
    {
        import deadcode.io.file;
        import deadcode.io.iomanager;
        import deadcode.graphics;
        
        auto fileMgr = new FileManager();
        fileMgr.add(new LocalFileProtocol);
        auto graphicsSystem = new OpenGLSystem;
        auto gui = new GUI(mainEventSource, graphicsSystem, fileMgr);
        
        this(gui);
    }

    this(GUI gui)
    {
        _gui = gui;
        _gui.onEvent.connect(&handleEvent);
        _sessionData = new GenericResource();
    }
   
    protected void handleEvent(Event ev)
    {
        onEvent.emit(ev);
    }

    int run()
	{
        // initProfiler();
		if (!_running)
        {
			_gui.init();
            _running = true;
            onStart.emit();
        }

		int ticks = 0;
		auto t = timer.currTime;
		while (_running)
		{
			tick();
			if (ticks-- <= 0)
			{
				ticks = 100;
                //auto t2 = timer.currTime;
                //Duration d = t2 - t;
                //t = t2;
                //double secs = cast(double)d.total!"hnsecs" * 0.0000001;
				// std.stdio.writeln(std.conv.text("FPS ", 100.0 / secs));
			}
		}

        onStop.emit();
        return 0;
	}

	void stop()
	{
		_running = false;
	}

    void tick()
    {
        onUpdate.emit(1,1);
        _gui.tick();
    }

    private final void queueStartCommands()
    {
        
    }

    W createWindow(W = Window)(string name = "MainWindow")
    {
        auto w = _gui.createWindow!W(name);
        w.show();
        return w;
    }
}

/*debug
{
    class TestWindow(MainWidget) : Window
    {
        this(const(char)[] _name, int width, int height, RenderTarget _renderTarget, StyleSheet ss)
        {
            super(_name, width, height, _renderTarget, ss);
        }
    }
}
*/
