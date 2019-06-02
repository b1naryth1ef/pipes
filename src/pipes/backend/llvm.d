module pipes.backend.llvm;

import llvm;
import std.string : toStringz;
import std.format : format;

import pipes.types;
import pipes.frontend.lexer : Lexer;
import pipes.frontend.parser : Parser, StepType;
import pipes.backend.bytecode;

extern (C) {
  void LLVMLinkInMCJIT();
}

class LLVMCompiler {
  protected BytecodeCompiler bytecodeCompiler;
  protected LLVMBuilderRef builder;
  protected LLVMModuleRef module_;

  protected LLVMValueRef[BCID] constants;
  protected LLVMValueRef[BCID] results;
  protected LLVMValueRef[BCID] functions;

  protected LLVMValueRef main;
  protected LLVMValueRef currentStepFunction;
  protected LLVMValueRef[BCID] stepFunctions;

  this(string programContents) {
    auto lexer = new Lexer(programContents);

    auto parser = new Parser(new Lexer(programContents));
    this.bytecodeCompiler = new BytecodeCompiler();
    this.bytecodeCompiler.compile(parser.all());

    // Initialize some LLVM stuff
    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();
    LLVMInitializeNativeAsmParser();
  }

  LLVMValueRef getBuiltinFunction(string name) {
    foreach (builtin, id; this.bytecodeCompiler.builtinFunctionIds) {
      if (builtin.symbolName == name) {
        return this.functions[id];
      }
    }
    assert(false);
  }

  void runModule() {
    char* error;
    LLVMVerifyModule(this.module_, LLVMAbortProcessAction, &error);
    LLVMDisposeMessage(error);

    LLVMExecutionEngineRef engine;
    LLVMLinkInMCJIT();
    LLVMInitializeNativeTarget();
    LLVMLoadLibraryPermanently("lib/libpipes.so");
    if (LLVMCreateExecutionEngineForModule(&engine, this.module_, &error) != 0) {
      assert(false);
    }
    LLVMDisposeMessage(error);

    LLVMRunFunctionAsMain(engine, this.main, 0, null, null);
    LLVMDisposeExecutionEngine(engine);
  }

  LLVMGenericValueRef runStep(BCID stepId) {
    char* error;
    LLVMVerifyModule(this.module_, LLVMAbortProcessAction, &error);
    LLVMDisposeMessage(error);

    LLVMExecutionEngineRef engine;
    LLVMLinkInMCJIT();
    LLVMInitializeNativeTarget();
    LLVMLoadLibraryPermanently("lib/libpipes.so");
    if (LLVMCreateExecutionEngineForModule(&engine, this.module_, &error) != 0) {
      assert(false);
    }
    LLVMDisposeMessage(error);

    return LLVMRunFunction(engine, this.stepFunctions[stepId], 0, null);
  }

  void writeModule(string outputPath) {
    LLVMPrintModuleToFile(this.module_, toStringz(outputPath), null);
  }

  void writeObject(string outputPath) {
    auto triple = LLVMGetDefaultTargetTriple();

    LLVMTargetRef target;
    char* targetError;
    LLVMGetTargetFromTriple(triple, &target, &targetError);
    if (targetError) {
      assert(false);
    }

    auto opt = LLVMCodeGenLevelDefault;
    auto reloc = LLVMRelocPIC;
    auto codeModel = LLVMCodeModelDefault;

    auto machine = LLVMCreateTargetMachine(
      target,
      triple,
      "",
      "",
      opt,
      reloc,
      codeModel,
    );

    char* targetMachineError;
    LLVMTargetMachineEmitToFile(
      machine,
      this.module_,
      cast(char*)toStringz(outputPath),
      LLVMObjectFile,
      &targetMachineError,
    );

    if (targetMachineError) {
      assert(false);
    }
  }

  void compile() {
    this.builder = LLVMCreateBuilder();
    this.module_ = LLVMModuleCreateWithName(toStringz("<pipes:program>"));

    foreach (func, id; this.bytecodeCompiler.builtinFunctionIds) {
      LLVMTypeRef[] argTypes;

      foreach (argType; func.argTypes) {
        argTypes ~= convertTypeToLLVM(argType);
      }

      auto type = LLVMFunctionType(
        convertTypeToLLVM(func._returnType),
        argTypes.ptr,
        cast(uint)argTypes.length,
        false,
      );

      this.functions[id] = LLVMAddFunction(this.module_, toStringz(func.symbolName), type);
    }

    foreach (step; this.bytecodeCompiler.steps) {
      LLVMTypeRef[] argTypes;

      if (step.parentStep !is null) {
        argTypes ~= convertTypeToLLVM(step.parentStep.passType);
      }

      Type returnType = step.returnType;

      auto func = LLVMAddFunction(this.module_, format("step_%s", step.id).toStringz, LLVMFunctionType(
        convertTypeToLLVM(returnType), argTypes.ptr, cast(uint)argTypes.length, false,
      ));

      this.stepFunctions[step.id] = func;
      this.currentStepFunction = func;

      auto entry = LLVMAppendBasicBlock(func, "entry");
      LLVMPositionBuilderAtEnd(this.builder, entry);

      foreach (op; step.ops) {
        this.results[op.id] = this.compileOne(op);
      }

      if (step.returnValueType.baseType != BaseType.VOID) {
        LLVMBuildRet(this.builder, this.results[step.returnValue]);
      } else {
        LLVMBuildRetVoid(this.builder);
      }
    }

    this.main = LLVMAddFunction(this.module_, "main", LLVMFunctionType(
      LLVMVoidType(), null, 0, false
    ));

    auto entry = LLVMAppendBasicBlock(this.main, "entry");
    LLVMPositionBuilderAtEnd(this.builder, entry);

    // Link steps together
    LLVMBasicBlockRef continuation;
    LLVMValueRef returnValue;
    LLVMValueRef[BCID] stepPassValueRefs;
    foreach (step; this.bytecodeCompiler.steps) {
      LLVMValueRef[] args;

      if (returnValue) {
        args ~= returnValue;
      }

      LLVMValueRef res;

      auto previousStep = step.parentStep;

      // If the previous step was a map then we have our work cut out for us. The
      //  goal now is to map over the stream generated by the previous step. This
      //  is (right now) very straightforward as we just call the next steps with
      //  each value in the stream.
      if (previousStep !is null && previousStep.step.type == StepType.MAP) {
        // Before step contains our next item stream call + a null result check
        auto beforeBlock = LLVMAppendBasicBlock(this.main, "mapBefore");
        // The map body contains the rest of the steps we call with this value
        auto bodyBlock = LLVMAppendBasicBlock(this.main, "mapBody");
        // The after block contains a final location when we're done reading
        //  values from the stream.
        auto afterBlock = LLVMAppendBasicBlock(this.main, "mapAfter");

        // Branch to the before
        LLVMBuildBr(this.builder, beforeBlock);

        // Fill out after
        LLVMPositionBuilderAtEnd(this.builder, afterBlock);
        LLVMBuildRetVoid(this.builder);

        LLVMPositionBuilderAtEnd(this.builder, beforeBlock);

        LLVMValueRef value;
        // TODO: generalize this

        string streamNextFn = "";
        if (previousStep.passType.baseType == BaseType.STRING) {
          streamNextFn = "stream_next_string";
        } else if (previousStep.passType.baseType == BaseType.TUPLE) {
          streamNextFn = "stream_next_tuple";
        } else if (previousStep.passType.baseType == BaseType.ARRAY) {
          streamNextFn = "stream_next_array";
        } else {
          assert(false);
        }

        auto streamNextFnRef = this.getBuiltinFunction(streamNextFn);
        value = LLVMBuildCall(this.builder, streamNextFnRef, args.ptr, cast(uint)args.length, "");
        auto done = LLVMBuildIsNull(this.builder, value, "");
        LLVMBuildCondBr(this.builder, done, afterBlock, bodyBlock);
        LLVMPositionBuilderAtEnd(this.builder, bodyBlock);
        continuation = beforeBlock;

        LLVMValueRef[] stepArgs = [value];
        res = LLVMBuildCall(this.builder, this.stepFunctions[step.id], stepArgs.ptr, cast(uint)stepArgs.length, "");

        stepPassValueRefs[step.id] = value;
      } else if (previousStep !is null && previousStep.step.type == StepType.FILTER) {
        // Block we goto if the filter condition is true
        auto continueBlock = LLVMAppendBasicBlock(this.main, "filterContinue");

        // Block we goto if the filter condition is false
        auto stopBlock = LLVMAppendBasicBlock(this.main, "filterStop");

        // Check the result of our filter step
        auto ifRes = LLVMBuildICmp(this.builder, LLVMIntEQ, args[0], LLVMConstInt(LLVMIntType(8), 1, false), "");
        LLVMBuildCondBr(this.builder, ifRes, continueBlock, stopBlock);

        // Position the builder at the stop block now
        LLVMPositionBuilderAtEnd(this.builder, stopBlock);
        if (continuation) {
          LLVMBuildBr(this.builder, continuation);
        } else {
          LLVMBuildRetVoid(this.builder);
        }

        // Build out the continue block, we call our next step and return void
        LLVMPositionBuilderAtEnd(this.builder, continueBlock);
        LLVMValueRef[] stepArgs = [stepPassValueRefs[previousStep.id]];
        res = LLVMBuildCall(this.builder, this.stepFunctions[step.id], stepArgs.ptr, cast(uint)stepArgs.length, "");

        stepPassValueRefs[step.id] = stepPassValueRefs[previousStep.id];
      } else {
        if (args.length) {
          stepPassValueRefs[step.id] = args[0];
        }
        res = LLVMBuildCall(this.builder, this.stepFunctions[step.id], args.ptr, cast(uint)args.length, "");
      }

      if (step.returnType !is null) {
        returnValue = res;
      }

      previousStep = step;
    }

    if (continuation) {
      LLVMBuildBr(this.builder, continuation);
    } else {
      LLVMBuildRetVoid(this.builder);
    }
  }

  protected LLVMValueRef compileOne(BCOP op) {
    final switch (op.op) {
      case BCI.CALL:
        return this.compileCall(op);
      case BCI.LOAD_CONST:
        return this.compileLoadConst(op);
      case BCI.ARG:
        return this.compileArg(op);
      case BCI.INDEX:
        return this.compileIndex(op);
      case BCI.INDEX_ARRAY:
        return this.compileIndexArray(op);
      case BCI.SUM:
        return this.compileSum(op);
    }
  }

  protected LLVMValueRef compileCall(BCOP op) {
    BCID targetId = op.args[0];
    auto target = this.functions[targetId];

    BCID[] argIds = op.args.length > 1 ? op.args[1..$] : [];
    LLVMValueRef[] args;

    foreach (argId; argIds) {
      args ~= this.results[argId];
    }

    return LLVMBuildCall(
      this.builder,
      this.functions[targetId],
      args.ptr,
      cast(uint)args.length,
      "",
    );
  }

  protected LLVMValueRef compileLoadConst(BCOP op) {
    auto constId = op.args[0];

    if (constId in this.bytecodeCompiler.constantStrings) {
      auto cons = this.bytecodeCompiler.constantStrings[constId];
      LLVMValueRef[] refs;

      refs ~= LLVMConstInt(LLVMIntType(64), cons.length, false);
      refs ~= LLVMBuildGlobalStringPtr(this.builder, toStringz(cons), toStringz("const-string"));

      auto consValue = LLVMConstStruct(refs.ptr, cast(uint)refs.length, false);
      auto consGlobal = LLVMAddGlobal(this.module_, LLVMTypeOf(consValue), "const-string");
      LLVMSetInitializer(consGlobal, consValue);
      LLVMValueRef[] indices = [
        LLVMConstInt(LLVMIntType(32), 0, false),
      ];
      return LLVMBuildGEP(this.builder, consGlobal, indices.ptr, cast(uint)indices.length, "");
    } else if (constId in this.bytecodeCompiler.constantNumbers) {
      auto cons = this.bytecodeCompiler.constantNumbers[constId];
      return LLVMConstReal(LLVMDoubleType(), cons);
    } else {
      assert(false);
    }
  }

  protected LLVMValueRef compileArg(BCOP op) {
    return LLVMGetParam(this.currentStepFunction, cast(uint)op.args[0]);
  }

  protected LLVMValueRef compileIndex(BCOP op) {
    LLVMDumpValue(this.results[op.args[0]]);

    LLVMValueRef[] indicies = [
      LLVMConstInt(LLVMIntType(32), 0, false),
      LLVMConstInt(LLVMIntType(32), op.args[1], false),
    ];

    auto valueBox = LLVMBuildGEP(
      this.builder,
      this.results[op.args[0]],
      indicies.ptr,
      cast(uint)indicies.length,
      "",
    );

    return LLVMBuildLoad(this.builder, valueBox, "");
  }

  protected LLVMValueRef compileIndexArray(BCOP op) {
    LLVMValueRef[] indicies = [
      LLVMConstInt(LLVMIntType(32), 0, false),
      LLVMConstInt(LLVMIntType(32), 1, false),
    ];

    auto ptrValue = LLVMBuildGEP(
      this.builder,
      this.results[op.args[0]],
      indicies.ptr,
      cast(uint)indicies.length,
      ""
    );

    auto ptrValueLoaded = LLVMBuildLoad(this.builder, ptrValue, "");

    LLVMValueRef[] indicies2 = [
      LLVMConstInt(LLVMIntType(32), op.args[1], false),
    ];

    auto valueBox = LLVMBuildGEP(
      this.builder,
      ptrValueLoaded,
      indicies2.ptr,
      cast(uint)indicies2.length,
      ""
    );

    return LLVMBuildLoad(this.builder, valueBox, "");
  }

  protected LLVMValueRef compileSum(BCOP op) {
    return LLVMBuildFAdd(this.builder, this.results[op.args[0]], this.results[op.args[1]], "");
  }
}

LLVMTypeRef convertTypeToLLVM(Type type) {
  assert(type);
  switch (type.baseType) {
    case BaseType.VOID:
      return LLVMVoidType();
    case BaseType.STRING:
      LLVMTypeRef[] fields = [
        LLVMIntType(64),
        LLVMPointerType(LLVMIntType(8), 0),
      ];

      auto structType = LLVMStructType(
        fields.ptr,
        cast(uint)fields.length,
        false,
      );

      return LLVMPointerType(structType, 0);
    case BaseType.NUMBER:
      return LLVMDoubleType();
    case BaseType.BOOL:
      return LLVMIntType(8);
    case BaseType.STREAM:
      // TODO: qualify the full struct?
      return LLVMPointerType(LLVMIntType(8), 0);
    case BaseType.TUPLE:
      LLVMTypeRef[] fields = [];

      foreach (fieldType; type.fieldTypes) {
        fields ~= convertTypeToLLVM(fieldType);
      }

      auto structType = LLVMStructType(
        fields.ptr,
        cast(uint)fields.length,
        true,
      );

      return LLVMPointerType(structType, 0);
    case BaseType.ANY:
      return LLVMPointerType(LLVMIntType(8), 0);
    case BaseType.ARRAY:
      LLVMTypeRef elementType;
      if (type.elementType) {
        elementType = LLVMPointerType(convertTypeToLLVM(type.elementType), 0);
      } else {
        elementType = LLVMPointerType(LLVMIntType(8), 0);
      }

      LLVMTypeRef[] fields = [LLVMIntType(64), elementType];

      auto structType = LLVMStructType(fields.ptr, cast(uint)fields.length, true);
      return LLVMPointerType(structType, 0);
    default:
      assert(false);
  }
}

unittest {
  auto compiler = new LLVMCompiler("'Hello World' -> echo");
  compiler.compile();
  compiler.writeModule("test.ir");
  compiler.writeObject("test.o");


  auto withCompiler = (string program) {
    auto compiler = new LLVMCompiler(program);
    compiler.compile();
    return compiler;
  };

  compiler = withCompiler("sum(1, 2)");
  auto res = compiler.runStep(compiler.bytecodeCompiler.steps[0].id);
  assert(LLVMGenericValueToFloat(LLVMDoubleType(), res) == 3);
  LLVMDisposeGenericValue(res);
}
