module pipes.main;

import std.stdio : writefln;
import pipes.backend.llvm : LLVMCompiler;

version (unittest) {

} else {
  int main(string[] args) {
    auto compiler = new LLVMCompiler(args[1]);
    compiler.compile();
    compiler.writeModule("test.ir");
    compiler.runModule();
    return 0;
  }
}
