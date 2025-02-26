#include "ir.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Global register counter for unique temporary register names */
static int reg_counter = 0;
static int new_reg(void) {
    return reg_counter++;
}

/* Simple Parameter Symbol Table */
typedef struct ParamEntry {
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
static void printType(Node *node) {
    if (!node || node->type != NT_TYPE) {
        printf("i32");
        return;
    }
    N_Type t = node->as.type;
    if (t.ptrs == 0)
    {
        switch(t.type) {
             case T_U8:   printf("i8"); break;
             case T_U16:  printf("i16"); break;
             case T_U32:  printf("i32"); break;
             case T_U64:  printf("i64"); break;
             case T_I8:   printf("i8"); break;
             case T_I16:  printf("i16"); break;
             case T_I32:  printf("i32"); break;
             case T_I64:  printf("i64"); break;
             default:     printf("i32"); break;
        }
    }
    else
    { printf("ptr"); }
}

/* Forward declarations of internal generator functions */
static void generateProgram(Node *node);
static void generateFnDef(Node *node);
static void generateFnDecl(Node *node);
static void generateBlock(Node *node);
static void generateStatement(Node *node);
static void generateExpr(Node *node, int targetReg);
static void generateVarDecl(Node *node);
static void generateBinOp(Node *node, int targetReg);
static void generateFnCall(Node *node, int targetReg);

/* Public interface: generateIR from an AST root */
void generateIR(Node *node) {
    if (!node)
        return;
    if (node->type == NT_PROGRAMME)
         generateProgram(node);
    else
         printf("; Unsupported top-level node type %d\n", node->type);
}

/* Generate a programme: a linked list of function definitions */
static void generateProgram(Node *node) {
    for (Node *prog = node; prog != NULL; prog = prog->as.programme.next) {
         if (prog->as.programme.stmt->as.prg_stmt.type == PST_FN_DEF)
         { generateFnDef(prog->as.programme.stmt->as.prg_stmt.prg_stmt); }
         else if (prog->as.programme.stmt->as.prg_stmt.type == PST_FN_DECL)
         { generateFnDecl(prog->as.programme.stmt->as.prg_stmt.prg_stmt); }
    }
}

/* Generate a function definition */
static void generateFnDef(Node *node) {
    if (!node || node->type != NT_FN_DEF)
        return;
    Node *fnDecl = node->as.fn_def.decl;
    Node *fnBlock = node->as.fn_def.block;
    if (!fnDecl || fnDecl->type != NT_FN_DECL)
        return;
    
    /* Print function header: define <ret_type> @<function_name>(<params>) { */
    printf("define ");
    printType(fnDecl->as.fn_decl.type);
    
    Node *fname = unwrap(fnDecl->as.fn_decl.ident);
    if (fname && fname->type == NT_IDENT)
         printf(" @%s(", (char*)fname->as.ident);
    else
         printf(" @<unknown>(");
    
    Node *param = fnDecl->as.fn_decl.params;
    int first = 1;
    while (param) {
         if (param->type != NT_PARAMETRE)
             break;
         if (!first)
             printf(", ");
         printType(param->as.parametre.type);
         Node *pname = unwrap(param->as.parametre.ident);
         if (pname && pname->type == NT_IDENT)
             printf(" %%%s", (char*)pname->as.ident);
         else
             printf(" %%<unknown>");
         first = 0;
         param = param->as.parametre.next;
    }
    printf(") {\n");
    
    /* Promote parameters into local allocas */
    for (param = fnDecl->as.fn_decl.params; param != NULL; param = param->as.parametre.next) {
         if (param->type != NT_PARAMETRE)
             break;
         Node *pname = unwrap(param->as.parametre.ident);
         if (pname && pname->type == NT_IDENT) {
              char *name = (char*)pname->as.ident;
              add_param(name);
              printf("  %%%s_addr = alloca ", name);
              printType(param->as.parametre.type);
              printf("\n");
              printf("  store ");
              printType(param->as.parametre.type);
              printf(" %%%s, ", name);
              printType(param->as.parametre.type);
              printf("* %%%s_addr\n", name);
         }
    }
    
    /* Generate the function body */
    generateBlock(fnBlock);
    
    printf("}\n\n");
    clear_params();
}

static void
generateFnDecl(Node *node)
{
    if (!node || node->type != NT_FN_DECL)
    { return; }

    Node *fnDecl = node;
    
    printf("declare ");
    printType(fnDecl->as.fn_decl.type);
    
    Node *fname = unwrap(fnDecl->as.fn_decl.ident);
    if (fname && fname->type == NT_IDENT)
         printf(" @%s(", (char*)fname->as.ident);
    else
         printf(" @<unknown>(");
    
    Node *param = fnDecl->as.fn_decl.params;
    int first = 1;
    while (param) {
         if (param->type != NT_PARAMETRE)
             break;
         if (!first)
             printf(", ");
         printType(param->as.parametre.type);
         Node *pname = unwrap(param->as.parametre.ident);
         if (pname && pname->type == NT_IDENT)
             printf(" noundef");
         else
             printf(" %%<unknown>");
         first = 0;
         param = param->as.parametre.next;
    }
    printf(")\n");
    
    clear_params();
}

/* Generate a block: a linked list of statements */
static void generateBlock(Node *node) {
    if (!node || node->type != NT_BLOCK)
        return;
    for (Node *blk = node; blk != NULL; blk = blk->as.block.next) {
         generateStatement(blk->as.block.stmt);
    }
}

/* Generate a statement */
static void generateStatement(Node *node) {
    if (!node || node->type != NT_STATEMENT)
        return;
    switch (node->as.stmt.type) {
         case ST_VAR_DECL:
              generateVarDecl(node->as.stmt.stmt);
              break;
         case ST_EXPR: {
              int reg = new_reg();
              generateExpr(node->as.stmt.stmt, reg);
              break;
         }
         case ST_RET: {
              int reg = new_reg();
              generateExpr(node->as.stmt.stmt, reg);
              printf("  ret i32 %%r%d\n", reg);
              break;
         }
         default:
              printf("  ; Unsupported statement type %d\n", node->as.stmt.type);
              break;
    }
}

/* Generate a variable declaration */
static void generateVarDecl(Node *node) {
    if (!node || node->type != NT_VAR_DECL)
        return;
    Node *vname = unwrap(node->as.var_decl.ident);
    if (vname && vname->type == NT_IDENT)
         printf("  %%%s = alloca ", (char*)vname->as.ident);
    else
         printf("  %%<unknown> = alloca ");
    printType(node->as.var_decl.type);
    printf("\n");
}

/* Generate an expression */
static void generateExpr(Node *node, int targetReg) {
    if (!node)
        return;
    node = unwrap(node);
    switch (node->type) {
         case NT_IDENT: {
              char *name = (char*)node->as.ident;
              if (is_parameter(name)) {
                  printf("  %%r%d = load i32, i32* %%%s_addr\n", targetReg, name);
              } else {
                  printf("  %%r%d = load i32, i32* %%%s\n", targetReg, name);
              }
              break;
         }
         case NT_CHR_LIT:
              printf("  %%r%d = add i32 0, %d\n", targetReg, node->as.chr_lit);
              break;
         case NT_NUM_LIT:
              printf("  %%r%d = add i32 0, %d\n", targetReg, node->as.num_lit);
              break;
         case NT_BIN_OP:
              generateBinOp(node, targetReg);
              break;
         case NT_FN_CALL:
              generateFnCall(node, targetReg);
              break;
         case NT_RET:
              generateExpr(node->as.ret.expr, targetReg);
              break;
         default:
              printf("  ; Unsupported expression node type %d\n", node->type);
              break;
    }
}

/* Generate a binary operation */
static void generateBinOp(Node *node, int targetReg) {
    if (!node || node->type != NT_BIN_OP)
        return;
    switch (node->as.bin_op.type) {
         case BOT_PLUS: {
              int leftReg = new_reg();
              int rightReg = new_reg();
              generateExpr(node->as.bin_op.left, leftReg);
              generateExpr(node->as.bin_op.right, rightReg);
              printf("  %%r%d = add i32 %%r%d, %%r%d\n", targetReg, leftReg, rightReg);
              break;
         }
         case BOT_ASSIGN: {
              int rightReg = new_reg();
              generateExpr(node->as.bin_op.right, rightReg);
              Node *lhs = unwrap(node->as.bin_op.left);
              if (lhs && lhs->type == NT_IDENT) {
                  char *name = (char*)lhs->as.ident;
                  if (is_parameter(name)) {
                      printf("  store i32 %%r%d, i32* %%%s_addr\n", rightReg, name);
                      printf("  %%r%d = load i32, i32* %%%s_addr\n", targetReg, name);
                  } else {
                      printf("  store i32 %%r%d, i32* %%%s\n", rightReg, name);
                      printf("  %%r%d = load i32, i32* %%%s\n", targetReg, name);
                  }
              } else {
                  printf("  ; Left-hand side of assignment is not an identifier\n");
              }
              break;
         }
         default:
              printf("  ; Unsupported binary operation %d\n", node->as.bin_op.type);
              break;
    }
}

/* Generate a function call */
static void generateFnCall(Node *node, int targetReg) {
    if (!node || node->type != NT_FN_CALL)
        return;
    int argRegs[16];  /* support up to 16 arguments */
    int argCount = 0;
    Node *arg = node->as.fn_call.args;
    while (arg && arg->type == NT_ARGUMENTS) {
         int reg = new_reg();
         generateExpr(arg->as.arguments.arg, reg);
         argRegs[argCount++] = reg;
         arg = arg->as.arguments.next;
    }
    printf("  %%r%d = call i32 @", targetReg);
    Node *fname = unwrap(node->as.fn_call.ident);
    if (fname && fname->type == NT_IDENT)
         printf("%s(", (char*)fname->as.ident);
    else
         printf("<unknown>(");
    for (int i = 0; i < argCount; i++) {
         if (i > 0)
              printf(", ");
         printf("i32 %%r%d", argRegs[i]);
    }
    printf(")\n");
}

