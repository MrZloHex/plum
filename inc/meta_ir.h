#ifndef __META_IR_H__
#define __META_IR_H__

#include "ast.h"
#include "dynarray.h"

// MNV - meta node vector
DECLARE_DYNARRAY(mnv, MNVec, Node *);

typedef struct
{
    MNVec vars;
    MNVec strs;
} Meta;

void
meta_init(Meta *meta);

void
meta_collect(Meta *meta, AST *ast);

#endif /* __META_IR_H__  */
