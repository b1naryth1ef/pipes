module pipes.stdlib.str;

import pipes.types;
import pipes.stdlib.meta : registerBuiltinFunction, registerBuiltinIntrinsic;

static this() {
  registerBuiltinFunction("str.endswith", [builtinTypes["string"], builtinTypes["string"]], builtinTypes["bool"], "str_endswith");
}
