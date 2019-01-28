module pipes.backend.bytecode;

import std.stdio : writefln;

import pipes.types;
import pipes.frontend.parser;
import pipes.stdlib.meta;

alias BCID = ulong;

enum BCI {
  CALL,  // FUNCTION, ARGS ...
  LOAD_CONST,  // CONST_ID
}

class BCOP {
  BCID id;
  BCI op;
  BCID[] args;
  Type resultType;

  this(BCID id, BCI op, BCID[] args, Type resultType = null) {
    this.id = id;
    this.op = op;
    this.args = args;
    this.resultType = resultType ? resultType : builtinTypes["void"];
  }
}

class BytecodeCompiler {
  BCOP[] ops;
  BCID[BuiltinFunction] builtinFunctionIds;
  string[BCID] constantStrings;

  protected BCID idx = 1;
  protected BCID previousStepValue = 0;

  this() {
    foreach (builtin; builtinFunctions.values) {
      this.builtinFunctionIds[builtin] = this.idx++;
    }
  }

  void compile(ASTNode[] steps) {
    foreach (step; steps) {
      this.compileOne(step);
    }
  }

  protected BCID addStringConstant(string cons) {
    auto id = this.idx++;
    this.constantStrings[id] = cons;
    return id;
  }

  protected BCID addOp(BCI op, BCID[] args, Type resultType = null) {
    auto res = new BCOP(this.idx++, op, args, resultType);
    this.ops ~= res;
    return res.id;
  }

  protected BCID compileOne(ASTNode node) {
    switch (node.type) {
      case ASTNodeType.STEP:
        return this.compileStep(node.step);
      case ASTNodeType.STRING:
        return this.compileString(node.string_);
      case ASTNodeType.CALL:
        return this.compileCall(node.call);
      default:
        assert(false);
    }
  }

  protected BCID compileStep(ASTNodeStep step) {
    auto exprResult = this.compileOne(step.expr);

    if (step.type == StepType.PASS) {
      this.previousStepValue = exprResult;
    }

    return exprResult;
  }

  protected BCID compileString(ASTNodeString string_) {
    auto cons =  this.addStringConstant(string_.string_);
    return this.addOp(BCI.LOAD_CONST, [cons], builtinTypes["string"]);
  }

  protected BCID compileCall(ASTNodeCall call) {
    BCID[] args;

    assert(call.target in builtinFunctions);
    auto target = builtinFunctions[call.target];

    args ~= this.builtinFunctionIds[target];

    if (this.previousStepValue != 0) {
      args ~= this.previousStepValue;
    }

    foreach (arg; call.args) {
      args ~= this.compileOne(arg);
    }

    if (args.length - 1 != target.argTypes.length) {
      writefln("mismatched arguments count %s vs %s", args.length, target.argTypes.length);
      assert(false);
    }

    Type argType;
    foreach (i, arg; args[1..$]) {
      if (arg in this.constantStrings) {
        argType = builtinTypes["string"];
      } else {
        auto op = this.getOp(arg);
        assert(op);
        argType = op.resultType;
      }

      if (argType != target.argTypes[i]) {
        writefln("mismatched arguments %s vs %s", argType, target.argTypes[i]);
        assert(false);
      }
    }

    return this.addOp(BCI.CALL, args);
  }

  protected BCOP getOp(BCID id) {
    foreach (op; this.ops) {
      if (op.id == id) {
        return op;
      }
    }
    return null;
  }

  protected BuiltinFunction getBuiltin(BCID id) {
    foreach (func, idx; this.builtinFunctionIds) {
      if (id == idx) {
        return func;
      }
    }
    return null;
  }
}

unittest {
  import pipes.frontend.lexer : Lexer;
  import pipes.frontend.parser : Parser;

  auto testCompile = (string contents) {
    auto lexer = new Lexer(contents);
    auto parser = new Parser(lexer);
    auto compiler = new BytecodeCompiler();
    compiler.compile(parser.all());
    return compiler;
  };

  assert(testCompile("'Hello World'").ops.length == 1);
  assert(testCompile("echo('Hello World')").ops.length == 2);
  assert(testCompile("'Hello World' -> echo").ops.length == 2);
}
