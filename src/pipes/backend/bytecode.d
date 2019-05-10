module pipes.backend.bytecode;

import std.stdio : writefln;

import pipes.types;
import pipes.frontend.parser;
import pipes.stdlib.meta;

alias BCID = ulong;

enum BCI {
  CALL,  // FUNCTION, ARGS ...
  LOAD_CONST,  // CONST_ID
  ARG,  // INDEX
  INDEX,  // OBJECT, INDEX
  INDEX_ARRAY, // ARRAY, INDEX
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

class BCStep {
  BCID id;
  ASTNodeStep step;
  BCOP[] ops;

  this(BCID id, ASTNodeStep step) {
    this.id = id;
    this.step = step;
  }

  @property Type returnType() {
    if (step.type == StepType.PASS || step.type == StepType.MAP) {
      if (ops.length) {
        if (step.type == StepType.MAP) {
          return ops[$-1].resultType.elementType;
        } else {
          return ops[$-1].resultType;
        }
      }
    } else if (step.type == StepType.STOP) {
      return builtinTypes["void"];
    } else if (step.type == StepType.CONTINUE) {
      return builtinTypes["void"];
    } else {
      assert(false);
    }

    return builtinTypes["void"];
  }
}

class BytecodeCompiler {
  BCStep[] steps;
  BCOP[] ops;
  BCID[BuiltinFunction] builtinFunctionIds;
  string[BCID] constantStrings;
  double[BCID] constantNumbers;

  protected BCStep previousStep;
  protected BCStep currentStep;
  protected BCID idx = 1;
  protected BCID stepIdx = 1;

  this() {
    foreach (funcs; builtinFunctions.values) {
      foreach (builtin; funcs) {
        this.builtinFunctionIds[builtin] = this.idx++;
      }
    }
  }

  void compile(ASTNode[] steps) {
    foreach (step; steps) {
      this.compileOne(step);
    }
  }

  protected BCID addNumberConstant(double cons) {
    auto id = this.idx++;
    this.constantNumbers[id] = cons;
    return id;
  }

  protected BCID addStringConstant(string cons) {
    auto id = this.idx++;
    this.constantStrings[id] = cons;
    return id;
  }

  protected BCID addNumberConstant(double cons) {
    auto id = this.idx++;
    this.constantNumbers[id] = cons;
    return id;
  }

  protected BCID addOp(BCI op, BCID[] args, Type resultType = null) {
    assert(this.currentStep);
    auto res = new BCOP(this.idx++, op, args, resultType);
    this.currentStep.ops ~= res;
    this.ops ~= res;
    return res.id;
  }

  protected BCID compileOne(ASTNode node) {
    switch (node.type) {
      case ASTNodeType.STEP:
        return this.compileStep(node.step);
      case ASTNodeType.STRING:
        return this.compileString(node.string_);
      case ASTNodeType.NUMBER:
        return this.compileNumber(node.number);
      case ASTNodeType.CALL:
        return this.compileCall(node.call);
      case ASTNodeType.VARIABLE:
        return this.compileVariable(node.variable);
      default:
        writefln("Error: unexpected AST node %s", node.type);
        assert(false);
    }
  }

  protected BCID compileStep(ASTNodeStep step) {
    this.currentStep = new BCStep(this.stepIdx++, step);
    this.steps ~= this.currentStep;

    auto exprResult = this.compileOne(step.expr);
    this.previousStep = this.currentStep;

    return exprResult;
  }

  protected BCID compileString(ASTNodeString string_) {
    auto cons = this.addStringConstant(string_.string_);
    return this.addOp(BCI.LOAD_CONST, [cons], builtinTypes["string"]);
  }

  protected BCID compileNumber(ASTNodeNumber number) {
    auto cons = this.addNumberConstant(number.number);
    return this.addOp(BCI.LOAD_CONST, [cons], builtinTypes["number"]);
  }

  protected Type getType(BCID id) {
    if (id in this.constantStrings) {
      return builtinTypes["string"];
    } else if (id in this.constantNumbers) {
      return builtinTypes["number"];
    } else {
      auto op = this.getOp(id);
      assert(op);
      return op.resultType;
    }
  }

  protected BCID compileCall(ASTNodeCall call) {
    BCID[] args;
    Type[] argTypes;

    // Placeholder
    args ~= -1;

    if (this.previousStep !is null) {
      Type previousStepReturnType = this.previousStep.returnType;

      /* if (this.previousStep.step.type == StepType.MAP) { */
      /*   assert(previousStepReturnType.baseType == BaseType.STREAM); */
      /*   previousStepReturnType = previousStepReturnType.elementType; */
      /* } */

      auto arg0 = this.addOp(BCI.ARG, [0], previousStepReturnType);
      args ~= arg0;
      argTypes ~= this.getType(arg0);
    }

    foreach (arg; call.args) {
      auto argId = this.compileOne(arg);
      args ~= argId;
      argTypes ~= this.getType(argId);
    }

    BuiltinFunction func;
    assert(call.target in builtinFunctions);
    outer: foreach (target; builtinFunctions[call.target]) {
      if (argTypes.length != target.argTypes.length) {
        continue;
      }

      foreach (idx, argType; argTypes) {
        if (argType != target.argTypes[idx]) {
          continue outer;
        }
      }

      func = target;
    }

    if (func is null) {
      writefln(
        "failed to find function matching signature: %s (%s)",
        call.target,
        dumpTypesToString(argTypes),
      );
      assert(false);
    }

    args[0] = this.builtinFunctionIds[func];

    return this.addOp(BCI.CALL, args, func.getReturnType(argTypes));
  }

  protected BCID compileVariable(ASTNodeVariable variable) {
    // TODO: should refer to cli args?
    assert(this.previousStep !is null);

    auto arg0 = this.addOp(BCI.ARG, [0], this.previousStep.returnType);
    if (variable.index == 0) {
      return arg0;
    }

    if (this.previousStep.returnType.baseType == BaseType.TUPLE) {
      assert(this.previousStep.returnType.fieldTypes.length >= variable.index);
      auto fieldType = this.previousStep.returnType.fieldTypes[variable.index - 1];
      return this.addOp(BCI.INDEX, [arg0, variable.index - 1], fieldType);
    } else if (this.previousStep.returnType.baseType == BaseType.ARRAY) {
      auto fieldType = this.previousStep.returnType.elementType;
      return this.addOp(BCI.INDEX_ARRAY, [arg0, variable.index - 1], fieldType);
    }

    assert(false);
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
  assert(testCompile("'Hello World' -> echo").ops.length == 3);
}
