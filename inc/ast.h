#ifndef __AST_H__
#define __AST_H__

#include "ast_nodes.h"
#include "dynstack.h"

DECLARE_DYNSTACK(ast_stack, ASTStack, Node *)

typedef struct
{
    Node *root;
    ASTStack stack;
} AST;

void
ast_init(AST *ast, Node *root);

Node *
ast_next(AST *ast);

#endif /* __AST_H__ */

