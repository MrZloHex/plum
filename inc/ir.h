#ifndef __GEN_H__
#define __GEN_H__

#include "ast.h"
#include "meta_ir.h"
#include "dynstr.h"
#include "dynarray.h"

typedef struct
{
    Node *type;
    int reg;
} ArgumentREG;
DECLARE_DYNARRAY(argreg, ArgRegs, ArgumentREG);

typedef struct
{
    Meta     *meta;
    AST      *ast;
    DynString glbl;
    DynString text;
    DynString decl;
    
    MetaScope *curr;
    ArgRegs    args;

    DynString ir;
} IR;

void
ir_init(IR *ir, Meta *meta, AST *ast);

void
ir_generate(IR *ir);

#endif /* GEN_H */

