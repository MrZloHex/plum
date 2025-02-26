#include "meta_ir.h"
#include <stdio.h>

void
meta_init(Meta *meta)
{
    mnv_init(&meta->vars, 16);
    mnv_init(&meta->strs, 16);
}

void
meta_collect(Meta *meta, AST *ast)
{
    size_t c = 0;
    Node *curr = ast_next(ast);
    while (curr)
    {
        printf("NODE T %d\n", curr->type);
        if (c > 10)
        {
            break;
        }
        c++;
        curr = ast_next(ast);
    }
    printf("NODE END\n");
}

DEFINE_DYNARRAY(mnv, MNVec, Node *);
