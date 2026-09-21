#ifndef __CODEGEN_H__
#define __CODEGEN_H__

#include <llvm-c/Core.h>

#include "ast.h"
#include "meta.h"

/* Local scoping and the user-type table are private to codegen.c.
   meta_pass destroys its scopes on the way out, so nothing it collected
   about locals survives; codegen keeps its own. */
typedef struct CGScope CGScope;
typedef struct CGTypes CGTypes;
typedef struct CGStrs  CGStrs;

typedef struct
{
    LLVMContextRef ctx;
    LLVMModuleRef  mod;
    LLVMBuilderRef builder;
    Meta          *meta;

    CGScope       *scope;   /* innermost local scope  */
    CGTypes       *types;   /* STRUCT / UNION / ENUM  */
    CGStrs        *strs;    /* interned string globals */

    LLVMValueRef   fn;       /* function being emitted */
    LLVMTypeRef    ret_type;

    LLVMBasicBlockRef loop_break;
    LLVMBasicBlockRef loop_continue;
} CodegenContext;

void
codegen_init(CodegenContext *c, const char *module_name, Meta *meta);

void
codegen_generate(ASTNode *root, CodegenContext *c);

void
codegen_deinit(CodegenContext *c, const char *filename);

#endif /* __CODEGEN_H__ */
