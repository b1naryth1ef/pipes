module pipes.types;

import std.format;

enum BaseType {
  VOID = 1,
  STRING = 2,
  NUMBER = 3,
  BOOL = 4,
  ARRAY = 5,
  STREAM = 6,
  TUPLE = 7,
  ANY = 8,
}

class Type {
  BaseType baseType;

  // Only for arrays and streams
  Type elementType;

  // Only for tuples
  Type[] fieldTypes;

  this(BaseType baseType, Type elementType = null, Type[] fieldTypes = null) {
    this.baseType = baseType;
    this.elementType = elementType;
    this.fieldTypes = fieldTypes;
  }

  override bool opEquals(Object other) {
    if (other is this) {
      return true;
    }

    if (auto otherType = cast(Type)other) {
      if (this.baseType == BaseType.STREAM && otherType.baseType == BaseType.STREAM) {
        if (this.elementType is null || otherType.elementType is null) {
          return true;
        }
      }

      if (this.baseType == BaseType.ARRAY && otherType.baseType == BaseType.ARRAY) {
        if (this.elementType is null || otherType.elementType is null) {
          return true;
        }
      }

      if (this.baseType == BaseType.ANY || otherType.baseType == BaseType.ANY) {
        return true;
      }

      return (
        (otherType.baseType == this.baseType) &&
        (otherType.elementType == this.elementType) &&
        (otherType.fieldTypes == this.fieldTypes)
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

string dumpTypesToString(Type[] types) {
  string output;
  foreach (type; types) {
    output ~= type.toString() ~ ", ";
  }
  if (!types.length) {
    return "";
  }
  return output[0..$-2];
}

__gshared Type[string] builtinTypes;

static this() {
  builtinTypes["void"] = new Type(BaseType.VOID);
  builtinTypes["string"] = new Type(BaseType.STRING);
  builtinTypes["number"] = new Type(BaseType.NUMBER);
  builtinTypes["bool"] = new Type(BaseType.BOOL);
  builtinTypes["any"] = new Type(BaseType.ANY);
}
