
#ifndef AST_H
#define AST_H

#include "token.h"

/* Forward decl */
typedef struct AST AST;

typedef enum ASTKind
{
    AST_PROGRAM,
    /* types */
    AST_TYPEDEF,
    AST_STRUCT,
    AST_UNION,
    AST_ENUM,
    AST_FIELD,      /* inside struct/union */
    /* functions */
    AST_FUNC_DECL,
    AST_FUNC_DEF,
    AST_PARAM,
    AST_BLOCK,
    /* statements */
    AST_IF,
    AST_ELIF,
    AST_ELSE,
    AST_LOOP,
    AST_BREAK,
    AST_RETURN,
    AST_VAR_DECL,
    AST_ASSIGN,
    AST_EXPR_STMT,
    /* expressions */
    AST_IDENTIFIER,
    AST_LITERAL,
    AST_CALL,
    AST_DOT,
    AST_UNARY,
    AST_BINARY,
    AST_SIZEOF
} ASTKind;

struct AST
{
    ASTKind  kind;
    Token   *tok;   /* location */
    char    *text;  /* extra string info (identifier name, operator, literal etc.) */

    size_t   nchild;
    AST    **child;
};

AST   *ast_new(ASTKind k, Token *tok, const char *text);
void   ast_add(AST *parent, AST *child);
void   ast_print(const AST *node, int indent);

#endif /* AST_H */
