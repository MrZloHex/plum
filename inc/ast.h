#ifndef AST_H
#define AST_H

#include <stddef.h>
#include "ast_nodes.h"


Node *
node_make_fndef(Node *decl, Node *block);

Node *
node_make_fndecl(Node *type, Node *id, Node *params);

Node *
node_make_parametre(Node *type, Node *id);

Node *
node_make_ident(const N_Ident value);

Node *
node_make_var_decl(Node *type, Node *id);

Node *
node_make_type(const char *type);

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


void
node_dump_fndef(Node *fndef, size_t offset);

void
node_dump_fndecl(Node *fndecl, size_t offset);

void
node_dump_ident(Node *id, size_t offset);

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

#endif

