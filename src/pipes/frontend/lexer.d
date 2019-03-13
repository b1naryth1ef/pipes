module pipes.frontend.lexer;

import std.stdio : writefln;
import std.conv : to;

class StringBuffer {
  size_t idx;
  protected string contents;

  this(string contents) {
    this.contents = contents;
    this.idx = -1;
  }

  string rest() {
    return this.contents[idx..this.contents.length];
  }

  char peek(size_t amount = 1) {
    assert(!this.atEnd(amount), "Overflow when peeking from string buffer");
    return this.contents[this.idx + amount];
  }

  char next() {
    assert(!this.atEnd(), "Overflow when reading from string buffer");
    this.idx += 1;
    return this.contents[this.idx];
  }

  string consume(size_t amount = 1) {
    assert(!this.atEnd(amount), "Overflow when reading from string buffer");
    auto preidx = this.idx;
    this.idx += amount;
    return this.contents[preidx + 1..preidx+amount];
  }

  bool atEnd(size_t amount = 1) {
    return this.idx + amount >= this.contents.length;
  }
}

enum TokenType {
  SYMBOL,
  KEYWORD,
  VARIABLE,
  STRING,
  NUMBER,

  SY_PIPE_MAP,
  SY_PIPE_PASS,
  SY_PIPE_REDUCE,
  SY_PIPE_CONTINUE,

  SY_LPAREN,
  SY_RPAREN,
}

class Token {
  TokenType type;

  this(TokenType type) {
    this.type = type;
  }

  union {
    string string_;
    double number_;
  }
}

class Lexer {
  protected StringBuffer buffer;

  this(string contents) {
    this.buffer = new StringBuffer(contents);
  }

  this(StringBuffer buffer) {
    this.buffer = buffer;
  }

  Token peek() {
    auto previous = this.buffer.idx;
    auto token = this.next();
    this.buffer.idx = previous;
    return token;
  }

  Token next() {
    if (buffer.atEnd()) {
      return null;
    }

    switch (buffer.peek()) {
      case 'A': .. case 'Z':
      case 'a': .. case 'z':
        return this.lexSymbol();
      case '0': .. case '9':
          return this.lexNumber();
      case '(':
      case ')':
        return new Token(buffer.next() == '(' ? TokenType.SY_LPAREN : TokenType.SY_RPAREN);
      case '@':
        if (buffer.peek(2) == '>') {
          buffer.consume(2);
          return new Token(TokenType.SY_PIPE_MAP);
        }
        return null;
      case '-':
        if (buffer.peek(2) == '>') {
          buffer.consume(2);
          return new Token(TokenType.SY_PIPE_PASS);
        }
        return null;
      case '=':
        if (buffer.peek(2) == '>') {
          buffer.consume(2);
          return new Token(TokenType.SY_PIPE_REDUCE);
        }
        return null;
      case '|':
        if (buffer.peek(2) == '>') {
          buffer.consume(2);
          return new Token(TokenType.SY_PIPE_CONTINUE);
        }
        return null;
      case '^':
        buffer.next();
        return this.lexVariable();
      case '\'':
        buffer.next();
        return this.lexString();
      case ' ':
      case '\n':
      case '\t':
        buffer.next();
        return this.next();
      default:
        return null;
    }
  }

  Token[] all() {
    Token[] result;

    auto token = this.next();
    while (token !is null) {
      result ~= token;
      token = this.next();
    }

    if (!this.buffer.atEnd()) {
      writefln("extra: '%s'", this.buffer.rest());
    }
    assert(this.buffer.atEnd(), "Extra characters left at end of buffer?");
    return result;
  }

  protected Token lexSymbol() {
    auto token = new Token(TokenType.SYMBOL);

    outer: while (!this.buffer.atEnd()) {
      switch (this.buffer.peek()) {
        case 'A': .. case 'Z':
        case 'a': .. case 'z':
        case '0': .. case '9':
        case '_':
          token.string_ ~= this.buffer.next();
          break;
        default:
          break outer;
      }
    }

    // TODO: check for keyword
    return token;
  }

  protected Token lexString() {
    auto token = new Token(TokenType.STRING);

    while (!buffer.atEnd()) {
      switch (this.buffer.peek()) {
        case '\n':
          assert(false, "Newline in string");
        case '\'':
          this.buffer.next();
          return token;
        default:
          token.string_ ~= this.buffer.next();
          break;
      }
    }

    assert(false, "Failed to find end of string");
  }

  protected Token lexVariable() {
    auto token = this.lexNumber();
    token.type = TokenType.VARIABLE;
    return token;
  }

  protected Token lexNumber() {
    auto token = new Token(TokenType.NUMBER);
    bool decimal;
    string contents;

    outer: while (!this.buffer.atEnd()) {
      switch (this.buffer.peek()) {
        case '0': .. case '9':
          contents ~= this.buffer.next();
          break;
        case '.':
          assert(!decimal);
          decimal = true;
          contents ~= this.buffer.next();
          break;
        default:
          break outer;
      }
    }

    token.number_ = contents.to!double;
    return token;
  }
}

void debugTokens(Token[] tokens) {
  writefln("=== Token Debug ===");
  foreach (idx, token; tokens) {
    writefln("  %s -> %s", idx, token.type);
  }
  writefln("\n");
}

unittest {
  import std.stdio : writefln;

  auto tokenTypes = (Token[] tokens) {
    TokenType[] result;
    foreach (token; tokens) {
      result ~= token.type;
    }
    return result;
  };

  auto testLex = (string contents) => (new Lexer(contents)).all();
  assert(testLex("echo('hello world')").length == 4);
  assert(testLex("'hello world' -> echo").length == 3);

  auto parts = testLex("'hello world' -> echo");
  assert(parts.length == 3);
  assert(parts[0].type == TokenType.STRING);
  assert(parts[0].string_ == "hello world");
  assert(parts[1].type == TokenType.SY_PIPE_PASS);
  assert(parts[2].type == TokenType.SYMBOL);
  assert(parts[2].string_ == "echo");

  assert(testLex("'abc' @> toUpper -> echo").length == 5);

  // Variable lexing
  assert(testLex("^0").length == 1);
  assert(testLex("test -> ^1")[2].number_ == 1.0);
  assert(testLex("test->^5->test")[2].number_ == 5.0);
  assert(testLex("test->^5->test")[2].type == TokenType.VARIABLE);

  assert(tokenTypes(testLex("test -> ^1 -> test")) == [
    TokenType.SYMBOL,
    TokenType.SY_PIPE_PASS,
    TokenType.VARIABLE,
    TokenType.SY_PIPE_PASS,
    TokenType.SYMBOL,
  ]);

  assert(tokenTypes(testLex("lines -> tsv -> takeString(1)")) == [
    TokenType.SYMBOL,
    TokenType.SY_PIPE_PASS,
    TokenType.SYMBOL,
    TokenType.SY_PIPE_PASS,
    TokenType.SYMBOL,
    TokenType.SY_LPAREN,
    TokenType.NUMBER,
    TokenType.SY_RPAREN,
  ]);
}
