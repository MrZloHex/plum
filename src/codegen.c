#include "codegen.h"

#include <llvm-c/Analysis.h>
#include <llvm-c/Target.h>
#include <llvm-c/TargetMachine.h>

#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "trace.h"

/* A codegen error is not recoverable: continuing would emit garbage IR, or
   feed LLVM a void alloca and hang it. TRACE_FATAL only logs, so bail here
   the way the parser does. */
#define CG_FATAL(...)            \
    do {                         \
        TRACE_FATAL(__VA_ARGS__);\
        exit(1);                 \
    } while (0)

/* ==========================================================================
 * Local scopes
 *
 * Every symbol carries its pointee type alongside the pointer. Opaque
 * pointers mean LLVMTypeOf(alloca) is just `ptr`, so the type has to be
 * remembered here or every load is wrong.
 * ======================================================================== */

typedef struct
{
    const char  *name;
    LLVMValueRef value;  /* alloca or global -- always a pointer */
    LLVMTypeRef  type;   /* what it points AT */
    ASTNode     *ntype;  /* the declared N_Type node, for pointer maths */
} CGSym;

struct CGScope
{
    CGSym   *syms;
    size_t   used, cap;
    CGScope *parent;
};

static void
scope_push(CodegenContext *c)
{
    CGScope *s = calloc(1, sizeof(CGScope));
    assert(s && "OOM");
    s->parent = c->scope;
    c->scope  = s;
}

static void
scope_pop(CodegenContext *c)
{
    CGScope *s = c->scope;
    if (!s)
    { return; }
    c->scope = s->parent;
    free(s->syms);
    free(s);
}

static void
scope_define(CodegenContext *c, const char *name, LLVMValueRef v,
             LLVMTypeRef t, ASTNode *ntype)
{
    CGScope *s = c->scope;
    if (s->used == s->cap)
    {
        s->cap  = s->cap ? s->cap * 2 : 16;
        s->syms = realloc(s->syms, s->cap * sizeof(CGSym));
        assert(s->syms && "OOM");
    }
    s->syms[s->used++] = (CGSym){ .name = name, .value = v, .type = t, .ntype = ntype };
}

static CGSym *
scope_lookup(CodegenContext *c, const char *name)
{
    for (CGScope *s = c->scope; s; s = s->parent)
    {
        for (size_t i = s->used; i-- > 0; )
        {
            if (strcmp(s->syms[i].name, name) == 0)
            { return &s->syms[i]; }
        }
    }
    return NULL;
}

/* ==========================================================================
 * User-defined types: STRUCT, UNION, ENUM
 * ======================================================================== */

typedef struct
{
    const char  *name;
    LLVMTypeRef  type;      /* struct body, or i32 for an enum */
    ASTNode     *record;    /* N_Record, NULL for enums/aliases */
    bool         is_union;
} CGType;

typedef struct
{
    const char *name;
    long long   value;
} CGEnumConst;

struct CGTypes
{
    CGType      *items;
    size_t       used, cap;
    CGEnumConst *consts;
    size_t       cused, ccap;
};

static CGType *
type_lookup(CodegenContext *c, const char *name)
{
    for (size_t i = 0; i < c->types->used; ++i)
    {
        if (strcmp(c->types->items[i].name, name) == 0)
        { return &c->types->items[i]; }
    }
    return NULL;
}

static CGType *
type_add(CodegenContext *c, const char *name)
{
    CGTypes *t = c->types;
    if (t->used == t->cap)
    {
        t->cap   = t->cap ? t->cap * 2 : 16;
        t->items = realloc(t->items, t->cap * sizeof(CGType));
        assert(t->items && "OOM");
    }
    t->items[t->used] = (CGType){ .name = name };
    return &t->items[t->used++];
}

static void
enum_const_add(CodegenContext *c, const char *name, long long v)
{
    CGTypes *t = c->types;
    if (t->cused == t->ccap)
    {
        t->ccap   = t->ccap ? t->ccap * 2 : 16;
        t->consts = realloc(t->consts, t->ccap * sizeof(CGEnumConst));
        assert(t->consts && "OOM");
    }
    t->consts[t->cused++] = (CGEnumConst){ .name = name, .value = v };
}

static bool
enum_const_get(CodegenContext *c, const char *name, long long *out)
{
    for (size_t i = 0; i < c->types->cused; ++i)
    {
        if (strcmp(c->types->consts[i].name, name) == 0)
        { *out = c->types->consts[i].value; return true; }
    }
    return false;
}

/* ==========================================================================
 * Types
 * ======================================================================== */

static LLVMTypeRef
map_base_type(CodegenContext *c, int bt)
{
    switch (bt)
    {
        case BT_ABYSS: return LLVMVoidTypeInContext(c->ctx);
        case BT_B1:    return LLVMInt1TypeInContext(c->ctx);
        case BT_C1:    return LLVMInt8TypeInContext(c->ctx);
        case BT_U8:
        case BT_I8:    return LLVMInt8TypeInContext(c->ctx);
        case BT_U16:
        case BT_I16:   return LLVMInt16TypeInContext(c->ctx);
        case BT_U32:
        case BT_I32:   return LLVMInt32TypeInContext(c->ctx);
        case BT_U64:
        case BT_I64:
        case BT_USIZE:
        case BT_ISIZE: return LLVMInt64TypeInContext(c->ctx);
        case BT_F32:   return LLVMFloatTypeInContext(c->ctx);
        case BT_F64:   return LLVMDoubleTypeInContext(c->ctx);
        default:
            CG_FATAL("unmapped base type %d", bt);
            return LLVMVoidTypeInContext(c->ctx);
    }
}

/* The declared type of a node, pointers applied. */
static LLVMTypeRef
map_type(CodegenContext *c, ASTNode *tn)
{
    N_Type *t = &tn->as.type;

    LLVMTypeRef base;
    if (t->kind == TT_BASE_TYPE)
    { base = map_base_type(c, t->type->as.base_type); }
    else
    {
        CGType *ut = type_lookup(c, t->type->as.ident);
        if (!ut)
        {
            CG_FATAL("unknown type `%s` at %d:%d",
                        t->type->as.ident, tn->loc.line, tn->loc.col);
            return LLVMVoidTypeInContext(c->ctx);
        }
        base = ut->type;
    }

    for (size_t i = 0; i < t->ptrs; ++i)
    { base = LLVMPointerType(base, 0); }

    return base;
}

/* ==========================================================================
 * String literals
 *
 * The lexeme still carries its quotes and unexpanded escapes.
 * ======================================================================== */

typedef struct
{
    const char  *text;
    LLVMValueRef global;
} CGStr;

struct CGStrs
{
    CGStr *items;
    size_t used, cap;
};

static char *
unescape(const char *lex, size_t *out_len)
{
    size_t n   = strlen(lex);
    const char *p = lex, *end = lex + n;

    if (n >= 2 && (*p == '"' || *p == '\''))
    { p += 1; end -= 1; }

    char  *buf = malloc((size_t)(end - p) + 1);
    size_t k   = 0;
    assert(buf && "OOM");

    while (p < end)
    {
        if (*p == '\\' && p + 1 < end)
        {
            p++;
            switch (*p)
            {
                case 'n':  buf[k++] = '\n'; break;
                case 't':  buf[k++] = '\t'; break;
                case 'r':  buf[k++] = '\r'; break;
                case '0':  buf[k++] = '\0'; break;
                case '\\': buf[k++] = '\\'; break;
                case '\'': buf[k++] = '\''; break;
                case '"':  buf[k++] = '"';  break;
                default:   buf[k++] = *p;   break;
            }
            p++;
        }
        else
        { buf[k++] = *p++; }
    }

    buf[k]   = '\0';
    *out_len = k;
    return buf;
}

static LLVMValueRef
str_global(CodegenContext *c, const char *lex)
{
    for (size_t i = 0; i < c->strs->used; ++i)
    {
        if (strcmp(c->strs->items[i].text, lex) == 0)
        { return c->strs->items[i].global; }
    }

    size_t len  = 0;
    char  *text = unescape(lex, &len);

    LLVMTypeRef  arr = LLVMArrayType(LLVMInt8TypeInContext(c->ctx), (unsigned)len + 1);
    char         name[32];
    snprintf(name, sizeof(name), ".str.%zu", c->strs->used);

    LLVMValueRef g = LLVMAddGlobal(c->mod, arr, name);
    LLVMSetInitializer(g, LLVMConstStringInContext(c->ctx, text, (unsigned)len, false));
    LLVMSetGlobalConstant(g, true);
    LLVMSetLinkage(g, LLVMPrivateLinkage);
    LLVMSetUnnamedAddr(g, true);
    free(text);

    CGStrs *s = c->strs;
    if (s->used == s->cap)
    {
        s->cap   = s->cap ? s->cap * 2 : 16;
        s->items = realloc(s->items, s->cap * sizeof(CGStr));
        assert(s->items && "OOM");
    }
    s->items[s->used++] = (CGStr){ .text = lex, .global = g };

    return g;
}

/* ==========================================================================
 * Expressions
 * ======================================================================== */

typedef struct
{
    LLVMValueRef ptr;   /* address */
    LLVMTypeRef  type;  /* what lives there */
} LValue;

/* The static type of an expression: a declared N_Type plus how many
   pointer levels are actually left after derefs/refs. `node` is NULL
   when we cannot work it out, which only costs us pointer scaling. */
typedef struct
{
    ASTNode *node;   /* an NT_TYPE node */
    size_t   ptrs;
} TypeInfo;

static LLVMValueRef gen_expr(CodegenContext *c, ASTNode *e);
static bool         gen_lvalue(CodegenContext *c, ASTNode *e, LValue *out);
static void         gen_block(CodegenContext *c, ASTNode *blk);
static TypeInfo     infer(CodegenContext *c, ASTNode *e);

/* Realise a TypeInfo as an LLVM type, or NULL if it is not known. */
static LLVMTypeRef
llvm_of(CodegenContext *c, TypeInfo ti)
{
    if (!ti.node)
    { return NULL; }

    N_Type *t = &ti.node->as.type;

    LLVMTypeRef base;
    if (t->kind == TT_BASE_TYPE)
    { base = map_base_type(c, t->type->as.base_type); }
    else
    {
        CGType *ut = type_lookup(c, t->type->as.ident);
        if (!ut)
        { return NULL; }
        base = ut->type;
    }

    for (size_t i = 0; i < ti.ptrs; ++i)
    { base = LLVMPointerType(base, 0); }

    return base;
}

/* Widen/narrow/convert v so it can be used where `to` is expected. */
static LLVMValueRef
coerce(CodegenContext *c, LLVMValueRef v, LLVMTypeRef to)
{
    if (!v || !to)
    { return v; }

    LLVMTypeRef from = LLVMTypeOf(v);
    if (from == to)
    { return v; }

    LLVMTypeKind fk = LLVMGetTypeKind(from);
    LLVMTypeKind tk = LLVMGetTypeKind(to);

    if (fk == LLVMIntegerTypeKind && tk == LLVMIntegerTypeKind)
    {
        unsigned fw = LLVMGetIntTypeWidth(from);
        unsigned tw = LLVMGetIntTypeWidth(to);
        if (fw == tw) { return v; }
        if (fw <  tw) { return LLVMBuildSExt (c->builder, v, to, "sext");  }
        return LLVMBuildTrunc(c->builder, v, to, "trunc");
    }
    if (fk == LLVMIntegerTypeKind && tk == LLVMPointerTypeKind)
    { return LLVMBuildIntToPtr(c->builder, v, to, "itop"); }
    if (fk == LLVMPointerTypeKind && tk == LLVMIntegerTypeKind)
    { return LLVMBuildPtrToInt(c->builder, v, to, "ptoi"); }
    if (fk == LLVMPointerTypeKind && tk == LLVMPointerTypeKind)
    { return v; } /* opaque pointers: nothing to convert */
    if (fk == LLVMIntegerTypeKind && (tk == LLVMFloatTypeKind || tk == LLVMDoubleTypeKind))
    { return LLVMBuildSIToFP(c->builder, v, to, "sitofp"); }

    return v;
}

static bool     field_index(ASTNode *record, const char *field,
                            unsigned *idx, ASTNode **type_out);
static CGType  *type_of_struct(CodegenContext *c, LLVMTypeRef t);

/* Unwrap NT_EXPR down to the node that carries meaning. */
static ASTNode *
strip(ASTNode *e)
{
    while (e && e->kind == NT_EXPR)
    { e = e->as.expr.expr; }
    return e;
}

/* Static type of an expression. Only pointer depth really matters here:
   it is what makes `p + 1` step by an element instead of a byte. */
static TypeInfo
infer(CodegenContext *c, ASTNode *e)
{
    TypeInfo none = { NULL, 0 };
    ASTNode *n = strip(e);
    if (!n)
    { return none; }

    switch (n->kind)
    {
        case NT_IDENT:
        {
            CGSym *s = scope_lookup(c, n->as.ident);
            if (!s || !s->ntype)
            { return none; }
            return (TypeInfo){ s->ntype, s->ntype->as.type.ptrs };
        }

        case NT_UNY_OP:
        {
            TypeInfo i = infer(c, n->as.uny_op.operand);
            if (n->as.uny_op.kind == UOT_DEREF)
            { return i.ptrs ? (TypeInfo){ i.node, i.ptrs - 1 } : none; }
            if (n->as.uny_op.kind == UOT_REF)
            { return i.node ? (TypeInfo){ i.node, i.ptrs + 1 } : none; }
            return i;
        }

        case NT_BIN_OP:
        {
            if (n->as.bin_op.kind == BOT_MEMBER)
            {
                TypeInfo base = infer(c, n->as.bin_op.left);
                if (!base.node)
                { return none; }

                LLVMTypeRef sty = llvm_of(c, (TypeInfo){ base.node, 0 });
                CGType *ut = sty ? type_of_struct(c, sty) : NULL;
                if (!ut || !ut->record)
                { return none; }

                ASTNode *fname = strip(n->as.bin_op.right);
                if (!fname || fname->kind != NT_IDENT)
                { return none; }

                unsigned idx = 0;
                ASTNode *ftype = NULL;
                if (!field_index(ut->record, fname->as.ident, &idx, &ftype))
                { return none; }

                return (TypeInfo){ ftype, ftype->as.type.ptrs };
            }
            /* assignment and arithmetic take the shape of the left side */
            return infer(c, n->as.bin_op.left);
        }

        case NT_FN_CALL:
        {
            ASTNode *decl = NULL;
            if (name_get(&c->meta->func_decls, n->as.fn_call.ident->as.ident, &decl) && decl)
            {
                ASTNode *rt = decl->as.fn_decl.type;
                return (TypeInfo){ rt, rt->as.type.ptrs };
            }
            return none;
        }

        default:
            return none;
    }
}

/* Index of `field` inside a record, and its declared type node. */
static bool
field_index(ASTNode *record, const char *field, unsigned *idx, ASTNode **type_out)
{
    unsigned i = 0;
    for (ASTNode *f = record->as.record.fields; f; f = f->as.rcrd_flds.next_field, ++i)
    {
        if (strcmp(f->as.rcrd_flds.ident->as.ident, field) == 0)
        {
            *idx      = i;
            *type_out = f->as.rcrd_flds.type;
            return true;
        }
    }
    return false;
}

static CGType *
type_of_struct(CodegenContext *c, LLVMTypeRef t)
{
    for (size_t i = 0; i < c->types->used; ++i)
    {
        if (c->types->items[i].type == t)
        { return &c->types->items[i]; }
    }
    return NULL;
}

static bool
gen_lvalue(CodegenContext *c, ASTNode *e, LValue *out)
{
    ASTNode *n = strip(e);
    if (!n)
    { return false; }

    if (n->kind == NT_IDENT)
    {
        CGSym *s = scope_lookup(c, n->as.ident);
        if (!s)
        { return false; }
        out->ptr  = s->value;
        out->type = s->type;
        return true;
    }

    /* ?p -- the address is whatever p holds */
    if (n->kind == NT_UNY_OP && n->as.uny_op.kind == UOT_DEREF)
    {
        TypeInfo    ti      = infer(c, n->as.uny_op.operand);
        LLVMTypeRef pointee = NULL;

        if (ti.node && ti.ptrs > 0)
        { pointee = llvm_of(c, (TypeInfo){ ti.node, ti.ptrs - 1 }); }
        if (!pointee)
        { pointee = LLVMInt8TypeInContext(c->ctx); }

        out->ptr  = gen_expr(c, n->as.uny_op.operand);
        out->type = pointee;
        return out->ptr != NULL;
    }

    /* a.b -- GEP into a struct, or the same address for a union */
    if (n->kind == NT_BIN_OP && n->as.bin_op.kind == BOT_MEMBER)
    {
        LValue base;
        if (!gen_lvalue(c, n->as.bin_op.left, &base))
        { return false; }

        LLVMTypeRef  sty  = base.type;
        LLVMValueRef sptr = base.ptr;

        /* @Foo f ... f.x -- step through the pointer first */
        if (LLVMGetTypeKind(sty) == LLVMPointerTypeKind)
        {
            TypeInfo ti = infer(c, n->as.bin_op.left);
            if (!ti.node || ti.ptrs == 0)
            { return false; }

            LLVMTypeRef pointee = llvm_of(c, (TypeInfo){ ti.node, ti.ptrs - 1 });
            if (!pointee)
            { return false; }

            sptr = LLVMBuildLoad2(c->builder, sty, sptr, "objptr");
            sty  = pointee;
        }

        CGType *ut = type_of_struct(c, sty);
        if (!ut || !ut->record)
        { return false; }

        ASTNode *fname = strip(n->as.bin_op.right);
        if (!fname || fname->kind != NT_IDENT)
        { return false; }

        unsigned idx = 0;
        ASTNode *ftype = NULL;
        if (!field_index(ut->record, fname->as.ident, &idx, &ftype))
        {
            CG_FATAL("no field `%s` in `%s`", fname->as.ident, ut->name);
            return false;
        }

        if (ut->is_union)
        {
            /* every member starts at the union's own address */
            out->ptr  = sptr;
            out->type = map_type(c, ftype);
            return true;
        }

        out->ptr  = LLVMBuildStructGEP2(c->builder, sty, sptr, idx, "fld");
        out->type = map_type(c, ftype);
        return true;
    }

    return false;
}

static LLVMValueRef
gen_call(CodegenContext *c, ASTNode *call)
{
    const char  *name   = call->as.fn_call.ident->as.ident;
    LLVMValueRef callee = LLVMGetNamedFunction(c->mod, name);

    if (!callee)
    {
        CG_FATAL("call to undeclared function `%s`", name);
        return NULL;
    }

    LLVMTypeRef fty = LLVMGlobalGetValueType(callee);

    unsigned nparams = LLVMCountParamTypes(fty);
    LLVMTypeRef ptypes[64];
    if (nparams > 64) { nparams = 64; }
    LLVMGetParamTypes(fty, ptypes);

    LLVMValueRef args[64];
    unsigned n = 0;
    for (ASTNode *a = call->as.fn_call.args;
         a && n < 64;
         a = a->as.argument.next_arg)
    {
        LLVMValueRef v = gen_expr(c, a->as.argument.argument);
        if (n < nparams)
        { v = coerce(c, v, ptypes[n]); }
        else if (v && LLVMGetTypeKind(LLVMTypeOf(v)) == LLVMIntegerTypeKind
                   && LLVMGetIntTypeWidth(LLVMTypeOf(v)) < 32)
        {
            /* C variadic default promotion */
            v = LLVMBuildSExt(c->builder, v, LLVMInt32TypeInContext(c->ctx), "vapromo");
        }
        args[n++] = v;
    }

    bool is_void = LLVMGetTypeKind(LLVMGetReturnType(fty)) == LLVMVoidTypeKind;
    return LLVMBuildCall2(c->builder, fty, callee, args, n, is_void ? "" : "call");
}

static LLVMValueRef
gen_binop(CodegenContext *c, ASTNode *n)
{
    N_BinOp *b = &n->as.bin_op;

    if (b->kind == BOT_ASSIGN)
    {
        LValue lv;
        if (!gen_lvalue(c, b->left, &lv))
        {
            CG_FATAL("left side of `=` is not assignable at %d:%d",
                        n->loc.line, n->loc.col);
            return NULL;
        }
        LLVMValueRef v = coerce(c, gen_expr(c, b->right), lv.type);
        LLVMBuildStore(c->builder, v, lv.ptr);
        return v;
    }

    if (b->kind == BOT_MEMBER)
    {
        LValue lv;
        if (!gen_lvalue(c, n, &lv))
        { return NULL; }
        return LLVMBuildLoad2(c->builder, lv.type, lv.ptr, "fldval");
    }

    LLVMValueRef l = gen_expr(c, b->left);
    LLVMValueRef r = gen_expr(c, b->right);
    if (!l || !r)
    { return NULL; }

    LLVMTypeKind lk = LLVMGetTypeKind(LLVMTypeOf(l));
    LLVMTypeKind rk = LLVMGetTypeKind(LLVMTypeOf(r));

    /* pointer arithmetic: p +/- n, scaled by the pointee like C */
    if ((b->kind == BOT_PLUS || b->kind == BOT_MINUS) && lk == LLVMPointerTypeKind)
    {
        TypeInfo    ti   = infer(c, b->left);
        LLVMTypeRef elem = NULL;

        if (ti.node && ti.ptrs > 0)
        { elem = llvm_of(c, (TypeInfo){ ti.node, ti.ptrs - 1 }); }
        if (!elem)
        { elem = LLVMInt8TypeInContext(c->ctx); }

        LLVMValueRef off = coerce(c, r, LLVMInt64TypeInContext(c->ctx));
        if (b->kind == BOT_MINUS)
        { off = LLVMBuildNeg(c->builder, off, "neg"); }
        return LLVMBuildGEP2(c->builder, elem, l, &off, 1, "padd");
    }

    /* comparisons against a pointer stay in pointer-land */
    if (lk == LLVMPointerTypeKind && rk == LLVMIntegerTypeKind)
    { r = LLVMBuildIntToPtr(c->builder, r, LLVMTypeOf(l), "itop"); }
    else if (rk == LLVMPointerTypeKind && lk == LLVMIntegerTypeKind)
    { l = LLVMBuildIntToPtr(c->builder, l, LLVMTypeOf(r), "itop"); }
    else
    {
        /* promote the narrower side */
        LLVMTypeRef lt = LLVMTypeOf(l), rt = LLVMTypeOf(r);
        if (lt != rt
            && LLVMGetTypeKind(lt) == LLVMIntegerTypeKind
            && LLVMGetTypeKind(rt) == LLVMIntegerTypeKind)
        {
            if (LLVMGetIntTypeWidth(lt) < LLVMGetIntTypeWidth(rt))
            { l = coerce(c, l, rt); }
            else
            { r = coerce(c, r, lt); }
        }
    }

    switch (b->kind)
    {
        case BOT_PLUS:  return LLVMBuildAdd (c->builder, l, r, "add");
        case BOT_MINUS: return LLVMBuildSub (c->builder, l, r, "sub");
        case BOT_MULT:  return LLVMBuildMul (c->builder, l, r, "mul");
        case BOT_DIV:   return LLVMBuildSDiv(c->builder, l, r, "div");
        case BOT_MOD:   return LLVMBuildSRem(c->builder, l, r, "rem");

        case BOT_EQUAL: return LLVMBuildICmp(c->builder, LLVMIntEQ,  l, r, "eq");
        case BOT_NEQ:   return LLVMBuildICmp(c->builder, LLVMIntNE,  l, r, "ne");
        case BOT_LESS:  return LLVMBuildICmp(c->builder, LLVMIntSLT, l, r, "lt");
        case BOT_LEQ:   return LLVMBuildICmp(c->builder, LLVMIntSLE, l, r, "le");
        case BOT_GREAT: return LLVMBuildICmp(c->builder, LLVMIntSGT, l, r, "gt");
        case BOT_GEQ:   return LLVMBuildICmp(c->builder, LLVMIntSGE, l, r, "ge");

        default:
            CG_FATAL("unhandled binary operator %d", b->kind);
            return NULL;
    }
}

static LLVMValueRef
gen_literal(CodegenContext *c, ASTNode *n)
{
    N_Literal *l = &n->as.literal;
    switch (l->kind)
    {
        case LT_INTEGER:
            return LLVMConstInt(LLVMInt32TypeInContext(c->ctx),
                                (unsigned long long)l->as.int_lit, true);
        case LT_BOOLEAN:
            return LLVMConstInt(LLVMInt1TypeInContext(c->ctx), l->as.bool_lit, false);
        case LT_CHARACTER:
            return LLVMConstInt(LLVMInt8TypeInContext(c->ctx),
                                (unsigned long long)(unsigned char)l->as.char_lit, false);
        case LT_STRING:
            return str_global(c, l->as.str_lit);
        case LT_FLOAT:
            return LLVMConstReal(LLVMDoubleTypeInContext(c->ctx), l->as.float_lit);
        default:
            CG_FATAL("unhandled literal kind %d", l->kind);
            return NULL;
    }
}

static LLVMValueRef
gen_expr(CodegenContext *c, ASTNode *e)
{
    ASTNode *n = strip(e);
    if (!n)
    { return NULL; }

    switch (n->kind)
    {
        case NT_LITERAL:
            return gen_literal(c, n);

        case NT_IDENT:
        {
            CGSym *s = scope_lookup(c, n->as.ident);
            if (s)
            { return LLVMBuildLoad2(c->builder, s->type, s->value, n->as.ident); }

            long long ev;
            if (enum_const_get(c, n->as.ident, &ev))
            { return LLVMConstInt(LLVMInt32TypeInContext(c->ctx), (unsigned long long)ev, true); }

            CG_FATAL("unknown identifier `%s` at %d:%d",
                        n->as.ident, n->loc.line, n->loc.col);
            return NULL;
        }

        case NT_BIN_OP:
            return gen_binop(c, n);

        case NT_UNY_OP:
        {
            N_UnyOp *u = &n->as.uny_op;

            if (u->kind == UOT_REF)
            {
                LValue lv;
                if (!gen_lvalue(c, u->operand, &lv))
                {
                    CG_FATAL("cannot take the address of this expression at %d:%d",
                                n->loc.line, n->loc.col);
                    return NULL;
                }
                return lv.ptr;
            }

            if (u->kind == UOT_DEREF)
            {
                LValue lv;
                if (gen_lvalue(c, e, &lv))
                { return LLVMBuildLoad2(c->builder, lv.type, lv.ptr, "deref"); }
                return NULL;
            }

            LLVMValueRef v = gen_expr(c, u->operand);
            return v ? LLVMBuildNeg(c->builder, v, "neg") : NULL;
        }

        case NT_FN_CALL:
            return gen_call(c, n);

        case NT_BUILTIN:
        {
            /* SIZE [ T ] -- T is parsed as an identifier */
            const char *tname = n->as.builtin.as.size->as.ident;

            LLVMTypeRef t = NULL;
            CGType *ut = type_lookup(c, tname);
            if (ut)
            { t = ut->type; }
            else
            {
                /* fall back on the base-type spellings */
                if      (!strcmp(tname, "B1"))    { t = LLVMInt1TypeInContext(c->ctx);  }
                else if (!strcmp(tname, "C1"))    { t = LLVMInt8TypeInContext(c->ctx);  }
                else if (!strcmp(tname, "U8")  || !strcmp(tname, "I8"))  { t = LLVMInt8TypeInContext(c->ctx);  }
                else if (!strcmp(tname, "U16") || !strcmp(tname, "I16")) { t = LLVMInt16TypeInContext(c->ctx); }
                else if (!strcmp(tname, "U32") || !strcmp(tname, "I32")) { t = LLVMInt32TypeInContext(c->ctx); }
                else if (!strcmp(tname, "U64") || !strcmp(tname, "I64")
                      || !strcmp(tname, "USIZE") || !strcmp(tname, "ISIZE"))
                { t = LLVMInt64TypeInContext(c->ctx); }
                else if (!strcmp(tname, "F32"))   { t = LLVMFloatTypeInContext(c->ctx);  }
                else if (!strcmp(tname, "F64"))   { t = LLVMDoubleTypeInContext(c->ctx); }
            }

            if (!t)
            {
                CG_FATAL("SIZE of unknown type `%s`", tname);
                return NULL;
            }
            return LLVMBuildIntCast2(c->builder, LLVMSizeOf(t),
                                     LLVMInt64TypeInContext(c->ctx), false, "size");
        }

        default:
            CG_FATAL("unhandled expression node %d at %d:%d",
                        n->kind, n->loc.line, n->loc.col);
            return NULL;
    }
}

/* ==========================================================================
 * Statements
 * ======================================================================== */

static bool
block_open(CodegenContext *c)
{
    LLVMBasicBlockRef bb = LLVMGetInsertBlock(c->builder);
    return bb && !LLVMGetBasicBlockTerminator(bb);
}

static void
gen_cond(CodegenContext *c, ASTNode *cond)
{
    LLVMBasicBlockRef merge = LLVMAppendBasicBlockInContext(c->ctx, c->fn, "if.end");

    /* IF */
    ASTNode *ifp = cond->as.cond.if_part;
    LLVMValueRef v = gen_expr(c, ifp->as.if_cond.expr);
    v = coerce(c, v, LLVMInt1TypeInContext(c->ctx));

    LLVMBasicBlockRef then_bb = LLVMAppendBasicBlockInContext(c->ctx, c->fn, "if.then");
    LLVMBasicBlockRef next_bb = LLVMAppendBasicBlockInContext(c->ctx, c->fn, "if.else");
    LLVMBuildCondBr(c->builder, v, then_bb, next_bb);

    LLVMPositionBuilderAtEnd(c->builder, then_bb);
    gen_block(c, ifp->as.if_cond.block);
    if (block_open(c))
    { LLVMBuildBr(c->builder, merge); }

    /* ELIF chain */
    for (ASTNode *el = cond->as.cond.elif_part; el; el = el->as.elif_cond.next_elif)
    {
        LLVMPositionBuilderAtEnd(c->builder, next_bb);

        LLVMValueRef ev = gen_expr(c, el->as.elif_cond.expr);
        ev = coerce(c, ev, LLVMInt1TypeInContext(c->ctx));

        LLVMBasicBlockRef ethen = LLVMAppendBasicBlockInContext(c->ctx, c->fn, "elif.then");
        LLVMBasicBlockRef enext = LLVMAppendBasicBlockInContext(c->ctx, c->fn, "elif.else");
        LLVMBuildCondBr(c->builder, ev, ethen, enext);

        LLVMPositionBuilderAtEnd(c->builder, ethen);
        gen_block(c, el->as.elif_cond.block);
        if (block_open(c))
        { LLVMBuildBr(c->builder, merge); }

        next_bb = enext;
    }

    /* ELSE */
    LLVMPositionBuilderAtEnd(c->builder, next_bb);
    if (cond->as.cond.else_part)
    { gen_block(c, cond->as.cond.else_part->as.else_cond.block); }
    if (block_open(c))
    { LLVMBuildBr(c->builder, merge); }

    LLVMPositionBuilderAtEnd(c->builder, merge);
}

static void
gen_loop(CodegenContext *c, ASTNode *loop)
{
    LLVMBasicBlockRef body  = LLVMAppendBasicBlockInContext(c->ctx, c->fn, "loop.body");
    LLVMBasicBlockRef contn = LLVMAppendBasicBlockInContext(c->ctx, c->fn, "loop.cont");
    LLVMBasicBlockRef brk   = LLVMAppendBasicBlockInContext(c->ctx, c->fn, "loop.end");

    LLVMBasicBlockRef save_b = c->loop_break;
    LLVMBasicBlockRef save_c = c->loop_continue;
    c->loop_break    = brk;
    c->loop_continue = contn;

    LLVMBuildBr(c->builder, body);

    LLVMPositionBuilderAtEnd(c->builder, body);
    gen_block(c, loop->as.loop.block);
    if (block_open(c))
    { LLVMBuildBr(c->builder, contn); }

    LLVMPositionBuilderAtEnd(c->builder, contn);
    LLVMBuildBr(c->builder, body);

    c->loop_break    = save_b;
    c->loop_continue = save_c;

    LLVMPositionBuilderAtEnd(c->builder, brk);
}

static void
gen_stmt(CodegenContext *c, ASTNode *st)
{
    if (!block_open(c))
    { return; } /* unreachable code after a return/break */

    switch (st->as.stmt.kind)
    {
        case ST_VAR_DECL:
        {
            ASTNode *d = st->as.stmt.stmt;
            LLVMTypeRef ty = map_type(c, d->as.var_decl.type);
            const char *nm = d->as.var_decl.ident->as.ident;

            LLVMValueRef slot = LLVMBuildAlloca(c->builder, ty, nm);
            scope_define(c, nm, slot, ty, d->as.var_decl.type);

            if (d->as.var_decl.init)
            {
                LLVMValueRef v = coerce(c, gen_expr(c, d->as.var_decl.init), ty);
                LLVMBuildStore(c->builder, v, slot);
            }
        } break;

        case ST_RET:
        {
            ASTNode *r = st->as.stmt.stmt;
            if (r->as.ret.expr && LLVMGetTypeKind(c->ret_type) != LLVMVoidTypeKind)
            {
                LLVMValueRef v = coerce(c, gen_expr(c, r->as.ret.expr), c->ret_type);
                LLVMBuildRet(c->builder, v);
            }
            else
            { LLVMBuildRetVoid(c->builder); }
        } break;

        case ST_BREAK:
        {
            if (!c->loop_break)
            {
                CG_FATAL("BREAK outside of a loop at %d:%d", st->loc.line, st->loc.col);
                return;
            }
            LLVMBuildBr(c->builder, c->loop_break);
        } break;

        case ST_COND:
            gen_cond(c, st->as.stmt.stmt);
            break;

        case ST_LOOP:
            gen_loop(c, st->as.stmt.stmt);
            break;

        case ST_EXPR:
            gen_expr(c, st->as.stmt.stmt);
            break;

        default:
            CG_FATAL("unhandled statement kind %d", st->as.stmt.kind);
            break;
    }
}

static void
gen_block(CodegenContext *c, ASTNode *blk)
{
    if (!blk)
    { return; }

    scope_push(c);
    for (ASTNode *s = blk->as.block.stmts; s; s = s->as.stmt.next_stmt)
    { gen_stmt(c, s); }
    scope_pop(c);
}

/* ==========================================================================
 * Functions
 * ======================================================================== */

/* Declare (or find) the function for this N_FnDecl. */
static LLVMValueRef
gen_fn_proto(CodegenContext *c, ASTNode *decl)
{
    const char *name = decl->as.fn_decl.ident->as.ident;

    LLVMValueRef existing = LLVMGetNamedFunction(c->mod, name);
    if (existing)
    { return existing; }

    LLVMTypeRef ptypes[64];
    unsigned    n       = 0;
    bool        va      = false;

    for (ASTNode *p = decl->as.fn_decl.params; p && n < 64; p = p->as.parametre.next_param)
    {
        if (p->as.parametre.vaarg)
        { va = true; continue; }          /* the `...` sentinel is not a parameter */
        ptypes[n++] = map_type(c, p->as.parametre.type);
    }

    LLVMTypeRef ret = map_type(c, decl->as.fn_decl.type);
    LLVMTypeRef fty = LLVMFunctionType(ret, ptypes, n, va);

    return LLVMAddFunction(c->mod, name, fty);
}

static void
gen_fn_def(CodegenContext *c, ASTNode *def)
{
    ASTNode     *decl = def->as.fn_def.decl;
    LLVMValueRef fn   = gen_fn_proto(c, decl);

    c->fn       = fn;
    c->ret_type = map_type(c, decl->as.fn_decl.type);

    LLVMBasicBlockRef entry = LLVMAppendBasicBlockInContext(c->ctx, fn, "entry");
    LLVMPositionBuilderAtEnd(c->builder, entry);

    scope_push(c);

    /* Parameters get their own stack slot so they can be assigned and
       have their address taken, like any other local. */
    unsigned i = 0;
    for (ASTNode *p = decl->as.fn_decl.params; p; p = p->as.parametre.next_param)
    {
        if (p->as.parametre.vaarg)
        { continue; }

        const char *pn = p->as.parametre.ident->as.ident;
        LLVMTypeRef pt = map_type(c, p->as.parametre.type);

        LLVMValueRef slot = LLVMBuildAlloca(c->builder, pt, pn);
        LLVMBuildStore(c->builder, LLVMGetParam(fn, i), slot);
        scope_define(c, pn, slot, pt, p->as.parametre.type);
        ++i;
    }

    gen_block(c, def->as.fn_def.block);

    /* Exactly one terminator, and only if the body left the block open. */
    if (block_open(c))
    {
        if (LLVMGetTypeKind(c->ret_type) == LLVMVoidTypeKind)
        { LLVMBuildRetVoid(c->builder); }
        else
        { LLVMBuildRet(c->builder, LLVMConstNull(c->ret_type)); }
    }

    scope_pop(c);
    c->fn = NULL;
}

/* ==========================================================================
 * Type definitions
 * ======================================================================== */

static void
gen_type_def(CodegenContext *c, ASTNode *td)
{
    const char *name = td->as.type_def.ident->as.ident;

    if (td->as.type_def.kind == TD_ENUM)
    {
        CGType *ut = type_add(c, name);
        ut->type   = LLVMInt32TypeInContext(c->ctx);

        long long v = 0;
        for (ASTNode *f = td->as.type_def.tdef->as.enumeration.fields;
             f;
             f = f->as.enum_flds.next_field)
        { enum_const_add(c, f->as.enum_flds.ident->as.ident, v++); }
        return;
    }

    if (td->as.type_def.kind == TD_RECORD)
    {
        ASTNode *rec = td->as.type_def.tdef;
        bool is_union = (rec->as.record.kind == TDRT_UNION);

        CGType *ut  = type_add(c, name);
        ut->record  = rec;
        ut->is_union = is_union;
        ut->type    = LLVMStructCreateNamed(c->ctx, name);

        LLVMTypeRef ftypes[64];
        unsigned    n = 0;

        if (is_union)
        {
            /* LLVM has no union: reserve the largest member and let member
               access reinterpret the same address. */
            LLVMTargetDataRef  td      = LLVMGetModuleDataLayout(c->mod);
            unsigned long long biggest = 0;
            LLVMTypeRef        widest  = LLVMInt8TypeInContext(c->ctx);

            for (ASTNode *f = rec->as.record.fields; f; f = f->as.rcrd_flds.next_field)
            {
                LLVMTypeRef        ft = map_type(c, f->as.rcrd_flds.type);
                unsigned long long sz = LLVMABISizeOfType(td, ft);
                if (sz > biggest)
                { biggest = sz; widest = ft; }
            }
            ftypes[n++] = widest;
        }
        else
        {
            for (ASTNode *f = rec->as.record.fields; f && n < 64; f = f->as.rcrd_flds.next_field)
            { ftypes[n++] = map_type(c, f->as.rcrd_flds.type); }
        }

        LLVMStructSetBody(ut->type, ftypes, n, false);
        return;
    }

    /* TD_ALIAS */
    CGType *ut = type_add(c, name);
    ut->type   = map_type(c, td->as.type_def.tdef);
}

/* ==========================================================================
 * Entry points
 * ======================================================================== */

void
codegen_init(CodegenContext *c, const char *module_name, Meta *meta)
{
    c->ctx     = LLVMContextCreate();
    c->mod     = LLVMModuleCreateWithNameInContext(module_name, c->ctx);
    c->builder = LLVMCreateBuilderInContext(c->ctx);
    c->meta    = meta;

    /* Without a data layout every ABI size query is meaningless, which is
       what union layout and SIZE [ T ] are built on. Take the host's. */
    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();

    char *triple = LLVMGetDefaultTargetTriple();
    LLVMSetTarget(c->mod, triple);

    LLVMTargetRef target = NULL;
    char *terr = NULL;
    if (LLVMGetTargetFromTriple(triple, &target, &terr) == 0)
    {
        LLVMTargetMachineRef tm = LLVMCreateTargetMachine(
            target, triple, "generic", "",
            LLVMCodeGenLevelDefault, LLVMRelocDefault, LLVMCodeModelDefault);
        LLVMTargetDataRef td = LLVMCreateTargetDataLayout(tm);
        char *dl = LLVMCopyStringRepOfTargetData(td);
        LLVMSetDataLayout(c->mod, dl);
        LLVMDisposeMessage(dl);
        LLVMDisposeTargetData(td);
        LLVMDisposeTargetMachine(tm);
    }
    if (terr)
    { LLVMDisposeMessage(terr); }
    LLVMDisposeMessage(triple);

    c->scope = NULL;
    c->types = calloc(1, sizeof(CGTypes));
    c->strs  = calloc(1, sizeof(CGStrs));
    assert(c->types && c->strs && "OOM");

    c->fn            = NULL;
    c->ret_type      = NULL;
    c->loop_break    = NULL;
    c->loop_continue = NULL;
}

void
codegen_generate(ASTNode *root, CodegenContext *c)
{
    /* Types first, then every prototype, then the bodies -- so a call can
       name a function that is defined further down the file. */
    for (ASTNode *ts = root->as.tu.tu_stmt; ts; ts = ts->as.tu_stmt.next_tu_stmt)
    {
        if (ts->as.tu_stmt.kind == TUST_TYPE_DEF)
        { gen_type_def(c, ts->as.tu_stmt.tu_stmt); }
    }

    for (ASTNode *ts = root->as.tu.tu_stmt; ts; ts = ts->as.tu_stmt.next_tu_stmt)
    {
        ASTNode *n = ts->as.tu_stmt.tu_stmt;
        if (ts->as.tu_stmt.kind == TUST_FN_DECL)
        { gen_fn_proto(c, n); }
        else if (ts->as.tu_stmt.kind == TUST_FN_DEF)
        { gen_fn_proto(c, n->as.fn_def.decl); }
    }

    scope_push(c); /* module scope */
    for (ASTNode *ts = root->as.tu.tu_stmt; ts; ts = ts->as.tu_stmt.next_tu_stmt)
    {
        if (ts->as.tu_stmt.kind == TUST_FN_DEF)
        { gen_fn_def(c, ts->as.tu_stmt.tu_stmt); }
    }
    scope_pop(c);
}

void
codegen_deinit(CodegenContext *c, const char *filename)
{
    char *err = NULL;
    if (LLVMVerifyModule(c->mod, LLVMReturnStatusAction, &err) && err && *err)
    { TRACE_ERROR("LLVM verify: %s", err); }
    if (err)
    { LLVMDisposeMessage(err); }

    err = NULL;
    if (LLVMPrintModuleToFile(c->mod, filename, &err))
    {
        TRACE_ERROR("failed to write %s: %s", filename, err ? err : "?");
        if (err) { LLVMDisposeMessage(err); }
    }

    while (c->scope)
    { scope_pop(c); }

    free(c->types->items);
    free(c->types->consts);
    free(c->types);
    free(c->strs->items);
    free(c->strs);

    LLVMDisposeBuilder(c->builder);
    LLVMDisposeModule(c->mod);
    LLVMContextDispose(c->ctx);
}
