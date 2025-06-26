#ifndef __AST_H__
#define __AST_H__

// #include "ast_nodes.h"
#include "dynstack.h"
#include "dynstr.h"
#include "arena.h"

typedef struct ASTNode ASTNode;

DECLARE_DYNSTACK(ast_stack, ASTStack, ASTNode *)

typedef struct
{
    Arena arena;
    ASTNode *root;
    ASTStack stack;
} AST;

void
ast_init(AST *ast);

ASTNode *
ast_node_new(AST *ast);

void
ast_reinit(AST *ast);

void
ast_deinit(AST *ast);

ASTNode *
ast_next(AST *ast);

DynString
ast_dump(AST *ast);


#include <stddef.h>

#include "location.h"

typedef enum
{
    // TOP LEVEL
    NT_TRANSLATION_UNIT,
    NT_TU_STMT,
    
    // TOP LEVEL STATEMENTS
    NT_FN_DECL,
    NT_FN_DEF,
    NT_TYPE_DEF,
    
    // TL STMT EXTRA
    NT_PARAMETRE,
    NT_ENUM_FIELDS,
    NT_RECORD,
    NT_FIELD,

    // BASIC NODES
    NT_TYPE,
    NT_BASE_TYPE,
    NT_IDENT,

    // BLOCK AND STATEMENTS
    NT_BLOCK,
    NT_STMT,
    NT_RET,
    NT_COND,
    NT_LOOP,
    NT_VAR_DECL,
    NT_EXPR,

    // CONDITIONAL
    NT_IF,
    NT_ELIF,
    NT_ELSE,

    // EXPRESSIONS
    NT_BIN_OP,
    NT_UNY_OP,
    NT_FN_CALL,
    NT_ARGUMENT,
    NT_LITERAL
} ASTNodeType;

typedef struct ASTNode ASTNode;

typedef struct
{
    ASTNode *next_unit; // N_TransUnit
    ASTNode *tu_stmt;   // N_TUStmt Linked list
} N_TransUnit;

typedef struct
{
    enum // Translation Unit Statement Type
    {
        TUST_FN_DEF,
        TUST_FN_DECL,
        TUST_TYPE_DEF
    } kind;
    ASTNode *tu_stmt;      // The tu statement
    ASTNode *next_tu_stmt; // N_TUStmt;
} N_TUStmt;

typedef struct
{
    ASTNode *ident;  // N_Ident
    ASTNode *type;   // N_Type
    ASTNode *params; // N_Parametre Linked list
} N_FnDecl;

typedef struct
{
    bool vaarg;
    ASTNode *ident;      // N_Ident
    ASTNode *type;       // N_Type
    ASTNode *next_param; // N_Parametre
} N_Parametre;

typedef struct
{
    ASTNode *decl;  // N_FnDecl
    ASTNode *block; // N_Block
} N_FnDef;

typedef struct
{
    enum // Type Defenition
    {
        TD_ALIAS,
        TD_RECORD,
        TD_ENUM
    } kind;
    ASTNode *ident; // N_Ident;
    ASTNode *tdef;   // N_Type || N_Record || N_EnumField Linked list
} N_TypeDef;

typedef struct
{
    ASTNode *ident;      // N_Ident name of enum constant
    ASTNode *next_field; // N_EnumField
} N_EnumField;

typedef struct
{
    enum // Type Defenition Record Type
    {
        TDRT_STRUCTURE,
        TDRT_UNION,
    } kind;
    ASTNode *fields; // N_Field Linked list
} N_Record;

typedef struct
{
    ASTNode *type;       // N_Type
    ASTNode *ident;      // N_Ident
    ASTNode *next_field; // N_Field
} N_Field;

typedef char *N_Ident;

typedef struct
{
    enum // Type of Type :)
    {
        TT_BASE_TYPE,
        TT_USER_TYPE
    } kind;
    size_t ptrs; // Quantity of pointers
    ASTNode *type; // N_BaseType || N_Ident if user type
} N_Type;

typedef enum // Base Type
{
    BT_ABYSS,
    BT_B1,
    BT_C1,
    BT_U8,
    BT_U16,
    BT_U32,
    BT_U64,
    BT_I8,
    BT_I16,
    BT_I32,
    BT_I64,
    BT_USIZE,
    BT_ISIZE,
    BT_F32,
    BT_F64,

    BT_QUANTITY
} N_BaseType;

typedef struct
{
    ASTNode *stmts; // N_Stmt Linked list
} N_Block;

typedef struct
{
    enum // Statement Type
    {
        ST_RET,
        ST_BREAK,
        ST_COND,
        ST_LOOP,
        ST_VAR_DECL, // TODO: maybe allow not only var decl, maybe record decl?? idk
        ST_EXPR
    } kind;
    ASTNode *stmt;      // The statement
    ASTNode *next_stmt; // N_Stmt
} N_Stmt;

typedef struct
{
    ASTNode *expr; // N_Expr
} N_Ret;

typedef struct
{
    ASTNode *if_part;   // N_If
    ASTNode *elif_part; // N_Elif Linked list
    ASTNode *else_part; // N_Else
} N_Cond;

typedef struct
{
    ASTNode *expr;  // N_Expr
    ASTNode *block; // N_Block
} N_If;

typedef struct
{
    ASTNode *expr;      // N_Expr
    ASTNode *block;     // N_Block
    ASTNode *next_elif; // N_Elif
} N_Elif;

typedef struct
{
    ASTNode *block; // N_Block
} N_Else;

typedef struct
{
    ASTNode *block; // N_Block;
} N_Loop;

typedef struct
{
    ASTNode *ident; // N_Ident
    ASTNode *type;  // N_Type
    ASTNode *init;  // N_Expr
} N_VarDecl;

typedef struct
{
    enum // Expression Type
    {
        ET_IDENT,
        ET_BIN_OP,
        ET_UNY_OP,
        ET_FN_CALL,
        ET_LITERAL
    } kind;
    ASTNode *expr; // The expression
} N_Expr;

typedef struct
{
    enum // Binary Operation Type
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
        BOT_MEMBER
    } kind;
    ASTNode *left;  // N_Expr
    ASTNode *right; // N_Expr
} N_BinOp;

typedef struct
{
    enum // Unary Operation Type
    {
        UOT_DEREF,
        UOT_REF
    } kind;
    ASTNode *operand; // N_Expr
} N_UnyOp;

typedef struct
{
    ASTNode *ident; // N_Ident
    ASTNode *args;  // N_Argument Linked list
} N_FnCall;

typedef struct
{
    ASTNode *argument; // N_Expr
    ASTNode *next_arg; // N_Argument
} N_Argument;

typedef struct
{
    enum // Literal Type
    {
        LT_INTEGER,
        LT_CHARACTER,
        LT_STRING,
        LT_BOOLEAN
    } kind;
    union
    {
        int   int_lit;
        char  char_lit;
        char *str_lit;
        bool  bool_lit;
    } as;
} N_Literal;

typedef struct ASTNode
{
    ASTNodeType kind;
    Location    loc;
    union
    {
        N_TransUnit     tu;
        N_TUStmt        tu_stmt;

        N_FnDecl        fn_decl;
        N_FnDef         fn_def;
        N_TypeDef       type_def;
        N_EnumField     enum_flds;
        N_Record        record;
        N_Field         rcrd_flds;
        N_Parametre     parametre;

        N_Type          type;
        N_BaseType      base_type;
        N_Ident         ident;

        N_Block         block;
        N_Stmt          stmt;
        N_Ret           ret;
        N_Cond          cond;
        N_Loop          loop;
        N_VarDecl       var_decl;
        N_Expr          expr;

        N_If            if_cond;
        N_Elif          elif_cond;
        N_Else          else_cond;

        N_BinOp         bin_op;
        N_UnyOp         uny_op;
        N_FnCall        fn_call;
        N_Argument      argument;
        N_Literal       literal;
    } as;
} ASTNode;



#endif /* __AST_H__ */

