module pipes.stdlib.global;

import pipes.types;
import pipes.stdlib.meta : registerBuiltinFunction;

static this() {
  registerBuiltinFunction("echo", [builtinTypes["string"]], null);
  registerBuiltinFunction("sum", [builtinTypes["number"], builtinTypes["number"]], builtinTypes["number"]);
  registerBuiltinFunction("concat", [builtinTypes["string"], builtinTypes["string"]], builtinTypes["string"]);
  registerBuiltinFunction("strLength", [builtinTypes["string"]], builtinTypes["number"]);

  auto numberStream = new Type(BaseType.STREAM, builtinTypes["number"]);

  // TODO: temp, eventually we'll just use reduce and sum
  registerBuiltinFunction("sumStream", [numberStream], builtinTypes["number"]);

  auto stringStream = new Type(BaseType.STREAM, builtinTypes["string"]);
  registerBuiltinFunction("lines", [], stringStream);

  auto anyStream = new Type(BaseType.STREAM);
  registerBuiltinFunction("length", [anyStream], builtinTypes["number"]);
  registerBuiltinFunction("ntoa", [builtinTypes["number"]], builtinTypes["string"]);

  auto numberStringTuple = new Type(BaseType.TUPLE, null, [builtinTypes["number"], builtinTypes["string"]]);
  auto numberStringTupleStream = new Type(BaseType.STREAM, numberStringTuple);
  registerBuiltinFunction("enumerate", [stringStream], numberStringTupleStream);

  auto anyArray = new Type(BaseType.ARRAY);
  registerBuiltinFunction("stream_next_string", [anyStream], builtinTypes["string"]);
  registerBuiltinFunction("stream_next_tuple", [anyStream], builtinTypes["any"]);
  registerBuiltinFunction("stream_next_array", [anyStream], anyArray);

  auto stringArray = new Type(BaseType.ARRAY, builtinTypes["string"]);
  registerBuiltinFunction("re", [builtinTypes["string"], builtinTypes["string"]], stringArray);

  registerBuiltinFunction("arrayLength", [anyArray], builtinTypes["number"]);
  registerBuiltinFunction("arrayFirstString", [stringArray], builtinTypes["string"]);

  auto stringArrayStream = new Type(BaseType.STREAM, stringArray);
  registerBuiltinFunction("reStream", [stringStream, builtinTypes["string"]], stringArrayStream);

  registerBuiltinFunction("takeString", [stringArrayStream, builtinTypes["number"]], stringStream);

  registerBuiltinFunction("tsv", [stringStream], stringArrayStream);
  // TODO:
  //  1. Support "generics" wherein we take a stream/array and return the type of its element
  //  2. Support specification based on argument types (array/stream are interchangeable)
  // registerBuiltinFunction("first", [anyArray], ARRAY_ELEMENT);
  // registerBuiltinFunction("first", [anyStream], STREAM_ELEMENT);
}
