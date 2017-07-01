// copied from https://github.com/forbjok/jsonserialized
module tests.jsonserialized.traits;

enum NoSerialize;

alias Identity(alias T) = T;

bool checkAccessible(alias T, string fieldName)() 
{
	if (!__ctfe)
	{
		T obj;
		alias FieldType = typeof(__traits(getMember, obj, fieldName));
 		string a = T.stringof;
 	}
 	return true;
}

enum IsAccessible(alias T, string fieldName) = is(typeof(checkAccessible!(T, fieldName)));
