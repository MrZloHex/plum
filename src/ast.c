#include "ast.h"
#include <stdio.h>
#include <assert.h>

void
ast_init(AST *ast, Node *root)
{
    ast->root = root;
    ast_stack_init(&ast->stack, 32);
    ast_stack_push(&ast->stack, root);
}

void
ast_reinit(AST *ast)
{
    ast_stack_deinit(&ast->stack);
    ast_stack_init(&ast->stack, 32);
    ast_stack_push(&ast->stack, ast->root);
}

#define PUSH_NODE(EL)                           \
    if (EL)                                     \
    { ast_stack_push(&ast->stack, EL); }

Node *
ast_next(AST *ast)
{
    if (ast_stack_size(&ast->stack) == 0)
    { return NULL; }

    Node *curr;
    ast_stack_pop(&ast->stack, &curr);

    switch (curr->type)
    {
        case NT_PROGRAMME:
        {
            PUSH_NODE(curr->as.programme.next);
            PUSH_NODE(curr->as.programme.stmt);
        } break;

        case NT_PRG_STMT:
        {
            PUSH_NODE(curr->as.prg_stmt.prg_stmt);
        } break;

        case NT_FN_DECL:
        {
            PUSH_NODE(curr->as.fn_decl.params);
            PUSH_NODE(curr->as.fn_decl.ident);
            PUSH_NODE(curr->as.fn_decl.type);
        } break;
        
        case NT_FN_DEF:
        {
            PUSH_NODE(curr->as.fn_def.block);
            PUSH_NODE(curr->as.fn_def.decl);
        } break;

        case NT_TYPE_DEF:
        {
            PUSH_NODE(curr->as.type_def.block);
            PUSH_NODE(curr->as.type_def.ident);
        } break;

        case NT_PARAMETRE:
        {
            PUSH_NODE(curr->as.parametre.next);
            PUSH_NODE(curr->as.parametre.ident);
            PUSH_NODE(curr->as.parametre.type);
        } break;

        case NT_FN_CALL:
        {
            PUSH_NODE(curr->as.fn_call.args);
            PUSH_NODE(curr->as.fn_call.ident);
        } break; 

        case NT_ARGUMENTS:
        {
            PUSH_NODE(curr->as.arguments.next);
            PUSH_NODE(curr->as.arguments.arg);
        } break;

        case NT_BLOCK:
        {
            PUSH_NODE(curr->as.block.next);
            PUSH_NODE(curr->as.block.stmt);
        } break;

        case NT_STATEMENT:
        {
            PUSH_NODE(curr->as.stmt.stmt);
        } break;

        case NT_VAR_DECL:
        {
            PUSH_NODE(curr->as.var_decl.value);
            PUSH_NODE(curr->as.var_decl.ident);
            PUSH_NODE(curr->as.var_decl.type);
        } break;

        case NT_RET:
        {
            PUSH_NODE(curr->as.ret.expr);
        } break;

        case NT_EXPR:
        {
            PUSH_NODE(curr->as.expr.expr);
        } break;

        case NT_BIN_OP:
        {
            PUSH_NODE(curr->as.bin_op.left);
            PUSH_NODE(curr->as.bin_op.right);
        } break;

        case NT_UNY_OP:
        {
            PUSH_NODE(curr->as.uny_op.operand);
        } break;

        case NT_COND_STMT:
        {
            PUSH_NODE(curr->as.cond_stmt.else_block);
            PUSH_NODE(curr->as.cond_stmt.if_block);
        } break;

        case NT_COND_IF:
        {
            PUSH_NODE(curr->as.cond_if.block);
            PUSH_NODE(curr->as.cond_if.expr);
        } break;

        case NT_COND_ELSE:
        {
            PUSH_NODE(curr->as.cond_else.block);
        } break;

        case NT_LOOP:
        {
            PUSH_NODE(curr->as.loop.block);
        } break;

        case NT_MEMBER:
        {
            PUSH_NODE(curr->as.member.field);
            PUSH_NODE(curr->as.member.base);
        } break;

        case NT_IDENT:
        case NT_NUM_LIT:
        case NT_CHR_LIT:
        case NT_STR_LIT:
        case NT_BOOL_LIT:
        case NT_TYPE:
            break;

        case NT_QUANT:
            assert(0 && "UNREACHABLE");
    }

    return curr;
}


DEFINE_DYNSTACK(ast_stack, ASTStack, Node *)
