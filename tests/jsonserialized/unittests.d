// copied from https://github.com/forbjok/jsonserialized
version (none):

module tests.jsonserialized.unittests;

unittest {
    import dunit.toolkit;

    import tests.jsonserialized.serialization;
    import tests.jsonserialized.deserialization;
    import stdx.data.json;

    struct TestSubStruct {
        int anotherInt;
        string anotherString;
    }

    struct TestStruct {
        struct NestedStruct {
            int nestedInt;
            string nestedString;
        }

        int singleInt;
        int[] intArray;
        int[][] arrayOfIntArrays;
        int[string] intStringAssocArray;
        int[int] intIntAssocArray;
        char singleChar;
        char[] charArray;
        string singleString;
        string[] stringArray;
        string[][] arrayOfStringArrays;
        string[string] stringAssocArray;
        string[string][string] stringAssocArrayOfAssocArrays;
        bool trueBool;
        bool falseBool;

        TestSubStruct subStruct;
        NestedStruct nestedStruct;
        NestedStruct[] arrayOfNestedStructs;
        NestedStruct[string] nestedStructAssocArray;
    }

    // Create test struct and set it up with some test values
    TestStruct ts;
    with (ts) {
        singleInt = 1234;
        intArray = [1, 2, 3, 4];
        arrayOfIntArrays = [[1, 2], [3, 4]];
        intStringAssocArray = ["one": 1, "two": 2, "three": 3];
        intIntAssocArray = [1: 3, 2: 1, 3: 2];
        singleChar = 'A';
        charArray = ['A', 'B', 'C', 'D'];
        singleString = "just a string";
        stringArray = ["a", "few", "strings"];
        arrayOfStringArrays = [["a", "b"], ["c", "d"]];
        stringAssocArray = ["a": "A", "b": "B", "c": "C"];
        stringAssocArrayOfAssocArrays = ["a": ["a": "A", "b": "B"], "b": ["c": "C", "d": "D"]];
        trueBool = true;
        falseBool = false;
        subStruct.anotherInt = 42;
        subStruct.anotherString = "Another string";
        nestedStruct.nestedInt = 53;
        nestedStruct.nestedString = "Nested string";
        arrayOfNestedStructs = [NestedStruct(1, "One"), NestedStruct(2, "Two")];
        nestedStructAssocArray = ["one": NestedStruct(1, "One"), "two": NestedStruct(2, "Two")];
    }

    // Serialize the struct to JSON
    auto jv = ts.serializeToJSONValue();

    // Create a new empty struct
    TestStruct ts2;

    // Deserialize the JSONValue into it
    ts2.deserializeFromJSONValue(jv);

    // Assert that both structs are identical
    assertEqual(ts2.singleInt, ts.singleInt);
    assertEqual(ts2.intArray, ts.intArray);
    assertEqual(ts2.arrayOfIntArrays, ts.arrayOfIntArrays);
    assertEqual(ts2.intStringAssocArray, ts.intStringAssocArray);
    assertEqual(ts2.intIntAssocArray, ts.intIntAssocArray);
    assertEqual(ts2.singleChar, ts.singleChar);
    assertEqual(ts2.charArray, ts.charArray);
    assertEqual(ts2.singleString, ts.singleString);
    assertEqual(ts2.stringArray, ts.stringArray);
    assertEqual(ts2.arrayOfStringArrays, ts.arrayOfStringArrays);
    assertEqual(ts2.stringAssocArray, ts.stringAssocArray);
    assertEqual(ts2.stringAssocArrayOfAssocArrays, ts.stringAssocArrayOfAssocArrays);
    assertEqual(ts2.trueBool, ts.trueBool);
    assertEqual(ts2.falseBool, ts.falseBool);
    assertEqual(ts2.subStruct, ts.subStruct);
    assertEqual(ts2.subStruct.anotherInt, ts.subStruct.anotherInt);
    assertEqual(ts2.subStruct.anotherString, ts.subStruct.anotherString);
    assertEqual(ts2.nestedStruct, ts.nestedStruct);
    assertEqual(ts2.nestedStruct.nestedInt, ts.nestedStruct.nestedInt);
    assertEqual(ts2.nestedStruct.nestedString, ts.nestedStruct.nestedString);
    assertEqual(ts2.arrayOfNestedStructs, ts.arrayOfNestedStructs);
    assertEqual(ts2.arrayOfNestedStructs[0].nestedInt, ts.arrayOfNestedStructs[0].nestedInt);
    assertEqual(ts2.arrayOfNestedStructs[0].nestedString, ts.arrayOfNestedStructs[0].nestedString);
    assertEqual(ts2.arrayOfNestedStructs[1].nestedInt, ts.arrayOfNestedStructs[1].nestedInt);
    assertEqual(ts2.arrayOfNestedStructs[1].nestedString, ts.arrayOfNestedStructs[1].nestedString);
    assertEqual(ts2.nestedStructAssocArray, ts.nestedStructAssocArray);
    assertEqual(ts2.nestedStructAssocArray["one"].nestedInt, ts.nestedStructAssocArray["one"].nestedInt);
    assertEqual(ts2.nestedStructAssocArray["two"].nestedString, ts.nestedStructAssocArray["two"].nestedString);

    // Attempt to deserialize partial JSON
    TestStruct ts3;
    ts3.deserializeFromJSONValue(`{ "singleInt": 42, "singleString": "Don't panic." }`.toJSONValue());

    ts3.singleInt.assertEqual(42);
    ts3.singleString.assertEqual("Don't panic.");

    // Attempt to deserialize JSON containing a property that does not exist in the struct
    TestStruct ts4;
    ts4.deserializeFromJSONValue(`{ "nonexistentString": "Move along, nothing to see here." }`.toJSONValue());

    auto ts5 = deserializeFromJSONValue!TestStruct(`{ "singleInt": 42, "singleString": "Don't panic." }`.toJSONValue());
    ts5.singleInt.assertEqual(42);
    ts5.singleString.assertEqual("Don't panic.");
}

unittest {
    import dunit.toolkit;

    import tests.jsonserialized.serialization;
    import tests.jsonserialized.deserialization;
    import stdx.data.json;

    class TestSubClass {
        int anotherInt;
    }

    class TestClass {
        static class NestedClass {
            int nestedInt;

            pure this() {
            }

            this(in int initInt) {
                nestedInt = initInt;
            }
        }

        int singleInt;
        int[] intArray;
        int[][] arrayOfIntArrays;
        int[string] intStringAssocArray;
        int[int] intIntAssocArray;
        char singleChar;
        char[] charArray;
        string singleString;
        string[] stringArray;
        string[][] arrayOfStringArrays;
        string[string] stringAssocArray;
        string[string][string] stringAssocArrayOfAssocArrays;
        NestedClass[] arrayOfNestedClasses;
        NestedClass[string] nestedClassAssocArray;

        auto subClass = new TestSubClass();
        auto nestedClass = new NestedClass(53);
    }

    // Create test struct and set it up with some test values
    auto tc = new TestClass();
    with (tc) {
        singleInt = 1234;
        intArray = [1, 2, 3, 4];
        arrayOfIntArrays = [[1, 2], [3, 4]];
        intStringAssocArray = ["one": 1, "two": 2, "three": 3];
        intIntAssocArray = [1: 3, 2: 1, 3: 2];
        singleChar = 'A';
        charArray = ['A', 'B', 'C', 'D'];
        singleString = "just a string";
        stringArray = ["a", "few", "strings"];
        arrayOfStringArrays = [["a", "b"], ["c", "d"]];
        stringAssocArray = ["a": "A", "b": "B", "c": "C"];
        stringAssocArrayOfAssocArrays = ["a": ["a": "A", "b": "B"], "b": ["c": "C", "d": "D"]];
        arrayOfNestedClasses = [new NestedClass(1), new NestedClass(2)];
        nestedClassAssocArray = ["one": new NestedClass(1), "two": new NestedClass(2)];
        subClass.anotherInt = 42;
    }

    // Serialize the struct to JSON
    auto jv = tc.serializeToJSONValue();

    // Create a new empty struct
    auto tc2 = new TestClass();

    // Deserialize the JSONValue into it
    tc2.deserializeFromJSONValue(jv);

    // Assert that both structs are identical
    assertEqual(tc2.singleInt, tc.singleInt);
    assertEqual(tc2.intArray, tc.intArray);
    assertEqual(tc2.arrayOfIntArrays, tc.arrayOfIntArrays);
    assertEqual(tc2.intStringAssocArray, tc.intStringAssocArray);
    assertEqual(tc2.intIntAssocArray, tc.intIntAssocArray);
    assertEqual(tc2.singleChar, tc.singleChar);
    assertEqual(tc2.charArray, tc.charArray);
    assertEqual(tc2.singleString, tc.singleString);
    assertEqual(tc2.stringArray, tc.stringArray);
    assertEqual(tc2.arrayOfStringArrays, tc.arrayOfStringArrays);
    assertEqual(tc2.stringAssocArray, tc.stringAssocArray);
    assertEqual(tc2.stringAssocArrayOfAssocArrays, tc.stringAssocArrayOfAssocArrays);
    assertEqual(tc2.subClass.anotherInt, tc.subClass.anotherInt);
    assertEqual(tc2.nestedClass.nestedInt, tc.nestedClass.nestedInt);
    assertEqual(tc2.arrayOfNestedClasses[0].nestedInt, tc.arrayOfNestedClasses[0].nestedInt);
    assertEqual(tc2.arrayOfNestedClasses[1].nestedInt, tc.arrayOfNestedClasses[1].nestedInt);
    assertEqual(tc2.nestedClassAssocArray["one"].nestedInt, tc.nestedClassAssocArray["one"].nestedInt);
    assertEqual(tc2.nestedClassAssocArray["two"].nestedInt, tc.nestedClassAssocArray["two"].nestedInt);
}

unittest {
    import dunit.toolkit;

    import tests.jsonserialized.deserialization : deserializeFromJSONValue;
    import stdx.data.json : toJSONValue;

    string[string] aa;
    auto jsonValue = `{ "aString": "theString", "anInt": 42 }`.toJSONValue();

    aa.deserializeFromJSONValue(jsonValue);

    assertEqual(aa["aString"], "theString");
    assertEqual(aa["anInt"], "42");
}

unittest {
    /* Unit tests for attempting to deserialize mismatching types */
    import dunit.toolkit;

    import tests.jsonserialized.deserialization : deserializeFromJSONValue;
    import stdx.data.json : toJSONValue;

    struct TestStruct {
        int intValue;
        string stringValue;
        int notArray;
        string alsoNotArray;
        int notAA;
        string alsoNotAA;
    }

    auto jsonValue = `{ "intValue": "aString", "stringValue": 42, "notArray": [], "alsoNotArray": [], "notAA": {}, "alsoNotAA": {} }`.toJSONValue();

    TestStruct ts;
    ts.deserializeFromJSONValue(jsonValue);

    assertEqual(ts.intValue, 0);
    assertEqual(ts.stringValue, "");
    assertEqual(ts.notArray, 0);
    assertEqual(ts.alsoNotArray, "");
    assertEqual(ts.notAA, 0);
    assertEqual(ts.alsoNotAA, "");
}
