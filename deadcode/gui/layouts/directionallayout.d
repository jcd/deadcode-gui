module deadcode.gui.layouts.directionallayout;

import deadcode.test;
import deadcode.gui.event;
import deadcode.gui.widget : Widget;
import deadcode.gui.layouts;
import deadcode.math;

/** Layouting of child widgets
*
* When this feature is set on a widget all child widgets will
* be layed by this class.
*/
class OldDirectionalLayout(bool isHorz) : ILayout
{
	//override EventUsed send(Event event, Widget widget)
	//{
	//    if (event.type != EventType.Resize)
	//        return EventUsed.no;
	//
	//    updateLayoutPreferred(widget);
	//    return EventUsed.no;
	//}

	private bool _stretchLastItem;

	enum Mode
	{
		scaleChildren,
		cullChildren,
	}
	private Mode _mode;

	this(bool stretchLastItem = true, Mode mode = Mode.cullChildren)
	{
		_stretchLastItem = stretchLastItem;
		_mode = mode;
	}

	override void layout(Widget widget, bool fit)
	{
		auto children = widget.children;
		if (children is null || children.length == 0) return; // nothing to layout

		final switch (_mode)
		{
			case Mode.scaleChildren:
				scaledLayout(widget, fit);
				break;
			case Mode.cullChildren:
				culledLayout(widget, fit);
				break;
		}
	}

	final private void culledLayout(Widget widget, bool fit)
	{
		auto children = widget.children;

		Rectf rect = widget.rect;

		static if (isHorz)
		{
			// Divide the current width into even horizontal pieces
			float d = rect.w / children.length;
			auto r = Rectf(rect.x, rect.y, d, rect.w);
			foreach (ref w; children)
			{
				w.rect = r;
				r.pos.x += d;
			}
		}
		else
		{
			RectfOffset pad = widget.style.padding;

			// Layout children until out of widget rect bounds
			auto r = Rectf(rect.x + pad.left, rect.y + pad.top, rect.w, 0);

			if (fit)
			{
				rect.h = 1000000f;
				rect.w = 1000000f;
			}

			foreach (ref w; children)
			{
				//Style childStyle = w.style;
				//if (style.position == CSSPosition.absolute || style.position == CSSPosition.fixed)
				//    continue;

				// no more room to in parent widget to layout children
				// w.visible = r.y < rect.y2;

				// r.h = w.preferredSize.y;
				Vec2f childSizeStyled = w.size;
				r.h = childSizeStyled.y;

				if (r.y < rect.y2)
					r.w = childSizeStyled.x;
				else
					r.w = 0; // collapse to skip rendering this child

				if (r.y2 > rect.y2)
				{
					// This widget cannot fit. Make it smaller in order to fit.
					float tmp = r.h;
					r.y2 = rect.y2;
					w.rect = r;
					r.h = tmp;
				}
				else
				{
					w.rect = r;
				}

				//if (w.id == 8)
				//    std.stdio.writeln("w8 pos ", w.pos.y);

				r.pos.y += r.h + 1.0; // 1 to prevent overlap
			}

			// If there is any space left then give it to the last widget
			if (_stretchLastItem && !fit && children[$-1].rect.y2 < (rect.y2 - pad.bottom))
			{
				Rectf rr = children[$-1].rect;
				rr.size.y += widget.rect.y2 - children[$-1].rect.y2 - pad.bottom;
				children[$-1].rect = rr;
			}
		}
	}

	final private void scaledLayout(Widget widget, bool fit)
	{
		auto children = widget.children;

		RectfOffset pad = widget.style.padding;
		const rect = widget.rect;
		auto r = Rectf(rect.x + pad.left, rect.y + pad.top, rect.w, 0);

		static if (isHorz)
		{
			// Divide the current width into even horizontal pieces
			float d = rect.w / children.length;
			r.w = d;
			foreach (ref w; children)
			{
				w.rect = r;
				r.pos.x += d;
			}
		}
		else
		{
			//// Get accumulated height for children
			//float fixedH = 0f;    // child has a fixed height set
			//float relativeH = 0f; // child has a relative height set
			//foreach (ref w; children)
			//{
			//
			//    h += w.h;
			//}

			// Divide the current height into even horizontal pieces
			float d = rect.h / children.length;
			r.h = d;
			foreach (ref w; children)
			{
				w.rect = r;
				r.pos.y += d;
			}
		
            /*
            FlexSize childrensFlex;
			int fractions = 0;
            
            float w = rect.w;

            foreach (idx, ref w; children)
			{
				auto style = w.style;
                int frac = style.layoutFraction;
                if (frac < 0)
                {
                    // Fit to child widget. ie. don't allocate a fraction.
                    FlexSize f = { 
                        Vec2f(style.minWidth.calculatePixels(w), style.minHeight.calculatePixels(d)),
                        Vec2f(style.maxWidth.calculatePixels(w), style.maxHeight.calculatePixels(d)),
                        Vec2f(style.width.calculatePixels(w), style.height.calculatePixels(d))
                    };

                    childrensFlex += f;
                }
                else
                {
                    fractions += frac;
                }
                //w.rect = r;
                //r.pos.y += d;
			}
        */
        }
	}
}

class DirectionalLayout(bool isHorz) : ILayout
{
	override void layout(Widget widget, bool fit)
	{
		auto children = widget.children;
		if (children is null || children.length == 0) return; // nothing to layout

		RectfOffset pad = widget.style.padding;
		auto r = widget.rect.offset(pad);

		static if (isHorz)
		{
            assert(0);
		}
		else
		{
			// Divide the current height into even horizontal pieces
            int fractionalItems = 0;
            float fixedPixels = 0;

			foreach (w; children)
			{
				w.x = r.x;
                if (w.style.width.isValid)
                {
                    float pixels = w.style.width.calculatePixels(r.w);
                    w.h = pixels;
                }
                else
                {
                    w.w = r.w;
                }

                if (w.style.height.isValid)
                {
                    float pixels = w.style.height.calculatePixels(r.h);
                    fixedPixels += pixels;
                    w.h = pixels;
                }
                else
                {
                    // TODO: add a fractional css property instead of always using 1 as here
                    fractionalItems += 1;
                }
			}

            float heightLeft = r.h - fixedPixels;
            float dH = heightLeft / fractionalItems;

            if (heightLeft < 0) 
                dH = 0;

            foreach (w; children)
			{
                w.y = r.y;
				if (w.style.height.isValid)
                {
                    r.y += w.h;
                }
                else
                {
                    w.h = dH;
                    r.y += dH;
                }
			}
        }
	}
}



alias DirectionalLayout!true HorizontalLayout;
alias DirectionalLayout!false VerticalLayout;

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
