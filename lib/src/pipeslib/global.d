module pipelib.global;

import core.stdc.stdio : printf, snprintf;
import core.stdc.stdlib : malloc, free;
import core.stdc.string : memcpy;

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

extern (C) PipeString* concat(PipeString* a, PipeString* b) {
  // Single shot allocation
  auto memory = malloc(PipeString.sizeof + a.length + b.length);
  char* newStringContents = cast(char*)&memory[PipeString.sizeof];
  PipeString* newString = cast(PipeString*)&memory[0];

  // Set new string properties
  newString.length = a.length + b.length;
  newString.start = cast(immutable(char)*)newStringContents;

  // Copy our strings over
  memcpy(&newStringContents[0], a.start, a.length);
  memcpy(&newStringContents[a.length], b.start, b.length);

  return newString;
}

extern (C) double sum(double a, double b) {
  return a + b;
}

unittest {
  auto str = PipeString.fromString("test");
  echo(&str);
}
