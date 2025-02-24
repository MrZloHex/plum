#include "ast.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


// TODO: MAKE IT ARENA
#define NODE_ALLOC(n)                          \
    Node *n = (Node *)calloc(1, sizeof(Node)); \
    if (!n)                                    \
    { exit(69); }

#define PRINT_OFFSET(off)               \
    for (size_t i = 0; i < off; ++i)    \
    { putc('\t', stdout); }


Node *
node_make_programme(Node *fndef)
{
    NODE_ALLOC(p);

    p->type = NT_PROGRAMME;
    p->as.programme.fndef = fndef;

    return p;
}

void
node_dump_programme(Node *pr, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("PROGRAMME\n");
    size_t c = 0;
    while (pr)
    {
        PRINT_OFFSET(offset);
        printf(" - %zu:\n", c++);
        node_dump_fndef(pr->as.programme.fndef, offset+1);
        pr = pr->as.programme.next;
    }
}


Node *
node_make_fndef(Node *decl, Node *block)
{
    NODE_ALLOC(fn);

    fn->type = NT_FN_DEF;
    fn->as.fn_def.decl = decl;
    fn->as.fn_def.block = block;

    return fn;
}

void
node_dump_fndef(Node *fndef, size_t offset)
{
    PRINT_OFFSET(offset) printf("FNDEF\n");
    node_dump_fndecl(fndef->as.fn_def.decl, offset+1);
    node_dump_block(fndef->as.fn_def.block, offset+1);
}

Node *
node_make_fndecl(Node *type, Node *id, Node *params)
{
    NODE_ALLOC(fn);

    fn->type = NT_FN_DECL;
    fn->as.fn_decl.type = type;
    fn->as.fn_decl.ident = id;
    fn->as.fn_decl.params = params;

    return fn;
}

void
node_dump_fndecl(Node *fndecl, size_t offset)
{
    PRINT_OFFSET(offset) printf("FNDECL\n");
    node_dump_type(fndecl->as.fn_decl.type, offset+1);
    node_dump_ident(fndecl->as.fn_decl.ident, offset+1);
    node_dump_parametre(fndecl->as.fn_decl.params, offset+1);
}


Node *
node_make_ident(const N_Ident value)
{
    NODE_ALLOC(n);
    
    n->type = NT_IDENT;
    n->as.ident = strdup(value);

    return n;
}

void
node_dump_ident(Node *id, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("ID `%s`\n", id->as.ident);
}

Node *
node_make_num_lit(const char *value)
{
    NODE_ALLOC(n);
    
    n->type = NT_NUM_LIT;
    n->as.num_lit = atoi(value);

    return n;
}

void
node_dump_num_lit(Node *lit, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("NUM LIT %d\n", lit->as.num_lit);
}

Node *
node_make_var_decl(Node *type, Node *id)
{
    NODE_ALLOC(n);
    
    n->type = NT_VAR_DECL;
    n->as.var_decl.type = type;
    n->as.var_decl.ident = id;

    return n;
}

void
node_dump_var_decl(Node *var, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("VAR DECL\n");
    node_dump_type(var->as.var_decl.type, offset+1);
    node_dump_ident(var->as.var_decl.ident, offset+1);
}

Node *
node_make_type(const char *type)
{
    NODE_ALLOC(n);
    
    n->type = NT_TYPE;
    if (strcmp(type, "U32") == 0)
    {
        n->as.type = T_U32;
    }
    else if (strcmp(type, "U8") == 0)
    {
        n->as.type = T_U8;
    }
    else if (strcmp(type, "I32") == 0)
    {
        n->as.type = T_I32;
    }
    else
    {
        fprintf(stderr, "UNKNOWN TYPE `%s`\n", type);
        exit(1);
    }

    return n;
}

void
node_dump_type(Node *type, size_t offset)
{
    static char *types[T_QUANT] =
    {
        "U8", "U16", "U32", "U64",
        "I8", "I16", "I32", "I64"
    };
    PRINT_OFFSET(offset);
    printf("TYPE %s\n", types[type->as.type]);
}

Node *
node_make_bin_op(BinOpType op, Node *left, Node *right)
{
    Node *n = malloc(sizeof(Node));
    
    n->type = NT_BIN_OP;
    n->as.bin_op.type = op;
    n->as.bin_op.left = left;
    n->as.bin_op.right = right;

    return n;
}

void
node_dump_bin_op(Node *op, size_t offset)
{
    static char *bo_type[BOT_QUANT] = { "ASSIGN", "PLUS" };
    PRINT_OFFSET(offset);
    printf("BIN OP %s\n", bo_type[op->as.bin_op.type]);
    PRINT_OFFSET(offset);
    printf(" left:\n");
    node_dump_expr(op->as.bin_op.left, offset+1);
    PRINT_OFFSET(offset);
    printf(" right:\n");
    node_dump_expr(op->as.bin_op.right, offset+1);
}

Node *
node_make_parametre(Node *type, Node *id)
{
    NODE_ALLOC(list);   
    
    list->type = NT_PARAMETRE;
    list->as.parametre.ident = id;
    list->as.parametre.type  = type;

    return list;
}

void
node_dump_parametre(Node *list, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("PARAMS\n");
    size_t c = 0;
    while (list)
    {
        PRINT_OFFSET(offset);
        printf(" - %zu:\n", c++);
        node_dump_type(list->as.parametre.type, offset+1);
        node_dump_ident(list->as.parametre.ident, offset+1);
        list = list->as.parametre.next;
    }
}

Node *
node_make_ret(Node *expr)
{
    NODE_ALLOC(ret);

    ret->type = NT_RET;
    ret->as.ret.expr = expr;

    return ret;
}

void
node_dump_ret(Node *ret, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("RETURN\n");
    node_dump_expr(ret->as.ret.expr, offset+1);
}


Node *
node_make_block(Node *stmt)
{
    NODE_ALLOC(bl);

    bl->type = NT_BLOCK;
    bl->as.block.stmt = stmt;

    return bl;
}

void
node_dump_block(Node *block, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("BLOCK\n");
    size_t c = 0;
    while (block)
    {
        PRINT_OFFSET(offset);
        printf(" - %zu:\n", c++);
        node_dump_stmt(block->as.block.stmt, offset+1);
        block = block->as.block.next;
    }
}

Node *
node_make_stmt(StmtType type, Node *stmt)
{
    NODE_ALLOC(s);

    s->type = NT_STATEMENT;
    s->as.stmt.type = type;
    s->as.stmt.stmt = stmt;

    return s;
}

void
node_dump_stmt(Node *stmt, size_t offset)
{
    static char *st_types[ST_QUANT] = { "EXPR", "VAR DECL", "RET" };
    PRINT_OFFSET(offset);
    printf("STMT %s\n", st_types[stmt->as.stmt.type]);
    if (stmt->as.stmt.type == ST_EXPR)
    { node_dump_expr(stmt->as.stmt.stmt, offset+1); }
    else if (stmt->as.stmt.type == ST_VAR_DECL)
    { node_dump_var_decl(stmt->as.stmt.stmt, offset+1); }
    else if (stmt->as.stmt.type == ST_RET)
    { node_dump_ret(stmt->as.stmt.stmt, offset+1); }
}

Node *
node_make_expr(ExprType type, Node *expr)
{
    NODE_ALLOC(e);

    e->type = NT_EXPR;
    e->as.expr.type = type;
    e->as.expr.expr = expr;

    return e;
}

void
node_dump_expr(Node *expr, size_t offset)
{
    static char *et_types[ET_QUANT] = { "IDENT", "NUM LIT", "BIN OP", "FN CALL" };
    PRINT_OFFSET(offset);
    printf("EXPR %s\n", et_types[expr->as.expr.type]);
    if (expr->as.expr.type == ET_IDENT)
    { node_dump_ident(expr->as.expr.expr, offset+1); }
    else if (expr->as.expr.type == ET_NUM_LIT)
    { node_dump_num_lit(expr->as.expr.expr, offset+1); }
    else if (expr->as.expr.type == ET_BIN_OP)
    { node_dump_bin_op(expr->as.expr.expr, offset+1); }
    else if (expr->as.expr.type == ET_FN_CALL)
    { node_dump_fncall(expr->as.expr.expr, offset+1); }
}

Node *
node_make_fncall(Node *id, Node *args)
{
    NODE_ALLOC(c);

    c->type = NT_FN_CALL;
    c->as.fn_call.ident = id;
    c->as.fn_call.args  = args;

    return c;
}

void
node_dump_fncall(Node *call, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("FN CALL\n");
    node_dump_ident(call->as.fn_call.ident, offset+1);
    node_dump_argument(call->as.fn_call.args, offset+1);
}

Node *
node_make_argument(Node *expr)
{
    NODE_ALLOC(a);

    a->type = NT_ARGUMENTS;
    a->as.arguments.arg = expr;

    return a;
}

void
node_dump_argument(Node *args, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("ARGUMENTS\n");
    size_t c = 0;
    while (args)
    {
        PRINT_OFFSET(offset);
        printf(" - %zu:\n", c++);
        node_dump_expr(args->as.arguments.arg, offset+1);
        args = args->as.arguments.next;
    }
}
