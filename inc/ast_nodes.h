#ifndef __AST_NODES_H__
#define __AST_NODES_H__
#if 0

typedef struct Node Node;

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
node_make_parametre_vaarg();

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
node_make_var_decl(Node *type, Node *id, Node *value);

Node *
node_make_type(const char *type);

Node *
node_make_type_ptr(Node *type);

Node *
node_make_user_type(Node *ident);

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

Node *
node_make_uny_op(UnyOpType op, Node *operand);

Node *
node_make_type_def(Node *ident, Node *block);

Node *
node_make_member(Node *base, Node *field);

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

void
node_dump_uny_op(Node *uny, size_t offset);

void
node_dump_type_def(Node *type, size_t offset);

void
node_dump_member(Node *member, size_t offset);

#endif
#endif /* __AST_NODES_H__ */
