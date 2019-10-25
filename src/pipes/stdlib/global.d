module pipes.stdlib.global;

import pipes.types;
import pipes.stdlib.meta : registerBuiltinFunction, registerBuiltinIntrinsic;
import pipes.backend.bytecode : BCI;

static this() {
  auto anyStream = new Type(BaseType.STREAM);
  auto anyArray = new Type(BaseType.ARRAY);
  auto numberStream = new Type(BaseType.STREAM, builtinTypes["number"]);
  auto stringStream = new Type(BaseType.STREAM, builtinTypes["string"]);
  auto numberStringTuple = new Type(BaseType.TUPLE, null, [builtinTypes["number"], builtinTypes["string"]]);
  auto numberStringTupleStream = new Type(BaseType.STREAM, numberStringTuple);
  auto stringArray = new Type(BaseType.ARRAY, builtinTypes["string"]);
  auto stringArrayStream = new Type(BaseType.STREAM, stringArray);

  registerBuiltinFunction("length", [builtinTypes["string"]], builtinTypes["number"], "strLength");
  registerBuiltinFunction("length", [anyStream], builtinTypes["number"], "streamLength");
  registerBuiltinFunction("length", [anyArray], builtinTypes["number"], "arrayLength");

  registerBuiltinIntrinsic("sum", [builtinTypes["number"], builtinTypes["number"]], builtinTypes["number"], (bc, args) {
    return bc.addOp(BCI.SUM, args, builtinTypes["number"]);
  });
  registerBuiltinFunction("sum", [numberStream], builtinTypes["number"], "sumStream");

  // String Specific
  registerBuiltinFunction("echo", [builtinTypes["string"]], null);
  registerBuiltinFunction("concat", [builtinTypes["string"], builtinTypes["string"]], builtinTypes["string"]);

  // Inputs
  registerBuiltinFunction("lines", [builtinTypes["string"]], stringStream);

  // Numbers
  registerBuiltinFunction("ntoa", [builtinTypes["number"]], builtinTypes["string"]);

  registerBuiltinFunction("enumerate", [stringStream], numberStringTupleStream);

  // Builtin (mostly?)
  registerBuiltinFunction("stream_next_string", [anyStream], builtinTypes["string"]);
  registerBuiltinFunction("stream_next_tuple", [anyStream], builtinTypes["any"]);
  registerBuiltinFunction("stream_next_array", [anyStream], anyArray);

  registerBuiltinFunction("arrayFirstString", [stringArray], builtinTypes["string"]);
  registerBuiltinFunction("takeString", [stringArrayStream, builtinTypes["number"]], stringStream);
  registerBuiltinFunction("tsv", [stringStream], stringArrayStream);

  // TODO:
  //  1. Support "generics" wherein we take a stream/array and return the type of its element
  //  2. Support specification based on argument types (array/stream are interchangeable)
  // registerBuiltinFunction("first", [anyArray], ARRAY_ELEMENT);
  // registerBuiltinFunction("first", [anyStream], STREAM_ELEMENT);
}
