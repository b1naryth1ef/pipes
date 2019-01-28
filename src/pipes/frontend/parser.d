module pipes.frontend.parser;

import pipes.frontend.lexer : Lexer, TokenType;

import std.stdio : writefln;

enum ASTNodeType {
  STEP,

  STRING,  // Literal string
  NUMBER,  // Literal number

  CALL,  // Function call
}

class Parser {
  protected Lexer lexer;

  this(Lexer lexer) {
    this.lexer = lexer;
  }

  ASTNode[] all() {
    ASTNode[] result;

    auto node = this.next();
    while (node !is null) {
      result ~= node;
      node = this.next();
    }

    return result;
  }

  /// Attempts to parse a single step
  ASTNode next() {
    auto node = new ASTNode(ASTNodeType.STEP);
    node.step.expr = this.readExpression();
    if (node.step.expr is null) {
      return null;
    }

    auto token = this.lexer.next();
    if (token is null) {
      node.step.type = StepType.STOP;
    } else if (token.type == TokenType.SY_PIPE_MAP) {
      node.step.type = StepType.MAP;
    } else if (token.type == TokenType.SY_PIPE_PASS) {
      node.step.type = StepType.PASS;
    } else if (token.type == TokenType.SY_PIPE_REDUCE) {
      node.step.type = StepType.REDUCE;
    } else if (token.type == TokenType.SY_PIPE_CONTINUE) {
      node.step.type = StepType.CONTINUE;
    } else {
      writefln("%s", token.type);
      assert(false, "Invalid token after expression (looking for pipe)");
    }

    return node;
  }

  protected ASTNode readExpression() {
    auto token = this.lexer.next();
    if (token is null) {
      return null;
    }

    switch (token.type) {
      case TokenType.SYMBOL:
        return parseCall(token.string_);
      case TokenType.STRING:
        auto node = new ASTNode(ASTNodeType.STRING);
        node.string_.string_ = token.string_;
        return node;
      default:
        writefln("Unhandled token type: %s", token.type);
        assert(false);
    }
  }

  protected ASTNode parseCall(string target) {
    auto node = new ASTNode(ASTNodeType.CALL);
    node.call.target = target;

    if (this.lexer.peek() && this.lexer.peek().type == TokenType.SY_LPAREN) {
      this.lexer.next();
      while (this.lexer.peek() && this.lexer.peek().type != TokenType.SY_RPAREN) {
        node.call.args ~= this.readExpression();
      }

      assert(this.lexer.next().type == TokenType.SY_RPAREN);
    }

    return node;
  }
}

class ASTNode {
  ASTNodeType type;

  this(ASTNodeType type) {
    this.type = type;
  }

  union {
    ASTNodeStep step;
    ASTNodeString string_;
    ASTNodeNumber number;
    ASTNodeCall call;
  }
}

enum StepType {
  MAP,
  PASS,
  REDUCE,
  CONTINUE,
  STOP,
}

struct ASTNodeStep {
  StepType type;
  ASTNode expr;
}

struct ASTNodeString {
  string string_;
}

struct ASTNodeNumber {
  double number;
}

struct ASTNodeCall {
  string target;
  ASTNode[] args;
}

unittest {
  auto testParse = (string contents) {
    auto lexer = new Lexer(contents);
    auto parser = new Parser(lexer);
    return parser.all();
  };

  auto tree = testParse("echo('hello world')");
  assert(tree.length == 1);
  assert(tree[0].type == ASTNodeType.STEP);
  assert(tree[0].step.type == StepType.STOP);
  assert(tree[0].step.expr.type == ASTNodeType.CALL);
  assert(tree[0].step.expr.call.target == "echo");
  assert(tree[0].step.expr.call.args[0].type == ASTNodeType.STRING);
  assert(tree[0].step.expr.call.args[0].string_.string_ == "hello world");

  tree = testParse("'hello world' -> echo");
  assert(tree.length == 2);
  assert(tree[0].type == ASTNodeType.STEP);
  assert(tree[0].step.type == StepType.PASS);
  assert(tree[1].type == ASTNodeType.STEP);
  assert(tree[1].step.type == StepType.STOP);
}

