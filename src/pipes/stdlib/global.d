module pipes.stdlib.global;

import pipes.types;
import pipes.stdlib.meta : registerBuiltinFunction;

static this() {
  registerBuiltinFunction("echo", [builtinTypes["string"]], null);
  registerBuiltinFunction("sum", [builtinTypes["number"], builtinTypes["number"]], builtinTypes["number"]);
  registerBuiltinFunction("concat", [builtinTypes["string"], builtinTypes["string"]], builtinTypes["string"]);
}
