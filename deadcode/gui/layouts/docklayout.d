module deadcode.gui.layouts.docklayout;

import std.algorithm;
import std.range;

import deadcode.test;
import deadcode.gui.event;
import deadcode.gui.widget : Widget;
import deadcode.gui.window : MouseCursor;
import deadcode.gui.layouts;
import deadcode.gui.style.types;
import deadcode.math;

class DockHostSplitter : Widget
{
	MouseCursor mouseCursorToRevertTo;
	bool isOver = false;

	this()
	{
		auto w = new Widget();
		w.parent = this;
	}

	final override EventUsed onMouseOverEvent(MouseOverEvent e)
	{
		mouseCursorToRevertTo = window.mouseCursor;
		window.mouseCursor = MouseCursor.sizeNS;
		isOver = true;
		return EventUsed.no;
	}

	final override EventUsed onMouseMoveEvent(MouseMoveEvent e)
	{
		if ((isOver || isGrabbingMouse) && (e.buttons & MouseButtonFlag.left) != 0)
		{
			auto d = cast(DockHost!false)parent;
			d.onSplitterMoved(e, this);
			if (!isGrabbingMouse)
				grabMouse();
			return EventUsed.yes;
		}
		return EventUsed.no;
	}

	final override EventUsed onMouseReleasedEvent(MouseReleasedEvent e)
	{
		releaseMouse();
		return EventUsed.no;
	}

	final override EventUsed onMouseOutEvent(MouseOutEvent e)
	{
		window.mouseCursor = mouseCursorToRevertTo;
		isOver = false;
		return EventUsed.no;
	}
}


class DockHost(bool isHorz) : Widget
{
	this()
	{
		auto s = styleOverride;
		s.position = CSSPosition.relative;
		layout = new DockLayout!isHorz();
	}

	private void onSplitterMoved(MouseMoveEvent e, DockHostSplitter splitter)
	{
		auto idx = children.countUntil!(a => a.id == splitter.id);
		assert(idx != -1);
		assert(idx > 0);
		assert(idx + 1 < children.length);

		// Adjust the two docked widgets on each side of the splitter
		Widget a;
		foreach_reverse (w; children[0..idx])
		{
			if (!w.style.position.isOutOfFlow && w.style.height.isValid && w.style.height.unit == CSSUnit.pct)
			{
				a = w;
				break;
			}
		}				
		
		Widget b;
		foreach_reverse (w; children[idx+1..$])
		{
			if (!w.style.position.isOutOfFlow && w.style.height.isValid && w.style.height.unit == CSSUnit.pct)
			{
				b = w;
				break;
			}
		}				

		assert(a !is null);
		assert(b !is null);

		auto aH = a.styleOverride.height;
		auto pctPerPixel = aH.value / a.rect.h;

		a.styleOverride.height = CSSScale(a.styleOverride.height.value + e.relative.y * pctPerPixel, CSSUnit.pct);
		b.styleOverride.height = CSSScale(b.styleOverride.height.value - e.relative.y * pctPerPixel, CSSUnit.pct);
		
		a.lastStyleVersion = uint.max;
		a.recalculateStyle();
		b.lastStyleVersion = uint.max;
		b.recalculateStyle();
	}

    override void layoutChildren(bool fit, Widget positionReference)
	{
		layout.layout(this, fit);
		
		// Adjust pct of docked widget that are flexible to make sure they
		// sum to 100%
		float flexScale = (cast(DockLayout!isHorz) layout).flexScale;
		foreach (w; children)
		{
			if (w.style.position.isOutOfFlow)
				continue;

			auto h = w.style.height;
			if (h.isValid && h.unit == CSSUnit.pct)
				w.styleOverride.height = CSSScale(h.value * flexScale, CSSUnit.pct);
		}
	
		// Also setup the child widget to have the correct pct scale that 
		// is forced here. This will
		// help when doing the resizing of the dock areas using the mouse.
		//w.styleOverride.height = CSSScale(h.value * scaleH, CSSUnit.pct);

		// Override child pct styles to make sure pct of all child pct scaled
		// widgets sums to 1.
		// Also place sizing widget between docked widgets.
		size_t numChildren = children.length;

		// Remove any splitters from front and end of children
		int idx = 0;
		
		// Remove splitters before first docked widget if any
		while (idx < children.length && children[idx].style.position.isOutOfFlow)
		{
			if (cast(DockHostSplitter)children[idx] !is null)
				removeChildAt(idx); // Splitters in as first children should be removed
			else
				idx++; // Other out of flow children should just stay
		}

		// Remove splitters after last docked widget if any
		idx = children.empty ? 0 : children.length - 1;
		while (idx < children.length && children[idx].style.position.isOutOfFlow)
		{
			if (cast(DockHostSplitter)children[idx] !is null)
				removeChildAt(idx); // Splitters in as first children should be removed
			idx--; // Other out of flow children should just stay
		}
		
		if (children.length <= 1)
			return;

		auto f = children
			.enumerate
			.retro
			.filter!(a => cast(DockHostSplitter)a[1] !is null || !a[1].style.position.isOutOfFlow);

		import std.exception;
		enforce(children.length < 64, "Limit of 64 children in DockHost reached");
		typeof(f.front)[64] buf;

		f.copy(buf[]);

		// From here in the patterns must be 
		// splitter -> widget -> splitter ... -> widget
		// or we should collapse splitters or insert splitters as nescessary
		
		auto r = buf[].find!(a => a[1] !is null);
		if (r.length <= 1)
			return;

		// Pop last docked widget
		Rectf lastRect = r.front[1].rect;
		r.popFront();

		bool lastWasSplitter = false;

		foreach (a; r)
		{
			if (a[1] is null)
				break;

			auto splitter = cast(DockHostSplitter)a[1];

			if (lastWasSplitter)
			{
				if (splitter is null)
				{
					lastRect = a[1].rect;
					lastWasSplitter = false;	
				}
				else
				{
					// Two splitters in a row should be collapsed
					removeChildAt(a[0]);
				}
			}
			else
			{
				Rectf splitterRect;
				Widget activeSplitter;
				if (splitter is null)
				{
					// So last was a docked widget and this is also a widget. We need to insert a splitter.
					activeSplitter = new DockHostSplitter();
					activeSplitter.parent = this;
					moveChildToIndex(_children.length-1, a[0]+1);
					activeSplitter.styleOverride.position = CSSPosition.absolute;
					activeSplitter.styleOverride.zIndex = 100;
					lastRect = a[1].rect;
					splitterRect = lastRect;
				}
				else
				{
					lastWasSplitter = true;
					activeSplitter = a[1];
					splitterRect = lastRect;
				}

				splitterRect.y -= 5;
				splitterRect.h = 10;
				activeSplitter.rect = splitterRect;

				auto so = activeSplitter.styleOverride; 
				if (so.top.value != splitterRect.y)
				{
					so.top = CSSScale(splitterRect.y, CSSUnit.pixels);
					activeSplitter.lastStyleVersion = uint.max;
					activeSplitter.recalculateStyle();
				}
				if (so.left.value != splitterRect.x)
				{
					so.left = CSSScale(splitterRect.x, CSSUnit.pixels);
					activeSplitter.lastStyleVersion = uint.max;
					activeSplitter.recalculateStyle();
				}
				if (so.width.value != splitterRect.w)
				{
					so.width = CSSScale(splitterRect.w, CSSUnit.pixels);
					activeSplitter.lastStyleVersion = uint.max;
					activeSplitter.recalculateStyle();
				}
				if (so.height.value != splitterRect.h)
				{
					so.height = CSSScale(splitterRect.h, CSSUnit.pixels);
					activeSplitter.lastStyleVersion = uint.max;
					activeSplitter.recalculateStyle();
				}
			}
		}
	}
	
}

class DockLayout(bool isHorz) : ILayout
{
	float flexScale = 1;

	override void layout(Widget widget, bool fit)
	{
		auto children = widget.children;
		if (children is null || children.length == 0) return; // nothing to layout

		RectfOffset pad = widget.style.padding;
		auto r = widget.rect.offset(pad);

		static if (isHorz)
		{
			assert(0);
            /*
            // Divide the current height into even horizontal pieces
            int fractionalItems = 0;
            float fixedPixels = 0;

			foreach (w; children)
			{
				w.y = r.y;
                if (w.style.height.isValid)
                {
                    float pixels = w.style.height.calculatePixels(r.h);
                    w.w = pixels;
                }
                else
                {
                    w.h = r.h;
                }

                if (w.style.width.isValid)
                {
                    float pixels = w.style.width.calculatePixels(r.w);
                    fixedPixels += pixels;
                    w.w = pixels;
                }
                else
                {
                    // TODO: add a fractional css property instead of always using 1 as here
                    fractionalItems += 1;
                }
			}

            float widthLeft = r.w - fixedPixels;
            float dW = widthLeft / fractionalItems;

            if (widthLeft < 0) 
                dW = 0;

            foreach (w; children)
			{
                w.x = r.x;
				if (w.style.width.isValid)
                {
                    r.x += w.w;
                }
                else
                {
                    w.w = dW;
                    r.x += dW;
                }
			}
            */
		}
		else
		{
			// Divide the current height into even horizontal pieces
            int fractionalItems = 0;
            float fixedPixels = 0;

			foreach (w; children)
			{
				auto h = w.style.height;
                if (h.isValid && h.unit == CSSUnit.pixels && !w.style.position.isOutOfFlow)
                {
                    float pixels = h.calculatePixels(r.h);
					fixedPixels += pixels;
				}
			}

			auto flexHeight = r.h - fixedPixels;
			if (flexHeight < 0)
				flexHeight = 0;

			float pctPixels = 0;

			foreach (w; children)
			{
				if (w.style.position.isOutOfFlow)
					continue;
				w.x = r.x;
                if (w.style.width.isValid)
                {
                    float pixels = w.style.width.calculatePixels(r.w);
                    w.w = pixels;
                }
                else
                {
                    w.w = r.w;
                }

                if (w.style.height.isValid)
                {
                    float pixels = w.style.height.calculatePixels(r.h);
                    if (w.style.height.unit == CSSUnit.pct)
						pctPixels += pixels;
                    w.h = pixels;
                }
                else
                {
					assert(0);
                    // TODO: add a fractional css property instead of always using 1 as here
                    //fractionalItems += 1;
                }
			}

            float heightLeft = r.h - fixedPixels - pctPixels;
           // float dH = heightLeft / fractionalItems;
			flexScale = 1;

			bool hasOverflow = heightLeft < 0;


            if (hasOverflow) 
			{
				// dH = 0;
				// Scale fixed pixels to fit
				flexScale = flexHeight / pctPixels;
			}

            foreach (idx, w; children)
			{
				if (w.style.position.isOutOfFlow)
					continue;

                w.y = r.y;
				auto h = w.style.height;
				if (h.isValid)
                {
					//if (idx != 0)
					//{
					//    w.onMouseMoveCallback(&handleMouseMoveEvent);
					//}

                    if (h.unit == CSSUnit.pct)
					{
						r.y += w.h * flexScale;
					}
					else
						r.y = w.h;
				}
                else
                {
					assert(0);
					//w.h = dH;
                    //r.y += dH;
                }
			}
        }
	}

	//final private EventUsed handleMouseMoveEvent(Event e, Widget w)
	//{
	//    import deadcode.gui.window : MouseCursor;
	//    MouseMoveEvent ev = cast(MouseMoveEvent)e;
	//    auto hitRect = w.rect;
	//    hitRect.h = 5;
	//    if (hitRect.contains(ev.position))
	//        w.window.mouseCursor(MouseCursor.sizeNS);
	//    else if (w.window.mouseCursor == MouseCursor.sizeNS)
	//        w.
	//    return EventUsed.no;
	//}
}



alias DockLayout!true HorizontalDockLayout;
alias DockLayout!false VerticalDockLayout;

version (unittest)
{
    import deadcode.gui.widget : Widgets, WidgetID;
    Widgets generateWidgets(int count)
    {
        Widgets result;
        foreach (WidgetID i; 0..count)
        {
            result ~= new Widget(i+1);
            result[$-1].styleOverride.padding = RectfOffset.zero;

            if (i != 0)
                result[$-1].parent = result[0];
        }
        result[0].layout = new DirectionalLayout!false();
        return result;
    }
}


@Test("Widget with no children",
      "Call layoutChildren",
      "Does Nothing")
unittest
{
    auto w = generateWidgets(1);
    w[0].layoutChildren(false, null);
    Assert(true); // Crash test
}

@Test("Widget with one child and no padding",
      "Call layoutChildren",
      "Child gets same rect as parent")
unittest
{
    auto w = generateWidgets(2);
    auto target = Rectf(10, 20, 30, 40);
    w[0].rect = target;
    Assert(w[0].rect != w[1].rect, "Initially child rect is not equal to parent rect");
    w[0].layoutChildren(false, null);
    Assert(w[0].rect, w[1].rect);
}


@Test("Widget with two children and no padding",
      "Call layoutChildren",
      "Each child gets half rect of parent")
unittest
{
    auto w = generateWidgets(3);
    auto target = Rectf(10, 20, 30, 40);
    w[0].rect = target;
    w[0].layoutChildren(false, null);

    Rectf expectedTopRect = w[0].rect;
    expectedTopRect.h *= 0.5f;
    Assert(expectedTopRect, w[1].rect, "Top rect");

    Rectf expectedBottomRect = w[0].rect;
    expectedBottomRect.h *= 0.5f;
    expectedBottomRect.y += expectedBottomRect.h; 
    Assert(expectedBottomRect, w[2].rect, "Bottom rect");
}

@Test("Widget with one child and padding",
      "Call LayoutChildren",
      "Child gets same rect as parent minus padding")
unittest
{
    auto w = generateWidgets(2);
    auto target = Rectf(10, 20, 30, 40);
    w[0].rect = target;
    auto padding = RectfOffset(1,2,3,4);
    w[0].style.padding = padding;
    w[0].layoutChildren(false, null);
    Assert(w[0].rect.offset(padding), w[1].rect);
}

@Test("Widget with two children and padding",
      "Call layoutChildren",
      "Each child gets half rect of parent minus padding")
unittest
{
    auto w = generateWidgets(3);
    auto target = Rectf(10, 20, 30, 40);
    w[0].rect = target;

    auto padding = RectfOffset(1,2,3,4);
    w[0].style.padding = padding;
    w[0].layoutChildren(false, null);
    
    auto r = w[0].rect.offset(padding);
    Rectf expectedTopRect = r;
    expectedTopRect.h *= 0.5f;
    Assert(expectedTopRect, w[1].rect, "Top rect");

    Rectf expectedBottomRect = r;
    expectedBottomRect.h *= 0.5f;
    expectedBottomRect.y += expectedBottomRect.h; 
    Assert(expectedBottomRect, w[2].rect, "Bottom rect");
}


@Test("Widget with 10 children and padding",
      "Call layoutChildren",
      "First and last child get expected rect")
unittest
{
    auto w = generateWidgets(11);
    auto target = Rectf(10, 20, 30, 40);
    w[0].rect = target;

    auto padding = RectfOffset(1,2,3,4);
    w[0].style.padding = padding;
    w[0].layoutChildren(false, null);

    auto r = w[0].rect.offset(padding);
    Rectf expectedTopRect = r;
    expectedTopRect.h *= 0.1f;
    Assert(expectedTopRect, w[1].rect, "Top rect");

    Rectf expectedBottomRect = r;
    expectedBottomRect.h *= 0.1f;
    expectedBottomRect.y = r.y2 - expectedBottomRect.h;
    auto diff = expectedBottomRect - w[10].rect; 
    auto epsilon = 0.001;
    Assert(diff.pos.length < epsilon, "Bottom rect pos is correct");
    Assert(diff.size.length < epsilon, "Bottom rect size is correct");
}
