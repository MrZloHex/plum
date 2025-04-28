#include "ast_nodes.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

const char *node_types_str[NT_QUANT] =
{
    "NT_EXPR",
    "NT_IDENT",

    "NT_NUM_LIT",
    "NT_CHR_LIT",
    "NT_STR_LIT",
    "NT_BOOL_LIT",

    "NT_BIN_OP",
    "NT_UNY_OP",
    "NT_TYPE",
    "NT_VAR_DECL",

    "NT_LOOP",
    "NT_COND_STMT",
    "NT_COND_IF",
    "NT_COND_ELSE",

    "NT_FN_DEF",
    "NT_FN_DECL",
    "NT_PARAMETRE",

    "NT_FN_CALL",
    "NT_ARGUMENTS",
    
    "NT_BLOCK",
    "NT_RET",
    "NT_STATEMENT",

    "NT_TYPE_DEF",
    
    "NT_PRG_STMT",
    "NT_PROGRAMME"
};


// TODO: MAKE IT ARENA
#define NODE_ALLOC(n)                          \
    Node *n = (Node *)calloc(1, sizeof(Node)); \
    if (!n)                                    \
    { exit(69); }

#define PRINT_OFFSET(off)               \
    for (size_t i = 0; i < off; ++i)    \
    { putc('\t', stdout); }


Node *
node_make_programme(Node *stmt)
{
    NODE_ALLOC(p);

    p->type = NT_PROGRAMME;
    p->as.programme.stmt = stmt;

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
        node_dump_prg_stmt(pr->as.programme.stmt, offset+1);
        pr = pr->as.programme.next;
    }
}

Node *
node_make_prg_stmt(PrgStmtType type, Node *stmt)
{
    NODE_ALLOC(s);

    s->type = NT_PRG_STMT;
    s->as.prg_stmt.type = type;
    s->as.prg_stmt.prg_stmt = stmt;

    return s;
}

void
node_dump_prg_stmt(Node *stmt, size_t offset)
{
    static char *ps_types[PST_QUANT] = { "FN DECL", "FN DEF", "TYPE DEF" };
    PRINT_OFFSET(offset);
    printf("PRG STMT %s\n", ps_types[stmt->as.prg_stmt.type]);
    if (stmt->as.prg_stmt.type == PST_FN_DEF)
    { node_dump_fndef(stmt->as.prg_stmt.prg_stmt, offset+1); }
    else if (stmt->as.prg_stmt.type == PST_FN_DECL)
    { node_dump_fndecl(stmt->as.prg_stmt.prg_stmt, offset+1); }
    else if (stmt->as.prg_stmt.type == PST_TYPE_DEF)
    { node_dump_type_def(stmt->as.prg_stmt.prg_stmt, offset+1); }
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

static int
chr_lit_to_int(const char *lit)
{
    if (!lit)
    { return 0; }
    if (lit[1] == '\\')
    {
        switch(lit[2]) {
            case 'n': return '\n';
            case 't': return '\t';
            case 'r': return '\r';
            case '\\': return '\\';
            case '\'': return '\'';
            case '\"': return '\"';
            default: return lit[2];
        }
    }
    else
    { return lit[1]; }
}

Node *
node_make_chr_lit(const char *value)
{
    NODE_ALLOC(n);
    
    n->type = NT_CHR_LIT;
    n->as.chr_lit = chr_lit_to_int(value);

    return n;
}

void
node_dump_chr_lit(Node *lit, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("CHR LIT %c\n", lit->as.chr_lit);
}

Node *
node_make_str_lit(const char *value)
{
    NODE_ALLOC(n);
    
    n->type = NT_STR_LIT;
    n->as.str_lit = strdup(value);

    return n;
}

void
node_dump_str_lit(Node *lit, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("STR LIT %s\n", lit->as.str_lit);
}

Node *
node_make_bool_lit(N_BoolLit lit)
{
    NODE_ALLOC(n);

    n->type = NT_BOOL_LIT;
    n->as.bool_lit = lit;

    return n;
}

void
node_dump_bool_lit(Node *lit, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("BOOL LIT %s\n", lit->as.bool_lit ? "TRUE" : "FALSE");
}

Node *
node_make_var_decl(Node *type, Node *id, Node *value)
{
    NODE_ALLOC(n);
    
    n->type = NT_VAR_DECL;
    n->as.var_decl.type = type;
    n->as.var_decl.ident = id;
    n->as.var_decl.value = value;

    return n;
}

void
node_dump_var_decl(Node *var, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("VAR DECL\n");
    node_dump_type(var->as.var_decl.type, offset+1);
    node_dump_ident(var->as.var_decl.ident, offset+1);
    if (var->as.var_decl.value)
    { node_dump_expr(var->as.var_decl.value, offset+1); }
}

Node *
node_make_type(const char *type)
{
    NODE_ALLOC(n);
    
    n->type = NT_TYPE;
    n->as.type.ptrs = 0;
    if (strcmp(type, "ABYSS") == 0)
    { n->as.type.type = T_ABYSS; }
    else if (strcmp(type, "B1") == 0)
    { n->as.type.type = T_B1; }
    else if (strcmp(type, "C1") == 0)
    { n->as.type.type = T_C1; }
    else if (strcmp(type, "C2") == 0)
    { n->as.type.type = T_C2; }
    else if (strcmp(type, "C4") == 0)
    { n->as.type.type = T_C4; }
    else if (strcmp(type, "U8") == 0)
    { n->as.type.type = T_U8; }
    else if (strcmp(type, "U16") == 0)
    { n->as.type.type = T_U16; }
    else if (strcmp(type, "U32") == 0)
    { n->as.type.type = T_U32; }
    else if (strcmp(type, "U64") == 0)
    { n->as.type.type = T_U64; }
    else if (strcmp(type, "I8") == 0)
    { n->as.type.type = T_I8; }
    else if (strcmp(type, "I16") == 0)
    { n->as.type.type = T_I16; }
    else if (strcmp(type, "I32") == 0)
    { n->as.type.type = T_I32; }
    else if (strcmp(type, "I64") == 0)
    { n->as.type.type = T_I64; }
    else
    {
        fprintf(stderr, "UNKNOWN TYPE `%s`\n", type);
        exit(1);
    }

    return n;
}

Node *
node_make_type_ptr(Node *type)
{
    type->as.type.ptrs += 1;
    return type;
}

void
node_dump_type(Node *type, size_t offset)
{
    static char *types[T_QUANT] =
    {
        "ABYSS",
        "B1",
        "C1", "C2", "C4",
        "U8", "U16", "U32", "U64",
        "I8", "I16", "I32", "I64"
    };
    PRINT_OFFSET(offset);
    printf("TYPE ");
    for (unsigned int i = 0; i < type->as.type.ptrs; ++i)
    { printf("POINTER TO "); }
    printf("%s\n", types[type->as.type.type]);
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
    static char *bo_type[BOT_QUANT] =
    {
        "ASSIGN", "PLUS", "MINUS", "MULT", "DIV", "MOD",
        "EQUAL", "NEQ", "LESS", "LEQ", "GREAT", "GEQ"
    };
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
node_make_uny_op(UnyOpType op, Node *operand)
{
    NODE_ALLOC(n);

    n->type = NT_UNY_OP;
    n->as.uny_op.type = op;
    n->as.uny_op.operand = operand;

    return n;
}

void
node_dump_uny_op(Node *uny, size_t offset)
{
    static char *uo_type[UOT_QUANT] = { "DEREF" };
    PRINT_OFFSET(offset);
    printf("UNY OP %s\n", uo_type[uny->as.uny_op.type]);
    node_dump_expr(uny->as.uny_op.operand, offset+1);
}

Node *
node_make_parametre(Node *type, Node *id)
{
    NODE_ALLOC(list);   
    
    list->type = NT_PARAMETRE;
    list->as.parametre.ident = id;
    list->as.parametre.type  = type;
    list->as.parametre.is_vaarg = false;

    return list;
}

Node *
node_make_parametre_vaarg()
{
    NODE_ALLOC(list);   
    
    list->type = NT_PARAMETRE;
    list->as.parametre.is_vaarg = true;

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
        if (list->as.parametre.is_vaarg)
        {
            PRINT_OFFSET(offset+1);
            printf("VA ARG\n");
        }
        else
        {
            node_dump_type(list->as.parametre.type, offset+1);
            node_dump_ident(list->as.parametre.ident, offset+1);
        }
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
    if (ret->as.ret.expr)
    { node_dump_expr(ret->as.ret.expr, offset+1); }
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
    static char *st_types[ST_QUANT] = { "EXPR", "VAR DECL", "RET", "COND", "LOOP", "BREAK" };
    PRINT_OFFSET(offset);
    printf("STMT %s\n", st_types[stmt->as.stmt.type]);
    if (stmt->as.stmt.type == ST_EXPR)
    { node_dump_expr(stmt->as.stmt.stmt, offset+1); }
    else if (stmt->as.stmt.type == ST_VAR_DECL)
    { node_dump_var_decl(stmt->as.stmt.stmt, offset+1); }
    else if (stmt->as.stmt.type == ST_RET)
    { node_dump_ret(stmt->as.stmt.stmt, offset+1); }
    else if (stmt->as.stmt.type == ST_COND)
    { node_dump_cond(stmt->as.stmt.stmt, offset+1); }
    else if (stmt->as.stmt.type == ST_LOOP)
    { node_dump_loop(stmt->as.stmt.stmt, offset+1); }
    else if (stmt->as.stmt.type == ST_BREAK)
    { PRINT_OFFSET(offset+1); printf("BREAK\n"); }
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
    static char *et_types[ET_QUANT] =
    { "IDENT", "NUM LIT", "CHR LIT", "STR LIT", "BOOL LIT", "BIN OP", "UNY OP", "FN CALL" };
    PRINT_OFFSET(offset);
    printf("EXPR %s\n", et_types[expr->as.expr.type]);
    if (expr->as.expr.type == ET_IDENT)
    { node_dump_ident(expr->as.expr.expr, offset+1); }
    else if (expr->as.expr.type == ET_NUM_LIT)
    { node_dump_num_lit(expr->as.expr.expr, offset+1); }
    else if (expr->as.expr.type == ET_CHR_LIT)
    { node_dump_chr_lit(expr->as.expr.expr, offset+1); }
    else if (expr->as.expr.type == ET_STR_LIT)
    { node_dump_str_lit(expr->as.expr.expr, offset+1); }
    else if (expr->as.expr.type == ET_BOOL_LIT)
    { node_dump_bool_lit(expr->as.expr.expr, offset+1); }
    else if (expr->as.expr.type == ET_BIN_OP)
    { node_dump_bin_op(expr->as.expr.expr, offset+1); }
    else if (expr->as.expr.type == ET_UNY_OP)
    { node_dump_uny_op(expr->as.expr.expr, offset+1); }
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



Node *
node_make_cond(Node *if_part, Node *else_part)
{
    NODE_ALLOC(a);

    a->type = NT_COND_STMT;
    a->as.cond_stmt.if_block = if_part;
    a->as.cond_stmt.else_block = else_part;

    return a;
}

Node *
node_make_if(Node *expr, Node *block)
{
    NODE_ALLOC(a);

    a->type = NT_COND_IF;
    a->as.cond_if.expr = expr;
    a->as.cond_if.block = block;

    return a;
}

Node *
node_make_else(Node *block)
{
    NODE_ALLOC(a);

    a->type = NT_COND_ELSE;
    a->as.cond_else.block = block;

    return a;
}

void
node_dump_cond(Node *cond, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("CONDITION:\n");
    node_dump_if(cond->as.cond_stmt.if_block, offset);
    if (cond->as.cond_stmt.else_block)
    { node_dump_else(cond->as.cond_stmt.else_block, offset); }
}

void
node_dump_if(Node *if_stmt, size_t offset)
{
    PRINT_OFFSET(offset);
    printf(" - IF\n");
    node_dump_expr(if_stmt->as.cond_if.expr, offset+1);
    node_dump_block(if_stmt->as.cond_if.block, offset+1);
}

void
node_dump_else(Node *else_stmt, size_t offset)
{
    PRINT_OFFSET(offset);
    printf(" - ELSE\n");
    node_dump_block(else_stmt->as.cond_else.block, offset+1);
}

Node *
node_make_loop(Node *block)
{
    NODE_ALLOC(n);

    n->type = NT_LOOP;
    n->as.loop.block = block;
    
    return n;
}

void
node_dump_loop(Node *loop, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("LOOP\n");
    node_dump_block(loop->as.loop.block, offset+1);
}

Node *
node_make_type_def(Node *ident, Node *block)
{
    NODE_ALLOC(n);

    n->type = NT_TYPE_DEF;
    n->as.type_def.ident = ident;
    n->as.type_def.block = block;

    return n;
}

void
node_dump_type_def(Node *type, size_t offset)
{
    PRINT_OFFSET(offset);
    printf("TYPEDEF %s\n", type->as.type_def.ident->as.ident);
    node_dump_block(type->as.type_def.block, offset+1);
}

