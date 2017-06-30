module deadcode.gui.layouts;

import deadcode.gui.widget;

interface ILayout
{
	void layout(Widget w, bool fit);
}

public import deadcode.gui.layouts.constraintlayout;
public import deadcode.gui.layouts.directionallayout;
public import deadcode.gui.layouts.gridlayout;
public import deadcode.gui.layouts.stacklayout;
