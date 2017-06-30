module deadcode.gui.label;

import deadcode.gui.widget;
import deadcode.gui.widgetfeatures.textrenderer;

import deadcode.math;

class Label : Widget
{
	private TextRenderer!string _renderer;

	//override const(Vec2f) preferredSize()
	//{
	//    auto ps = renderer.layoutSize;
	//    if (ps.x != 0 && ps.y != 0)
	//        return max(ps, size);
	//    auto fontHeight = style.font.fontHeight;
	//
	//    return max(Vec2f(100, fontHeight), size);
	//}

	this(string text)
	{
		super();
		_renderer = content(this, text);
	}

	@property
	{
		void text(string text)
		{
			_renderer.text = text;
		}

		string text()
		{
			return _renderer.text;
		}
	}

	//override protected void calculateSize()
	//{
	//    size = intrinsicSize;
	//    super.calculateSize();
	//}

	override const(Vec2f) intrinsicSize() {
		_renderer.ensureLayedOut(this);
		Vec2f isize = _renderer.layoutSize;

		RectfOffset pad = style.padding;
		isize.x += pad.horizontal;
		isize.y += pad.vertical;
		return isize;
	}
}
