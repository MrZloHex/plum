#include "meta_ir.h"
#include <stdio.h>
#include <assert.h>
#include <string.h>

void
meta_init(Meta *meta)
{
    scopes_init(&meta->scopes, 16);
    mnv_init(&meta->strs, 16);
    mnv_init(&meta->funcs, 16);
}


void
meta_collect(Meta *meta, AST *ast)
{
    // size_t c = 0;
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
                mnv_append(&curr_scope.params, var);
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
                mnv_init(&curr_scope.vars,  32);
                mnv_init(&curr_scope.params, 8);
                Node *decl = ast_next(ast);
                assert(decl->type == NT_FN_DECL && "NOT A FN DECL");
                mnv_append(&meta->funcs, decl);

                Node *type = ast_next(ast);
                Node *ident = ast_next(ast);
                Node *var = node_make_var_decl(type, ident);
                curr_scope.scope = var;
            }
            else if (curr->type == NT_FN_DECL)
            {
                //printf("DECL SKIP\n");
                mnv_append(&meta->funcs, curr);
                skip_decl = true;
            }
            else if (curr->type == NT_PRG_STMT || curr->type == NT_PROGRAMME)
            { /* printf("SKIP OUTSIDE\n"); SKIP IT */ }
            else
            { assert(0 && "SMTH OUTSIDE SCOPE "); } 
        }
        
        // c++;
        curr = ast_next(ast);
    }

    if (in_scope)
    {
        // printf("OUT SCOPE\n");
        in_scope = false;
        scopes_append(&meta->scopes, curr_scope);
    }

    // printf("NODE END\n");
}

int
meta_is_param(MetaScope *scope, const char *name)
{
    for (size_t i = 0; i < scope->vars.size; ++i)
    {
        Node *var = scope->vars.data[i];
        if (strcmp(var->as.var_decl.ident->as.ident, name) == 0)
        { return 0; }
    }

    for (size_t i = 0; i < scope->params.size; ++i)
    {
        Node *var = scope->params.data[i];
        if (strcmp(var->as.var_decl.ident->as.ident, name) == 0)
        { return 1; }
    }

    return -1;
}

Node *
meta_find_func(Meta *meta, const char *name)
{
    for (size_t i = 0; i < meta->funcs.size; ++i)
    {
        Node *fn = meta->funcs.data[i];
        if (strcmp(fn->as.fn_decl.ident->as.ident, name) == 0)
        { return fn; }
    }
    return NULL;
}

Node *
meta_find_type(Meta *meta, const char *name)
{
    for (size_t i = 0; i < meta->scopes.size; ++i)
    {
        MetaScope scope = meta->scopes.data[i];
        return meta_find_type_in_scope(&scope, name);
    }
    return NULL;
}

Node *
meta_find_type_in_scope(MetaScope *scope, const char *name)
{
    for (size_t j = 0; j < scope->params.size; ++j)
    {
        Node *var = scope->params.data[j];
        if (strcmp(var->as.var_decl.ident->as.ident, name) == 0)
        {
            return var->as.var_decl.type;
        }
    }
    for (size_t j = 0; j < scope->vars.size; ++j)
    {
        Node *var = scope->vars.data[j];
        if (strcmp(var->as.var_decl.ident->as.ident, name) == 0)
        {
            return var->as.var_decl.type;
        }
    }
    return NULL;
}

MetaScope *
meta_find_scope(Meta *meta, const char *name)
{
    for (size_t i = 0; i < meta->scopes.size; ++i)
    {
        MetaScope scope = meta->scopes.data[i];
        if (strcmp(scope.scope->as.var_decl.ident->as.ident, name) == 0)
        {
            return &meta->scopes.data[i];
        }
    }
    return NULL;
}

int
meta_find_str(Meta *meta, const char *lit)
{
    for (size_t i = 0; i < meta->strs.size; ++i)
    {
        Node *l = meta->strs.data[i];
        if (strcmp(l->as.str_lit, lit) == 0)
        {
            return (int)i;
        }
    }
    return -1;
}

void
meta_dump(Meta *meta)
{
    printf("SCOPES:\n");
    for (size_t i = 0; i < meta->scopes.size; ++i)
    {
        MetaScope scope = meta->scopes.data[i];
        printf("\t%zu\n", i);
        node_dump_var_decl(scope.scope, 1);
        printf("\tPARAMS:\n");
        for (size_t j = 0; j < scope.params.size; ++j)
        {
            node_dump_var_decl(scope.params.data[j], 2);
        }
        printf("\tVARIABLES:\n");
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

    printf("DECLARATIONS:\n");
    for (size_t i = 0; i < meta->funcs.size; ++i)
    {
        printf("\t%zu\n", i);
        node_dump_fndecl(meta->funcs.data[i], 1);
    }
}

DEFINE_DYNARRAY(mnv, MNVec, Node *);
DEFINE_DYNARRAY(scopes, Scopes, MetaScope);
