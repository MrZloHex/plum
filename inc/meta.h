#ifndef __META_H__
#define __META_H__

#include "ast.h"
#include "dynarray.h"
#include "dynmap.h"

typedef struct
{
    enum
    {
        SYM_VAR,
        SYM_FN,
        SYM_TYPE
    }        kind;
    N_Type   type;
    ASTNode *decl;
    char    *name;
} Symbol;

DECLARE_DYNARRAY(sms, Symbols, Symbol);

typedef struct
{
    Symbols syms;
} Scope;

DECLARE_DYNARRAY(scs, Scopes, Scope);

typedef struct 
{
    Scopes scopes;
    size_t curr;
} SymTab;

size_t
str_hash(const char *str);

#define str_eq(a,b) (strcmp((a),(b))==0)

DECLARE_DYNMAP(name, char *, ASTNode *, str_hash, str_eq);

typedef struct
{
    SymTab symtab;
    name_map str_lits;
    name_map func_decls;
    name_map types;
} Meta;


void
meta_init(Meta *meta);

void
meta_pass(Meta *meta, AST *ast);

void
meta_dump(const Meta *meta);

void
meta_deinit(Meta *meta);

#endif /* __META_H__  */
