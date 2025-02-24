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
    ET_BIN_OP,
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

// BASE

typedef enum
{
    NT_EXPR,
    NT_IDENT,
    NT_BIN_OP,
    NT_TYPE,
    NT_VAR_DECL,
    NT_RET,
    NT_FN_DEF,
    NT_FN_DECL,
    NT_PARAMETRE,
    NT_BLOCK,
    NT_STATEMENT
} NodeType;

typedef struct Node_S
{
    NodeType type;
    union
    {
        N_Expression expr;
        N_Ident      ident;
        N_Bin_Op     bin_op;
        N_Type       type;
        N_Var_Decl   var_decl;
        N_FnDef      fn_def;
        N_FnDecl     fn_decl;
        N_Parametre  parametre;
        N_Block      block;
        N_Ret        ret;
        N_Statement  stmt;
    } as;
} Node;

#endif /* __AST_NODES_H__ */
