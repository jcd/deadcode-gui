// copied from https://github.com/forbjok/jsonserialized
module tests.jsonserialized.deserialization;

import tests.jsonserialized.traits;
import std.conv;
import stdx.data.json;	
import std.meta;
import std.traits;

void deserializeFromJSONValue(T)(ref T array, in JSONValue jsonValue) if (isArray!T) {
    alias ElementType = ForeachType!T;

    // Iterate each item in the array JSONValue and add them to values, converting them to the actual type
    auto jsonArray = jsonValue.get!(JSONValue[]);
    auto jsonArrayLength = jsonArray.length;
    
    static if (isStaticArray!T)
    {
    	if (jsonArrayLength > array.length)
    		jsonArrayLength = array.length;
    }

    foreach(idx; 0..jsonArrayLength) {
        
        static if (is(ElementType == struct)) {
            // This item is a struct - instantiate it
            ElementType newStruct;

            // ...deserialize into the new instance
            newStruct.deserializeFromJSONValue(jsonArray[idx]);

            // ...and add it to the array
            array[idx] = newStruct;
        }
        else static if (is(ElementType == class)) {
            // The item type is class - create a new instance
            auto newClass = new ElementType();

            // ...deserialize into the new instance
            newClass.deserializeFromJSONValue(jsonArray[idx]);

            // ...and add it to the array
            array[idx] = newClass;
        }
        else static if (isSomeString!ElementType) {
            array[idx] = jsonArray[idx].get!string.to!ElementType;
        }
        else static if (isArray!ElementType) {
            // An array of arrays. Recursion time!
            ElementType subArray;

            subArray.deserializeFromJSONValue(jsonArray[idx]);
            array[idx] = subArray;
        }
        else {
            array[idx] = jsonArray[idx].to!ElementType;
        }
    }
}

void deserializeFromJSONValue(T)(ref T associativeArray, in JSONValue jsonValue) if (isAssociativeArray!T) {
    alias VType = ValueType!T;

    // Iterate each item in the JSON object
    foreach(stringKey, value; jsonValue.get!(JSONValue[string])) {
        auto key = stringKey.to!(KeyType!T);

        static if (isAssociativeArray!VType) {
            /* The associative array's value type is another associative array type.
               It's recursion time. */

            if (key in associativeArray) {
                associativeArray[key].deserializeFromJSONValue(value);
            }
            else {
                VType subAssocArray;

                subAssocArray.deserializeFromJSONValue(value);
                associativeArray[key] = subAssocArray;
            }
        }
        else static if (is(VType == struct)) {
            // The value type is a struct - instantiate it
            VType newStruct;

            // ...deserialize into the new instance
            newStruct.deserializeFromJSONValue(value);

            // ...and add it to the associative array
            associativeArray[key] = newStruct;
        }
        else static if (is(VType == class)) {
            // The value type is class - create a new instance
            auto newClass = new VType();

            // ...deserialize into the new instance
            newClass.deserializeFromJSONValue(value);

            // ...and add it to the associative array
            associativeArray[key] = newClass;
        }
        else static if (isSomeString!VType) {
            string v;

            if (value.hasType!string)
                v = value.get!string;
            else if (value.hasType!long)
                v = value.get!long.to!string;

            associativeArray[key] = v.to!VType;
        }
        else {
            associativeArray[key] = value.to!VType;
        }
    }
}

void deserializeFromJSONValue(T)(ref T obj, in JSONValue jsonValue) if (is(T == struct) || is(T == class)) {

	static if (is(T == class)) {
		alias allClasses = BaseClassesTuple!T;
		enum fieldNames = staticMap!(FieldNameTuple, allClasses);
	}
	else {
    	enum fieldNames = FieldNameTuple!T;
	}

    foreach(fieldName; fieldNames) {
        enum accessible = IsAccessible!(T, fieldName);

        static if (accessible) {
        	alias Field = Identity!(__traits(getMember, obj, fieldName));
	        alias FieldType = typeof(Field);

	        if (fieldName !in jsonValue) {
	            continue;
	        }

	        static if (hasUDA!(Field, NoSerialize)) {
	        	// skip
	        }
	        else static if (is(FieldType == struct)) {
	            // This field is a struct - recurse into it
	            __traits(getMember, obj, fieldName).deserializeFromJSONValue(jsonValue[fieldName]);
	        }
	        else static if (is(FieldType == class)) {
	            // This field is a class - recurse into it unless it is null
	            if (__traits(getMember, obj, fieldName) !is null) {
	                __traits(getMember, obj, fieldName).deserializeFromJSONValue(jsonValue[fieldName]);
	            }
	        }
	        else static if (isSomeString!FieldType) {
	            // If the JSONValue does not contain a string, don't try to deserialize
	            if (!jsonValue[fieldName].hasType!string)
	                continue;

	            // Because all string types are stored as string in JSONValue, get it as string and convert it to the correct string type
	            __traits(getMember, obj, fieldName) = jsonValue[fieldName].get!string.to!FieldType;
	        }
	        else static if (isArray!FieldType) {
	            // If the JSONValue does not contain an array, don't try to deserialize
	            if (!jsonValue[fieldName].hasType!(JSONValue[]))
	                continue;

	            // Field is an array
	            __traits(getMember, obj, fieldName).deserializeFromJSONValue(jsonValue[fieldName]);
	        }
	        else static if (isAssociativeArray!FieldType) {
	            // Field is an associative array
	            __traits(getMember, obj, fieldName).deserializeFromJSONValue(jsonValue[fieldName]);
	        }
	        else static if (isIntegral!FieldType) {
	            // If the JSONValue type does not contain a long, don't try to deserialize
	            if (!jsonValue[fieldName].hasType!long)
	                continue;

	            static if (is(FieldType == enum))
		            __traits(getMember, obj, fieldName) = cast(FieldType)jsonValue[fieldName].to!(OriginalType!FieldType);
		        else
		            __traits(getMember, obj, fieldName) = jsonValue[fieldName].to!FieldType;
	        }
	        else {
	            __traits(getMember, obj, fieldName) = jsonValue[fieldName].to!FieldType;
	        }
	    }
    }
}

T deserializeFromJSONValue(T)(in JSONValue jsonValue) if (is(T == struct)) {
    T obj;

    obj.deserializeFromJSONValue(jsonValue);
    return obj;
}
