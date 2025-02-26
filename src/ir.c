#include "ir.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define DYNSTR_IMPL
#include "dynstr.h"

static int reg_counter = 0;
static int
new_reg(void)
{ return reg_counter++; }

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
static void generateProgram(Node *node, DynString *str);
static void generateFnDef(Node *node, DynString *str);
static void generateFnDecl(Node *node, DynString *str);
static void generateBlock(Node *node, DynString *str);
static void generateStatement(Node *node, DynString *str);
static void generateExpr(Node *node, int targetReg, DynString *str);
static void generateVarDecl(Node *node, DynString *str);
static void generateBinOp(Node *node, int targetReg, DynString *str);
static void generateFnCall(Node *node, int targetReg, DynString *str);

void
generateIR(Node *node, DynString *str)
{
    if (!node)
    { return; }

    if (node->type == NT_PROGRAMME)
    { generateProgram(node, str); }
    else
    { dynstr_append_fstr(str, "; Unsupported top-level node type %d\n", node->type); }
}

/* Generate a programme: a linked list of function definitions */
static void
generateProgram(Node *node, DynString *str) 
{
    for (Node *prog = node; prog != NULL; prog = prog->as.programme.next)
    {
         if (prog->as.programme.stmt->as.prg_stmt.type == PST_FN_DEF)
         { generateFnDef(prog->as.programme.stmt->as.prg_stmt.prg_stmt, str); }
         else if (prog->as.programme.stmt->as.prg_stmt.type == PST_FN_DECL)
         { generateFnDecl(prog->as.programme.stmt->as.prg_stmt.prg_stmt, str); }
    }
}

static void
generateFnDef(Node *node, DynString *str) 
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
    
    generateBlock(fnBlock, str);
    
    dynstr_append_str(str, "}\n\n");
    clear_params();
}

static void
generateFnDecl(Node *node, DynString *str)
{
    if (!node || node->type != NT_FN_DECL || !str)
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
generateBlock(Node *node, DynString *str)
{
    if (!node || node->type != NT_BLOCK || !str)
    { return; }

    for (Node *blk = node; blk != NULL; blk = blk->as.block.next)
    {
         generateStatement(blk->as.block.stmt, str);
    }
}

/* Generate a statement */
static void
generateStatement(Node *node, DynString *str)
{
    if (!node || node->type != NT_STATEMENT || !str)
    { return; }

    switch (node->as.stmt.type)
    {
         case ST_VAR_DECL:
              generateVarDecl(node->as.stmt.stmt, str);
              break;
         case ST_EXPR: {
              int reg = new_reg();
              generateExpr(node->as.stmt.stmt, reg, str);
              break;
         }
         case ST_RET: {
              int reg = new_reg();
              generateExpr(node->as.stmt.stmt, reg, str);
              dynstr_append_fstr(str, "  ret i32 %%r%d\n", reg);
              break;
         }
         default:
              dynstr_append_fstr(str, "  ; Unsupported statement type %d\n", node->as.stmt.type);
              break;
    }
}

/* Generate a variable declaration */
static void
generateVarDecl(Node *node, DynString *str)
{
    if (!node || node->type != NT_VAR_DECL || !str)
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
generateExpr(Node *node, int targetReg, DynString *str)
{
    if (!node || !str)
    { return; }

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
              generateBinOp(node, targetReg, str);
              break;
         case NT_FN_CALL:
              generateFnCall(node, targetReg, str);
              break;
         case NT_RET:
              generateExpr(node->as.ret.expr, targetReg, str);
              break;
         default:
              dynstr_append_fstr(str, "  ; Unsupported expression node type %d\n", node->type);
              break;
    }
}

/* Generate a binary operation */
static void
generateBinOp(Node *node, int targetReg, DynString *str)
{
    if (!node || node->type != NT_BIN_OP || !str)
    { return; }

    switch (node->as.bin_op.type)
    {
         case BOT_PLUS: {
              int leftReg = new_reg();
              int rightReg = new_reg();
              generateExpr(node->as.bin_op.left, leftReg, str);
              generateExpr(node->as.bin_op.right, rightReg, str);
              dynstr_append_fstr(str, "  %%r%d = add i32 %%r%d, %%r%d\n", targetReg, leftReg, rightReg);
              break;
         }
         case BOT_ASSIGN: {
              int rightReg = new_reg();
              generateExpr(node->as.bin_op.right, rightReg, str);
              Node *lhs = unwrap(node->as.bin_op.left);
              if (lhs && lhs->type == NT_IDENT) {
                  char *name = (char*)lhs->as.ident;
                  if (is_parameter(name)) {
                      dynstr_append_fstr(str, "  store i32 %%r%d, i32* %%%s_addr\n", rightReg, name);
                      dynstr_append_fstr(str, "  %%r%d = load i32, i32* %%%s_addr\n", targetReg, name);
                  } else {
                      dynstr_append_fstr(str, "  store i32 %%r%d, i32* %%%s\n", rightReg, name);
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
generateFnCall(Node *node, int targetReg, DynString *str)
{
    if (!node || node->type != NT_FN_CALL || !str)
    { return; }

    int argRegs[16];  /* support up to 16 arguments */
    int argCount = 0;
    Node *arg = node->as.fn_call.args;
    while (arg && arg->type == NT_ARGUMENTS)
    {
         int reg = new_reg();
         generateExpr(arg->as.arguments.arg, reg, str);
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

