module deadcode.gui.controls.scrollarea;
version(none):

import deadcode.edit.bufferview;
import deadcode.gui.event : MouseWheelEvent, EventUsed;
import deadcode.gui.widget;
import deadcode.gui.widgetfeatures;
import deadcode.math;

class ScrollView : Widget
{
	private
    {
        Widget _scrollContent;
        Vec2f _scrollOffset = Vec2f(0f, 0f);
        Vec2f _scrollSpeed = Vec2f(4f, 4f);
    }

    @property
    {
        const(Vec2f) contentSize() const
        {
            return _scrollContent.size;
        }

        void contentSize(Vec2f sz)
        {
            _scrollContent.size = sz;
        }

        void scrollSpeed(Vec2f s) pure nothrow @safe
        {
            _scrollSpeed = s;
        }

        Vec2f scrollSpeed() const pure nothrow @safe
        {
            return _scrollSpeed;
        }

        Widget contentWidget() pure nothrow @safe
        {
            return _scrollContent;
        }
    }

    this(Vec2f contentSize) nothrow
	{
        _scrollContent = new Widget(this, 0, 0, contentSize.x, contentSize.y);
    }

	override EventUsed onMouseWheelEvent(MouseWheelEvent event)
    {
        _scrollOffset += e.scroll * _scrollSpeed;
        _scrollOffset = _scrollOffset.min(Vec2f(0,0));
        forceDirty();
        return EventUsed.yes;
    }


    override void updateLayout(bool fit, Widget positionReference)
	{
        _scrollContent.pos = rect.offset(_scrollOffset).pos;
        _scrollContent.updateLayout(fit, _scrollContent);
    }

    override void draw()
	{
		if (!visible || w() == 0)
			return;

     	import derelict.opengl3.gl3;

		Rectf r = rect;
		r.y = window.size.y - (r.h + r.y);

		glScissor( cast(int)r.x, cast(int)r.y, cast(int)r.w, cast(int)r.h);
		glEnable(GL_SCISSOR_TEST);
		super.draw();
		glDisable(GL_SCISSOR_TEST);
    }
}
