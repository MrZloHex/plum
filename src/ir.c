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
        printf("PARAM %s\n", node_types_str[param->type]);
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

static void
gen_ident(IR *ir, int r, Node *etype)
{
    Node *id = ast_next(ir->ast);
    assert(id->type == NT_IDENT && "NOT IDENT");

    int is_param = meta_is_param(ir->curr, id->as.ident);
    if (is_param < 0)
    { assert(0 && "NO SUCH IDENT"); }

    dynstr_append_fstr
    (
        &ir->text, "  %%r%d = load %s, %s* %%%s%s\n",
        r, gen_type(etype), gen_type(etype),
        id->as.ident, (is_param ? "_addr" : "")
    );
}

static void
gen_expr(IR *ir, int r, Node *exp_type);

static void
gen_bin_op(IR *ir, int res, Node *exp_type)
{
    Node *binop = ast_next(ir->ast);
    assert(binop->type == NT_BIN_OP && "NOT BIN OP");

    if (binop->as.bin_op.type == BOT_PLUS)
    {
        int lr = new_reg();
        int rr = new_reg();

        gen_expr(ir, lr, exp_type);
        gen_expr(ir, rr, exp_type);
        
        dynstr_append_fstr
        (
            &ir->text, "  %%r%d = add %s %%r%d, %%r%d\n",
            res, gen_type(exp_type),
            lr, rr
        );
    }
    else
    {
        assert(0 && "NOT IMPL");
    }
}

static void
gen_expr(IR *ir, int r, Node *exp_type)
{

    Node *expr = ast_next(ir->ast);
    assert(expr->type == NT_EXPR && "NOT EXPR");
    
    if (expr->as.expr.type == ET_BIN_OP)
    {
        gen_bin_op(ir, r, exp_type);
    }
    else if (expr->as.expr.type == ET_IDENT)
    {
        gen_ident(ir, r, exp_type);
    }
    else
    {
        assert(0 && "NOT IMPL");
    }
}

static void
gen_var_decl(IR *ir)
{
    Node *decl = ast_next(ir->ast);
    assert(decl->type == NT_VAR_DECL && "NOT VAR DECL");
    Node *id   = ast_next(ir->ast);
    Node *type = ast_next(ir->ast);
    printf(" TYPE %s\n", node_types_str[type->type]);
    assert(type->type == NT_TYPE  && "NOT TYPE");
    assert(id->type   == NT_IDENT && "NOT ID");

    dynstr_append_fstr
    (
        &ir->text, "  %%%s = alloca %s\n",
        id->as.ident, gen_type(type)
    );
    dynstr_append_fstr
    (
        &ir->text, "  store %s %%%s, %s%s %%%s_addr\n",
        gen_type(type), id->as.ident,
        gen_type(type),
        (type->as.type.ptrs ? "" : "*"),
        id->as.ident
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
gen_block(IR *ir)
{
    Node *stmt = ast_next(ir->ast);
    assert(stmt->type == NT_STATEMENT && "NOT A STATEMENT");

    if (stmt->as.stmt.type == ST_RET)
    { gen_return(ir); }
    else if (stmt->as.stmt.type == ST_VAR_DECL)
    {
        gen_var_decl(ir);
    }
    else
    {
        assert(0 && "NOT IMPL");
    }
        
    // ast_next(ir->ast);
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

    Node *b = ast_next(ir->ast);
    assert(b->type == NT_BLOCK && "NOT A BLOCK");
    gen_block(ir);

    dynstr_append_str(&ir->text, "}\n\n");
}

static void
gen_programme(IR *ir)
{
aga:
    Node *s = ast_next(ir->ast);
    assert(s->type == NT_PRG_STMT && "NOT PRG STMT");
    if (s->as.prg_stmt.type == PST_FN_DECL)
    { gen_fn_decl(ir); }
    if (s->as.prg_stmt.type == PST_FN_DEF)
    { gen_fn_def(ir); }

    s = ast_next(ir->ast);
    assert(s && "NULL");
    printf("\n%s\n", ir->decl.data);
    printf("\n%s\n", ir->text.data);
    printf("NEXT %s\n", node_types_str[s->type]);
    if (s->type == NT_STATEMENT)
        node_dump_stmt(s, 1);
    if (s->type == NT_PRG_STMT)
        node_dump_prg_stmt(s, 1);
    
    if (s->type == NT_PROGRAMME)
    { goto aga; }
}

void
ir_generate(IR *ir)
{
    Node *n = ast_next(ir->ast);
    if (n->type == NT_PROGRAMME)
    { gen_programme(ir); }
}




static int str_counter = 0;
static int
new_str(void)
{ return str_counter++; }

typedef struct ParamEntry
{
    char *name;
    struct ParamEntry *next;
} ParamEntry;

static ParamEntry *current_params = NULL;

static void add_param(char *name) {
    ParamEntry *entry = malloc(sizeof(ParamEntry));
    entry->name = name;
    entry->next = current_params;
    current_params = entry;
}

static int is_parameter(const char *name) {
    ParamEntry *iter = current_params;
    while (iter) {
         if (strcmp(iter->name, name) == 0)
              return 1;
         iter = iter->next;
    }
    return 0;
}

static void clear_params(void) {
    while (current_params) {
         ParamEntry *tmp = current_params;
         current_params = current_params->next;
         free(tmp);
    }
}

/* Utility: Recursively unwrap NT_EXPR nodes */
static Node* unwrap(Node *node) {
    while (node && node->type == NT_EXPR) {
        node = node->as.expr.expr;
    }
    return node;
}

/* Print an LLVM IR type for a type node (expected to be NT_TYPE) */
static void
printType(Node *node, DynString *str)
{
    if (!node || node->type != NT_TYPE || !str)
    {
        dynstr_append_str(str, "UNKNOWN TYPE");
        return;
    }
    N_Type t = node->as.type;
    if (t.ptrs == 0)
    {
        switch(t.type) {
             case T_C1:   dynstr_append_str(str, "i8"); break;
             case T_C2:   dynstr_append_str(str, "i16"); break;
             case T_C4:   dynstr_append_str(str, "i32"); break;
             case T_U8:   dynstr_append_str(str, "i8"); break;
             case T_U16:  dynstr_append_str(str, "i16"); break;
             case T_U32:  dynstr_append_str(str, "i32"); break;
             case T_U64:  dynstr_append_str(str, "i64"); break;
             case T_I8:   dynstr_append_str(str, "i8"); break;
             case T_I16:  dynstr_append_str(str, "i16"); break;
             case T_I32:  dynstr_append_str(str, "i32"); break;
             case T_I64:  dynstr_append_str(str, "i64"); break;
             default:     dynstr_append_str(str, "UNKNOWN TYPE"); break;
        }
    }
    else
    { dynstr_append_str(str, "ptr"); }
}

/* Forward declarations of internal generator functions */
static void generateProgram(Node *node, DynString *str, Meta *meta);
static void generateFnDef(Node *node, DynString *str, Meta *meta);
static void generateFnDecl(Node *node, DynString *str, Meta *meta);
static void generateBlock(Node *node, DynString *str, Meta *meta);
static void generateStatement(Node *node, DynString *str, Meta *meta);
static void generateExpr(Node *node, int targetReg, DynString *str, Meta *meta, Node *type);
static void generateVarDecl(Node *node, DynString *str, Meta *meta);
static void generateBinOp(Node *node, int targetReg, DynString *str, Meta *meta, Node *type);
static void generateFnCall(Node *node, int targetReg, DynString *str, Meta *meta);

void
generate_literals(Meta *meta, DynString *str)
{
    // @.str.1 = constant [6 x i8] c"HELLO\00"
    for (size_t i = 0; i < meta->strs.size; ++i)
    {
        char *raw = meta->strs.data[i]->as.str_lit;
        DynString s;
        dynstr_init(&s, strlen(raw)+10);
        dynstr_append_str(&s, raw);
        dynstr_insert_str(&s, strlen(raw) - 1, "\\00");

        dynstr_append_fstr(str, "@.str.%zu = constant [%d x i8] c%s\n", i+1, strlen(raw)-1, s.data);
        dynstr_deinit(&s);
    }
    dynstr_append(str, '\n');
}

void
generateIR(AST *ast, Meta *meta, DynString *str)
{
    if (!ast || !meta || !str)
    { return; }

    generate_literals(meta, str);

    Node *node = ast->root;
    if (node->type == NT_PROGRAMME)
    { generateProgram(node, str, meta); }
    else
    { dynstr_append_fstr(str, "; Unsupported top-level node type %d\n", node->type); }
}

/* Generate a programme: a linked list of function definitions */
static void
generateProgram(Node *node, DynString *str, Meta *meta) 
{
    for (Node *prog = node; prog != NULL; prog = prog->as.programme.next)
    {
         if (prog->as.programme.stmt->as.prg_stmt.type == PST_FN_DEF)
         { generateFnDef(prog->as.programme.stmt->as.prg_stmt.prg_stmt, str, meta); }
         else if (prog->as.programme.stmt->as.prg_stmt.type == PST_FN_DECL)
         { generateFnDecl(prog->as.programme.stmt->as.prg_stmt.prg_stmt, str, meta); }
    }
}

static MetaScope *curr_scope = NULL;

static void
generateFnDef(Node *node, DynString *str, Meta *meta) 
{
    if (!node || node->type != NT_FN_DEF)
    { return; }

    Node *fnDecl = node->as.fn_def.decl;
    Node *fnBlock = node->as.fn_def.block;
    if (!fnDecl || fnDecl->type != NT_FN_DECL)
    { return; }
    
    /* Print function header: define <ret_type> @<function_name>(<params>) { */
    dynstr_append_str(str, "define ");
    printType(fnDecl->as.fn_decl.type, str);
    
    Node *fname = unwrap(fnDecl->as.fn_decl.ident);

    // SAVE CURRENT SCOPE
    curr_scope = meta_find_scope(meta, fname->as.ident);
    
    if (fname && fname->type == NT_IDENT)
    { dynstr_append_fstr(str, " @%s(", (char*)fname->as.ident); }
    else
    { dynstr_append_str(str, " @<unknown>("); }
    
    Node *param = fnDecl->as.fn_decl.params;
    int first = 1;
    while (param)
    {
         if (param->type != NT_PARAMETRE)
         { break; }

         if (!first)
         { dynstr_append_str(str, ", "); }

         printType(param->as.parametre.type, str);
         Node *pname = unwrap(param->as.parametre.ident);
         if (pname && pname->type == NT_IDENT)
         { dynstr_append_fstr(str, " %%%s", (char*)pname->as.ident); }
         else
         { dynstr_append_str(str, " %%<unknown>"); }
         first = 0;
         param = param->as.parametre.next;
    }
    dynstr_append_str(str, ") {\n");
    
    /* Promote parameters into local allocas */
    for (param = fnDecl->as.fn_decl.params; param != NULL; param = param->as.parametre.next)
    {
         if (param->type != NT_PARAMETRE)
         { break; }

         Node *pname = unwrap(param->as.parametre.ident);
         if (pname && pname->type == NT_IDENT)
         {
              char *name = (char*)pname->as.ident;
              add_param(name);
              dynstr_append_fstr(str, "  %%%s_addr = alloca ", name);
              printType(param->as.parametre.type, str);
              dynstr_append_fstr(str, "\n");
              dynstr_append_fstr(str, "  store ");
              printType(param->as.parametre.type, str);
              dynstr_append_fstr(str, " %%%s, ", name);
              printType(param->as.parametre.type, str);
              dynstr_append_fstr(str, "* %%%s_addr\n", name);
         }
    }
    
    generateBlock(fnBlock, str, meta);
    
    dynstr_append_str(str, "}\n\n");
    clear_params();
}

static void
generateFnDecl(Node *node, DynString *str, Meta *meta)
{
    if (!node || node->type != NT_FN_DECL || !str || !meta)
    { return; }

    Node *fnDecl = node;
    
    dynstr_append_str(str, "declare ");
    printType(fnDecl->as.fn_decl.type, str);
    
    Node *fname = unwrap(fnDecl->as.fn_decl.ident);
    if (fname && fname->type == NT_IDENT)
    { dynstr_append_fstr(str, " @%s(", (char*)fname->as.ident); }
    else
    { dynstr_append_str(str, " @<unknown>("); }
    
    Node *param = fnDecl->as.fn_decl.params;
    int first = 1;
    while (param)
    {
         if (param->type != NT_PARAMETRE)
         { break; }

         if (!first)
         { dynstr_append_str(str, ", "); }
         printType(param->as.parametre.type, str);

         Node *pname = unwrap(param->as.parametre.ident);
         if (pname && pname->type == NT_IDENT)
         { dynstr_append_str(str, " noundef"); }
         else
         { dynstr_append_str(str, " %%<unknown>"); }
         first = 0;
         param = param->as.parametre.next;
    }
    dynstr_append_str(str, ")\n");
    
    clear_params();
}

/* Generate a block: a linked list of statements */
static void
generateBlock(Node *node, DynString *str, Meta *meta)
{
    if (!node || node->type != NT_BLOCK || !str || !meta)
    { return; }

    for (Node *blk = node; blk != NULL; blk = blk->as.block.next)
    {
         generateStatement(blk->as.block.stmt, str, meta);
    }
}

/* Generate a statement */
static void
generateStatement(Node *node, DynString *str, Meta *meta)
{
    if (!node || node->type != NT_STATEMENT || !str || !meta)
    { return; }

    switch (node->as.stmt.type)
    {
         case ST_VAR_DECL:
              generateVarDecl(node->as.stmt.stmt, str, meta);
              break;
         case ST_EXPR: {
              int reg = new_reg();
              generateExpr(node->as.stmt.stmt, reg, str, meta, NULL);
              break;
         }
         case ST_RET: {
              int reg = new_reg();
              Node *fn_type = curr_scope->scope->as.var_decl.type;
              generateExpr(node->as.stmt.stmt, reg, str, meta, fn_type);
              dynstr_append_str(str, "  ret ");
              printType(fn_type, str);
              dynstr_append_fstr(str, " %%r%d\n", reg);
              break;
         }
         default:
              dynstr_append_fstr(str, "  ; Unsupported statement type %d\n", node->as.stmt.type);
              break;
    }
}

/* Generate a variable declaration */
static void
generateVarDecl(Node *node, DynString *str, Meta *meta)
{
    if (!node || node->type != NT_VAR_DECL || !str || !meta)
    { return; }

    Node *vname = unwrap(node->as.var_decl.ident);
    if (vname && vname->type == NT_IDENT)
    { dynstr_append_fstr(str, "  %%%s = alloca ", (char*)vname->as.ident); }
    else
    { dynstr_append_str(str, "  %%<unknown> = alloca "); }

    printType(node->as.var_decl.type, str);
    dynstr_append_str(str, "\n");
}

/* Generate an expression */
static void
generateExpr(Node *node, int targetReg, DynString *str, Meta *meta, Node *type)
{
    if (!node || !str || !meta)
    { return; }

    printf("CURR `%s`\n\n\n\n", str->data);
    node = unwrap(node);
    switch (node->type)
    {
         case NT_IDENT: {
              char *name = (char*)node->as.ident;
              if (is_parameter(name))
              { dynstr_append_fstr(str, "  %%r%d = load i32, i32* %%%s_addr\n", targetReg, name); }
              else
              { dynstr_append_fstr(str, "  %%r%d = load i32, i32* %%%s\n", targetReg, name); }
              break;
         }
         case NT_CHR_LIT:
              dynstr_append_fstr(str, "  %%r%d = add i32 0, %d\n", targetReg, node->as.chr_lit);
              break;
         case NT_STR_LIT:
              size_t str_n = new_str();
              dynstr_append_fstr(str, "  %%r%d = add i32 0, %d\n", targetReg, node->as.chr_lit);
              dynstr_append_str(str, "STRING LITERAL\n");
              break;
         case NT_NUM_LIT:
              dynstr_append_fstr(str, "  %%r%d = add i32 0, %d\n", targetReg, node->as.num_lit);
              break;
         case NT_BIN_OP:
              generateBinOp(node, targetReg, str, meta, type);
              break;
         case NT_FN_CALL:
              generateFnCall(node, targetReg, str, meta);
              break;
         case NT_RET:
              generateExpr(node->as.ret.expr, targetReg, str, meta, type);
              break;
         default:
              dynstr_append_fstr(str, "  ; Unsupported expression node type %d\n", node->type);
              break;
    }
}

/* Generate a binary operation */
static void
generateBinOp(Node *node, int targetReg, DynString *str, Meta *meta, Node *type)
{
    assert(type && "NO TYPE");
    if (!node || node->type != NT_BIN_OP || !str || !meta)
    { return; }

    switch (node->as.bin_op.type)
    {
        case BOT_PLUS: {
              int leftReg = new_reg();
             int rightReg = new_reg();
             generateExpr(node->as.bin_op.left, leftReg, str, meta, type);
             generateExpr(node->as.bin_op.right, rightReg, str, meta, type);
             dynstr_append_fstr(str, "  %%r%d = add", targetReg);
             printType(type, str);
             dynstr_append_fstr(str, " %%r%d, %%r%d\n", targetReg, leftReg, rightReg);
             break;
        }
        case BOT_ASSIGN: {
             int rightReg = new_reg();
             generateExpr(node->as.bin_op.right, rightReg, str, meta, type);
             Node *lhs = unwrap(node->as.bin_op.left);
             if (lhs && lhs->type == NT_IDENT) {
                 char *name = (char*)lhs->as.ident;
                 if (is_parameter(name)) {
                     dynstr_append_fstr(str, "  store i32 %%r%d, i32* %%%s_addr\n", rightReg, name);
                     dynstr_append_fstr(str, "  %%r%d = load i32, i32* %%%s_addr\n", targetReg, name);
                 } else {
                     dynstr_append_str(str, "  store ");
                     printType(meta_find_type_in_scope(curr_scope, name), str);
                     dynstr_append_fstr(str, " %%r%d, ", rightReg);
                     printType(meta_find_type_in_scope(curr_scope, name), str);
                     dynstr_append_fstr(str, "* %%%s\n", name);
                     dynstr_append_fstr(str, "  %%r%d = load i32, i32* %%%s\n", targetReg, name);
                 }
             } else {
                 dynstr_append_fstr(str, "  ; Left-hand side of assignment is not an identifier\n");
             }
             break;
        }
        default:
             dynstr_append_fstr(str, "  ; Unsupported binary operation %d\n", node->as.bin_op.type);
             break;
    }
}

/* Generate a function call */
static void
generateFnCall(Node *node, int targetReg, DynString *str, Meta *meta)
{
    if (!node || node->type != NT_FN_CALL || !str || !meta)
    { return; }

    int argRegs[16];  /* support up to 16 arguments */
    int argCount = 0;
    Node *arg = node->as.fn_call.args;
    while (arg && arg->type == NT_ARGUMENTS)
    {
         int reg = new_reg();
         assert(0 && "HERE");
         generateExpr(arg->as.arguments.arg, reg, str, meta, NULL);
         argRegs[argCount++] = reg;
         arg = arg->as.arguments.next;
    }
    dynstr_append_fstr(str, "  %%r%d = call i32 @", targetReg);
    Node *fname = unwrap(node->as.fn_call.ident);
    if (fname && fname->type == NT_IDENT)
    { dynstr_append_fstr(str, "%s(", (char*)fname->as.ident); }
    else
    { dynstr_append_str(str, "<unknown>("); }
    for (int i = 0; i < argCount; i++)
    {
         if (i > 0)
         { dynstr_append_str(str, ", "); }
         dynstr_append_fstr(str, "i32 %%r%d", argRegs[i]);
    }
    dynstr_append_str(str, ")\n");
}

