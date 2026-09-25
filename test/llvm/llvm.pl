; Proves PLUM can drive the LLVM-C API through opaque @ABYSS handles:
; builds `I32 add(I32,I32) { return a+b; }` and writes it out.

!USES <../../extern/llvm.pl>
!USES <../../extern/stdio.pl>
!USES <../../extern/stdlib.pl>

I32 main: []
 | @ABYSS ctx = (LLVMContextCreate)[]
 | @ABYSS mod = (LLVMModuleCreateWithNameInContext)[ "plum_built" | ctx ]
 | @ABYSS bld = (LLVMCreateBuilderInContext)[ ctx ]
 |
 | @ABYSS i32 = (LLVMInt32TypeInContext)[ ctx ]
 |
 | ; LLVMFunctionType wants an array of types
 | @@ABYSS ptypes = (malloc)[ 2 * 8 ] AS @@ABYSS
 | ?(ptypes + 0) = i32
 | ?(ptypes + 1) = i32
 | @ABYSS fnty = (LLVMFunctionType)[ i32 | ptypes | 2 | 0 ]
 |
 | @ABYSS fn = (LLVMAddFunction)[ mod | "add" | fnty ]
 | @ABYSS bb = (LLVMAppendBasicBlockInContext)[ ctx | fn | "entry" ]
 | (LLVMPositionBuilderAtEnd)[ bld | bb ]
 |
 | @ABYSS a = (LLVMGetParam)[ fn | 0 ]
 | @ABYSS b = (LLVMGetParam)[ fn | 1 ]
 | @ABYSS sum = (LLVMBuildAdd)[ bld | a | b | "sum" ]
 | (LLVMBuildRet)[ bld | sum ]
 |
 | ; and a main that calls it
 | @ABYSS mainty = (LLVMFunctionType)[ i32 | 0 AS @@ABYSS | 0 | 0 ]
 | @ABYSS mfn = (LLVMAddFunction)[ mod | "main" | mainty ]
 | @ABYSS mbb = (LLVMAppendBasicBlockInContext)[ ctx | mfn | "entry" ]
 | (LLVMPositionBuilderAtEnd)[ bld | mbb ]
 |
 | @@ABYSS args = (malloc)[ 2 * 8 ] AS @@ABYSS
 | ?(args + 0) = (LLVMConstInt)[ i32 | 40 | 1 ]
 | ?(args + 1) = (LLVMConstInt)[ i32 | 2 | 1 ]
 | @ABYSS call = (LLVMBuildCall2)[ bld | fnty | fn | args | 2 | "r" ]
 | (LLVMBuildRet)[ bld | call ]
 |
 | @C1 err = 0
 | I32 bad = (LLVMVerifyModule)[ mod | LLVMReturnStatusAction | @err AS @@C1 ]
 | (printf)[ "verify bad=%d\n" | bad ]
 |
 | (LLVMPrintModuleToFile)[ mod | "built.ll" | @err AS @@C1 ]
 | (puts)[ "wrote built.ll" ]
 |
 | (LLVMDisposeBuilder)[ bld ]
 | (LLVMDisposeModule)[ mod ]
 | (LLVMContextDispose)[ ctx ]
 | RET [ 0 ]
 \_
