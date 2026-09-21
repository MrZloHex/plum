/* meta.c */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "meta.h"

/* Where the dump goes; stdout unless meta_dump was given something else. */
static FILE *dump_out = NULL;
#define DUMP_OUT (dump_out ? dump_out : stdout)

/*------------------------------------------------------------
 * Вспомогательные: работа со стеком областей (SymTab)
 *-----------------------------------------------------------*/

// Вход в новый scope: инициализируем Symbols и добавляем Scope
static void symtab_push_scope(SymTab *st)
{
    Scope new_scope;
    // начальная ёмкость, например, 8
    if (sms_init(&new_scope.syms, 8) != 0) {
        fprintf(stderr, "Out of memory initializing scope\n");
        exit(1);
    }
    if (scs_append(&st->scopes, new_scope) != 0) {
        fprintf(stderr, "Out of memory pushing scope\n");
        exit(1);
    }
    st->curr = scs_size(&st->scopes) - 1;
}

// Выход из текущего scope: деинициализируем Symbols и удаляем Scope
static void symtab_pop_scope(SymTab *st)
{
    size_t n = scs_size(&st->scopes);
    if (n == 0) return;
    size_t idx = n - 1;
    Scope tmp;
    scs_get(&st->scopes, idx, &tmp);
    sms_deinit(&tmp.syms);
    scs_remove(&st->scopes, idx);
    if (scs_size(&st->scopes) == 0)
        st->curr = 0;
    else
        st->curr = scs_size(&st->scopes) - 1;
}

// Вставка символа в текущий scope; возвращает false при дубликате
static bool symtab_insert(SymTab *st,
                          const char *name,
                          int kind,
                          N_Type type,
                          ASTNode *decl)
{
    Scope *sc = &st->scopes.data[st->curr];
    for (size_t i = 0; i < sms_size(&sc->syms); ++i) {
        Symbol tmp;
        sms_get(&sc->syms, i, &tmp);
        if (strcmp(tmp.name, name) == 0)
            return false;
    }
    Symbol s;
    s.kind = kind;
    s.type = type;
    s.decl = decl;
    s.name = strdup(name);
    if (!s.name) {
        fprintf(stderr, "Out of memory copying symbol name\n");
        exit(1);
    }
    if (sms_append(&sc->syms, s) != 0) {
        fprintf(stderr, "Out of memory inserting symbol\n");
        exit(1);
    }
    return true;
}

// Поиск символа по имени в стеках scope-ов
static Symbol *symtab_lookup(SymTab *st, const char *name)
{
    for (size_t lvl = st->curr + 1; lvl-- > 0; ) {
        Scope *sc = &st->scopes.data[lvl];
        for (size_t i = 0; i < sms_size(&sc->syms); ++i) {
            Symbol tmp;
            sms_get(&sc->syms, i, &tmp);
            if (strcmp(tmp.name, name) == 0)
                return &sc->syms.data[i];
        }
        if (lvl == 0) break;
    }
    return NULL;
}

/*------------------------------------------------------------
 * Рекурсивный обход ASTNode
 * собирает:
 *  - FN_DECL, FN_DEF → func_decls, symtab
 *  - TYPE_DEF → symtab
 *  - VAR_DECL → globals (lvl0) + symtab
 *  - LITERAL (строки) → str_lits
 *  - блоки → push/pop scope
 *-----------------------------------------------------------*/

static void collect_node(ASTNode *node, Meta *m)
{
    if (!node) return;

    switch (node->kind) {

    case NT_TRANSLATION_UNIT:
        for (ASTNode *ts = node->as.tu.tu_stmt;
             ts;
             ts = ts->as.tu_stmt.next_tu_stmt)
        {
            collect_node(ts->as.tu_stmt.tu_stmt, m);
        }
        break;

    case NT_FN_DECL: {
        char *fname = node->as.fn_decl.ident->as.ident;
        name_put(&m->func_decls, fname, node);
        symtab_insert(&m->symtab,
                      fname,
                      SYM_FN,
                      node->as.fn_decl.type->as.type,
                      node);
        break;
    }

    case NT_FN_DEF:
        /* прототип внутри */
        collect_node(node->as.fn_def.decl, m);
        /* новый scope */
        symtab_push_scope(&m->symtab);
        for (ASTNode *p = node->as.fn_def.decl->as.fn_decl.params;
             p;
             p = p->as.parametre.next_param)
        {
            const char *pn = p->as.parametre.ident->as.ident;
            symtab_insert(&m->symtab,
                          pn,
                          SYM_VAR,
                          p->as.parametre.type->as.type,
                          p);
        }
        collect_node(node->as.fn_def.block, m);
        symtab_pop_scope(&m->symtab);
        break;

    case NT_TYPE_DEF: {
        char *tname = node->as.type_def.ident->as.ident;
        /* регистрируем в symtab */
        symtab_insert(&m->symtab, tname, SYM_TYPE,
                      node->as.type_def.tdef->as.type, node);
        /* теперь сохраняем в отдельном map’е для удобства */
        name_put(&m->types, tname, node);
        break;
    }


    case NT_VAR_DECL: {
        char *vname = node->as.var_decl.ident->as.ident;
        if (m->symtab.curr == 0) {
            name_put(&m->str_lits, vname, node);
        }
        symtab_insert(&m->symtab,
                      vname,
                      SYM_VAR,
                      node->as.var_decl.type->as.type,
                      node);
        collect_node(node->as.var_decl.init, m);
        break;
    }

    case NT_LITERAL:
        if (node->as.literal.kind == LT_STRING) {
            name_put(&m->str_lits,
                         node->as.literal.as.str_lit,
                         node);
        }
        break;

    case NT_BLOCK:
        symtab_push_scope(&m->symtab);
        for (ASTNode *s = node->as.block.stmts;
             s;
             s = s->as.stmt.next_stmt)
        {
            collect_node(s->as.stmt.stmt, m);
        }
        symtab_pop_scope(&m->symtab);
        break;

    case NT_IF:
        collect_node(node->as.if_cond.expr, m);
        collect_node(node->as.if_cond.block, m);
        collect_node(node->as.cond.elif_part, m);
        collect_node(node->as.cond.else_part, m);
        break;

    case NT_ELIF:
        collect_node(node->as.elif_cond.expr, m);
        collect_node(node->as.elif_cond.block, m);
        collect_node(node->as.elif_cond.next_elif, m);
        break;

    case NT_ELSE:
        collect_node(node->as.else_cond.block, m);
        break;

    case NT_LOOP:
        collect_node(node->as.loop.block, m);
        break;

    case NT_STMT:
        collect_node(node->as.stmt.stmt, m);
        collect_node(node->as.stmt.next_stmt, m);
        break;

    case NT_EXPR:
        collect_node(node->as.expr.expr, m);
        break;

    case NT_BIN_OP:
        collect_node(node->as.bin_op.left, m);
        collect_node(node->as.bin_op.right, m);
        break;

    case NT_UNY_OP:
        collect_node(node->as.uny_op.operand, m);
        break;

    case NT_FN_CALL:
        collect_node(node->as.fn_call.ident, m);
        for (ASTNode *a = node->as.fn_call.args;
             a;
             a = a->as.argument.next_arg)
        {
            collect_node(a->as.argument.argument, m);
        }
        break;

    default:
        break;
    }
}

void
meta_dump(const Meta *m, FILE *out)
{
    dump_out = out;

    fprintf(DUMP_OUT, "=== Scopes (%zu) ===\n", scs_size(&m->symtab.scopes));
    for (size_t lvl = 0; lvl < scs_size(&m->symtab.scopes); ++lvl)
    {
        Scope sc;
        scs_get(&m->symtab.scopes, lvl, &sc);
        fprintf(DUMP_OUT, " Scope %zu:\n", lvl);
        for (size_t i = 0; i < sms_size(&sc.syms); ++i)
        {
            Symbol s;
            sms_get(&sc.syms, i, &s);
            const char *kstr = (s.kind==SYM_FN  ? "FN"
                                : s.kind==SYM_TYPE? "TYPE"
                                :                   "VAR");
            fprintf(DUMP_OUT, "   [%s] %s\n", kstr, s.name);
        }
    }

    /* Функции */
    // {
    //     size_t n = name_size(&m->func_decls);
    //     name_entry *arr = name_data(&m->func_decls);
    //     fprintf(DUMP_OUT, "=== Functions (%zu) ===\n", n);
    //     for (size_t i = 0; i < n; ++i)
    //     {
    //         fprintf(DUMP_OUT, "  %s\n", arr[i].key);
    //     }
    // }

    // /* Строковые литералы */
    // {
    //     size_t n = name_map_size(&m->str_lits);
    //     name_entry *arr = name_map_data(&m->str_lits);
    //     fprintf(DUMP_OUT, "=== String Literals (%zu) ===\n", n);
    //     for (size_t i = 0; i < n; ++i)
    //     {
    //         fprintf(DUMP_OUT, "  \"%s\"\n", arr[i].key);
    //     }
    // }

    fflush(DUMP_OUT);
    dump_out = NULL;
}

/*------------------------------------------------------------
 * Публичные функции
 *-----------------------------------------------------------*/

void meta_init(Meta *m)
{
    scs_init(&m->symtab.scopes, 8);
    m->symtab.curr = 0;
    symtab_push_scope(&m->symtab);

    name_init(&m->str_lits, 16);
    name_init(&m->func_decls, 16);
    name_init(&m->types, 16);
}

void meta_pass(Meta *m, AST *ast)
{
    /* запускаем рекурсивный сбор от корня */
    collect_node(ast->root, m);
}

void meta_deinit(Meta *m)
{
    /* развернём все scope-ы */
    while (scs_size(&m->symtab.scopes) > 0) {
        symtab_pop_scope(&m->symtab);
    }
    scs_deinit(&m->symtab.scopes);

    name_deinit(&m->str_lits);
    name_deinit(&m->func_decls);
    name_deinit(&m->types);
}


size_t
str_hash(const char *key)
{
    unsigned long hash = 5381;
    int c;
    while ((c = *key++))
        hash = ((hash << 5) + hash) + (unsigned long)c;
    return (size_t)hash;
}

DEFINE_DYNARRAY(sms, Symbols, Symbol);
DEFINE_DYNARRAY(scs, Scopes, Scope);
DEFINE_DYNMAP(name, char *, ASTNode *, str_hash, str_eq);
