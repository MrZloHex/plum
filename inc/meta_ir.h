#ifndef __META_IR_H__
#define __META_IR_H__

#include "ast.h"
#include "dynarray.h"

// MNV - meta node vector
DECLARE_DYNARRAY(mnv, MNVec, Node *);

typedef struct
{
    MNVec vars;
    MNVec params;
    Node *scope;
} MetaScope;

DECLARE_DYNARRAY(scopes, Scopes, MetaScope);

typedef struct
{
    Scopes scopes;
    MNVec strs;
    MNVec funcs;
} Meta;

void
meta_init(Meta *meta);

void
meta_collect(Meta *meta, AST *ast);

int
meta_is_param(MetaScope *scope, const char *name);

Node *
meta_find_func(Meta *meta, const char *name);

Node *
meta_find_type(Meta *meta, const char *name);

Node *
meta_find_type_in_scope(MetaScope *scope, const char *name);

MetaScope *
meta_find_scope(Meta *meta, const char *name);

void
meta_dump(Meta *meta);

#endif /* __META_IR_H__  */
