#ifndef __GEN_H__
#define __GEN_H__

#include "ast.h"
#include "meta_ir.h"
#include "dynstr.h"

typedef struct
{
    Meta     *meta;
    AST      *ast;
    DynString glbl;
    DynString text;
    DynString decl;
    

    MetaScope *curr;
} IR;

void
ir_init(IR *ir, Meta *meta, AST *ast);

void
ir_generate(IR *ir);

#endif /* GEN_H */

