module deadcode.gui.widget;

import deadcode.animation.mutator;
import deadcode.animation.timeline;
public import deadcode.core.event;
import deadcode.core.signals;
import deadcode.graphics;
import deadcode.gui.event;
import deadcode.gui.style;
import deadcode.gui.widgetfeatures;
import deadcode.gui.layouts;
import deadcode.gui.window;
import deadcode.math; // Rectf;

import std.algorithm;
import std.array : empty;
import std.math : isNaN;

// widget
// control

// Behaviors:
//   Grab mouse       :
//   Drag (drag area) : +windows, -controls
//   Dock             : +windows, -controls
//   Focus            : ++
//   Layout           : +windows, -controls
//   Constraints      : ++
//   Style            : +windows, +control
//   Animation        : ++
//   MouseSensitivity : ++ (considered for mouse interaction)

alias uint WidgetID;
enum NullWidgetID = 0u;

enum _traceDirty = false;

void _printDirty(lazy const(char)[] name)
{
	static if (_traceDirty)
	{
		import core.sys.windows.stacktrace;
		//std.stdio.writeln(name, " dirty ", new StackTrace());
		std.stdio.writeln(name);
	}
}

alias Widget[] Widgets;

class Widget : Stylable
{
	private static WidgetID _nextID = 1u;

	// mixin Reflect;

	WidgetID id;

	//@Persist
	string _name;

	//@Persist
	// float zOrder;

	//@Persist
	bool acceptsKeyboardFocus;

	//@Persist
	bool manualLayout;

	// Events
	alias EventUsed delegate(Event event, Widget widget) OnEvent;
	OnEvent[EventType] events;

	//struct StyleState
	//{
	//    Style targetStyle; // Can be null in the case where style has reached the target style
	//    Style style;       // The style going towards target style using transition settings. (instant per default)
	//}
	//
	//StyleState styleState;

	Timeline.Runner transitionRunner;
	Timeline.Runner backgroundSpriteAnimationRunner;
    Rectf backgroundSpriteRect;

    bool _recalculateStyle = true; // True if an event occurred that may result in a change to _targeStyle
	Style _targetStyle;         // Style found by lookup in stylesheet
	Style _widgetSpecificStyle; // Used to set style programatically and will override anything in _targetStyle
	Style _computedStyle;       // Used style. May also be influenced by transition animations.

    uint lastStyleID;
    uint lastStyleVersion;

	WidgetFeature[] features;
    ILayout layout;
	NineGridRenderer _background;
/*
	void accept(Serializer v)
	{
		v.visit(_name);
		v.visit(zOrder);
		v.visit(acceptsKeyboardFocus);
		v.visit(manualLayout);
		v.visit(featureNamesxxx);
		foreach (f; features)
			v.visit(f);
	}
*/
	const(string[]) classes() const pure nothrow @safe { return null; }

	mixin Signal!(Event) onKeyboardFocusSignal;
	mixin Signal!(Event) onKeyboardUnfocusSignal;

	@property Window window() pure nothrow @safe
	{
		return _parent is null ? null : _parent.window;
	}

	@property const(Window) window() const pure nothrow @safe
	{
		return _parent is null ? null : _parent.window;
	}

	// Move features to managers
	auto featuresByType(T)()
	{
		return features
				    .map!(a => cast(T)a)
				    .filter!(a => a !is null);
	}

    bool hasFeature(T)()
    {
        return !featuresByType!T.empty;
    }

	auto removeFeaturesByType(T)()
	{
		// TODO: do inplace remove instead
        import std.array;
        features = features
            .filter!(a => cast(T)a is null).array;
	}

	@property bool hasStyleOverride()
	{
		return _widgetSpecificStyle !is null;
	}

    //@property const(Style) styleOverride()
    //{
    //    if (_widgetSpecificStyle is null)
    //        _widgetSpecificStyle = new Style("");
    //    return _widgetSpecificStyle;
    //}

    @property Style styleOverride()
	{
		if (_widgetSpecificStyle is null)
			_widgetSpecificStyle = new Style("");
		return _widgetSpecificStyle;
	}

	// Convenience accessors
	@property NineGridRenderer background()
	{
		Style st = style;
		if (st !is null && st.background is null)
		{
			_background = null;
			return null;
		}
		else if (_background is null)
		{
			_background = new NineGridRenderer();
		}
		return _background;
	}

	//    foreach (f; features)
	//    {
	//        NineGridRenderer r = cast(NineGridRenderer)f;
	//        if (r)
	//            return r;
	//    }
	//    return null;
	//}

	//@property bool backgroundEnabled()
	//{
	//    return background !is null;
	//
	//    foreach (ref f; features)
	//    {
	//        NineGridRenderer r = cast(NineGridRenderer)f;
	//        if (r)
	//        {
	//            f = newBg;
	//        }
	//    }
	//
	//    WidgetFeature item = newBg;
	//    features = [item] ~ features;
	//}

    void recalculateStyle() nothrow pure @safe
    {
        _recalculateStyle = true;
    }

    /*
        A widgets style consists of three styles:
        1, the target style as found by inspecting the stylesheets
        2, the overridden style properties set directly on a widget instance
        3, the computed style which is used for rendering

        The computed style is not necessarily a mix between the target and override style since
        a transition animation may be in progress which alters the computed style to transition towards
        target+overide style.

        Some stuff can invalidate current widgets target style:
        * Name or class or pseudo class change of any widget that is used for a css selector for this widget
        * Add or remove of any widget that is used for a css selector for this widget

        Some stuff can invalidate current widgets override style:
        * override style changed

        Some stuff can change the final computed style:
        * All that changes target or override style as desribed above.
        * Modifications done by the animation system

        The simplest solution to decrease recalc of computed style a bit is to recalc all styles when:
        * A pseudo condition has changed on any widget
        * A name or class has changed on any widget
        * Override style has changed on this widget
        * A widget is added or deleted

        That means the common case of moving/scaling/animating does not require recalc.
        TODO: Later the stylesheet.getStyle() could return the set of widgets that were part of a match and
              only recalc style if they changed (would not work for the widget-added case of course).
    */
    @property Style style()
	{
		if (id == 8)
		{
			int a = 0;
			a++;
		}

        if (!_recalculateStyle && _computedStyle !is null)
            return _computedStyle;

		version (Profiler) auto frameZonex = Zone(profiler, "CalcStyle");

        //if (!_recalcTarget
        //    return _computedStyle;

		// Get the style that this widget is supposed to have.
		// In case the widgets current active style is not that style
		// and the target style has transitions set we need to
		// animate style changes.
        bool itn = _targetStyle !is null;
		version (unittest)
        {
            Style newTargetStyle = window is null || window.styleSheet is null ? 
                new Style("") : 
            window.styleSheet.getStyle(this);
        }
        else
        {
            Style newTargetStyle = window.styleSheet.getStyle(this);
        }

		if (_computedStyle is null)
		{
			// Overlay the override style on top of targetStyle
			_targetStyle = newTargetStyle;

			Style endTargetStyle = _targetStyle;
			if (_widgetSpecificStyle !is null)
			{
				endTargetStyle = _widgetSpecificStyle.clone();
				endTargetStyle.styleSheet = null;
				endTargetStyle.overlay(_targetStyle);
			}

			_computedStyle = endTargetStyle;
			//_computedStyle = newTargetStyle.clone();

		}
		else if (_targetStyle !is newTargetStyle || lastStyleVersion == uint.max)
		{
			_targetStyle = newTargetStyle;

			if (_targetStyle.hasTransitions)
			{
				if (_computedStyle.styleSheet !is null)
				{
					// A transition animation is going to be done and the current style
					// is owned by a style sheet. Make a clone that the widget can own and
					// animate.
					_computedStyle = _computedStyle.clone();
					_computedStyle.styleSheet = null;
				}

				import deadcode.animation.clip;
				auto clip = new Clip!Style();
				//clip.createCurves!CubicCurve(0, _computedStyle, 0.5, _targetStyle);
				snapshotInterpolatedStyle();

				// Overlay the override style on top of targetStyle
				Style endTargetStyle = _targetStyle;
				if (_widgetSpecificStyle !is null)
				{
					endTargetStyle = _widgetSpecificStyle.clone();
					endTargetStyle.styleSheet = null;
					endTargetStyle.overlay(_targetStyle);
				}

                static import deadcode.gui.style;
				deadcode.gui.style.createCurves(clip, _computedStyle, endTargetStyle);

				// clip.createCubicCurve!"x"(0, x, 1, x+100.0);
				if (transitionRunner !is null)
					transitionRunner.abort();
				transitionRunner = window.timeline.animate(_computedStyle, clip);
			}
			else
			{
				if (transitionRunner !is null)
					transitionRunner.abort();

				if (_computedStyle.styleSheet is null)
					destroy(_computedStyle);

				// Overlay the override style on top of targetStyle
				Style endTargetStyle = _targetStyle;
				if (_widgetSpecificStyle !is null)
				{
					endTargetStyle = _widgetSpecificStyle.clone();
					endTargetStyle.styleSheet = null;
					endTargetStyle.overlay(_targetStyle);
				}

				_computedStyle = endTargetStyle;
			}
		}

        if (_computedStyleChanged())
        {
            forceDirty();
            stopBackgroundSpriteAnimation();
            backgroundSpriteRect = _computedStyle.backgroundSprite;
            if (visible)
                startBackgroundSpriteAnimation();
            lastStyleID = _computedStyle.id;
            lastStyleVersion = _computedStyle.currentVersion;
        }

		_recalculateStyle = false;
		return _computedStyle;
	}

    protected void startBackgroundSpriteAnimation() nothrow
    {
        if (_computedStyle.backgroundSpriteAnimation !is null)
        {
            // TODO: get rid of closure
            backgroundSpriteAnimationRunner =
                window.timeline.animate(_computedStyle.backgroundSpriteAnimation.frameTime,
                                        (double timestamp, int count) {
                                            backgroundSpriteRect = _computedStyle.getBackgroundSpriteRectForFrame(count);
                                        });
        }
    }

    protected void stopBackgroundSpriteAnimation() nothrow
    {
        if (backgroundSpriteAnimationRunner !is null)
        {
            backgroundSpriteAnimationRunner.abort();
            backgroundSpriteAnimationRunner = null;
        }
    }

    private bool _computedStyleChanged()
    {
        return _computedStyle !is null &&
            (lastStyleVersion != _computedStyle.currentVersion ||
            lastStyleID != _computedStyle.id);
    }

	// Copy current dimensions of this widget to it style in order to use the style as starting point for
	// an animation.
	private void snapshotInterpolatedStyle()
	{
		assert(_computedStyle.styleSheet is null);
		CSSScale nullScale = CSSScale(0, CSSUnit.pixels);
		// Vec2f p = calcPosition(_computedStyle);

		_computedStyle.position = CSSPosition.fixed;
		_computedStyle.right = nullScale;
		_computedStyle.bottom = nullScale;

		_computedStyle.left = CSSScale(_rect.x, CSSUnit.pixels);
		_computedStyle.top = CSSScale(_rect.y, CSSUnit.pixels);
		_computedStyle.width = CSSScale(_rect.w, CSSUnit.pixels);
		_computedStyle.height = CSSScale(_rect.h, CSSUnit.pixels);
	}

	/*
	@property Style style()
	{
		// Get the style that this widget is supposed to have.
		// In case the widgets current active style is not that style
		// and the target style has transitions set we need to
		// animate style changes.
		Style newTargetStyle = window.styleSheet.getStyleForWidget(this);

		return newTargetStyle;
		//if (_computedStyle.matchesStyle(newTargetStyle))
		//    return _computedStyle;

		// Got a new target. Schedule transitions if necessary. (and abort existing)

	}
	*/

	//
	//private void onStyleChanged(UsedStyle s)
	//{
	//    if (s !is _computedStyle)
	//        s.onChanged.disconnect(&onStyleChanged);
	//    else
	//        _sizeDirty = true; // force a redraw... TODO: this also forces layout which is wrong (maybe)
	//}

	//Style getStyleForClass(string className)
	//{
	//    return window.styleSheet.getStyle(this, [className]);
	//}

	//void transition(Property*

	@property bool visible() const nothrow @safe
    {
        return _visible;
    }

	@property bool ancestorsVisible() nothrow @safe
	{
		auto w = this;
		while (w !is null && w.visible)
			w = w.parent;
		return w is null;
	}

    @property void visible(bool v)
    {
        if (_visible == v)
            return;
        int a = 0;
		if (this.id == 77 )
		{
			if (v)
				a++;
			else
				a--;
		}
		_visible = v;

        if (_computedStyle)
        {
            if (v)
                startBackgroundSpriteAnimation();
            else
                stopBackgroundSpriteAnimation();
        }

        // If this widget has keyboard focus then release it.
        if (!_visible)
        {
            auto win = window;
            if (window !is null && window.getKeyboardFocusWidgetID == id)
                window.setKeyboardFocusWidget(NullWidgetID);
        }

        recalculateStyle();
    }

    void show()
    {
        visible = true;
    }

    void hide()
    {
        visible = false;
    }

	protected
	{
		@Bindable()
		Rectf _rect;  // rect for events like mouse over etc.
		Vec2f _minSize;
		Vec2f _maxSize;

        bool _sizeDirty;
		Widget _parent;
		Widgets _children;
    }

    protected bool _visible;

	private void eventCallbackHelper(EventT)(EventType t, EventUsed delegate(EventT, Widget) del) nothrow
	{
		if (del is null)
			events.remove(t);
		else
			events[t] = (Event e, Widget w) { return del(cast(EventT)e, w); } ;
	}

	@property
	{
		Widget closestNamed()
		{
			Widget cur = this;
			while (cur !is null && cur.name is null)
				cur = cur.parent;
			return cur;
		}

		string[] nameStack()
		{
			string[] result;
			Widget cur = this;
			while (cur !is null)
			{
				auto n = cur.name;
				if (n !is null)
					result ~= n;
			    cur = parent;
            }
			return result;
		}

		string name() const pure nothrow @safe
		{
			return _name;
		}

		void name(string n) nothrow
		{
			_name = n;
			if (window !is null)
				window.setWidgetName(this, n);
            recalculateStyle();
		}

		ubyte matchStylable(string stylableName) const pure nothrow @safe
		{
			return matchStylableImpl(this, stylableName);
		}

		/*
		ref Rectf rect()
		{
			_printDirty("rect");
			_sizeDirty = true;
			return _rect;
		}
		*/

		void rect(Rectf r)
		{
//			import core.sys.windows.stacktrace;
            //if (r != _rect)
            //{
            //    _sizeDirty = true;
				_rect = r;
				//_printDirty("rect");
//			}
		}

		Rectf rect() const
		{
			return _rect;
		}

		package void forceDirty()
		{
			_sizeDirty = true;
		}

		//const(Rectf) rectStyled()
		//{
		//    return calcRect(style);
		//    //auto st = style;
		//    //final switch (st.position)
		//    //{
		//    //    case CSSPosition.fixed:
		//    //        if (this is window)
		//    //            return calcRect(_rect, st);
		//    //        return calcRect(window.rectStyled, st);
		//    //    case CSSPosition.absolute:
		//    //        Widget p = parent; // lookFirstPositionedParent();
		//    //        if (p is null)
		//    //            return calcRect(_rect, st);
		//    //        return calcRect(p.rectStyled, st);
		//    //    case CSSPosition.relative:
		//    //        return calcRect(_rect, st);
		//    //    case CSSPosition.static_:
		//    //        break;
		//    //    case CSSPosition.invalid:
		//    //        break;
		//    //}
		//    return _rect;
		//}

/*
		private const(Rectf) calcBaseRectForPosition(CSSPosition cssPos)
		{
			Rectf res = _rect;
			final switch (cssPos)
			{
				case CSSPosition.fixed:
					if (this !is window)
						res = window.rect;
					else
						return rect;
				case CSSPosition.absolute:
					Widget p = parent; // lookFirstPositionedParent();
					if (p !is null)
						res = p.rect;
					else
						return rect();
				case CSSPosition.relative:
					break;
				case CSSPosition.static_:
					return _rect;
					break;
				case CSSPosition.invalid:
					return _rect;
					break;
			}

			Widget p = parent; // lookFirstPositionedParent();
			if (p is null)
				res.size = window.size;
			else
				res.size = p.size;

			return res;
		}
*/

		/*
		// Like .rect but with padding applied
		const(Rectf) contentRect()
		{
			auto st = style;
			return _rect.offset(st.padding);
		}

		// Like .rect but with padding applied
		void contentRect(Rectf r)
		{
			auto st = style;
			rect = _rect.offset(st.padding.reverse());
		}
*/
		const(Vec2f) size() const
		{
			return _rect.size;
		}

		void size(Vec2f sz)
		{
			_printDirty("size");
            //if (sz != _rect.size)
            //{
            //    _sizeDirty = true;
			    _rect.size = sz;
//            }
		}

		const(Vec2f) intrinsicSize() {
			Vec2f invalid;
			return invalid;
		}

		void size(Vec2i sz)
		{
			size = Vec2f(sz.x, sz.y);
		}

        void minSize(Vec2f sz)
        {
            _minSize = sz;
        }

        void maxSize(Vec2f sz)
        {
            _maxSize = sz;
        }

        //
        //const(Vec2f) preferredSize()
        //{
        //    return size;
        //}
        //
        //void preferredSize(Vec2f prefSize)
        //{
        //
        //}

        //const(Vec2f) minSize()
        //{
        //    return _minSize;
        //}
        //
        //void minSize(Vec2f mSize)
        //{
        //}
        //
        //const(Vec2f) maxSize()
        //{
        //    return preferredSize;
        //}
        //
        //void maxSize(Vec2f mSize)
        //{
        //}

		ref float x()
		{
			return _rect.x;
		}

		const(float) x() const
		{
			return _rect.x;
		}

		ref float y()
		{
			return _rect.y;
		}

		const(float) y() const
		{
			return _rect.y;
		}

        ref float w()
        {
            return _rect.w;
        }

        const(float) w() const
		{
			return _rect.w;
		}

        ref float minWidth()
        {
            return _minSize.x;
        }

        const(float) minWidth() const
		{
            return _minSize.x;
		}

        ref float maxWidth()
        {
            return _maxSize.x;
        }

        const(float) maxWidth() const
		{
            return _maxSize.x;
		}

        //@Bindable()
        //void w(float value)
        //{
        //    //std.stdio.writeln("h ", name, " ", _rect.h);
        //    if (_rect.w != value)
        //    {
        //        _printDirty("w");
        //        _sizeDirty = true;
        //        _rect.w = value;
        //    }
        //}


		ref h()
		{
            return _rect.h;
		}

		const(float) h() const
		{
			return _rect.h;
		}

        ref float minHeight()
        {
            return _minSize.y;
        }

        const(float) minHeight() const
		{
            return _minSize.y;
		}

        ref float maxHeight()
        {
            return _maxSize.y;
        }

        const(float) maxHeight() const
		{
            return _maxSize.y;
		}

		Vec2f pos()
		{
			return _rect.pos;
		}

		void pos(Vec2f p)
		{
			_rect.pos = p;
        }

        void overridePos(Vec2f p)
        {
			_rect.pos = p;
            styleOverride(); // ensure override style
            _widgetSpecificStyle.position = CSSPosition.fixed;
            _widgetSpecificStyle.right = CSSScale(window.w - p.x, CSSUnit.pixels); // Set right instead in order to handle resizing (need support for setting style prop back to auto on override)
            _widgetSpecificStyle.left = CSSScale(1, CSSUnit.automatic);
            _widgetSpecificStyle.top = CSSScale(p.y, CSSUnit.pixels);  // ditto for top
            _widgetSpecificStyle.increaseVersion();
            lastStyleVersion = uint.max; // force style recalc
            _recalculateStyle = true;
        }

		bool sizeChanged()
		{
			return _sizeDirty;
		}

		void onMouseClickCallback(EventUsed delegate(Event, Widget) del) nothrow { eventCallbackHelper(GUIEvents.mouseClicked, del); }
		void onMouseMoveCallback(EventUsed delegate(Event, Widget) del) nothrow { eventCallbackHelper(GUIEvents.mouseMove, del); }
		void onMouseOverCallback(EventUsed delegate(Event, Widget) del) nothrow { eventCallbackHelper(GUIEvents.mouseOver, del); }
		void onMouseOutCallback(EventUsed delegate(Event, Widget) del) nothrow { eventCallbackHelper(GUIEvents.mouseOut, del); }
		void onMouseWheelCallback(EventUsed delegate(MouseWheelEvent, Widget) del) nothrow { eventCallbackHelper(GUIEvents.mouseWheel, del); }
		void onKeyPressedCallback(EventUsed delegate(KeyPressedEvent, Widget) del) nothrow { eventCallbackHelper(GUIEvents.keyPressed, del); }
		void onKeyReleasedCallback(EventUsed delegate(KeyReleasedEvent, Widget) del) nothrow { eventCallbackHelper(GUIEvents.keyReleased, del); }
		void onTextCallback(EventUsed delegate(Event, Widget) del) nothrow { eventCallbackHelper(GUIEvents.text, del); }
		void onCommandCallback(EventUsed delegate(CommandEvent, Widget) del) nothrow { eventCallbackHelper(GUIEvents.command, del); }


		/// XXX: Doing cursor shapes! But these callbacks need to be signals because several listeners must be possible!.
		void onKeyboardFocusCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(GUIEvents.inputFocus, del); }
		void onKeyboardUnfocusCallback(EventUsed delegate(Event, Widget) del) { eventCallbackHelper(GUIEvents.inputUnfocus, del); }
	}

    void setFlexSize(FlexSize flexSize)
    {
        size = flexSize.preferred;
        _minSize = flexSize.min;
        if (_minSize.x.isNaN)
            _minSize.x = -float.infinity;
        if (_minSize.y.isNaN)
            _minSize.y = -float.infinity;

        _maxSize = flexSize.max;
        if (_maxSize.x.isNaN)
            _maxSize.x = float.infinity;
        if (_maxSize.y.isNaN)
            _maxSize.y = float.infinity;
    }

	void moveBy(float x, float y)
	{
		_printDirty("moveBy");
		//_sizeDirty = true;
		_rect.x += x;
		_rect.y += y;
	}

	void moveTo(float x, float y)
	{
		_printDirty("moveTo");
		//_sizeDirty = true;
		_rect.x = x;
		_rect.y = y;
	}

	void resizeBy(float x, float y)
	{
		_printDirty("resizeBy");
		//_sizeDirty = true;
		_rect.x += x;
		_rect.y += y;
	}

	void resizeTo(float x, float y)
	{
		_printDirty("resizeTo");
		//_sizeDirty = true;
		_rect.w = x;
		_rect.h = y;
	}


	/*
	@property Application app()
	{
		auto w = window;
		return w is null ? null : w.app;
	}
	*/

	@property Widget parent() pure nothrow @safe
	{
		return _parent;
	}

	@property const(Widget) parent() const pure nothrow @safe
	{
		return _parent;
	}

	@property void parent(Widget newParent) nothrow
	{
        //debug 
        //{
        //    auto np = newParent;
        //    while (np !is null)
        //    {
        //        if (np is this)
        //            throw new Exception("Trying the set new parent of widget where the widget itself it new the parent or an ancestor of the new parent");
        //        np = np.parent;
        //    }
        //}

        if (newParent is _parent)
			return; // noop

		if (newParent is null)
		{
			if (window !is null)
				window.deregister(this);
			removeFromParent();
			_parent = null;
		}
		else
		{
			newParent.addChild(this);
		}
        recalculateStyle();
	}

    void destroyRecurse()
    {
        parent = null;
        foreach (c; children)
            c.destroyRecurse();
        destroy(this); // Risky
    }

	/*
	 * Returns: true if this widget was removed from a parent ie. it had a parent
	 */
	private bool removeFromParent() nothrow
	{
		return _parent !is null && _parent.removeChild(this);
	}

	protected void addChild(Widget w) nothrow
	{
		Window oldWindow = w.window;
		w.removeFromParent();
		w._parent = this;

		if (oldWindow !is null && oldWindow !is window)
			oldWindow.deregister(w);

		if (oldWindow !is window && window !is null)
			window.register(w);

		_children ~= w;
        w.recalculateStyle();
    }

	WT add(WT,Args...)(Args args)
	{
		auto w = new WT(args);
        w.parent = this;
        return w;
	}

    WT get(WT = Widget)(int idx)
    {
        if (idx >= children.length)
            return null;
        return cast(WT)children[idx];
    }

	void replaceChild(Widget replaceThisChild, Widget withThisWidget)
	{
		import std.array;
		auto idx = _children.countUntil(replaceThisChild);
		if (idx == -1)
			return;

		withThisWidget.parent = null;

		auto old = _children[idx];
		_children.replaceInPlace(idx, idx+1, [withThisWidget]);

		if (withThisWidget.window is null && window !is null)
			window.register(withThisWidget);

		withThisWidget._parent = this;

		old.parent = null;

        withThisWidget.recalculateStyle();
	}

    void moveChildToIndex(int moveThisChildAtIndex, int toThisIndex)
    {
        import std.exception;
        enforce(!_children.empty);
        
        if (moveThisChildAtIndex == toThisIndex)
            return;

        enforce(moveThisChildAtIndex < _children.length);
        enforce(toThisIndex < _children.length);

        //auto w = _children[moveThisChildAtIndex];
		swapRanges(_children[moveThisChildAtIndex..moveThisChildAtIndex+1], _children[toThisIndex..toThisIndex+1]);
        // _children.replaceInPlace(toThisIndex, toThisIndex + 1, _children[moveThisChildAtIndex..moveThisChildAtIndex+1]); 
    }

    //void moveChildBefore(Widget moveThisChild, Widget afterThisChild)
    //{
    //    import std.array;
    //
    //    auto idx = _children.countUntil(afterThisChild);
    //    if (idx == -1)
    //        return;
    //
    //    _children.insertInPlace(idx, moveThisChild);
    //
    //    foreach (ref w; _children)
    //    {
    //        if (
    //    }
    //}


	//void moveChildBefore(Widget moveThisChild, Widget beforeThisChild)
	//{
	//    import std.array;
	//
	//    auto idx = _children.countUntil(beforeThisChild);
	//    if (idx == -1)
	//        return;
	//
	//    _children.insertInPlace(idx, moveThisChild);
	//
	//    foreach (ref w; _children)
	//    {
	//        if (
	//    }
	//}

	/*
	 * Returns: true is toRemove was removed from this widget ie. was a child
	 */
	protected bool removeChild(Widget toRemove) nothrow
	{
		auto idx = _children.countUntil!((a,b) => a.id == b.id)(toRemove);
		bool found = idx != -1;
		if (found)
			_children = _children.remove(idx);
		return found;
	}

	protected bool removeChildAt(int idx) nothrow
	{
		bool found = idx > 0 && idx < _children.length;
		if (found)
			_children = _children.remove(idx);
		return found;
	}


	@property inout(Widgets) children() inout nothrow pure @safe
	{
		return _children;
	}

	Widget getChildByName(string childName) nothrow pure @safe
	{
		if (childName.empty)
			return null;

		foreach (w; _children)
			if (w.name == childName)
				return w;
		return null;
	}

	void hideChildren()
	{
		foreach (child; _children)
			child.visible = false;
	}

	bool isDecendantOf(Widget w)
	{
		Widget p = parent;
		while (p !is null && w !is p)
		{
			p = p.parent;
		}

		return w is p;
	}

	bool isAncestorOf(Widget w)
	{
		return w.isDecendantOf(this);
	}

	void setKeyboardFocusWidget()
	{
		assert(window !is null);
		window.setKeyboardFocusWidget(this);
	}

	@property bool hasKeyboardFocus() const pure nothrow @safe
	{
		assert(window !is null);
		return window.hasKeyboardFocus(this);
	}

	@property bool isMouseOver() const pure nothrow @safe
	{
		assert(window !is null);
		return window.isMouseOverWidget(this);
	}

	@property bool isMouseDown() const pure nothrow @safe
	{
		assert(window !is null);
		return window.isMouseDownWidget(this);
	}

    bool isVisible() const nothrow @safe
    {
        return visible;
    }

	void grabMouse()
	{
		assert(window !is null);
		window.grabMouse(this);
	}

	bool isGrabbingMouse()
	{
		assert(window !is null);
		return window.isGrabbingMouse(this);
	}

	void releaseMouse()
	{
		assert(window !is null);
		window.releaseMouse();
	}

	package this(WidgetID _id, Widget _parent, float x = 0, float y = 0, float width = 100, float height = 100) nothrow
	{
		assert(_parent !is null);
		this(_id, x, y, width, height);
		this.parent = _parent;
//		if (window !is null)
//			window.register(this);
	}

	package this(WidgetID _id, float x = 0, float y = 0, float width = 100, float height = 100) nothrow
	{
		//this(Rectf(x, y, x+w, y+h), _parentId);
		manualLayout = false;
		_visible = true;
		// zOrder = 0f;
		//_sizeDirty = true;
		_rect = Rectf(x, y, width, height);
		id = _id == NullWidgetID ? _nextID++ : _id;
		this.acceptsKeyboardFocus = false;
        _minSize = Vec2f(-float.infinity, -float.infinity);
        _maxSize = Vec2f(float.infinity, float.infinity);
	}

	this(Widget _parent, float x = 0, float y = 0, float width = 100, float height = 100) nothrow
	{
		this(NullWidgetID, _parent, x, y, width, height);
	}

	this(float x = 0, float y = 0, float width = 100, float height = 100) nothrow
	{
		this(NullWidgetID, x, y, width, height);
	}

	EventUsed capture(Event ev, Widget target)
	{
		return EventUsed.no;
	}

	EventUsed onEvent(GUIEvent event)
	{
		auto t = event.type;
    	
		if (event.targetWidget == this)
		{
			if (t == GUIEvents.inputFocus)
			{
				onKeyboardFocusSignal.emit(event);
				recalculateStyle();
			}
    		else if (t == GUIEvents.inputUnfocus)
			{
				onKeyboardUnfocusSignal.emit(event);
				recalculateStyle();
			}
			else if (t == GUIEvents.mouseOver)
			{
				recalculateStyle();
			}
			else if (t == GUIEvents.mouseOut)
			{
				recalculateStyle();
			}
			else if (t == GUIEvents.mousePressed)
			{
				recalculateStyle();
			}
			else if (t == GUIEvents.mouseReleased)
			{
				recalculateStyle();
			}
		}

		//if (event.type == EventType.KeyDown)
		//	std.stdio.writeln("event ", event, " to ", this.id);
		OnEvent * handler = event.type in events;

		EventUsed used = EventUsed.no;

		if (event.type == GUIEvents.mouseClicked)
		{
		//	std.stdio.writeln("fdsaf");
		}

		if (handler)
		{
			used = (*handler)(event, this);
		}
		else
		{
			//handler = EventType.Default in events;
			//if (handler)
			//    used = (*handler)(event, this);
		}

		auto bg = background;
		if (!used && bg !is null)
			used = bg.send(event, this);

		foreach (f; features)
		{
			if (used)
				break;
			used = f.send(event, this);
		}

		if (used == EventUsed.no)
			used = dispatchEventsToHandlerMethods(event);

		return used;
	}

	// Call overrided onXXXEvent where XXX is the event type on this 
	// widget. In case you override Widget.onEvent() you probably want to
	// call this dispatch method if you do not handle the event yourself.
	// The default implementation of Widget.onEvent() will call this method.
	EventUsed dispatchEventsToHandlerMethods(Event event)
	{
		//enum code = ctGenerateEventCallbackSwitch(); 
		//enum code = 
		//pragma (msg, code);
		//mixin(code);
		return GUIEvents.dispatch(this, event);
	}

	EventUsed onMouseMoveEvent(MouseMoveEvent e)
	{
		return EventUsed.no;
	}

	EventUsed onMouseOverEvent(MouseOverEvent e)
	{
		return EventUsed.no;
	}

	EventUsed onMouseOutEvent(MouseOutEvent e)
	{
		return EventUsed.no;
	}

	EventUsed onMouseWheelEvent(MouseWheelEvent e)
	{
		return EventUsed.no;
	}

	EventUsed onMousePressedEvent(MousePressedEvent e)
	{
		return EventUsed.no;
	}

	EventUsed onMouseReleasedEvent(MouseReleasedEvent e)
	{
		return EventUsed.no;
	}

	EventUsed onMouseClickedEvent(MouseClickedEvent e)
	{
		return EventUsed.no;
	}

	EventUsed onMouseDoubleClickedEvent(MouseDoubleClickedEvent e)
	{
		return EventUsed.no;
	}

	EventUsed onMouseTripleClickedEvent(MouseTripleClickedEvent e)
	{
		return EventUsed.no;
	}

	EventUsed onKeyPressedEvent(KeyPressedEvent e)
	{
		return EventUsed.no;
	}

	EventUsed onKeyReleasedEvent(KeyReleasedEvent e)
	{
		return EventUsed.no;
	}

	EventUsed onCommandEvent(CommandEvent e)
	{
		return EventUsed.no;
	}

	// mixin(ctGenerateEventCallbacks());

	protected void drawFeatures()
	{
		auto bg = background;
		if (bg !is null)
			bg.draw(this);

		// Draw features
		foreach (f; features)
		{
			drawFeatureCalls++;
			f.draw(this);
		}
	}

	protected void drawChildren()
	{
        auto win = window;
        auto r = win.rect;

		static bool compare(Widget a, Widget b)
		{
			return a.style.zIndex < b.style.zIndex;
		}

		// Draw children
		Widget[128] sortedChildren;
		sortedChildren[0..children.length] = children[];
		
		foreach (w; sortedChildren[0..children.length].sort!compare)
		{
			auto drawRect = r.clip(w.rect);
            if (!drawRect.empty || this == win)
                w.draw();
            else if (w.visible)
                drawRect = drawRect;
		}
	}

    void layoutChildren(bool fit, Widget positionReference)
    {
        if (layout is null)
        {
            Vec2f p = positionReference.pos;
            //Vec2f s = positionReference.size;
            foreach (w; children)
            {
                w.pos = p;
              //  w.size = s;
            }
        }
        else
        {
            layout.layout(this, fit);
        }
    }

	protected void layoutRecurse(bool fit, Widget positionReference)
	{
		foreach (w; children)
			w.updateLayout(fit, positionReference);
	}

	//private void recalcSize()
	//{
	//    _rect.size = calcSize(this);
	//}

	//protected void recalcPosition()
	//{
	//    //if (parent !is null && id == 8)
	//    //    std.stdio.writeln("pospre ", _rect.pos.v);
	//    _rect.pos = calcPosition(this);
	//    //if (id == 8)
	//    //    std.stdio.writeln("c ", _rect.size.y);
	//    //if (parent !is null && id == 8 && _rect.pos.x != 200)
	//    //{
	//    //    std.stdio.writeln("pospost ", _rect.pos.v);
	//    //    calcPosition(style);
	//    //    std.stdio.writeln("pospost ", _rect.pos.v);
	//    //}
	//}

	protected void calculateSize(Widget positionReference)
	{
        FlexSize flexSize = calcSize(this, positionReference);
        setFlexSize(flexSize);
        //if (size != newSize)
        //{
        //    forceDirty();
        //}
	}

	protected void calculatePosition(Widget positionReference)
	{
        import std.math;
        if (!isFinite(size.y))
        {
            auto dd = size.y;
        }
		Vec2f newPos = calcPosition(this, positionReference);
        //if (pos != newPos)
        //{
            pos = newPos;
        //    forceDirty();
        //}
	}

	protected void calculateChildrenSizes(Widget positionReference)
	{
		// Get sized ready for the children so that any layouter have them
		foreach (w; children)
			if (!w.manualLayout)
				w.calculateSize(positionReference);
	}

	protected void calculateChildrenPositions(Widget positionReference)
	{
		// Position goes last so that a base position calculated by e.g. DirectionalLayout feature
		// can be used as relative pos for the calcPosition (ie. the styled position)
		foreach (w; children)
			if (!w.manualLayout)
				w.calculatePosition(positionReference);
	}

	void updateLayout(bool fit, Widget positionReference)
	{
		if (!visible || w() == 0)
			return;

        import std.array;

        Style st = style;
        if (st.position == CSSPosition.relative || st.position == CSSPosition.absolute || positionReference is null ||
            (st.position.isMixed && (st.position[1] == CSSPosition.relative || st.position[1] == CSSPosition.absolute)))
            positionReference = this;

        static Rectf[] origChildrenRects;
        assumeSafeAppend(origChildrenRects);
        origChildrenRects.length = children.length;

        children.map!"a.rect".copy(origChildrenRects);

		//import std.stdio;
		//writeln(name);
		//writeln(children.map!(a => "   Pre " ~ a.name ~ ": " ~ rect.toString()));
        calculateChildrenSizes(positionReference);
//        writeln(children.map!(a => "   SZ  " ~ a.name ~ ": " ~ rect.toString()));
		layoutChildren(false, positionReference);
//        writeln(children.map!(a => "   LO  " ~ a.name ~ ": " ~ rect.toString()));
		calculateChildrenPositions(positionReference);
//        writeln(children.map!(a => "   PS  " ~ a.name ~ ": " ~ rect.toString()));

		if (children.length != origChildrenRects.length)
		{
			foreach (c; children)
				c.forceDirty();
		}
		else
		{
			// TODO: Make sure children are the same!
			auto newChildrenRects = children.map!"a.rect";
			int idx = 0;
			foreach (ref childRect; newChildrenRects)
			{
				Rectf origRect = origChildrenRects[idx];
				if (!childRect.isIdentical(origRect))
					children[idx].forceDirty();
				idx++;
			}
		}

		// Positions and sizes for children are now set and we can recurse
		layoutRecurse(fit, positionReference);
	}

	static int drawCalls;
	static int drawFeatureCalls;
	void draw()
	{
		drawCalls++;
		if (!visible || w() == 0)
			return;

		drawFeatures();
		drawChildren();
	}

	void update()
	{
        recalculateStyle();
		// TODO: check for convergence
		// TODO: only re-iterate features that asks for it e.g. constraints
		for (int i = 0; i < 1; i++)
		{
			//activeStyle.model.transform = activeStyle.model.transform * Mat4f.makeTranslate(Vec3f(0.0005f,0f,0f));

			//onLayout();
			//for (int j = 0; j < 10000; j++)
			auto bg = background;
			if (bg !is null)
				bg.update(this);
			foreach (f; features)
			{
				f.update(this);
			}
		}

		if (_sizeDirty)
		{
			// Send resize event to children
            // TODO: optimize this to not always recalc _all_ widgets with anything is dirty
			_sizeDirty = false;

			if (window !is null)
			{
				window._sizeDirty = true;
			}
		}

		// TODO: remove from here since win.update runs on all widget ie. widget that does not
		// get update calls is because that have not registered with win.
//		foreach (w; children)
//		{
//			w.update();
//		}


//		OnEvent * handler = EventType.Update in events;

//		if (handler)
//			(*handler)(Event(EventType.Update), this);

		/*
	//	Rectf wrect = Window.active.windowToWorld(rect);
	//	float[] vert = quadVertices(wrect);
	//	float[] uv = quadUVs(wrect, activeStyle.model.material, Window.active);
		activeStyle.model.mesh.buffers[0].setData(vert);
		activeStyle.model.mesh.buffers[1].setData(uv);
		activeStyle.model.draw();
  */
	}

	void getScreenOffsetToWorldTransform(ref Mat4f transform)
	{
		Rectf wrect = window.windowToWorld(rect);

		// Since text are layed out using pixel coords we scale into world coords
		transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0));
	}

	void getScreenToWorldTransform(ref Mat4f transform)
	{
		//		Rectf wrect = widget.window.windowToWorld(widget.rect);

		// Since text are layed out using pixel coords we scale into world coords
		Vec2f scale = window.pixelSizeToWorld(Vec2f(1,1));
		getScreenOffsetToWorldTransform(transform);
		//		transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0)) * Mat4f.makeScale(Vec3f(scale.x, scale.y, 1.0));
		transform = transform * Mat4f.makeScale(Vec3f(scale.x, scale.y, 1.0));
	}

	void getStyledScreenOffsetToWorldTransform(ref Mat4f transform)
	{
//		Rectf wrect = window.windowToWorld(rectStyled);
		Rectf wrect = window.windowToWorld(rect);

		// Since text are layed out using pixel coords we scale into world coords
		transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0));
	}

	void getStyledScreenToWorldTransform(ref Mat4f transform)
	{
		//		Rectf wrect = widget.window.windowToWorld(widget.rect);

		// Since text are layed out using pixel coords we scale into world coords
		Vec2f scale = window.pixelSizeToWorld(Vec2f(1,1));
		getStyledScreenOffsetToWorldTransform(transform);

		//		transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0)) * Mat4f.makeScale(Vec3f(scale.x, scale.y, 1.0));
		transform = transform * Mat4f.makeScale(Vec3f(scale.x, scale.y, 1.0));
	}
}

/*
bool isInFrontOf(Widget isThis, Widget inFrontOfThis)
{
	return isThis.window.isWidgetInFrontOfWidget(isThis, inFrontOfThis);
}
*/