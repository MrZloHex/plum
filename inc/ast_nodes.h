#ifndef __AST_NODES_H__
#define __AST_NODES_H__

struct Node_S;

// BLOCK

typedef struct
{
    struct Node_S *stmt;
    struct Node_S *next;
} N_Block;

// TYPES 

typedef enum
{
   T_ABYSS,
   T_B1,
   T_C1,
   T_C2,
   T_C4,
   T_U8,
   T_U16,
   T_U32,
   T_U64,
   T_I8,
   T_I16,
   T_I32,
   T_I64,
   T_QUANT
} BaseTypes;

typedef struct
{
    unsigned int ptrs;
    BaseTypes type;
} N_Type;

// STATEMENTS

typedef enum
{
    ST_EXPR,
    ST_VAR_DECL,
    ST_RET,
    ST_COND,
    ST_LOOP,
    ST_BREAK,
    ST_QUANT
} StmtType;

typedef struct
{
    StmtType type;
    struct Node_S *stmt;
} N_Statement;

// LOOP

typedef struct
{
    struct Node_S *block;
} N_Loop;


// IF

typedef struct
{
    struct Node_S *ident;
    struct Node_S *block;
} N_If;

typedef struct
{
    struct Node_S *block;
} N_Else;

typedef struct
{
    struct Node_S *if_block;   // N_If
    struct Node_S *else_block; // N_Else
} N_CondStmt;

// DECLARATIONS

typedef struct
{
    struct Node_S *ident;
    struct Node_S *type;
} N_Var_Decl;


// EXPRESSIONS

typedef enum
{
    ET_IDENT,
    ET_NUM_LIT,
    ET_CHR_LIT,
    ET_STR_LIT,
    ET_BOOL_LIT,
    ET_BIN_OP,
    ET_FN_CALL,
    ET_QUANT
} ExprType;

typedef struct N_Expr_S
{
    ExprType type;
    struct Node_S *expr;
} N_Expression;

// RET

typedef struct
{
    struct Node_S *expr;
} N_Ret;

// OPERATIONS

typedef enum
{
    BOT_ASSIGN,
    BOT_PLUS,
    BOT_MINUS,
    BOT_MULT,
    BOT_DIV,
    BOT_MOD,
    BOT_EQUAL,
    BOT_NEQ,
    BOT_LESS,
    BOT_LEQ,
    BOT_GREAT,
    BOT_GEQ,
    BOT_QUANT
} BinOpType;

typedef struct
{
    BinOpType type;
    struct Node_S *left;
    struct Node_S *right;
} N_Bin_Op;

// TERMINALS

typedef char *N_Ident;

typedef int   N_NumLit;
typedef char  N_ChrLit;
typedef char *N_StrLit;
typedef enum
{
    BL_FALSE,
    BL_TRUE
} N_BoolLit;

// FUNCTION DEFINITION

typedef struct
{
    struct Node_S *type;
    struct Node_S *ident;
    struct Node_S *next;
} N_Parametre;

typedef struct
{
    struct Node_S *ident;
    struct Node_S *type;
    struct Node_S *params;
} N_FnDecl;

typedef struct
{
    struct Node_S *decl;
    struct Node_S *block;
} N_FnDef;

typedef struct
{
    struct Node_S *arg; // EXPR
    struct Node_S *next;
} N_Arguments;

typedef struct
{
    struct Node_S *ident;
    struct Node_S *args;
} N_FnCall;

// PROGRAMME

typedef enum
{
    PST_FN_DECL,
    PST_FN_DEF,
    PST_QUANT
} PrgStmtType;

typedef struct
{
    PrgStmtType type;
    struct Node_S *prg_stmt;
} N_PrgStmt;

typedef struct
{
    struct Node_S *stmt;
    struct Node_S *next;
} N_Programme;

// BASE

typedef enum
{
    NT_EXPR,
    NT_IDENT,

    NT_NUM_LIT,
    NT_CHR_LIT,
    NT_STR_LIT,
    NT_BOOL_LIT,

    NT_BIN_OP,
    NT_TYPE,
    NT_VAR_DECL,

    NT_LOOP,

    NT_COND_STMT,
    NT_COND_IF,
    NT_COND_ELSE,


    NT_FN_DEF,
    NT_FN_DECL,
    NT_PARAMETRE,
    
    NT_FN_CALL,
    NT_ARGUMENTS,
    
    NT_BLOCK,
    NT_RET,
    NT_STATEMENT,

    NT_PRG_STMT,
    NT_PROGRAMME,
    
    NT_QUANT
} NodeType;

extern const char *node_types_str[NT_QUANT];

typedef struct Node_S
{
    NodeType type;
    union
    {
        N_Expression expr;
        N_Ident      ident;

        N_NumLit     num_lit;
        N_ChrLit     chr_lit;
        N_StrLit     str_lit;
        N_BoolLit    bool_lit;
        
        N_Bin_Op     bin_op;
        N_Type       type;
        N_Var_Decl   var_decl;

        N_Loop       loop;
        
        N_CondStmt   cond_stmt;
        N_If         cond_if;
        N_Else       cond_else;
        
        N_FnDef      fn_def;
        N_FnDecl     fn_decl;
        N_Parametre  parametre;
        
        N_FnCall     fn_call;
        N_Arguments  arguments;
        
        N_Block      block;
        N_Ret        ret;
        N_Statement  stmt;

        N_PrgStmt    prg_stmt;
        N_Programme  programme;
    } as;
} Node;



#include <stddef.h>

Node *
node_make_programme(Node *fndef);

Node *
node_make_prg_stmt(PrgStmtType type, Node *stmt);

Node *
node_make_fndef(Node *decl, Node *block);

Node *
node_make_fndecl(Node *type, Node *id, Node *params);

Node *
node_make_parametre(Node *type, Node *id);

Node *
node_make_ident(const N_Ident value);

Node *
node_make_num_lit(const char *value);

Node *
node_make_chr_lit(const char *value);

Node *
node_make_str_lit(const char *value);

Node *
node_make_bool_lit(N_BoolLit lit);

Node *
node_make_var_decl(Node *type, Node *id);

Node *
node_make_type(const char *type);

Node *
node_make_type_ptr(Node *type);

Node *
node_make_bin_op(BinOpType op, Node *left, Node *right);

Node *
node_make_ret(Node *expr);

Node *
node_make_block(Node *stmt);

Node *
node_make_stmt(StmtType type, Node *stmt);

Node *
node_make_expr(ExprType type, Node *expr);

Node *
node_make_fncall(Node *id, Node *args);

Node *
node_make_argument(Node *expr);

Node *
node_make_cond(Node *if_part, Node *else_part);

Node *
node_make_if(Node *expr, Node *block);

Node *
node_make_else(Node *block);

Node *
node_make_loop(Node *block);


void
node_dump_programme(Node *prog, size_t offset);

void
node_dump_prg_stmt(Node *stmt, size_t offset);

void
node_dump_fndef(Node *fndef, size_t offset);

void
node_dump_fndecl(Node *fndecl, size_t offset);

void
node_dump_ident(Node *id, size_t offset);

void
node_dump_num_lit(Node *lit, size_t offset);

void
node_dump_chr_lit(Node *lit, size_t offset);

void
node_dump_str_lit(Node *lit, size_t offset);

void
node_dump_bool_lit(Node *lit, size_t offset);

void
node_dump_var_decl(Node *var, size_t offset);

void
node_dump_type(Node *type, size_t offset);

void
node_dump_parametre(Node *list, size_t offset);

void
node_dump_ret(Node *ret, size_t offset);

void
node_dump_block(Node *stmt, size_t offset);

void
node_dump_stmt(Node *stmt, size_t offset);

void
node_dump_expr(Node *expr, size_t offset);

void
node_dump_bin_op(Node *op, size_t offset);

void
node_dump_fncall(Node *call, size_t offset);

void
node_dump_argument(Node *args, size_t offset);

void
node_dump_cond(Node *cond, size_t offset);

void
node_dump_if(Node *if_stmt, size_t offset);

void
node_dump_else(Node *else_stmt, size_t offset);

void
node_dump_loop(Node *loop, size_t offset);

#endif /* __AST_NODES_H__ */
