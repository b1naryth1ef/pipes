module pipes.backend.llvm;

import llvm;
import std.string : toStringz;

import pipes.types;
import pipes.frontend.lexer : Lexer;
import pipes.frontend.parser : Parser;
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

  this(string programContents) {
    auto lexer = new Lexer(programContents);
    auto parser = new Parser(lexer);
    this.bytecodeCompiler = new BytecodeCompiler();
    this.bytecodeCompiler.compile(parser.all());

    // Initialize some LLVM stuff
    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();
    LLVMInitializeNativeAsmParser();
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
        convertTypeToLLVM(func.returnType),
        argTypes.ptr,
        cast(uint)argTypes.length,
        false,
      );

      this.functions[id] = LLVMAddFunction(this.module_, toStringz(func.name), type);
    }

    this.main = LLVMAddFunction(this.module_, "main", LLVMFunctionType(
      LLVMVoidType(), null, 0, false
    ));

    auto entry = LLVMAppendBasicBlock(this.main, "entry");
    LLVMPositionBuilderAtEnd(this.builder, entry);

    foreach (op; this.bytecodeCompiler.ops) {
      this.results[op.id] = this.compileOne(op);
    }

    LLVMBuildRetVoid(this.builder);
  }

  protected LLVMValueRef compileOne(BCOP op) {
    final switch (op.op) {
      case BCI.CALL:
        return this.compileCall(op);
      case BCI.LOAD_CONST:
        return this.compileLoadConst(op);
    }
  }

  protected LLVMValueRef compileCall(BCOP op) {
    BCID targetId = op.args[0];
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
    } else {
      assert(false);
    }
  }
}

LLVMTypeRef convertTypeToLLVM(Type type) {
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
    case BaseType.STREAM:
      // TODO: qualify the full struct?
      return LLVMPointerType(LLVMIntType(8), 0);
    default:
      assert(false);
  }
}

unittest {
  auto compiler = new LLVMCompiler("'Hello World' -> echo");
  compiler.compile();
  compiler.writeModule("test.ir");
  compiler.writeObject("test.o");
}
