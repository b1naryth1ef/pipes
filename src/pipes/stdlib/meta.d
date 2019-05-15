module pipes.stdlib.meta;

import pipes.types;
import pipes.backend.bytecode : BytecodeCompiler, BCID;

alias IntrinsicGenFn = BCID function(BytecodeCompiler, BCID[]);

class BuiltinFunction {
  string name;
  string symbolName;
  Type[] argTypes;
  Type _returnType;

  Type function(BuiltinFunction, Type[]) generateReturnType;

  IntrinsicGenFn intrinsicGenFn;

  this(string name, Type[] argTypes, Type returnType = null, string symbolName = null) {
    this.name = name;
    this.symbolName = symbolName !is null ? symbolName : name;
    this.argTypes = argTypes;
    this._returnType = returnType ? returnType : builtinTypes["void"];
  }

  Type getReturnType(Type[] args) {
    if (this.generateReturnType) {
      return this.generateReturnType(this, args);
    }
    return this._returnType;
  }

  @property bool isIntrinsic() {
    return this.intrinsicGenFn !is null;
  }
}

__gshared BuiltinFunction[][string] builtinFunctions;

void registerBuiltinFunction(string name, Type[] argTypes, Type returnType, string symbolName = null, Type function(BuiltinFunction, Type[]) generateReturnType = null) {
  if (name !in builtinFunctions) {
    builtinFunctions[name] = [];
  }
  auto func = new BuiltinFunction(name, argTypes, returnType, symbolName);
  func.generateReturnType = generateReturnType;
  builtinFunctions[name] ~= func;
}

void registerBuiltinIntrinsic(string name, Type[] argTypes, Type returnType, IntrinsicGenFn fn) {
  if (name !in builtinFunctions) {
    builtinFunctions[name] = [];
  }
  auto func = new BuiltinFunction(name, argTypes, returnType);
  func.intrinsicGenFn = fn;
  builtinFunctions[name] ~= func;
}
