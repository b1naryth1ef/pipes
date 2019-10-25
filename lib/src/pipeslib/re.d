module pipelib.regex;

import pipelib.global : PipeArray, PipeString, createPipeArray, Stream;
import core.stdc.stdlib : malloc;

// PCRE2 stuff
extern (C) {
  struct pcre2_code {};
  struct pcre2_general_context {};
  struct pcre2_compile_context {};
  struct pcre2_match_data {};
  struct pcre2_match_context {};

  pcre2_code* pcre2_compile_8(const char* pattern, size_t length, uint options, int* errorcode, size_t* erroroffset, pcre2_compile_context* context);

  void pcre2_code_free_8(pcre2_code* code);

  pcre2_match_data* pcre2_match_data_create_from_pattern_8(const pcre2_code* code, pcre2_general_context* gcontext);
  void pcre2_match_data_free_8(pcre2_match_data* data);

  int pcre2_match_8(const pcre2_code* code, const char* subject, size_t length, size_t start, uint options, pcre2_match_data* match_data, pcre2_match_context* context);

  size_t* pcre2_get_ovector_pointer_8(pcre2_match_data* match_data);
}

extern (C) {
  // TODO: would be cool to have an option like :only_matched or smth
  struct RegexStream {
    Stream* source;

    pcre2_code* code;
    pcre2_match_data* data;
  }

  PipeArray* streamRegexNextArray(Stream* stream) {
    auto regexStream = cast(RegexStream*)stream.data;
    auto next = regexStream.source.nextString(regexStream.source);
    if (next is null) {
      return null;
    }

    auto res = pcre2_match_8(regexStream.code, next.start, next.length, 0, 0, regexStream.data, null);
    assert(res > 0);
    if (res == 1) {
      return createPipeArray(0);
    }

    auto ovector = pcre2_get_ovector_pointer_8(regexStream.data);
    auto arr = createPipeArray(res);

    size_t start = 0;
    size_t end = 0;
    for (size_t idx = 0; idx < res; idx++) {
      start = ovector[2 * idx];
      end = ovector[2 * idx + 1];

      PipeString* newString = cast(PipeString*)malloc(PipeString.sizeof);
      newString.length = end - start;
      newString.start = &next.start[start];
      arr.stringData[idx] = newString;
    }

    return arr;
  }

  Stream* re_match_stream(Stream* source, PipeString* pattern) {
    assert(source.nextString);

    int errorcode;
    size_t erroroffset;
    auto code = pcre2_compile_8(pattern.start, pattern.length, 0, &errorcode, &erroroffset, null);
    assert(code != null);

    auto data = pcre2_match_data_create_from_pattern_8(code, null);

    auto memory = malloc(Stream.sizeof + RegexStream.sizeof);
    auto stream = cast(Stream*)memory;
    auto regexStream = cast(RegexStream*)&memory[Stream.sizeof];

    regexStream.source = source;
    regexStream.code = code;
    regexStream.data = data;

    stream.data = cast(void*)regexStream;
    stream.nextArray = &streamRegexNextArray;

    return stream;
  }

  PipeArray* re_match(PipeString* input, PipeString* pattern) {
    int errorcode;
    size_t erroroffset;
    auto code = pcre2_compile_8(pattern.start, pattern.length, 0, &errorcode, &erroroffset, null);
    assert(code != null);

    auto data = pcre2_match_data_create_from_pattern_8(code, null);

    auto res = pcre2_match_8(code, input.start, input.length, 0, 0, data, null);
    assert(res > 0);
    if (res == 1) {
      return createPipeArray(0);
    }

    auto ovector = pcre2_get_ovector_pointer_8(data);
    auto arr = createPipeArray(res - 1);

    size_t start = 0;
    size_t end = 0;
    for (size_t idx = 0; idx < res; idx++) {
      start = ovector[2 * idx];
      end = ovector[2 * idx + 1];

      PipeString* newString = cast(PipeString*)malloc(PipeString.sizeof);
      newString.length = end - start;
      newString.start = &input.start[start];
      arr.stringData[idx] = newString;

      /**
        The following is a copy implementation of this loop:

        auto memory = malloc(PipeString.sizeof + end - start);
        char* newStringContents = cast(char*)&memory[PipeString.sizeof];
        PipeString* newString = cast(PipeString*)&memory[0];
        newString.start = cast(immutable(char)*)newStringContents;

        memcpy(&newStringContents[0], &input.start[start], end - start);
        newString.length = end - start;
        arr.stringData[idx] = newString;
      **/
    }

    pcre2_match_data_free_8(data);
    pcre2_code_free_8(code);

    return arr;
  }
}

unittest {
  import core.stdc.stdio : printf;

  const char* pattern = "(\\d)";
  const char* text = "yolo1swag";

  int errorcode;
  size_t erroroffset;
  auto code = pcre2_compile_8(pattern, 4, 0, &errorcode, &erroroffset, null);
  assert(code != null);

  auto data = pcre2_match_data_create_from_pattern_8(code, null);

  auto res = pcre2_match_8(code, text, 9, 0, 0, data, null);
  assert(res == 2);

  auto ovector = pcre2_get_ovector_pointer_8(data);
  printf("%d / %d\n", ovector[0], ovector[1]);

  pcre2_match_data_free_8(data);
}
