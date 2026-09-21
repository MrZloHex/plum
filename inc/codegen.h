#ifndef CODEGEN_H
#define CODEGEN_H

#include "ast.h"
#include "meta.h"
#include <llvm-c/Core.h>
#include <stdlib.h>
#include <string.h>

// хеш и сравнение для dynmap
size_t str_hash(const char *s);
#define str_eq(a,b) (strcmp((a),(b))==0)
// карта имя → LLVMValueRef для локальных переменных и параметров
DECLARE_DYNMAP(lmap, char *, LLVMValueRef, str_hash, str_eq);

typedef struct {
    LLVMContextRef ctx;
    LLVMModuleRef  mod;
    LLVMBuilderRef builder;
    Meta         *meta;       // заполненные метаданные
    lmap_map           locals;     // локалы: alloca и параметры
} CodegenContext;

// инициализация контекста (создание LLVMContext/Module/Builder)
void codegen_init(
    CodegenContext *c,
    const char     *module_name,
    Meta           *meta
);

// обход AST и генерация IR
void codegen_generate(
    ASTNode        *root,
    CodegenContext *c
);

// вывод IR в файл и освобождение всего
void codegen_deinit(
    CodegenContext *c,
    const char     *filename
);

#endif /* CODEGEN_H */
