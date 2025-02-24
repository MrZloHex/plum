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
   T_U8,
   T_U16,
   T_U32,
   T_U64,
   T_I8,
   T_I16,
   T_I32,
   T_I64,
   T_QUANT
} N_Type;

// STATEMENTS

typedef enum
{
    ST_EXPR,
    ST_VAR_DECL,
    ST_RET,
    ST_QUANT
} StmtType;

typedef struct
{
    StmtType type;
    struct Node_S *stmt;
} N_Statement;


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

typedef int N_NumLit;

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
    struct Node_S *arg;
    struct Node_S *next;
} N_Arguments;

typedef struct
{
    struct Node_S *ident;
    struct Node_S *args;
} N_FnCall;

// PROGRAMME

typedef struct
{
    struct Node_S *fndef;
    struct Node_S *next;
} N_Programme;

// BASE

typedef enum
{
    NT_EXPR,
    NT_IDENT,
    NT_NUM_LIT,
    NT_BIN_OP,
    NT_TYPE,
    NT_VAR_DECL,
    NT_RET,
    NT_FN_DEF,
    NT_FN_DECL,
    NT_PARAMETRE,
    NT_FN_CALL,
    NT_ARGUMENTS,
    NT_BLOCK,
    NT_STATEMENT,
    NT_PROGRAMME
} NodeType;

typedef struct Node_S
{
    NodeType type;
    union
    {
        N_Expression expr;
        N_Ident      ident;
        N_NumLit     num_lit;
        N_Bin_Op     bin_op;
        N_Type       type;
        N_Var_Decl   var_decl;
        N_FnDef      fn_def;
        N_FnDecl     fn_decl;
        N_Parametre  parametre;
        N_FnCall     fn_call;
        N_Arguments  arguments;
        N_Block      block;
        N_Ret        ret;
        N_Statement  stmt;
        N_Programme  programme;
    } as;
} Node;

#endif /* __AST_NODES_H__ */
