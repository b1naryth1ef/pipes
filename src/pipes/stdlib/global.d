module pipes.stdlib.global;

import pipes.types;
import pipes.stdlib.meta : registerBuiltinFunction;

static this() {
  registerBuiltinFunction("echo", [builtinTypes["string"]], null);
  registerBuiltinFunction("sum", [builtinTypes["number"], builtinTypes["number"]], builtinTypes["number"]);
  registerBuiltinFunction("concat", [builtinTypes["string"], builtinTypes["string"]], builtinTypes["string"]);

  auto stringStream = new Type(BaseType.STREAM, builtinTypes["string"]);
  registerBuiltinFunction("lines", [], stringStream);
  registerBuiltinFunction("debug_stream", [stringStream], null);
}
