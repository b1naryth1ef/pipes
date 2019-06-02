module pipes.stdlib.os;

import pipes.types;
import pipes.stdlib.meta : registerBuiltinFunction, registerBuiltinIntrinsic;

static this() {
  auto stringStream = new Type(BaseType.STREAM, builtinTypes["string"]);
  registerBuiltinFunction("os.files", [builtinTypes["string"]], stringStream, "os_files");
  registerBuiltinFunction("os.dirs", [builtinTypes["string"]], stringStream, "os_dirs");
  registerBuiltinFunction("os.ls", [builtinTypes["string"]], stringStream, "os_ls");
  registerBuiltinFunction("os.fileSize", [builtinTypes["string"]], builtinTypes["number"], "os_file_size");
}
