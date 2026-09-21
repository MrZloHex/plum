#include "codegen.h"
#include <llvm/Config/llvm-config.h>
#include <llvm-c/Analysis.h>
#include <llvm-c/BitWriter.h>

// инициализация
void
codegen_init(
    CodegenContext *c,
    const char     *module_name,
    Meta           *meta
) {
    c->meta    = meta;
    c->ctx     = LLVMContextCreate();
    c->mod     = LLVMModuleCreateWithNameInContext(module_name, c->ctx);
    c->builder = LLVMCreateBuilderInContext(c->ctx);
    lmap_init(&c->locals, 16);
}

// сопоставление базового типа
static LLVMTypeRef
map_base_type(
    N_BaseType bt,
    LLVMContextRef ctx
) {
    switch (bt) {
    case BT_I32: return LLVMInt32TypeInContext(ctx);
    case BT_I64: return LLVMInt64TypeInContext(ctx);
    case BT_F32: return LLVMFloatTypeInContext(ctx);
    case BT_F64: return LLVMDoubleTypeInContext(ctx);
    case BT_B1:  return LLVMInt1TypeInContext(ctx);
    default:     return LLVMVoidTypeInContext(ctx);
    }
}

// рекурсивное маппинг N_Type (с указателями)
static LLVMTypeRef
map_type(
    ASTNode         *type_node,
    CodegenContext  *c
) {
    N_Type *nt = &type_node->as.type;
    // базовый или пользовательский
    LLVMTypeRef base;
    if (nt->kind == TT_BASE_TYPE) {
        // внутри nt->type — узел NT_BASE_TYPE
        N_BaseType bt = nt->type->as.base_type;
        base = map_base_type(bt, c->ctx);
    } else {
        // пользовательский: найдем в meta.types map
        const char *name = nt->type->as.ident;
        ASTNode *tdef;
        name_get(&c->meta->types, (char*)name, &tdef);
        // предположим, alias -> recurse или record -> struct
        base = LLVMVoidTypeInContext(c->ctx); // TODO: обработка user-types
    }
    // указатели
    for (size_t i = 0; i < nt->ptrs; ++i)
        base = LLVMPointerType(base, 0);
    return base;
}

// прототипы генераторов
static void gen_node(ASTNode *n, CodegenContext *c);
static LLVMValueRef gen_expr(ASTNode *e, CodegenContext *c);
static void gen_block(ASTNode *blk, CodegenContext *c);
static void gen_fn_def(ASTNode *fn, CodegenContext *c);

static void
gen_block(
    ASTNode        *blk,
    CodegenContext *c
) {
    // каждый VAR_DECL в block -> локальный
    for (ASTNode *s = blk->as.block.stmts;
         s;
         s = s->as.stmt.next_stmt)
    {
        gen_node(s->as.stmt.stmt, c);
    }
}

static void
gen_fn_def(
    ASTNode        *fn,
    CodegenContext *c
) {
    N_FnDef  *fd   = &fn->as.fn_def;
    N_FnDecl *decl = &fd->decl->as.fn_decl;

    // параметры
    size_t pc = 0;
    for (ASTNode *p = decl->params; p; p = p->as.parametre.next_param)
        ++pc;
    LLVMTypeRef *args = calloc(pc, sizeof *args);
    size_t i = 0;
    for (ASTNode *p = decl->params;
         p;
         p = p->as.parametre.next_param, ++i)
    {
        args[i] = map_type(p->as.parametre.type, c);
    }
    // сигнатура
    LLVMTypeRef ret_ty = map_type(decl->type, c);
    LLVMTypeRef fty    = LLVMFunctionType(ret_ty,
                                          args,
                                          (unsigned)pc,
                                          false);
    LLVMValueRef fnv = LLVMAddFunction(c->mod,
                                       decl->ident->as.ident,
                                       fty);
    free(args);

    // entry
    LLVMBasicBlockRef entry = LLVMAppendBasicBlock(fnv, "entry");
    LLVMPositionBuilderAtEnd(c->builder, entry);
    // регистрируем параметры
    for (i = 0; i < pc; ++i) {
        const char *n = decl->params->as.parametre.ident->as.ident;
        LLVMValueRef pv = LLVMGetParam(fnv, (unsigned)i);
        lmap_put(&c->locals, (char*)n, pv);
    }
    // тело
    gen_block(fd->block, c);
    // завершающий ret
    if (ret_ty == LLVMVoidTypeInContext(c->ctx))
        LLVMBuildRetVoid(c->builder);
    LLVMBuildRet(c->builder, LLVMConstNull(ret_ty));
}

static void
gen_node(
    ASTNode        *n,
    CodegenContext *c
) {
    switch (n->kind) {
        case NT_FN_DEF:
            gen_fn_def(n, c);
            break;
        case NT_VAR_DECL: {
            // alloca + init
            LLVMTypeRef ty = map_type(n->as.var_decl.type, c);
            LLVMValueRef all = LLVMBuildAlloca(c->builder,
                                               ty,
                                               n->as.var_decl.ident->as.ident);
            if (n->as.var_decl.init) {
                LLVMValueRef iv = gen_expr(n->as.var_decl.init, c);
                LLVMBuildStore(c->builder, iv, all);
            }
            lmap_put(&c->locals,
                     n->as.var_decl.ident->as.ident,
                     all);
            break;
        }
        case NT_RET: {
            LLVMValueRef rv = NULL;
            if (n->as.ret.expr)
                rv = gen_expr(n->as.ret.expr, c);
            LLVMBuildRet(c->builder, rv);
            break;
        }
        default:
            // прочие узлы, например expr
            gen_expr(n, c);
            break;
    }
}

static LLVMValueRef
gen_expr(
    ASTNode        *e,
    CodegenContext *c
) {
    N_Expr *ex = &e->as.expr;
    switch (ex->kind) {
        case ET_LITERAL: {
            N_Literal *L = &ex->expr->as.literal;
            if (L->kind == LT_INTEGER)
                return LLVMConstInt(LLVMInt32TypeInContext(c->ctx),
                                    (uint64_t)L->as.int_lit,
                                    true);
            if (L->kind == LT_BOOLEAN)
                return LLVMConstInt(LLVMInt1TypeInContext(c->ctx),
                                    L->as.bool_lit,
                                    false);
            return NULL;
        }
        case ET_IDENT: {
            LLVMValueRef ptr;
            if (lmap_get(&c->locals,
                         e->as.expr.expr->as.ident,
                         &ptr) != 0)
            {
                fprintf(stderr, "Unknown var %s\n",
                        e->as.expr.expr->as.ident);
                exit(1);
            }
            // загрузка
            return LLVMBuildLoad2(c->builder,
                                  LLVMTypeOf(ptr),
                                  ptr,
                                  "loadtmp");
        }
        case ET_BIN_OP: {
            N_BinOp *bo = &ex->expr->as.bin_op;
            LLVMValueRef l = gen_expr(bo->left, c);
            LLVMValueRef r = gen_expr(bo->right, c);
            switch (bo->kind) {
                case BOT_PLUS:  return LLVMBuildAdd(c->builder, l, r, "add");
                case BOT_MINUS: return LLVMBuildSub(c->builder, l, r, "sub");
                case BOT_MULT:  return LLVMBuildMul(c->builder, l, r, "mul");
                case BOT_DIV:   return LLVMBuildSDiv(c->builder, l, r, "div");
                case BOT_ASSIGN: {
                    // получить указатель lvalue
                    LLVMValueRef ptr;
                    lmap_get(&c->locals,
                             bo->left->as.expr.expr->as.ident,
                             &ptr);
                    LLVMBuildStore(c->builder, r, ptr);
                    return r;
                }
                default: return NULL;
            }
        }
        default:
            return NULL;
    }
}

void
codegen_generate(
    ASTNode        *root,
    CodegenContext *c
) {
    for (ASTNode *ts = root->as.tu.tu_stmt;
         ts;
         ts = ts->as.tu_stmt.next_tu_stmt)
    {
        gen_node(ts->as.tu_stmt.tu_stmt, c);
    }
}

void
codegen_deinit(
    CodegenContext *c,
    const char     *filename
) {
    char *err = NULL;
    LLVMVerifyModule(c->mod, LLVMReturnStatusAction, &err);
    if (err) {
        fprintf(stderr, "LLVM Verify Error: %s\n", err);
        LLVMDisposeMessage(err);
    }
    LLVMPrintModuleToFile(c->mod, filename, &err);
    LLVMDisposeBuilder(c->builder);
    LLVMDisposeModule(c->mod);
    LLVMContextDispose(c->ctx);
    lmap_deinit(&c->locals);
}

DEFINE_DYNMAP(lmap, char *, LLVMValueRef, str_hash, str_eq);
