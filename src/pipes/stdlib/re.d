module pipes.stdlib.re;

import pipes.types;
import pipes.stdlib.meta : registerBuiltinFunction, registerBuiltinIntrinsic;

static this() {
  auto stringArray = new Type(BaseType.ARRAY, builtinTypes["string"]);
  auto stringArrayStream = new Type(BaseType.STREAM, stringArray);
  auto stringStream = new Type(BaseType.STREAM, builtinTypes["string"]);

  registerBuiltinFunction("re.match", [builtinTypes["string"], builtinTypes["string"]], stringArray, "re_match");
  registerBuiltinFunction("re.match", [stringStream, builtinTypes["string"]], stringArrayStream, "re_match_stream");
}
