
#include "ast.h"

AST *ast_new(ASTKind k, Token *tok, const char *text)
{
    AST *n = (AST *)xmalloc(sizeof(AST));
    n->kind = k;
    n->tok = tok ? (Token *)memcpy(xmalloc(sizeof(Token)), tok, sizeof(Token)) : NULL;
    n->text = text ? strdup(text) : NULL;
    n->nchild = 0;
    n->child = NULL;
    return n;
}

void ast_add(AST *parent, AST *child)
{
    parent->child = (AST **)realloc(parent->child, sizeof(AST *) * (parent->nchild + 1));
    parent->child[parent->nchild++] = child;
}

static const char *kind_name(ASTKind k)
{
    switch (k)
    {
#define CASE(x) case x: return #x;
        CASE(AST_PROGRAM) CASE(AST_TYPEDEF) CASE(AST_STRUCT) CASE(AST_UNION)
        CASE(AST_ENUM) CASE(AST_FIELD) CASE(AST_FUNC_DECL) CASE(AST_FUNC_DEF)
        CASE(AST_PARAM) CASE(AST_BLOCK) CASE(AST_IF) CASE(AST_ELIF) CASE(AST_ELSE)
        CASE(AST_LOOP) CASE(AST_BREAK) CASE(AST_RETURN) CASE(AST_VAR_DECL)
        CASE(AST_ASSIGN) CASE(AST_EXPR_STMT) CASE(AST_IDENTIFIER) CASE(AST_LITERAL)
        CASE(AST_CALL) CASE(AST_DOT) CASE(AST_UNARY) CASE(AST_BINARY) CASE(AST_SIZEOF)
#undef CASE
    default: return "UNKNOWN";
    }
}

void ast_print(const AST *node, int indent)
{
    for (int i = 0; i < indent; ++i) printf("  ");
    printf("%s", kind_name(node->kind));
    if (node->text) printf(" \"%s\"", node->text);
    if (node->tok)  printf(" (l%d)", node->tok->line);
    printf("\n");
    for (size_t i = 0; i < node->nchild; ++i)
        ast_print(node->child[i], indent + 1);
}
