module deadcode.gui.widgetfeatures;

static import deadcode.core.event;
import deadcode.gui.widget : Widget;
import deadcode.gui.style;

class WidgetFeature
{
	deadcode.core.event.EventUsed send(deadcode.core.event.Event event, Widget widget) { return deadcode.core.event.EventUsed.no; }
	void update(Widget widget) {}
	void draw(Widget widget) {}
}

public import deadcode.gui.widgetfeatures.boxrenderer;
public import deadcode.gui.widgetfeatures.dragger;
public import deadcode.gui.widgetfeatures.textrenderer;
public import deadcode.gui.widgetfeatures.windowdragger;
public import deadcode.gui.widgetfeatures.windowresizer;
public import deadcode.gui.widgetfeatures.ninegridrenderer;

