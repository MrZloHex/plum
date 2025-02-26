#include "meta_ir.h"
#include <stdio.h>
#include <assert.h>

void
meta_init(Meta *meta)
{
    scopes_init(&meta->scopes, 16);
    mnv_init(&meta->strs, 16);
}


void
meta_collect(Meta *meta, AST *ast)
{
    size_t c = 0;
    Node *curr = ast_next(ast);
    MetaScope curr_scope;
    bool in_scope = false;
    bool skip_decl = false;
    while (curr)
    {
        // printf("NODE T %s\n", node_types_str[curr->type]);
        if (in_scope)
        {
            if (curr->type == NT_FN_DEF || curr->type == NT_FN_DECL)
            { assert(0 && "FN DEF OR DECL IN SCOPE"); }
            else if (curr->type == NT_PROGRAMME)
            {
                // printf("OUT SCOPE\n");
                in_scope = false;
                scopes_append(&meta->scopes, curr_scope);
            }

            if (curr->type == NT_PARAMETRE)
            {
                // printf("GOT PARAM\n");
                Node *type = ast_next(ast);
                Node *ident = ast_next(ast);
                Node *var = node_make_var_decl(type, ident);
                // node_dump_var_decl(var, 1);
                mnv_append(&curr_scope.vars, var);
            }
            if (curr->type == NT_VAR_DECL)
            {
                // printf("GOT VAR DECL\n");
                //node_dump_var_decl(curr, 1);
                mnv_append(&curr_scope.vars, curr);
            }
            if (curr->type == NT_STR_LIT)
            {
                mnv_append(&meta->strs, curr);
            }
        }
        else if (skip_decl)
        {
            if (curr->type == NT_PROGRAMME)
            {
                // printf("SKIP FIN\n");
                skip_decl = false;
            }
        }
        else
        {
            if (curr->type == NT_FN_DEF)
            {
                // printf("IN SCOPE\n");
                in_scope = true;
                mnv_init(&curr_scope.vars, 32);
                ast_next(ast);
            }
            else if (curr->type == NT_FN_DECL)
            {
                // printf("DECL SKIP\n");
                skip_decl = true;
            }
            else if (curr->type == NT_PRG_STMT || curr->type == NT_PROGRAMME)
            { /* printf("SKIP OUTSIDE\n"); SKIP IT */ }
            else
            { assert(0 && "SMTH OUTSIDE SCOPE "); } 
        }
        


        c++;
        curr = ast_next(ast);
    }

    if (in_scope)
    {
        printf("OUT SCOPE\n");
        in_scope = false;
        scopes_append(&meta->scopes, curr_scope);
    }

    // printf("NODE END\n");
}

void
meta_dump(Meta *meta)
{
    printf("SCOPES:\n");
    for (size_t i = 0; i < meta->scopes.size; ++i)
    {
        printf("\t%zu\n", i);
        printf("\tVARIABLES:\n");
        MetaScope scope = meta->scopes.data[i];
        for (size_t j = 0; j < scope.vars.size; ++j)
        {
            node_dump_var_decl(scope.vars.data[j], 2);
        }
    }

    printf("STR LITERALS:\n");
    for (size_t i = 0; i < meta->strs.size; ++i)
    {
        printf("\t%zu\n", i);
        node_dump_str_lit(meta->strs.data[i], 1);
    }
}

DEFINE_DYNARRAY(mnv, MNVec, Node *);
DEFINE_DYNARRAY(scopes, Scopes, MetaScope);
