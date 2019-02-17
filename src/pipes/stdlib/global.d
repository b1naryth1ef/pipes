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

  registerBuiltinFunction("stream_next_string", [anyStream], builtinTypes["string"]);
  registerBuiltinFunction("stream_next_tuple", [anyStream], builtinTypes["any"]);
}
