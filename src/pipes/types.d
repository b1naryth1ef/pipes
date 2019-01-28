module pipes.types;

import std.format;

enum BaseType {
  VOID = 1,
  STRING = 2,
  NUMBER = 3,
  ARRAY = 4,
  STREAM = 5,
}

class Type {
  BaseType baseType;

  // Only for arrays and streams
  Type elementType;

  this(BaseType baseType, Type elementType = null) {
    this.baseType = baseType;
    this.elementType = elementType;
  }

  override bool opEquals(Object other) {
    if (other is this) {
      return true;
    }

    if (auto otherType = cast(Type)other) {
      return (
        (otherType.baseType == this.baseType) &&
        (otherType.elementType == this.elementType)
      );
    }

    return false;
  }

  override string toString() {
    if (elementType !is null) {
      return format("Type<%s, %s>", this.baseType, this.elementType);
    }
    return format("Type<%s>", this.baseType);
  }
}

__gshared Type[string] builtinTypes;

static this() {
  builtinTypes["void"] = new Type(BaseType.VOID);
  builtinTypes["string"] = new Type(BaseType.STRING);
  builtinTypes["number"] = new Type(BaseType.NUMBER);
}
