module deadcode.gui.resources.font;

import std.exception : enforce;

import deadcode.core.path;


import deadcode.graphics.font : GFont = Font;
import deadcode.gui.locations;
import deadcode.gui.resource;

import deadcode.io.iomanager;

import deadcode.util.jsonx;

import deadcode.test;
mixin registerUnittests;

class Font : GFont, IResource!Font
{
	private static @property Font builtIn() { return null; } // hide

	public this()
	{

	}

	//private this(string path, size_t size)
	//{
	//    super(path, size);
	//}

	@property
	{
		string name()
		{
			return _name;
		}

		void name(string name)
		{
			_name = name;
		}

		Handle handle() const pure nothrow @safe
		{
			return _handle;
		}

		void handle(Handle h)
		{
			_handle = h;
		}

		Manager manager() pure nothrow @safe
		{
			return _manager;
		}

		const(Manager) manager() const pure nothrow @safe
		{
			return _manager;
		}

		void manager(Manager m)
		{
			_manager = m;
		}
	}

	Font interpolate(Font endValue, float delta)
	{
		return delta <= 0 ? this : endValue;
	}

private:
	Manager _manager;
	Handle _handle;
	string _name;
}


class FontManager : ResourceManager!Font
{
	private Handle builtinFontHandle;
    private static FontManager _fallbackFontManager;

    static @property FontManager fallbackFontManager()
    {
        enforce(_fallbackFontManager !is null);
        return _fallbackFontManager;
    }

    void setAsFallback()
    {
        _fallbackFontManager = this;
    }

	@property Font builtinFont()
	{
		return get(builtinFontHandle);
	}

	static FontManager create(FileManager fileManager)
	{
		auto fm = new FontManager;
		auto fp = new JsonFontSerializer;
		fm.fileManager = fileManager;
		fm.addSerializer(fp);

		fm.createBuiltinFont();

		return fm;
	}

	private void createBuiltinFont()
	{
        import deadcode.platform.config;
		builtinFontHandle = declare(builtinFontPath, TTFFontLoader.singleton).handle;
	}

	Font create(string path, size_t size = 16)
	{
		auto f = declare();
		f.init(path, size);
		return f;
	}
}

class JsonFontSerializer : ResourceSerializer!Font
{
	override bool canRead() pure const nothrow { return true; }

	override bool canHandle(URI uri)
	{
		return uri.extension == ".font";
	}

	override void deserialize(Font res, string str)
	{
		struct FontSpec
		{
			string uri;
			int size;
		}

		auto spec = jsonDecode!FontSpec(str);

		// TODO: make Font accept an IO or databuffer
		res.init(spec.uri, spec.size);
		res.manager.onResourceLoaded(res, this);
	}
}

class TTFFontLoader : IResourceLoader!Font
{
	static TTFFontLoader _the;
	static @property singleton()
	{
		if (_the is null)
		{
			_the = new TTFFontLoader;
		}
		return _the;
	}

	bool load(Font r, URI uri)
	{
		enum defaultFontSize = 18;
        r.init(uri.uriString, defaultFontSize);
		r.manager.onResourceLoaded(r, null);
		return true;
	}

	bool save(Font p, URI uri)
	{
		throw new Exception("Cannot save fonts");
	}
}

unittest
{
	FontManager m = new FontManager;
	auto p = new JsonFontSerializer;
	m.addSerializer(p);

	auto r = m.declare();
	AssertIs(m.get(r.handle), r, "Resource from declare same as resource gotten by handle from manager");
	//auto r2 = m.declare("font1");
	//AssertIs(r, r2, "Redeclaring with same name results in same resource");
	//auto r3 = m.declare("font1", new URI("resources/fonts/default.font"));
	//AssertIs(r, r3, "Redeclaring with same name and a uri results in same resource");
}
