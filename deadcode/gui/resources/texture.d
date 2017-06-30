module deadcode.gui.resources.texture;

static import deadcode.graphics.texture;
import deadcode.gui.locations;
import deadcode.gui.resource;

import deadcode.io.iomanager;

import std.file;

class Texture : deadcode.graphics.texture.Texture, IResource!Texture
{
	private static @property Texture builtIn() { return null; } // hide

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

	Manager _manager;
	Handle _handle;
	string _name;
}

class TextureManager : ResourceManager!Texture
{
	private Handle builtinTextureHandle;

	@property Texture builtinTexture()
	{
		return get(builtinTextureHandle);
	}

	static TextureManager create(FileManager fileManager)
	{
		auto fm = new TextureManager;
		auto fp = new TextureSerializer;
		fm.fileManager = fileManager;
		fm.addSerializer(fp);
		fm.createBuiltinTexture();
		return fm;
	}

	static class BuiltinLoader : Loader
	{
		bool load(Texture t, URI uri)
		{
			import deadcode.graphics.color;
			deadcode.graphics.texture.Texture.create(8, 8, Color.magenta, t);
			return true;
		}

		bool save(Texture p, URI uri)
		{
			throw new Exception("Cannot save textures");
		}
	}

	void createBuiltinTexture()
	{
		auto res = declare(new URI("builtin:default"), new BuiltinLoader);
		builtinTextureHandle = res.handle;
	}

}

class TextureSerializer : ResourceSerializer!Texture
{
	override bool canRead() pure const nothrow { return true; }

	override bool canHandle(URI uri)
	{
		import deadcode.core.path;

		import std.algorithm;
		return [ ".png" ].countUntil(uri.extension) >= 0;
	}

	override void deserialize(Texture res, FileAccess fileAccess)
	{
		// TODO: Make use of the IO instead of using sdl builtin loader
		Texture.create(res.uri.toString(), res);
		res.manager.onResourceLoaded(res, this);
	}
}
