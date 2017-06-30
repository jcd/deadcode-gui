module deadcode.gui.widgetlocation;

import deadcode.gui.widget : Widget;

enum RelativeLocation
{
	topOf,
	bottomOf,
	leftIn,
	rightIn,
	above,
	below,
	leftOf,
	rightOf,
	inside,
}

enum WidgetPlacementResult
{
	success,
	placementInsideNotPossible,
}

/// The preferred location of a widget
struct PreferredLocation
{
	string widgetName;          /// Name of widget that the subject should be relative to or null if window
	RelativeLocation location;  /// The location relative to the names widget
}

WidgetPlacementResult placeWidgetRelative(Widget placeThisWidget, Widget relativeToThisWidget, RelativeLocation loc)
{
	import deadcode.gui.layouts;

	auto w = relativeToThisWidget;

	Widget layoutWidget = null;

	// TODO: fix bottom and right positions
	final switch (loc)
	{
		case RelativeLocation.bottomOf:
			bool horz = true;
			auto lo = cast(GridLayout)w.layout;
			if (lo !is null && lo.direction == GridLayout.Direction.column)
			{
				placeThisWidget.parent = w;
			}
			else
			{
				auto newLayout = new Widget();
				//newLayout.features ~= new VerticalLayout(false, VerticalLayout.Mode.scaleChildren);
				newLayout.layout = new GridLayout(GridLayout.Direction.column, 1);

				//newLayout.features ~= new VerticalLayout(false);
				w.parent.replaceChild(w, newLayout);
				w.parent = newLayout;
				// w.features = w.features.filter!(a => cast(ConstraintLayout)a is null).array;
				w.manualLayout = false;
				placeThisWidget.parent = newLayout;
			}
			break;
		case RelativeLocation.topOf:
			bool horz = true;
			layoutWidget = getFirstAncestorWithLayout!VerticalLayout(w);
			break;
		case RelativeLocation.leftIn:
			bool horz = false;
			layoutWidget = getFirstAncestorWithLayout!HorizontalLayout(w);
			if (layoutWidget !is null)
				placeThisWidget.parent = layoutWidget;
			break;
		case RelativeLocation.rightIn:
			bool horz = false;
			layoutWidget = getFirstAncestorWithLayout!HorizontalLayout(w);
			break;
		case RelativeLocation.above:
			bool horz = true;
			layoutWidget = getFirstAncestorWithLayout!VerticalLayout(w);
			if (layoutWidget is w)
				layoutWidget = getFirstAncestorWithLayout!VerticalLayout(w.parent);
			if (layoutWidget !is null)
				placeThisWidget.parent = layoutWidget;
			break;
		case RelativeLocation.below:
			bool horz = true;
			layoutWidget = getFirstAncestorWithLayout!VerticalLayout(w);
			if (layoutWidget is w)
				layoutWidget = getFirstAncestorWithLayout!VerticalLayout(w.parent);
			break;
		case RelativeLocation.leftOf:
			bool horz = false;
			layoutWidget = getFirstAncestorWithLayout!HorizontalLayout(w);
			if (layoutWidget is w)
				layoutWidget = getFirstAncestorWithLayout!HorizontalLayout(w.parent);
			if (layoutWidget !is null)
				placeThisWidget.parent = layoutWidget;
			break;
		case RelativeLocation.rightOf:
			bool horz = false;
			layoutWidget = getFirstAncestorWithLayout!HorizontalLayout(w);
			if (layoutWidget is w)
				layoutWidget = getFirstAncestorWithLayout!HorizontalLayout(w.parent);
			break;
		case RelativeLocation.inside:
			layoutWidget = getFirstAncestorWithLayout!StackLayout(w);
			if (layoutWidget is w)
				placeThisWidget.parent = w;
			else
			{
				return WidgetPlacementResult.placementInsideNotPossible;
				//addMessage("Cannot put widget '%s' inside widget '%s'", placeThisWidget.name, relativeToWidgetWithThisName);
			}
			break;
	}
	return WidgetPlacementResult.success;
}

private Widget getFirstAncestorWithLayout(LayoutType)(Widget _parent)
{
	while (_parent !is null)
	{
		if ( (cast(LayoutType)(_parent.layout)) !is null)
			return _parent;
		_parent = _parent.parent;
	}
	return null;
}

private Widget getFirstAncestorWithFeature(FeatureType)(Widget _parent)
{
	while (_parent !is null)
	{
		if (getFeatureByType!FeatureType(_parent) !is null)
			return _parent;
		_parent = _parent.parent;
	}
	return null;
}


/+
// Dispatch.
class WidgetLocationUpdater
{
    private
    {
        static struct ScheduledLocationUpdate
        {
			// Either id or name should be set. ID takes precedens
			Widget widgetIDToPlace;
			Widget widgetNameToPlace;

			// Either id or name should be set. ID takes precedens
			string relativeWidgetID;
			string relativeWidgetName;

            RelativeLocation location;

            bool done =  false;
        }
        ScheduledLocationUpdate[] _items;
		Application app;
    }

	this(IWidgetLookup a)
	{
		app = a;
	}

    // Schedule a widget to have its location relative to another widget
    // set.
	void scheduleWidgetPlacement(WidgetID placeThisWidget, WidgetID relativeToWidgetWithThisName, RelativeLocation loc)
    {
        assumeSafeAppend(_items);
        _items ~= ScheduledLocationUpdate(placeThisWidget, null, relativeToWidgetWithThisName, null, loc);
    }

    // Schedule a widget to have its location relative to another widget
    // set.
	void scheduleWidgetPlacement(WidgetID placeThisWidget, string relativeToWidgetWithThisName, RelativeLocation loc)
    {
        assumeSafeAppend(_items);
        _items ~= ScheduledLocationUpdate(placeThisWidget, null, NullWidgetID, relativeToWidgetWithThisName, loc);
    }

	// Schedule a widget to have its location relative to another widget
    // set.
	void scheduleWidgetPlacement(string placeThisWidget, WidgetID relativeToWidgetWithThisName, RelativeLocation loc)
    {
        assumeSafeAppend(_items);
        _items ~= ScheduledLocationUpdate(null, placeThisWidget, relativeToWidgetWithThisName, null, loc);
    }

	// Schedule a widget to have its location relative to another widget
    // set.
	void scheduleWidgetPlacement(string placeThisWidget, string relativeToWidgetWithThisName, RelativeLocation loc)
    {
        assumeSafeAppend(_items);
        _items ~= ScheduledLocationUpdate(NullWidgetID, placeThisWidget, NullWidgetID, relativeToWidgetWithThisName, loc);
    }

    void performLocationUpdates()
    {
        if (_items.empty)
            return;

        bool changed = true;
        bool anyChange = false;
        while (changed)
        {
            changed = false;
            foreach (ref i; _items)
            {
                if (!i.done)
                {
					auto res = app.placeWidgetRelative(i.w, i.relativeWidget, i.location);
					final switch (res)
					{
						case Application.WidgetPlacementResult.success:
							i.done = true;
							break;
						case Application.WidgetPlacementResult.placementInsideNotPossible:
							app.addMessage("Cannot place %s inside %s", i.w.name, i.relativeWidget);
							i.done = true;
							break;
						case Application.WidgetPlacementResult.unknownRelativeWidget:
							break;
					}
                    changed = changed || i.done;
                    anyChange = anyChange || changed;
                }
            }
        }

        if (anyChange)
        {
            assumeSafeAppend(_items);
            int nextSlot = 0;
            foreach (i, loc; _items)
            {
                if (!loc.done)
                {
                    swap(_items[nextSlot], loc);
                    nextSlot++;
                }
            }
        }
    }
}
+/