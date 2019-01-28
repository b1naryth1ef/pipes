module pipelib.global;

import core.stdc.stdio : printf, snprintf;

struct PipeString {
  ulong length;
  immutable(char)* start;

  static PipeString fromString(string source) {
    return PipeString(source.length, &source[0]);
  }
}

extern (C) void echo(PipeString* str) {
  printf("%.*s\n", str.length, str.start);
}

extern (C) double sum(double a, double b) {
  return a + b;
}

unittest {
  auto str = PipeString.fromString("test");
  echo(&str);
}
