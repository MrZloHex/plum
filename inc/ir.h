#ifndef __GEN_H__
#define __GEN_H__

#include "ast_nodes.h"
#include "dynstr.h"

void
generateIR(Node *node, DynString *str);

#endif /* GEN_H */

