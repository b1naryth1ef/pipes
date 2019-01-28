module pipes.stdlib.meta;

import pipes.types;

class BuiltinFunction {
  string name;
  Type[] argTypes;
  Type returnType;

  this(string name, Type[] argTypes, Type returnType = null) {
    this.name = name;
    this.argTypes = argTypes;
    this.returnType = returnType ? returnType : builtinTypes["void"];
  }
}

__gshared BuiltinFunction[string] builtinFunctions;

void registerBuiltinFunction(string name, Type[] argTypes, Type returnType) {
  builtinFunctions[name] = new BuiltinFunction(name, argTypes, returnType);
}
