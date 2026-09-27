; llvm.pl -- LLVM-C declarations for the PLUM backend.
;
; Every LLVM handle (context, module, builder, type, value, basic block)
; is opaque, so they are all @ABYSS here. That is the whole trick that
; lets PLUM drive a C API without any binding layer.

; --- enum values, from llvm-c/Core.h --------------------------------------
I32 LLVMVoidTypeKind    = 0
I32 LLVMFloatTypeKind   = 2
I32 LLVMDoubleTypeKind  = 3
I32 LLVMIntegerTypeKind = 8
I32 LLVMStructTypeKind  = 10
I32 LLVMArrayTypeKind   = 11
I32 LLVMPointerTypeKind = 12

I32 LLVMIntEQ  = 32
I32 LLVMIntNE  = 33
I32 LLVMIntUGT = 34
I32 LLVMIntUGE = 35
I32 LLVMIntULT = 36
I32 LLVMIntULE = 37
I32 LLVMIntSGT = 38
I32 LLVMIntSGE = 39
I32 LLVMIntSLT = 40
I32 LLVMIntSLE = 41

I32 LLVMRealOEQ = 1
I32 LLVMRealOGT = 2
I32 LLVMRealOGE = 3
I32 LLVMRealOLT = 4
I32 LLVMRealOLE = 5
I32 LLVMRealUNE = 14

I32 LLVMPrivateLinkage = 9
I32 LLVMReturnStatusAction = 1

I32 LLVMCodeGenLevelDefault = 2
I32 LLVMRelocDefault        = 0
I32 LLVMCodeModelDefault    = 0

; --- context, module, builder ---------------------------------------------
@ABYSS LLVMContextCreate: []
ABYSS  LLVMContextDispose: [ @ABYSS ctx ]
@ABYSS LLVMModuleCreateWithNameInContext: [ @C1 name | @ABYSS ctx ]
ABYSS  LLVMDisposeModule: [ @ABYSS m ]
@ABYSS LLVMCreateBuilderInContext: [ @ABYSS ctx ]
ABYSS  LLVMDisposeBuilder: [ @ABYSS b ]
ABYSS  LLVMDisposeMessage: [ @C1 msg ]

; --- target ---------------------------------------------------------------
; LLVMInitializeNativeTarget/AsmPrinter are static inline in the C header,
; so they are not linkable symbols. These are the real ones.
ABYSS  LLVMInitializeX86TargetInfo: []
ABYSS  LLVMInitializeX86Target: []
ABYSS  LLVMInitializeX86TargetMC: []
ABYSS  LLVMInitializeX86AsmPrinter: []
ABYSS  LLVMInitializeARMTargetInfo: []
ABYSS  LLVMInitializeARMTarget: []
ABYSS  LLVMInitializeARMTargetMC: []
ABYSS  LLVMInitializeRISCVTargetInfo: []
ABYSS  LLVMInitializeRISCVTarget: []
ABYSS  LLVMInitializeRISCVTargetMC: []
ABYSS  LLVMInitializeAVRTargetInfo: []
ABYSS  LLVMInitializeAVRTarget: []
ABYSS  LLVMInitializeAVRTargetMC: []
@C1    LLVMGetDefaultTargetTriple: []
ABYSS  LLVMSetTarget: [ @ABYSS m | @C1 triple ]
I32    LLVMGetTargetFromTriple: [ @C1 triple | @@ABYSS out | @@C1 err ]
@ABYSS LLVMCreateTargetMachine: [ @ABYSS t | @C1 triple | @C1 cpu | @C1 feat | I32 lvl | I32 reloc | I32 cm ]
ABYSS  LLVMDisposeTargetMachine: [ @ABYSS tm ]
@ABYSS LLVMCreateTargetDataLayout: [ @ABYSS tm ]
@C1    LLVMCopyStringRepOfTargetData: [ @ABYSS td ]
ABYSS  LLVMSetDataLayout: [ @ABYSS m | @C1 dl ]
ABYSS  LLVMDisposeTargetData: [ @ABYSS td ]
@ABYSS LLVMGetModuleDataLayout: [ @ABYSS m ]
U64    LLVMABISizeOfType: [ @ABYSS td | @ABYSS ty ]

; --- types ----------------------------------------------------------------
@ABYSS LLVMVoidTypeInContext: [ @ABYSS ctx ]
@ABYSS LLVMInt1TypeInContext: [ @ABYSS ctx ]
@ABYSS LLVMInt8TypeInContext: [ @ABYSS ctx ]
@ABYSS LLVMInt16TypeInContext: [ @ABYSS ctx ]
@ABYSS LLVMInt32TypeInContext: [ @ABYSS ctx ]
@ABYSS LLVMInt64TypeInContext: [ @ABYSS ctx ]
@ABYSS LLVMFloatTypeInContext: [ @ABYSS ctx ]
@ABYSS LLVMDoubleTypeInContext: [ @ABYSS ctx ]
@ABYSS LLVMPointerType: [ @ABYSS elem | I32 addrspace ]
@ABYSS LLVMArrayType: [ @ABYSS elem | I32 count ]
@ABYSS LLVMFunctionType: [ @ABYSS ret | @@ABYSS params | I32 n | I32 vararg ]
@ABYSS LLVMStructCreateNamed: [ @ABYSS ctx | @C1 name ]
ABYSS  LLVMStructSetBody: [ @ABYSS st | @@ABYSS elems | I32 n | I32 packed ]
I32    LLVMGetTypeKind: [ @ABYSS ty ]
I32    LLVMGetIntTypeWidth: [ @ABYSS ty ]
@ABYSS LLVMTypeOf: [ @ABYSS v ]
@ABYSS LLVMGetReturnType: [ @ABYSS fnty ]
I32    LLVMCountParamTypes: [ @ABYSS fnty ]
ABYSS  LLVMGetParamTypes: [ @ABYSS fnty | @@ABYSS out ]
@C1    LLVMPrintTypeToString: [ @ABYSS ty ]

; --- constants ------------------------------------------------------------
@ABYSS LLVMConstInt: [ @ABYSS ty | U64 v | I32 sign_extend ]
@ABYSS LLVMConstReal: [ @ABYSS ty | F64 v ]
I32    LLVMIsConstant: [ @ABYSS v ]
@ABYSS LLVMConstNull: [ @ABYSS ty ]
@ABYSS LLVMConstPointerNull: [ @ABYSS ty ]
@ABYSS LLVMConstStringInContext: [ @ABYSS ctx | @C1 s | I32 len | I32 dont_null_terminate ]
@ABYSS LLVMSizeOf: [ @ABYSS ty ]

; --- module contents ------------------------------------------------------
@ABYSS LLVMAddFunction: [ @ABYSS m | @C1 name | @ABYSS fnty ]
@ABYSS LLVMGetNamedFunction: [ @ABYSS m | @C1 name ]
@ABYSS LLVMGetParam: [ @ABYSS fn | I32 idx ]
@ABYSS LLVMAddGlobal: [ @ABYSS m | @ABYSS ty | @C1 name ]
ABYSS  LLVMSetInitializer: [ @ABYSS g | @ABYSS v ]
ABYSS  LLVMSetGlobalConstant: [ @ABYSS g | I32 c ]
ABYSS  LLVMSetLinkage: [ @ABYSS g | I32 linkage ]
ABYSS  LLVMSetUnnamedAddr: [ @ABYSS g | I32 u ]
@ABYSS LLVMGlobalGetValueType: [ @ABYSS g ]

; --- basic blocks ---------------------------------------------------------
@ABYSS LLVMAppendBasicBlockInContext: [ @ABYSS ctx | @ABYSS fn | @C1 name ]
ABYSS  LLVMPositionBuilderAtEnd: [ @ABYSS b | @ABYSS bb ]
@ABYSS LLVMGetInsertBlock: [ @ABYSS b ]
@ABYSS LLVMGetBasicBlockTerminator: [ @ABYSS bb ]

; --- instructions ---------------------------------------------------------
@ABYSS LLVMBuildAlloca: [ @ABYSS b | @ABYSS ty | @C1 name ]
@ABYSS LLVMBuildStore: [ @ABYSS b | @ABYSS v | @ABYSS ptr ]
@ABYSS LLVMBuildLoad2: [ @ABYSS b | @ABYSS ty | @ABYSS ptr | @C1 name ]
@ABYSS LLVMBuildCall2: [ @ABYSS b | @ABYSS fnty | @ABYSS fn | @@ABYSS args | I32 n | @C1 name ]
@ABYSS LLVMBuildRet: [ @ABYSS b | @ABYSS v ]
@ABYSS LLVMBuildRetVoid: [ @ABYSS b ]
@ABYSS LLVMBuildBr: [ @ABYSS b | @ABYSS dest ]
@ABYSS LLVMBuildCondBr: [ @ABYSS b | @ABYSS cond | @ABYSS t | @ABYSS f ]
@ABYSS LLVMBuildPhi: [ @ABYSS b | @ABYSS ty | @C1 name ]
ABYSS  LLVMAddIncoming: [ @ABYSS phi | @@ABYSS vals | @@ABYSS blocks | I32 n ]
@ABYSS LLVMBuildGEP2: [ @ABYSS b | @ABYSS ty | @ABYSS ptr | @@ABYSS idx | I32 n | @C1 name ]
@ABYSS LLVMBuildStructGEP2: [ @ABYSS b | @ABYSS ty | @ABYSS ptr | I32 idx | @C1 name ]

@ABYSS LLVMBuildAdd: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildSub: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildMul: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildSDiv: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildSRem: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildAnd: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildOr: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildXor: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildShl: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildAShr: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildNeg: [ @ABYSS b | @ABYSS v | @C1 name ]
@ABYSS LLVMBuildNot: [ @ABYSS b | @ABYSS v | @C1 name ]
@ABYSS LLVMBuildICmp: [ @ABYSS b | I32 pred | @ABYSS l | @ABYSS r | @C1 name ]

@ABYSS LLVMBuildFAdd: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildFSub: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildFMul: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildFDiv: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildFRem: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildFNeg: [ @ABYSS b | @ABYSS v | @C1 name ]
@ABYSS LLVMBuildFCmp: [ @ABYSS b | I32 pred | @ABYSS l | @ABYSS r | @C1 name ]

@ABYSS LLVMBuildSExt: [ @ABYSS b | @ABYSS v | @ABYSS ty | @C1 name ]
@ABYSS LLVMBuildZExt: [ @ABYSS b | @ABYSS v | @ABYSS ty | @C1 name ]
@ABYSS LLVMBuildTrunc: [ @ABYSS b | @ABYSS v | @ABYSS ty | @C1 name ]
@ABYSS LLVMBuildIntToPtr: [ @ABYSS b | @ABYSS v | @ABYSS ty | @C1 name ]
@ABYSS LLVMBuildPtrToInt: [ @ABYSS b | @ABYSS v | @ABYSS ty | @C1 name ]
@ABYSS LLVMBuildSIToFP: [ @ABYSS b | @ABYSS v | @ABYSS ty | @C1 name ]
@ABYSS LLVMBuildFPToSI: [ @ABYSS b | @ABYSS v | @ABYSS ty | @C1 name ]
@ABYSS LLVMBuildFPCast: [ @ABYSS b | @ABYSS v | @ABYSS ty | @C1 name ]
@ABYSS LLVMBuildUIToFP: [ @ABYSS b | @ABYSS v | @ABYSS ty | @C1 name ]
@ABYSS LLVMBuildFPToUI: [ @ABYSS b | @ABYSS v | @ABYSS ty | @C1 name ]
@ABYSS LLVMBuildFPExt: [ @ABYSS b | @ABYSS v | @ABYSS ty | @C1 name ]
@ABYSS LLVMBuildFPTrunc: [ @ABYSS b | @ABYSS v | @ABYSS ty | @C1 name ]
@ABYSS LLVMBuildIntCast2: [ @ABYSS b | @ABYSS v | @ABYSS ty | I32 is_signed | @C1 name ]

; --- output ---------------------------------------------------------------
I32 LLVMVerifyModule: [ @ABYSS m | I32 action | @@C1 err ]
I32 LLVMPrintModuleToFile: [ @ABYSS m | @C1 path | @@C1 err ]

@ABYSS LLVMBuildUDiv: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildURem: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]
@ABYSS LLVMBuildLShr: [ @ABYSS b | @ABYSS l | @ABYSS r | @C1 name ]

@ABYSS LLVMGetEntryBasicBlock: [ @ABYSS fn ]
@ABYSS LLVMGetFirstInstruction: [ @ABYSS bb ]
ABYSS  LLVMPositionBuilderBefore: [ @ABYSS b | @ABYSS instr ]
