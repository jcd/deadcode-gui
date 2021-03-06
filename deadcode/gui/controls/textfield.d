module deadcode.gui.controls.textfield;

import deadcode.edit.bufferview;
import deadcode.gui.controls.texteditor;
import deadcode.gui.widget;
import deadcode.math;

class TextField : TextEditor
{
    //override const(Vec2f) preferredSize()
    //{
    //    auto ps = renderer.layoutSize;
    //    if (ps.x != 0 && ps.y != 0)
    //        return max(ps, size);
    //    auto fontHeight = style.font.fontHeight;
    //
    //    return max(Vec2f(100, fontHeight), size);
    //}

	this(BufferView buf)
	{
		super(buf);
		bufferView.visibleLineCount = 1;
	}

	override void draw()
	{
		if (!visible || w() == 0)
			return;
		renderer.ensureLayedOut(this);
		renderer.cursorSupported = hasKeyboardFocus;
		super.draw();
	}
}
