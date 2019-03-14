module pipes.stdlib.meta;

import pipes.types;

class BuiltinFunction {
  string name;
  string symbolName;
  Type[] argTypes;
  Type _returnType;

  Type function(BuiltinFunction, Type[]) generateReturnType;

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
