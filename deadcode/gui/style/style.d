module deadcode.gui.style.style;

import deadcode.animation.clip;
import deadcode.animation.curve;
import deadcode.animation.interpolate;
import deadcode.animation.mutator;
import deadcode.math;

import deadcode.graphics.color : Color;

import deadcode.gui.resources.material;
import deadcode.gui.resources.font : Font, FontManager;

import deadcode.gui.style.property;
import deadcode.gui.style.stylesheet : StyleSheet;
import deadcode.gui.style.types;

import std.datetime;
import std.string;
import deadcode.core.signals;
import std.math : isNaN;

import deadcode.test;
//mixin registerUnittests;


alias string StyleID;
immutable StyleID NullStyleName = "";
immutable StyleID DefaultStyleName = "default";

string stylePropertyToCSSName(string name)
{
	string res;
	foreach (c; name)
	{
		if (c == '_')
		{
			// skip
		}
		else if (c >= 'A' && c <= 'Z')
		{
			res ~= "-";
			res ~= c.toLower();
		}
		else
		{
			res ~= c;
		}
	}
	return res;
}
mixin template styleProperty(string type, string name)
{
	mixin(type ~ " _" ~ name ~ ";");
	mixin("bool _" ~ name ~ "IsSet;");
	mixin("void clear" ~ toUpper(name[0..1]) ~ name[1..$] ~ "() pure nothrow { _" ~ name ~ "IsSet = false; }");
	mixin("@property " ~ type ~ " " ~ name ~ "() { " ~
		  " if ( _" ~ name ~ "IsSet) return _" ~ name ~ ";" ~
		  " else { " ~ type ~ " t; style.getProperty(\"" ~ stylePropertyToCSSName(name) ~ "\", t); return t; } }");
	mixin("@property void " ~ name ~ "(" ~ type ~ " value) { _" ~ name ~ " = value; _" ~ name ~ "IsSet = true; }");
}

class Style
{
	@NonBindable()
	StyleSheet styleSheet; // StyleSheet owning this style

	private static uint _nextID = 1;
	uint id = 0;
	uint currentVersion = 0;

	void increaseVersion() pure @safe nothrow
	{
		currentVersion++;
	}

	public
	// package
	{
		Rectf[PropertyID] rects;  // Keys in the map are property names
		float[][PropertyID] floats;
		bool[][PropertyID] bools;
		Vec2f[PropertyID]vec2fs;

		Duration[][PropertyID] durations;
		CubicCurveParameters[][PropertyID] curveParameters;
		PropertyID[][PropertyID] propertyIDs;

		Transition[PropertyID] transitionCache; // derived from other properties in the style

		// Curve[] curves;

		// bool hasNewTransistionProperties;
		// Transition[] transitions;
		// Transition[PropertyID] transitions; // as opposed to the above maps the key here is the name of the property to be transitioned

		@Bindable()
		{
			CSSPositionMix _position;
			CSSScaleMix _width;
			CSSScaleMix _height;
			CSSScaleMix _minWidth;
			CSSScaleMix _minHeight;
			CSSScaleMix _maxWidth;
			CSSScaleMix _maxHeight;
			CSSScaleMix _left;
			CSSScaleMix _right;
			CSSScaleMix _top;
			CSSScaleMix _bottom;
			CSSVisibility _visibility;
			CSSDisplay _display;
		}

		// ref types
		Font _font;
		Material _background;

		// value types
		@NonBindable()
		bool _wordWrap;  // bit 0

		@NonBindable()
		Color _color;    // bit 1

		@NonBindable()
		Color _backgroundColor;    // bit 2

		@NonBindable()
		int _zIndex; // bit 3

		@Bindable()
		RectfOffset _padding;

		@NonBindable()
		RectfOffset _backgroundSpriteBorder;

		@NonBindable()
		Rectf       _backgroundSprite;

        @NonBindable()
        SpriteFrames _backgroundSpriteAnimation;

		// float _glyphPadding; etc....

		// bitmask. One bit set unset for each by value property that does not support null values should be null.
		// The fields are:
		// * wordWrap bit 0
		// * color bit 1
		ubyte _nullFields;
	}

//	package StyleFields _fields; // Fields set on this style

	@property
	{
		bool hasTransitions() const pure nothrow
		{
			return transitionCache.length != 0;
		}

		CSSPositionMix position() const
		{
			return _position;
		}

		void position(T)(T p) if (is(T:CSSPositionMix) || is(T:CSSPosition))
		{
			_position = p;
		}

		//@Bindable()
		//itCSSAnimator rectCSSAnimator() const
		//{
		//    return RectCSSAnimator(true, _width, _width, _height, _height, _edgesOffset, _edgesOffset, 0);
		//}
		//
		//@Bindable()
		//void rectCSSAnimator(RectCSSAnimator a)
		//{
		//    _rectCSSAnimator = a;
		//}

		//RectCSSOffset edgesOffset() const
		//{
		//    return _edgesOffset;
		//}
		//
		//void edgesOffset(RectCSSOffset offset)
		//{
		//    _edgesOffset = offset;
		//}

		CSSScaleMix left() const
		{
			return _left;
		}

		void left(T)(T v) pure nothrow @safe if (is (T:CSSScale) || is(T:CSSScaleMix))

		{
			_left = v;
		}

		CSSScaleMix top() const
		{
			return _top;
		}

		void top(T)(T v) pure nothrow @safe if (is (T:CSSScale) || is(T:CSSScaleMix))

		{
			_top = v;
		}

		CSSScaleMix right() const
		{
			return _right;
		}

		void right(T)(T v) pure nothrow @safe if (is (T:CSSScale) || is(T:CSSScaleMix))

		{
			_right = v;
		}

		CSSScaleMix bottom() const
		{
			return _bottom;
		}

		void bottom(T)(T v) pure nothrow @safe if (is (T:CSSScale) || is(T:CSSScaleMix))
		{
			_bottom = v;
		}

		CSSScaleMix width() const
		{
			return _width;
		}

		void width(T)(T v) pure nothrow @safe if (is (T:CSSScale) || is(T:CSSScaleMix))
		{
			_width = v;
		}

		CSSScaleMix minWidth() const
		{
			return _minWidth;
		}

		void minWidth(T)(T v) pure nothrow @safe if (is (T:CSSScale) || is(T:CSSScaleMix))
		{
			_minWidth = v;
		}

        CSSScaleMix maxWidth() const
		{
			return _maxWidth;
		}

		void maxWidth(T)(T v) pure nothrow @safe if (is (T:CSSScale) || is(T:CSSScaleMix))
		{
			_maxWidth = v;
		}

		CSSScaleMix height() const
		{
			return _height;
		}

		void height(T)(T v) pure nothrow @safe if (is (T:CSSScale) || is(T:CSSScaleMix))
		{
			_height = v;
		}

		CSSScaleMix minHeight() const
		{
			return _minHeight;
		}

		void minHeight(T)(T v) pure nothrow @safe if (is (T:CSSScale) || is(T:CSSScaleMix))
		{
			_minHeight = v;
		}

        CSSScaleMix maxHeight() const
		{
			return _maxHeight;
		}

		void maxHeight(T)(T v) pure nothrow @safe if (is (T:CSSScale) || is(T:CSSScaleMix))
		{
			_maxHeight = v;
		}

		@Bindable()
		Font font()
		{
			auto f = _font;
			if (f !is null)
				f.ensureLoaded();
			return f;
		}

		@Bindable()
		void font(Font f)
		{
			_font = f;
		}

		@Bindable()
		Material background()
		{
			auto b = _background;
			if (b !is null)
				b.ensureLoaded();
			return b;
		}

		@Bindable()
		void background(Material b)
		{
			_background = b;
		}

		@Bindable()
		Color color() const
		{
			return _color;
		}

		@Bindable()
		void color(Color c)
		{
			_nullFields |= 2;
			_color = c;
		}
		
		@Bindable()
		Color backgroundColor() const
		{
			return _backgroundColor;
		}

		@Bindable()
		void backgroundColor(Color c)
		{
			_nullFields |= 4;
			_backgroundColor = c;
		}

		@Bindable()
		int zIndex() const
		{
			return _zIndex;
		}

		@Bindable()
		void zIndex(int i) pure @safe nothrow
		{
			_zIndex = i;
		}

		bool zIndexIsAuto() const pure @safe nothrow
		{
			return _zIndex == typeof(_zIndex).min;
		}

		@Bindable()
		bool wordWrap() const pure @safe nothrow
		{
			return _wordWrap;
		}

		@Bindable()
		void wordWrap(bool w)
		{
			_nullFields |= 1;
			_wordWrap = w;
		}

		RectfOffset padding() const
		{
			return _padding;
		}

		// TODO: make a paddingX, paddingY etc. methods
		void padding(RectfOffset w)
		{
			_padding = w;
		}

		@Bindable()
		RectfOffset backgroundSpriteBorder() const
		{
			RectfOffset r = _backgroundSpriteBorder;
			if (r.top.isNaN())
				r.top = 0; // default to 0 offset

			if (r.left.isNaN())
				r.left = 0; // default to 0 offset

			if (r.right.isNaN())
				r.right = 0; // default to 0 offset

			if (r.bottom.isNaN())
				r.bottom = 0; // default to 0 offset
			return r;
		}

		@Bindable()
		void backgroundSpriteBorder(RectfOffset w)
		{
			_backgroundSpriteBorder = w;
		}

		@Bindable()
		Rectf backgroundSprite()
		{
			Rectf r = _backgroundSprite;
			Vec2f sz;
			if (background !is null && background.texture !is null)
				sz = background.texture.size;
			else
				sz = Vec2f(0,0);

			if (r.x.isNaN())
				r.x = 0; // default to 0 offset

			if (r.y.isNaN())
				r.y = 0; // default to 0 offset

			if (r.w.isNaN())
				r.w = sz.x;

			if (r.h.isNaN())
				r.h = sz.y;

			return r;
		}

		@Bindable()
		void backgroundSprite(Rectf w)
		{
			_backgroundSprite = w;
		}

        const(SpriteFrames) backgroundSpriteAnimation() const pure nothrow @safe
        {
            return _backgroundSpriteAnimation;
        }

        void backgroundSpriteAnimation(SpriteFrames f)
        {
            _backgroundSpriteAnimation = f;
        }

        CSSVisibility visibility() const pure nothrow @safe
        {
            return _visibility;
        }

        void visibility(CSSVisibility v) pure nothrow @safe
        {
            _visibility = v;
        }

        CSSDisplay display() const pure nothrow @safe
        {
            return _display;
        }

        void display(CSSDisplay v) pure nothrow @safe
        {
            _display = v;
        }

		string name() const
		{
			return _name;
		}
	}

	string _name;

	this(string name) nothrow @safe
	{
		id = _nextID++;
		this._name = name;
		zIndex = typeof(zIndex).min;
	}

	this(StyleSheet s) nothrow @safe
	{
		id = _nextID++;
		styleSheet = s;
		zIndex = typeof(zIndex).min;
	}

    final Rectf getBackgroundSpriteRectForFrame(int n)
    {
        if (background is null || backgroundSpriteAnimation is null)
            return backgroundSprite;

        Rectf r = backgroundSprite;
        n = n % backgroundSpriteAnimation.count;
        int row = n / backgroundSpriteAnimation.columns;
        int col = n % backgroundSpriteAnimation.columns;
        r.x += backgroundSprite.w * col;
        r.y += backgroundSprite.h * row;
        return r;
    }

    final void setBackgroundSpriteForFrame(int n)
    {
    }

	void rebuildTransitionCache()
	{
		enum emptyPropertyIDs = PropertyID[].init;
		enum emptyDurations = Duration[].init;
		enum emptyDelays = Duration[].init;
		enum emptyTimings = CubicCurveParameters[].init;

		transitionCache = (Transition[PropertyID]).init;

		auto propertyNames = propertyIDs.get("transition-property", emptyPropertyIDs);
		int aa = 4;
		if (propertyNames.length)
		{
			aa += propertyNames.length;
		}

		foreach (p; propertyIDs.get("transition-property", emptyPropertyIDs))
			transitionCache[p] = Transition(p);

		bool gotAllTransition = false;
		foreach (i, p; durations.get("transition-duration", emptyDurations))
		{
			if (i < propertyNames.length)
				transitionCache[propertyNames[i]].duration = p;
			else
			{
				if (!gotAllTransition)
					transitionCache["all"] = Transition("all", p);
				else
					transitionCache["all"].duration = p;
				gotAllTransition = true;
			}
		}

		foreach (i, p; curveParameters.get("transition-timing", emptyTimings))
		{
			if (i < propertyNames.length)
				transitionCache[propertyNames[i]].timing = p;
			else
			{
				if (!gotAllTransition)
				{
					auto allTrans = Transition("all");
					allTrans.timing = p;
					transitionCache["all"] = allTrans;
					gotAllTransition = true;
				}
				else
				{
					transitionCache["all"].timing = p;
				}
			}
		}

		foreach (i, p; durations.get("transition-delay", emptyDelays))
		{
			if (i < propertyNames.length)
				transitionCache[propertyNames[i]].delay = p;
			else
			{
				if (!gotAllTransition)
				{
					auto allTrans = Transition("all");
					allTrans.delay = p;
					transitionCache["all"] = allTrans;
					gotAllTransition = true;
				}
				else
				{
					transitionCache["all"].delay = p;
				}
			}
		}
	}

	bool getTransitionForProperty(PropertyID id, ref Transition t) const pure nothrow
	{
		auto p = id in transitionCache;
		if (p is null)
		{
			p = "all" in transitionCache;
			if (p is null)
				return false;
		}
		t = *p;
		return true;
	}

	bool getProperty(PropertyID id, ref float value) const pure nothrow
	{
		auto v = id in floats;
		if (v is null || v.length == 0)
		{
			import deadcode.gui.style.manager;
			import deadcode.gui.resource;
			const(StyleSheet) ss = styleSheet;
			const(ResourceManager!StyleSheet) ssm = ss.manager;
			auto mgr = cast(const(StyleSheetManager))(ssm);
			assert(mgr);
			if (mgr !is null)
			{
				auto spec = mgr.lookupPropertySpecification(id);
				auto floatSpec = cast(const(PropertySpecification!float))(spec);
				if (floatSpec !is null)
					value = floatSpec.getDefaultValue();
			}
			return false;
		}
		value = (*v)[0];
		return true;
	}

	bool getProperty(PropertyID id, ref const(float)[] values) const pure nothrow
	{
		auto v = id in floats;
		if (v is null)
			return false;
		values = *v;
		return true;
	}

	bool getProperty(PropertyID id, ref Vec2f value) const pure nothrow
	{
		auto v = id in vec2fs;
		if (v is null)
			return false;
		value = *v;
		return true;
	}

	//bool getProperty(PropertyID id, ref Vec2f[] value) const pure nothrow
	//{
	//    auto v = id in vec2fs;
	//    if (v is null)
	//        return false;
	//    value = *v;
	//    return true;
	//}

	//bool getPropertyDef(PropertyID id, ref float value) const pure nothrow
	//{
	//    auto v = id in floats;
	//    if (v is null)
	//        return styleSheet.manager
	//    value = *v;
	//    return true;
	//}

	bool getProperty(PropertyID id, ref Rectf value)
	{
		auto v = id in rects;
		if (v is null)
			return false;
		value = *v;
		return true;
	}

	//bool getProperty(PropertyID id, ref Rectf[] value)
	//{
	//    auto v = id in rects;
	//    if (v is null)
	//        return false;
	//    value = *v;
	//    return true;
	//}

	// Reset to init state ie. having all fields "null" values
	/*
	void xxclear()
	{
		_position = CSSPosition.invalid;
		_width = CSSScaleMix.init;
		_height = CSSScaleMix.init;
		_left = CSSScaleMix.init;
		_right = CSSScaleMix.init;
		_top = CSSScaleMix.init;
		_bottom = CSSScaleMix.init;
		_font = null;
		_background = null;
		_nullFields = 0;
		_color = Color.init;
		_backgroundColor = Color.init;
		_padding = RectfOffset.init;
		_backgroundSpriteBorder = RectfOffset.init;
		_backgroundSprite = Rectf.init;

		foreach (ref v; floats)
			v.length = 0;

		foreach (ref v; rects)
			v = Rectf.init;

		foreach (ref v; vec2fs)
			v = Vec2f.init;


	}
*/




	//static void diff(Style s1, Style s2, Style output)
	//{
	//    diff(s1._fields, s2._fields, output._fields);
	//}


	// reset in the same state as s
	/*
	void reset(Style s)
	{
		_fields._position = s._fields._position;
		_fields._edgesOffset = s._fields._edgesOffset;
		_fields._font = s._fields._font;
		_fields._background = s._fields._background;
		_fields._color = s._fields._color;
		_fields._backgroundColor = s._fields._backgroundColor;
		_fields._wordWrap = s._fields._wordWrap;
		_fields._nullFields = s._fields._nullFields;
		_fields._padding = s._fields._padding;
		_fields._backgroundSpriteBorder = s._fields._backgroundSpriteBorder;
		_fields._backgroundSprite = s._fields._backgroundSprite;

		foreach (key, ref v; _fields.floats)
			v = s._fields.floats[key];

		foreach (key, ref v; _fields.rects)
			v = s._fields.rects[key];

		foreach (key, ref v; _fields.vec2fs)
			v = s._fields.vec2fs[key];
	}
	*/

	private void setInvalid(float src, ref float dst)
	{
		if (dst.isNaN())
			dst = src;
	}

	private void setInvalid(CSSScale src, ref CSSScale dst)
	{
		if (dst.value.isNaN())
		{
			dst.value = src.value;
			dst.unit = src.unit;
		}
	}

	private void setInvalid(RectCSSOffset src, ref RectCSSOffset dst)
	{
		setInvalid(src.left, dst.left);
		setInvalid(src.top, dst.top);
		setInvalid(src.right, dst.right);
		setInvalid(src.bottom, dst.bottom);
	}

	private void setInvalid(RectfOffset src, ref RectfOffset dst)
	{
		setInvalid(src.left, dst.left);
		setInvalid(src.top, dst.top);
		setInvalid(src.right, dst.right);
		setInvalid(src.bottom, dst.bottom);
	}

	private void setInvalid(Vec2f src, ref Vec2f dst)
	{
		setInvalid(src.x, dst.x);
		setInvalid(src.y, dst.y);
	}

	private void setInvalid(Rectf src, ref Rectf dst)
	{
		setInvalid(src.x, dst.x);
		setInvalid(src.y, dst.y);
		setInvalid(src.w, dst.w);
		setInvalid(src.h, dst.h);
	}

	// Override fields on this that are null with the values of sf
	void overlay(Style sf)
	{
		increaseVersion();
		if (_font is null)
			_font = sf._font;

		if (sf._background !is null)
		{
			if (_background is null)
				_background = sf._background; // TODO: hmmm. could this make _background be modified later because of a second overlay?
			else
			{
				if (_background.shader is null)
					_background.shader = sf._background.shader;
				if (_background.texture is null)
					_background.texture = sf._background.texture;
			}
		}

		if (!(_nullFields & 1) && (sf._nullFields & 1))
		{
			_wordWrap = sf._wordWrap;
			_nullFields |= 1;
		}

		if (!(_nullFields & 2) && (sf._nullFields & 2) )
		{
			_color = sf._color;
			_nullFields |= 2;
		}

		if (! (_nullFields & 4) && (sf._nullFields & 4) )
		{
			_backgroundColor = sf._backgroundColor;
			_nullFields |= 4;
		}

        if (zIndexIsAuto() && !sf.zIndexIsAuto())
			_zIndex = sf._zIndex;

		setInvalid(sf._padding, _padding);
		setInvalid(sf._backgroundSpriteBorder, _backgroundSpriteBorder);
		setInvalid(sf._backgroundSprite, _backgroundSprite);
        if (_backgroundSpriteAnimation is null)
            _backgroundSpriteAnimation = sf._backgroundSpriteAnimation;
		setInvalid(sf._width, _width);
		setInvalid(sf._minWidth, _minWidth);
		setInvalid(sf._maxWidth, _maxWidth);
		setInvalid(sf._height, _height);
		setInvalid(sf._minHeight, _minHeight);
		setInvalid(sf._maxHeight, _maxHeight);
		setInvalid(sf._left, _left);
		setInvalid(sf._top, _top);
		setInvalid(sf._right, _right);
		setInvalid(sf._bottom, _bottom);

		if (_position == CSSPosition.invalid)
			_position = sf._position;

        if (_visibility == CSSVisibility.invalid)
			_visibility = sf._visibility;

        if (_display == CSSDisplay.invalid)
			_display = sf._display;

		foreach (key, values; sf.propertyIDs)
			PropertySpecification!PropertyID.overlay(propertyIDs, key, values);

		foreach (key, values; sf.curveParameters)
			PropertySpecification!CubicCurveParameters.overlay(curveParameters, key, values);

		foreach (key, values; sf.durations)
			PropertySpecification!Duration.overlay(durations, key, values);

		foreach (key, values; sf.floats)
			PropertySpecification!float.overlay(floats, key, values);

		foreach (key, value; sf.rects)
			PropertySpecification!Rectf.overlay(rects, key, value);

		foreach (key, value; sf.vec2fs)
			PropertySpecification!Vec2f.overlay(vec2fs, key, value);
	}

	Style clone() @safe
	{
		auto st = new Style(styleSheet);
		copy(st);
		return st;
	}

	void copy(Style target) pure @safe
	{
		Style st = target;
		st.increaseVersion();
		st._position = _position;
		st._width = _width;
		st._minWidth = _minWidth;
		st._maxWidth = _maxWidth;
		st._height= _height;
		st._minHeight= _minHeight;
		st._maxHeight= _maxHeight;
		st._left = _left;
		st._top = _top;
		st._right = _right;
		st._bottom = _bottom;
		st._visibility = _visibility;
		st._font = _font;
		st._background = _background;
		st._nullFields = _nullFields;
		st._color = _color;
		st._backgroundColor = _backgroundColor;
        st._zIndex = _zIndex;
		st._padding = _padding;
		st._backgroundSpriteBorder = _backgroundSpriteBorder;
		st._backgroundSprite = _backgroundSprite;
		st._backgroundSpriteAnimation = _backgroundSpriteAnimation;

		foreach (k, v; propertyIDs)
			st.propertyIDs[k] = v.dup;

		foreach (k, v; curveParameters)
			st.curveParameters[k] = v.dup;

		foreach (k, v; durations)
			st.durations[k] = v.dup;

		foreach (k, v; rects)
			st.rects[k] = v;

		foreach (k, v; floats)
			st.floats[k] = v.dup;

		foreach (k, v; vec2fs)
			st.vec2fs[k] = v;
	}

	bool matchesStyle(Style s) const pure nothrow @safe
	{
		return s is this;
	}
}

version (Have_deadcode_animation)
{
    void createCurves(Clip!Style clip, Style y1, Style y2)
    {
        struct CurveProvider
        {
            Style a;
            Style b;

            this(Style styleA, Style styleB)
            {
                a = styleA;
                b = styleB;
            }

            Curve!FieldType getCurve(OwnerType, FieldType, string fieldPath)(FieldType q1, FieldType q2)
            {
                import deadcode.gui.style.types;
                // Lookup transitions in the y2 style
                // pragma(msg, "FP " ~ fieldPath ~ " -> " ~ stylePropertyToCSSName(fieldPath));
                string cssName = stylePropertyToCSSName(fieldPath);
                Transition* transition = cssName in b.transitionCache;
                if (transition is null)
                {
                    //return new ConstantCurve!FieldType(0, q2, 5.0); // Todo: make instant curve. Just use 5 secs for now
                    return new LinearCurve!FieldType(0, q1, 0, q2);
                }
                else
                {
                    float begin = transition.delay.split!"usecs"().usecs / 1_000_000f;
                    float duration = transition.duration.split!"usecs"().usecs / 1_000_000f;
                    import deadcode.math.bezier;
                    auto b = UnitBezier(transition.timing[0], transition.timing[1],
                                        transition.timing[2], transition.timing[3]);

                    return new CubicBezierCurve!FieldType(begin, q1, begin + duration, q2, b);
                }
            }
        }

        clip.bindings ~= getTransitionCurves(CurveProvider(y1, y2), y1, y2);
    }
}


/*
class UsedStyle
{
	// The used style may be inbetween two styles when transitioning
	Style from;
	Style to;
	private float _offset; // 0 = from style, 1 = to style. interval [0..1].

	Signal!MixedStyle onChanged;

	this(Style fromStyle, Style toStyle)
	{
		super(fromStyle.styleSheet);
		from = fromStyle;
		to = toStyle;
		offset = 0;
	}

	@property
	{
		@Binding
		void offset(float o)
		{
			_offset = o;
			update();
		}

		@Binding
		float offset() const pure nothrow @safe
		{
			return _offset;
		}
	}

	override bool matchesStyle(Style s) const pure nothrow @safe
	{
		return s is to || s is this;
	}

	void update()
	{
		onChanged.emit(this);
	}
}
*/


// Example sheet:
//
// color = white;
//
// * {
// font: "resources/fonts/cour.ttf" 16;
// padding: 2 2 2 2;
//  color: $color;
//     background-shader: "default.shaderprogram";
// }
//
// TextEditor[lars] > [ib] {
// color: yellow;
// background: "bgplain.png;
// }


version (unittest)
{
	import std.typecons;
	import deadcode.graphics.rendertarget;
	import deadcode.gui.window;
	import deadcode.gui.widget;

	Window createTestWindow()
	{
		return new Window("testWindow", 100, 200, new BlackHole!RenderTarget(), null);
	}
}
