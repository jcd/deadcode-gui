module deadcode.gui.controls.scrollview;

import deadcode.edit.bufferview;
import deadcode.gui.event : MouseWheelEvent, EventUsed;
import deadcode.gui.widget;
import deadcode.gui.widgetfeatures;
import deadcode.math;

class ScrollView : Widget
{
	private
    {
        Widget _scrollArea;
        Vec2f _scrollOffset = Vec2f(0f, 0f);
        Vec2f _scrollSpeed = Vec2f(4f, 4f);
    }

    @property
    {
        const(Vec2f) contentSize() const
        {
            return _scrollArea.size;
        }

        void contentSize(Vec2f sz)
        {
            _scrollArea.size = sz;
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
            return _scrollArea;
        }
    }

    this(Vec2f contentSize) nothrow
	{
        _scrollArea = new Widget(this, 0, 0, contentSize.x, contentSize.y);

   		onMouseWheelCallback = &scroll;
    }

    private deadcode.core.event.EventUsed scroll(MouseWheelEvent e, Widget w)
    {
        _scrollOffset += e.scroll * _scrollSpeed;
        _scrollOffset = _scrollOffset.min(Vec2f(0,0));
        forceDirty();
        return EventUsed.yes;
    }


    override void updateLayout(bool fit, Widget positionReference)
	{
        _scrollArea.pos = rect.offset(_scrollOffset).pos;
        _scrollArea.updateLayout(fit, _scrollArea);
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
