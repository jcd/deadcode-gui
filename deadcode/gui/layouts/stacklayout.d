module deadcode.gui.layouts.stacklayout;

import deadcode.gui.event;
import deadcode.gui.widget : Widget;
import deadcode.gui.layouts;
import deadcode.math;

/** Layouting of child widgets
*
* When this feature is set on a widget all child widgets will
* be layed by this class.
*/
class StackLayout : ILayout
{
	override void layout(Widget widget, bool fit)
	{
		auto children = widget.children;
		if (children is null || children.length == 0) return; // nothing to layout

		Rectf rect = widget.rect;

		RectfOffset pad = widget.style.padding;

		// Layout children until out of widget rect bounds
		auto r = Rectf(rect.x + pad.left, rect.y + pad.top, rect.w - pad.horizontal, rect.h - pad.vertical);

		foreach (ref w; children)
		{
			if (w.visible)
			{
				w.rect = r;
				break;
			}
		}
	}
}
