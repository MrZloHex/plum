#include "ir.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#define DYNSTR_IMPL
#include "dynstr.h"


#warning "REFACTOR IT"
static int reg_counter = 0;
static int
new_reg(void)
{ return reg_counter++; }

void
ir_init(IR *ir, Meta *meta, AST *ast)
{
    ir->ast = ast;
    ir->meta = meta;
    dynstr_init(&ir->glbl, 1024);
    dynstr_init(&ir->text, 4096);
    dynstr_init(&ir->decl, 1024);
    dynstr_init(&ir->ir,   8192);
}

static char *
gen_type(Node *type)
{
    if (type->as.type.ptrs > 0)
    { return "ptr"; }

    switch(type->as.type.type)
    {
        case T_C1:    return "i8";
        case T_C2:    return "i16";
        case T_C4:    return "i32";
        case T_U8:    return "i8";
        case T_U16:   return "i16";
        case T_U32:   return "i32";
        case T_U64:   return "i64";
        case T_I8:    return "i8";
        case T_I16:   return "i16";
        case T_I32:   return "i32";
        case T_I64:   return "i64";
        case T_ABYSS: return "void";
        case T_QUANT: assert(0 && "UNREACHABLE");
    }

    assert(0 && "UNKOWN TYPE");
}

static DynString
gen_params(IR *ir, DynString *str, bool name)
{ 
    Node *p = ast_next(ir->ast);
    assert(p->type == NT_PARAMETRE && "NOT PARAM");

    DynString addr;
    if (name)
    { dynstr_init(&addr, 8); }

    dynstr_append(str, '(');
    Node *param = p;
    for (;;)
    {
        Node *type = ast_next(ir->ast);
        Node *id   = ast_next(ir->ast);
        assert(type->type == NT_TYPE  && "NOT TYPE");
        assert(id->type   == NT_IDENT && "NOT ID");

        dynstr_append_fstr
        (
            str, "%s noundef %s%s, ",
            gen_type(type),
            name ? "%" : "",
            name ? id->as.ident : ""
        );

        if (name)
        {
            dynstr_append_fstr
            (
                &addr, "  %%%s_addr = alloca %s\n",
                id->as.ident, gen_type(type)
            );
            dynstr_append_fstr
            (
                &addr, "  store %s %%%s, %s%s %%%s_addr\n",
                gen_type(type), id->as.ident,
                gen_type(type),
                (type->as.type.ptrs ? "" : "*"),
                id->as.ident
            );
        }

        param = param->as.parametre.next;
        if (param)
        { ast_next(ir->ast); } // PARAMETRE
        else
        { break; }
        
    }
    dynstr_set(str, str->size-2, ')');
    dynstr_set(str, str->size-1, '\n');

    return addr;
}

static void
gen_fn_decl(IR *ir)
{
    ast_next(ir->ast); // DECL
    Node *type = ast_next(ir->ast);
    Node *id   = ast_next(ir->ast);
    assert(type->type == NT_TYPE  && "NOT TYPE");
    assert(id->type   == NT_IDENT && "NOT ID");

    dynstr_append_fstr
    (
        &ir->decl, "declare %s @%s",
        gen_type(type),
        id->as.ident
    );

#warning "ADD HANDLING EMPTY PARAM LIST IN FN DECL"
    gen_params(ir, &ir->decl, false);
}

static Node *
gen_ident(IR *ir, int r, Node *etype)
{
    Node *id = ast_next(ir->ast);
    assert(id->type == NT_IDENT && "NOT IDENT");

    int is_param = meta_is_param(ir->curr, id->as.ident);
    if (is_param < 0)
    { assert(0 && "NO SUCH IDENT"); }
    
    if (!etype)
    {
        etype = meta_find_type_in_scope(ir->curr, id->as.ident);
        assert(etype && "NO SUCH VAR");
    }

    dynstr_append_fstr
    (
        &ir->text, "  %%r%d = load %s, %s* %%%s%s\n",
        r, gen_type(etype), gen_type(etype),
        id->as.ident, (is_param ? "_addr" : "")
    );

    return etype;
}

static void
gen_chr_lit(IR *ir, int r, Node *etype)
{
    Node *lit = ast_next(ir->ast);
    assert(lit->type == NT_CHR_LIT && "NOT CHR LIT");
    assert(etype && "HUY");
    assert(etype->type == NT_TYPE && "NOT TYPE");

    dynstr_append_fstr
    ( 
        &ir->text, "  %%r%d = add %s 0, %d\n" ,
        r, gen_type(etype), lit->as.chr_lit
    );
}

static void
gen_num_lit(IR *ir, int r, Node *etype)
{
    Node *lit = ast_next(ir->ast);
    assert(lit->type == NT_NUM_LIT && "NOT NUM LIT");
    assert(etype && "HUY");
    assert(etype->type == NT_TYPE && "NOT TYPE");

    dynstr_append_fstr
    ( 
        &ir->text, "  %%r%d = add %s 0, %d\n" ,
        r, gen_type(etype), lit->as.num_lit
    );
}

static Node *
gen_expr(IR *ir, int r, Node *exp_type);

static void
gen_fn_call(IR *ir, int r)
{
    Node *call = ast_next(ir->ast);
    assert(call->type == NT_FN_CALL && "NOT FN CALL");

    Node *id = ast_next(ir->ast);
    assert(id->type == NT_IDENT && "NOT ID");

    Node *a = ast_next(ir->ast);
    assert(a->type == NT_ARGUMENTS && "NOT ARGUMENT");

    argreg_init(&ir->args, 8);

    Node *arg = a;
    for (;;)
    {
        int reg = new_reg();
        Node *type = gen_expr(ir, reg, NULL);
        argreg_append(&ir->args, (ArgumentREG){ .reg = reg, .type = type });

        arg = arg->as.arguments.next;
        if (arg)
        { ast_next(ir->ast); }
        else
        { break; }
    }

    Node *fn = meta_find_func(ir->meta, id->as.ident);
    assert(fn && "FN DECL NOT FOUND");

    dynstr_append_fstr
    ( 
        &ir->text, "  %%r%d = call %s @%s(",
        r, gen_type(fn->as.fn_decl.type), id->as.ident
    );

    for (size_t i = 0; i < ir->args.size; ++i)
    {
        ArgumentREG arg = ir->args.data[i];
        dynstr_append_fstr(&ir->text, "%s %%r%d, ", gen_type(arg.type), arg.reg);
    }
    if (ir->args.size)
    {
        dynstr_remove(&ir->text, ir->text.size-1);
        dynstr_remove(&ir->text, ir->text.size-1);
    }

    dynstr_append_str(&ir->text, ")\n");

    argreg_deinit(&ir->args);
}


static void
gen_bin_op(IR *ir, int res, Node *exp_type)
{
    Node *binop = ast_next(ir->ast);
    assert(binop->type == NT_BIN_OP && "NOT BIN OP");

    if (binop->as.bin_op.type == BOT_PLUS)
    {
        int rr = new_reg();
        int lr = new_reg();

        gen_expr(ir, rr, exp_type);
        gen_expr(ir, lr, exp_type);
        
        dynstr_append_fstr
        (
            &ir->text, "  %%r%d = add %s %%r%d, %%r%d\n",
            res, gen_type(exp_type),
            lr, rr
        );
    }
    else if (binop->as.bin_op.type == BOT_ASSIGN)
    {
        assert(binop->as.bin_op.left->as.expr.type == ET_IDENT && "LVAL NOT IDENT");
        int rr = new_reg();

        Node *id = binop->as.bin_op.left->as.expr.expr;
        Node *type = meta_find_type_in_scope(ir->curr, id->as.ident);
        assert(type && "NO SUCH IDENT");

        gen_expr(ir, rr, type);

        // I KNOW THAT LVALUE IS IDENT
        dynstr_append_fstr
        (
            &ir->text, "  store %s %%r%d, %s* %%%s\n",
            gen_type(type), rr,
            gen_type(type), id->as.ident
        );
        // AND NOW SKIP IT
        ast_next(ir->ast);
        ast_next(ir->ast);
    }
    else
    {
        assert(0 && "NOT IMPL");
    }
}

static Node *
gen_expr(IR *ir, int r, Node *exp_type)
{
    Node *expr = ast_next(ir->ast);
    assert(expr->type == NT_EXPR && "NOT EXPR");
    
    if (expr->as.expr.type == ET_BIN_OP)
    { gen_bin_op(ir, r, exp_type); }
    else if (expr->as.expr.type == ET_IDENT)
    { return gen_ident(ir, r, exp_type); }
    else if (expr->as.expr.type == ET_NUM_LIT)
    { gen_num_lit(ir, r, exp_type); }
    else if (expr->as.expr.type == ET_CHR_LIT)
    { gen_chr_lit(ir, r, exp_type); }
    else if (expr->as.expr.type == ET_FN_CALL)
    { gen_fn_call(ir, r); }
    else
    {
        assert(0 && "NOT IMPL");
    }

    return NULL;
}

static void
gen_var_decl(IR *ir)
{
    Node *decl = ast_next(ir->ast);
    assert(decl->type == NT_VAR_DECL && "NOT VAR DECL");

    Node *type = ast_next(ir->ast);
    Node *id   = ast_next(ir->ast);
    assert(type->type == NT_TYPE  && "NOT TYPE");
    assert(id->type   == NT_IDENT && "NOT ID");

    dynstr_append_fstr
    (
        &ir->text, "  %%%s = alloca %s\n",
        id->as.ident, gen_type(type)
    );
}

static void
gen_return(IR *ir)
{
    Node *r = ast_next(ir->ast);
    assert(r->type == NT_RET && "NOT RETURN");

    Node *fn_type = ir->curr->scope->as.var_decl.type;
    if (fn_type->as.type.type == T_ABYSS)
    {
        dynstr_append_str(&ir->text, "  ret void\n");
        return;
    }
    else
    {
        int ret = new_reg();
        gen_expr(ir, ret, fn_type);
        dynstr_append_fstr(&ir->text, "  ret %s %%r%d\n", gen_type(fn_type), ret);
    }
}

static void
gen_stmt(IR *ir)
{
    Node *stmt = ast_next(ir->ast);
    assert(stmt->type == NT_STATEMENT && "NOT A STATEMENT");

    if (stmt->as.stmt.type == ST_RET)
    { gen_return(ir); }
    else if (stmt->as.stmt.type == ST_VAR_DECL)
    { gen_var_decl(ir); }
    else if (stmt->as.stmt.type == ST_EXPR)
    { gen_expr(ir, -1, NULL); }
    else
    {
        assert(0 && "NOT IMPL");
    }
}

static void
gen_fn_def(IR *ir)
{
    ast_next(ir->ast); // DEF
    ast_next(ir->ast); // DECL
    Node *type = ast_next(ir->ast);
    Node *id   = ast_next(ir->ast);
    assert(type->type == NT_TYPE  && "NOT TYPE");
    assert(id->type   == NT_IDENT && "NOT ID");

    ir->curr = meta_find_scope(ir->meta, id->as.ident);

    dynstr_append_fstr
    (
        &ir->text, "define dso_local %s @%s",
        gen_type(type),
        id->as.ident
    );


    if (ir->curr->params.size)
    {
        DynString p = gen_params(ir, &ir->text, true);
        dynstr_set(&ir->text, ir->text.size-1, ' ');
        dynstr_append_str(&ir->text, "{\n");

        dynstr_append_str(&ir->text, p.data);
        dynstr_deinit(&p);
    }
    else
    {
        dynstr_append_str(&ir->text, "() {\n");
    }

    Node *b = ast_next(ir->ast);
    Node *block = b;
    for (;;)
    {
        assert(b->type == NT_BLOCK && "NOT A BLOCK");
        gen_stmt(ir);

        printf("==============BLOCK=============\n");
        printf("%s\n", ir->text.data);
        printf("================================\n");
    
        block = block->as.block.next;
        if (block)
        { ast_next(ir->ast); }
        else
        { break; }
    }

    dynstr_append_str(&ir->text, "}\n\n");
}

static void
gen_programme(IR *ir)
{
    for (;;)
    {
        Node *s = ast_next(ir->ast);
        assert(s->type == NT_PRG_STMT && "NOT PRG STMT");

        if (s->as.prg_stmt.type == PST_FN_DECL)
        { gen_fn_decl(ir); }
        if (s->as.prg_stmt.type == PST_FN_DEF)
        { gen_fn_def(ir); }

        s = ast_next(ir->ast);
        if (!s)
        { break; }

        assert(s->type == NT_PROGRAMME && "NOT A PROGRAMME");
    }
}

void
ir_generate(IR *ir)
{
    Node *n = ast_next(ir->ast);
    if (n->type == NT_PROGRAMME)
    { gen_programme(ir); }


    dynstr_append_str(&ir->ir, ir->glbl.data);
    dynstr_append_str(&ir->ir, ir->text.data);
    dynstr_append_str(&ir->ir, ir->decl.data);
}

DEFINE_DYNARRAY(argreg, ArgRegs, ArgumentREG);
