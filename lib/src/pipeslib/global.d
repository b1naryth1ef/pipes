module pipelib.global;

import core.stdc.stdio : printf, snprintf, FILE, stdin, fread;
import core.stdc.stdlib : malloc, free, realloc;
import core.stdc.string : memcpy, memchr;

alias PipeNumber = double;

extern (C) {
  /**
    This struct represents a stream of data (either strings or numbers) that can
     be read in a sequential fashion. Streams are optimal for situations where
     its inadvisable to preload or buffer all the data the stream will contain,
     or in situations where data may be produces over a long period of time.

    Internally this struct is an interface which can be implementted by producers
     of stream data.
  */
  struct Stream {
    void* data;

    /**
      Returns the next string in the stream, or null if no further entries exist.
    */
    PipeString* function(Stream*) nextString;

    /**
      Returns the next tuple in the stream, or null if no further entires exist.
    */
    PipeTuple* function(Stream*) nextTuple;

    /**
      Returns the next array in the stream, or null if no further entires exist.
    */
    PipeArray* function(Stream*) nextArray;

    /**
      Copies the next double in the stream to the given memory location. If no
       further entries exist, this function returns false and will not copy any
       value into the passed memory location.
    */
    bool function(Stream*, PipeNumber*) nextNumber;
  }

  PipeString* stream_next_string(Stream* stream) {
    return stream.nextString(stream);
  }

  PipeTuple* stream_next_tuple(Stream* stream) {
    return stream.nextTuple(stream);
  }

  PipeArray* stream_next_array(Stream* stream) {
    return stream.nextArray(stream);
  }

  bool stream_next_number(Stream* stream, PipeNumber* result) {
    return stream.nextNumber(stream, result);
  }

  /**
    Implementation of string storage in the Pipes language.

    Generally its advisable that allocations of PipeString are contiguous, but
     this is not a strict requirement.
  */
  struct PipeString {
    ulong length;
    immutable(char)* start;

    static PipeString fromString(string source) {
      return PipeString(source.length, &source[0]);
    }
  }

  void echo(PipeString* str) {
    printf("%.*s\n", str.length, str.start);
  }

  PipeString* concat(PipeString* a, PipeString* b) {
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

  PipeNumber sum(PipeNumber a, PipeNumber b) {
    return a + b;
  }

  PipeString* ntoa(PipeNumber input) {
    ubyte[4096] buffer;
    auto size = snprintf(cast(char*)buffer.ptr, 4096, "%f", input);

    auto memory = malloc(PipeString.sizeof + size);
    auto newString = cast(PipeString*)memory;
    auto newStringContents = cast(immutable(char)*)&memory[PipeString.sizeof];

    memcpy(cast(void*)newStringContents, buffer.ptr, size);
    newString.length = size;
    newString.start = newStringContents;

    return newString;
  }

  PipeNumber length(Stream* stream) {
    size_t length = 0;

    if (stream.nextString !is null) {
      while (stream.nextString(stream) !is null) {
        length++;
      }
    } else if (stream.nextNumber !is null) {
      PipeNumber v;
      while (stream.nextNumber(stream, &v)) {
        length++;
      }
    } else if (stream.nextTuple !is null) {
      while (stream.nextTuple(stream) !is null) {
        length++;
      }
    } else {
      assert(false);
    }

    return cast(PipeNumber)length;
  }

  PipeNumber strLength(PipeString* str) {
    return str.length;
  }

  /// Implementation for a stream which reads data from a file line by line.
  struct FileLineStream {
    FILE* file;
    ubyte[4096] previousBuffer;
    size_t previousBufferLength;
  }

  PipeString* streamLinesNextString(Stream* stream) {
    auto fs = (cast(FileLineStream*)stream.data);
    ubyte[4096] buffer;
    size_t readSize;
    PipeString* result;
    bool foundNewline = false;

    while (true) {
      // If we have buffered data from a prior read iteration then we need to use
      //  that instead of reading from the actual file.
      if (fs.previousBufferLength > 0) {
        buffer = fs.previousBuffer;
        readSize = fs.previousBufferLength;
        fs.previousBufferLength = 0;
      } else {
        readSize = fread(buffer.ptr, 1, 4096, fs.file);
      }

      // Locate a newline in our buffer
      // ptrdiff_t newlineIndex = countUntil(buffer.ptr, '\n');
      ptrdiff_t newlineIndex = -1;
      void* newlineLocation = memchr(buffer.ptr, '\n', 4096);
      if (newlineLocation) {
        newlineIndex = cast(ubyte*)newlineLocation - buffer.ptr;
      }

      // If we didn't read anything, that means we're EOF (so everything currently
      //  in our PipeString buffer is a line).
      if (readSize == 0) {
        return result;
      }

      // If we found a newline then we need to preserve the extraneous data we
      //  obtained from fread in a persistant buffer for the next invocation of
      //  this function.
      if (newlineIndex > -1) {
        foundNewline = true;

        ptrdiff_t remainingLength = readSize - newlineIndex - 1;
        if (remainingLength > 0) {
          fs.previousBufferLength = remainingLength;
          memcpy(fs.previousBuffer.ptr, newlineLocation + 1, remainingLength);
        }

        // Split at the newline
        readSize = newlineIndex;
      }

      if (result) {
        // In this case we already have a previous PipeString allocated, so our
        //  best course of action is to use realloc to extend that existing memory
        //  block. There are a few important details to considering during this
        //  operation:
        //    1. Normally we consider PipeString's as immutable, but in this case
        //     we haven't passed our pointer to anyone else yet so its safe to
        //     mutate and modify this memory.
        //    2. Since we're dealing with contiguous memory blocks here things
        //     are slightly more complicated than they need to be.
        auto newMemory = realloc(cast(void*)result, PipeString.sizeof + result.length + readSize);
        result = cast(PipeString*)newMemory;
        result.start = cast(immutable(char)*)&newMemory[PipeString.sizeof];
        memcpy(cast(void*)&result.start[result.length], buffer.ptr, readSize);
        result.length += readSize;
      } else {
        // If we don't have a previous PipeString to extend, we need to allocate
        //  a new one plus the storage space for our string in a contiguous memory
        //  block.
        auto memory = malloc(PipeString.sizeof + readSize);
        result = cast(PipeString*)memory;
        result.length = readSize;
        result.start = cast(immutable(char)*)&memory[PipeString.sizeof];
        memcpy(cast(void*)result.start, buffer.ptr, readSize);
      }

      if (foundNewline) {
        return result;
      }
    }
  }

  Stream* lines() {
    auto memory = malloc(Stream.sizeof + FileLineStream.sizeof);
    auto stream = cast(Stream*)memory;
    auto fileStream = cast(FileLineStream*)&memory[Stream.sizeof];

    fileStream.file = stdin;
    fileStream.previousBufferLength = 0;
    stream.data = cast(void*)fileStream;
    stream.nextString = &streamLinesNextString;
    stream.nextTuple = null;
    stream.nextNumber = null;
    return stream;
  }

  /// Enumerate
  struct EnumerateStream {
    Stream* source;
    size_t index = 0;
  }


  PipeTuple* streamEnumerateNextTuple(Stream* stream) {
    auto enumStream = cast(EnumerateStream*)stream.data;
    auto next = enumStream.source.nextString(enumStream.source);

    if (next is null) {
      return null;
    }

    auto result = createPipeTuple(cast(PipeNumber)enumStream.index, next);

    enumStream.index += 1;
    return result;
  }

  Stream* enumerate(Stream* source) {
    auto memory = malloc(Stream.sizeof + EnumerateStream.sizeof);
    auto stream = cast(Stream*)memory;
    auto enumStream = cast(EnumerateStream*)&memory[Stream.sizeof];

    enumStream.index = 0;
    enumStream.source = source;
    stream.data = cast(void*)enumStream;
    stream.nextTuple = &streamEnumerateNextTuple;
    stream.nextString = null;
    stream.nextNumber = null;

    // TODO: support numbers
    assert(source.nextString);

    return stream;
  }

  struct PipeTuple {}

  PipeTuple* createPipeTuple(Args...)(Args args) {
    size_t size = 0;
    foreach (arg; args) {
      size += arg.sizeof;
    }

    auto memory = malloc(size);
    size_t pos = 0;
    foreach (arg; args) {
      memcpy(&memory[pos], &arg, arg.sizeof);
      pos += arg.sizeof;
    }

    return cast(PipeTuple*)memory;
  }

  PipeNumber sumStream(Stream* stream) {
    assert(stream.nextNumber);
    PipeNumber sum;
    PipeNumber next;

    while (stream.nextNumber(stream, &next)) {
      sum += next;
    }

    return sum;
  }

  struct PipeArray {
    ulong length;
    void* data;

    @property PipeString** stringData() {
      return cast(PipeString**)this.data;
    }
  }

  PipeArray* createPipeArray(uint length) {
    auto arr = cast(PipeArray*)malloc(PipeArray.sizeof + ((void*).sizeof * length));
    arr.data = cast(void*)arr + PipeArray.sizeof;
    arr.length = length;
    return arr;
  }

  PipeNumber arrayLength(PipeArray* arr) {
    return cast(double)arr.length;
  }

  PipeString* arrayFirstString(PipeArray* arr) {
    assert(arr.length >= 1);
    return cast(PipeString*)arr.stringData[0];
  }

  Stream* tsv(Stream* source) {
    auto stream = cast(Stream*)malloc(Stream.sizeof);
    stream.data = cast(void*)source;
    stream.nextArray = &streamTSVNextArray;
    return stream;
  }

  PipeString* createPipeString(immutable(char)* data, size_t length) {
    auto str = cast(PipeString*)malloc(PipeString.sizeof);
    str.start = data;
    str.length = length;
    return str;
  }

  PipeArray* streamTSVNextArray(Stream* stream) {
    auto source = cast(Stream*)stream.data;

    auto next = source.nextString(source);
    if (next is null) {
      return null;
    }

    // Blech
    size_t tabCount = 0;
    for (size_t idx = 0; idx < next.length; idx++) {
      if (next.start[idx] == '\t') {
        tabCount += 1;
      }
    }

    auto res = createPipeArray(cast(uint)(tabCount + 1));

    size_t resIdx = 0;
    size_t currStart = 0;
    for (size_t idx = 0; idx < next.length; idx++) {
      if (next.start[idx] == '\t') {
        res.stringData[resIdx] = createPipeString(next.start + currStart, idx-1-currStart);
        resIdx += 1;
        currStart = idx + 1;
      }
    }

    if (currStart < next.length) {
      res.stringData[resIdx] = createPipeString(next.start + currStart, next.length-1-currStart);
    }

    return res;
  }

  struct TakeStringStream {
    Stream* source;
    size_t index;
  }

  PipeString* streamTakeStringNextString(Stream* source) {
    auto takeStringStream = cast(TakeStringStream*)source.data;

    auto next = takeStringStream.source.nextArray(takeStringStream.source);
    if (next is null) {
      return null;
    }

    assert(next.length > takeStringStream.index);
    return next.stringData[takeStringStream.index];
  }

  Stream* takeString(Stream* source, PipeNumber index) {
    assert(source.nextString);

    auto memory = malloc(Stream.sizeof + TakeStringStream.sizeof);
    auto stream = cast(Stream*)memory;
    auto takeStringStream = cast(TakeStringStream*)&memory[Stream.sizeof];

    takeStringStream.source = source;
    takeStringStream.index = cast(size_t)index;

    stream.data = cast(void*)takeStringStream;
    stream.nextString = &streamTakeStringNextString;
    return stream;
  }

}


unittest {
  auto str = PipeString.fromString("test");
  echo(&str);

  PipeNumber a = 1.0;
  PipeNumber b = 2.0;
  auto tuple = createPipeTuple(a, b);

  import std.stdio;
  writefln("%s", PipeNumber.sizeof);
}
