#include "buildit.h"
#include <stdlib.h>
#include <string.h>

#include <llvm-c/Core.h>
#include <llvm-c/IRReader.h>
#include <llvm-c/Target.h>
#include <llvm-c/TargetMachine.h>
#include <llvm-c/Support.h>

int
buildit
(
    const char *ir_str,
    FILE *obj_file,
    char **error_msg_ptr
)
{
    if (!ir_str || !obj_file) {
        if (error_msg_ptr)
            *error_msg_ptr = LLVMCreateMessage("Invalid NULL argument");
        return 1;
    }

    LLVMContextRef      ctx    = LLVMContextCreate();
    LLVMMemoryBufferRef mb     = NULL;
    char               *err    = NULL;

    /* 1) Создаём MemoryBuffer из строки */
    mb = LLVMCreateMemoryBufferWithMemoryRangeCopy(
             ir_str,
             strlen(ir_str),
             "in-memory");
    if (!mb) {
        if (error_msg_ptr)
            *error_msg_ptr = LLVMCreateMessage("Failed to create MemoryBuffer");
        LLVMContextDispose(ctx);
        return 2;
    }

    /* 2) Парсим IR */
    LLVMModuleRef module = NULL;
    if (LLVMParseIRInContext(ctx, mb, &module, &err)) {
        if (error_msg_ptr)
            *error_msg_ptr = err;  // LLVM выделяет сообщение
        LLVMDisposeMemoryBuffer(mb);
        LLVMContextDispose(ctx);
        return 3;
    }

    /* 3) Инициализируем таргет для генерации кода */
    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();

    char         *triple;
    LLVMTargetRef target;
    triple = LLVMGetDefaultTargetTriple();

    if (LLVMGetTargetFromTriple(triple, &target, &err)) {
        if (error_msg_ptr)
            *error_msg_ptr = err;
        LLVMDisposeModule(module);
        LLVMContextDispose(ctx);
        return 4;
    }

    LLVMTargetMachineRef tm =
        LLVMCreateTargetMachine(target,
                                triple,
                                /*cpu*/     "",
                                /*features*/"",
                                LLVMCodeGenLevelDefault,
                                LLVMRelocDefault,
                                LLVMCodeModelDefault);

    /* 4) Устанавливаем DataLayout */
    LLVMTargetDataRef td = LLVMCreateTargetDataLayout(tm);
    LLVMSetModuleDataLayout(module, td);
    LLVMSetTarget(module, triple);

    /* 5) Эмитим объектный файл */
    LLVMMemoryBufferRef obj_buf = NULL;
    if
    (
        LLVMTargetMachineEmitToMemoryBuffer
        (
            tm, module,
            LLVMObjectFile,
            &err, &obj_buf
        )
    )
    {
        if (error_msg_ptr)
        { *error_msg_ptr = err; }
        LLVMDisposeModule(module);
        LLVMContextDispose(ctx);
        return 1;
    }

    const char *start = LLVMGetBufferStart(obj_buf);
    size_t      size  = LLVMGetBufferSize(obj_buf);

    /* Записываем в FILE* */
    if (fwrite(start, 1, size, obj_file) != size)
    {
        if (error_msg_ptr)
        { *error_msg_ptr = LLVMCreateMessage("Failed to write object data"); }
        LLVMDisposeMemoryBuffer(obj_buf);
        LLVMDisposeModule(module);
        LLVMContextDispose(ctx);
        return 1;
    }

    LLVMDisposeMemoryBuffer(obj_buf);

    /* 6) Очистка */
    LLVMDisposeModule(module);
    LLVMContextDispose(ctx);
    return 0;
}

