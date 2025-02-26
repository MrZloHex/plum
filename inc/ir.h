#ifndef __GEN_H__
#define __GEN_H__

#include "ast.h"
#include "meta_ir.h"
#include "dynstr.h"

void
generateIR(AST *ast, Meta *meta, DynString *str);

#endif /* GEN_H */

