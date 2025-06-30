#define ARENA_IMPL
#include "ast.h"
#include <assert.h>
#include "trace.h"

void
ast_init(AST *ast)
{
    arena_init(&ast->arena, sizeof(ASTNode)*512);
    ast->root = ast_node_new(ast);
    *ast->root = (ASTNode)
    { .kind = NT_TRANSLATION_UNIT };

    ast_stack_init(&ast->stack, 32);
    ast_stack_push(&ast->stack, ast->root);
}

ASTNode *
ast_node_new(AST *ast)
{
    ASTNode *node = arena_alloc(&ast->arena, sizeof(ASTNode));
    *node = (ASTNode){0};
    return node;
}

void
ast_reinit(AST *ast)
{
    ast_stack_deinit(&ast->stack);
    ast_stack_init(&ast->stack, 32);
    ast_stack_push(&ast->stack, ast->root);
}

void
ast_deinit(AST *ast)
{
    ast_stack_deinit(&ast->stack);
    arena_destroy(&ast->arena);
}

void
ast_dump_node(ASTNode *, size_t);

DynString
ast_dump(AST *ast)
{
    ast_dump_node(ast->root, 0);
}


#define PUSH_NODE(EL)                           \
    if (EL)                                     \
    { ast_stack_push(&ast->stack, EL); }


ASTNode *
ast_next(AST *ast)
{
    if (ast_stack_size(&ast->stack) == 0)
    { return NULL; }

    ASTNode *curr;
    ast_stack_pop(&ast->stack, &curr);

    switch (curr->kind)
    {
        case NT_TRANSLATION_UNIT:
        {
            //PUSH_NODE(curr->as.tu.next_unit);
            PUSH_NODE(curr->as.tu.tu_stmt);
        } break;

        case NT_TU_STMT:
        {
            PUSH_NODE(curr->as.tu_stmt.next_tu_stmt);
            PUSH_NODE(curr->as.tu_stmt.tu_stmt);
        } break;

        case NT_FN_DECL:
        {
            PUSH_NODE(curr->as.fn_decl.params);
            PUSH_NODE(curr->as.fn_decl.ident);
            PUSH_NODE(curr->as.fn_decl.type);
        } break;

        case NT_PARAMETRE:
        {
            PUSH_NODE(curr->as.parametre.next_param);
            PUSH_NODE(curr->as.parametre.ident);
            PUSH_NODE(curr->as.parametre.type);
        } break;
        
        case NT_FN_DEF:
        {
            PUSH_NODE(curr->as.fn_def.block);
            PUSH_NODE(curr->as.fn_def.decl);
        } break;

        case NT_TYPE_DEF:
        {
            PUSH_NODE(curr->as.type_def.tdef);
            PUSH_NODE(curr->as.type_def.ident);
        } break;

        case NT_ENUM:
        {
            PUSH_NODE(curr->as.enumeration.fields);
        } break;

        case NT_ENUM_FIELDS:
        {
            PUSH_NODE(curr->as.enum_flds.next_field);
            PUSH_NODE(curr->as.enum_flds.ident);
        } break;

        case NT_RECORD:
        {
            PUSH_NODE(curr->as.record.fields);
        } break;

        case NT_FIELD:
        {
            PUSH_NODE(curr->as.rcrd_flds.next_field);
            PUSH_NODE(curr->as.rcrd_flds.ident);
            PUSH_NODE(curr->as.rcrd_flds.type);
        } break;

        case NT_BLOCK:
        {
            PUSH_NODE(curr->as.block.stmts);
        } break;
        
        case NT_STMT:
        {
            PUSH_NODE(curr->as.stmt.next_stmt);
            PUSH_NODE(curr->as.stmt.stmt);
        } break;

        case NT_RET:
        {
            PUSH_NODE(curr->as.ret.expr);
        } break;

        case NT_COND:
        {
            PUSH_NODE(curr->as.cond.else_part);
            PUSH_NODE(curr->as.cond.elif_part);
            PUSH_NODE(curr->as.cond.if_part);
        } break;

        case NT_IF:
        {
            PUSH_NODE(curr->as.if_cond.block);
            PUSH_NODE(curr->as.if_cond.expr);
        } break;

        case NT_ELIF:
        {
            PUSH_NODE(curr->as.elif_cond.next_elif);
            PUSH_NODE(curr->as.elif_cond.block);
            PUSH_NODE(curr->as.elif_cond.expr);
        } break;

        case NT_ELSE:
        {
            PUSH_NODE(curr->as.else_cond.block);
        } break;

        case NT_LOOP:
        {
            PUSH_NODE(curr->as.loop.block);
        } break;

        case NT_VAR_DECL:
        {
            PUSH_NODE(curr->as.var_decl.init);
            PUSH_NODE(curr->as.var_decl.ident);
            PUSH_NODE(curr->as.var_decl.type);
        } break;

        case NT_EXPR:
        {
            PUSH_NODE(curr->as.expr.expr);
        } break;

        case NT_BIN_OP:
        {
            PUSH_NODE(curr->as.bin_op.right);
            PUSH_NODE(curr->as.bin_op.left);
        } break;

        case NT_UNY_OP:
        {
            PUSH_NODE(curr->as.uny_op.operand);
        } break;

        case NT_FN_CALL:
        {
            PUSH_NODE(curr->as.fn_call.args);
            PUSH_NODE(curr->as.fn_call.ident);
        } break; 

        case NT_ARGUMENT:
        {
            PUSH_NODE(curr->as.argument.next_arg);
            PUSH_NODE(curr->as.argument.argument);
        } break;

        case NT_IDENT:
        case NT_LITERAL:
        case NT_TYPE:
        case NT_BASE_TYPE:
            break;

        default:
            assert(0 && "UNREACHABLE");
    }

    return curr;
}

static inline void
print_offset(size_t depth)
{
        for (size_t i = 0; i < depth; ++i)
        {
            printf("  ");
        }
        return;
    if (depth == 1)
    {
        printf("|-");
    }
    else if (depth > 1)
    {
        printf("`-");
    }
}


const static char *ast_type_str[] =
{
    "TranslationUnit", "TU Statement",
    "FuncDecl", "FuncDef", "TypeDef",
    "Parametre", "Enum", "EnumField", "Record", "RecordField",
    "Type", "BaseType", "Identifier",
    "Block", "Statement", "Return", "Condition", "Loop", "VarDecl", "Expression",
    "IfStmt", "ElifStmt", "ElseStmt",
    "BinOp", "UnyOp", "FuncCall", "Argument", "Literal", "BuiltIn"
};

#define PRINTIT(node) \
    print_offset(depth); \
    printf("%s %d:%d", ast_type_str[node->kind], node->loc.line, node->loc.col);


void
dummy_dump(AST *ast)
{
    ast_reinit(ast);
    ASTNode *curr = ast_next(ast);
    size_t depth = 0;
    while (curr)
    {
        PRINTIT(curr); printf("\n");
        curr = ast_next(ast);
    }
}

void
ast_dump_node(ASTNode *curr, size_t depth)
{
    static bool type_print_full = true;
    if (!curr)
    { return; }

    switch (curr->kind)
    {
        case NT_TRANSLATION_UNIT:
        {
            PRINTIT(curr); printf("\n");
            ast_dump_node(curr->as.tu.tu_stmt, depth+1);
        } break;

        case NT_TU_STMT:
        {
            ast_dump_node(curr->as.tu_stmt.tu_stmt, depth);
            ast_dump_node(curr->as.tu_stmt.next_tu_stmt, depth);
        } break;

        case NT_FN_DECL:
        {
            PRINTIT(curr);
            printf(" `%s` of type ", curr->as.fn_decl.ident->as.ident);
            type_print_full = false;
            ast_dump_node(curr->as.fn_decl.type, depth);
            printf("\n");
            ast_dump_node(curr->as.fn_decl.params, depth+1);
        } break;

        case NT_PARAMETRE:
        {
            PRINTIT(curr);
            if (curr->as.parametre.vaarg)
            { printf(" VAARG\n"); }
            else
            {
                printf(" `%s` - ", curr->as.parametre.ident->as.ident);
                type_print_full = false;
                ast_dump_node(curr->as.parametre.type, depth);
                printf("\n");
            }
            ast_dump_node(curr->as.parametre.next_param, depth);
        } break;
 
        case NT_FN_DEF:
        {
            PRINTIT(curr);
            printf(" `%s` - ", curr->as.fn_def.decl->as.fn_decl.ident->as.ident);
            type_print_full = false;
            ast_dump_node(curr->as.fn_def.decl->as.fn_decl.type, depth);
            printf("\n");
            ast_dump_node(curr->as.fn_def.decl->as.fn_decl.params, depth+1);
            ast_dump_node(curr->as.fn_def.block, depth+1);
        } break;

        case NT_TYPE_DEF:
        {
            PRINTIT(curr);
            printf(" `%s`", curr->as.type_def.ident->as.ident);
            if (curr->as.type_def.kind == TD_ALIAS)
            { printf(" ALIAS TO\n"); }
            else if (curr->as.type_def.kind == TD_ENUM)
            { printf(" ENUM\n"); }
            else
            { printf("\n"); }

            type_print_full = true;
            ast_dump_node(curr->as.type_def.tdef, depth+1);
        } break;

        case NT_ENUM:
        {
            ast_dump_node(curr->as.enumeration.fields, depth);
        } break;

        case NT_ENUM_FIELDS:
        {
            PRINTIT(curr);
            printf(" `%s`\n", curr->as.enum_flds.ident->as.ident);
            ast_dump_node(curr->as.enum_flds.next_field, depth);
        } break;

        case NT_RECORD:
        {
            PRINTIT(curr);
            printf(" %s\n", curr->as.record.kind == TDRT_UNION ? "UNION" : "STRUCTURE");
            ast_dump_node(curr->as.record.fields, depth+1);
        } break;

        case NT_FIELD:
        {
            PRINTIT(curr);
            printf(" `%s` - ", curr->as.rcrd_flds.ident->as.ident);
            type_print_full = false;
            ast_dump_node(curr->as.rcrd_flds.type, depth);
            printf("\n");
            ast_dump_node(curr->as.rcrd_flds.next_field, depth);
        } break;

        case NT_TYPE:
        {
            const static char *type_str[BT_QUANTITY] = 
            {
                "ABYSS", "B1", "C1",
                "U8", "U16", "U32", "U64",
                "I8", "I16", "I32", "I64",
                "USIZE", "ISIZE", "F32", "F64"
            };

            if (type_print_full)
            { PRINTIT(curr); printf(" "); }

            for (size_t i = 0; i < curr->as.type.ptrs; ++i)
            { printf("PTR TO "); }

            if (curr->as.type.kind == TT_USER_TYPE)
            { printf("`%s`", curr->as.type.type->as.ident); }
            else
            { printf("%s", type_str[curr->as.type.type->as.base_type]); }

            if (type_print_full)
            { printf("\n"); }
        } break;

        case NT_BLOCK:
        {
            PRINTIT(curr); printf("\n");
            ast_dump_node(curr->as.block.stmts, depth+1);
        } break;
        
        case NT_STMT:
        {
            // TODO: remove exceecive printing
            // print just the stmt
            PRINTIT(curr);
            const static char *stmt_type_str[] =
            {
                "RETURN", "BREAK", "CONDITION",
                "LOOP", "VAR DECL", "EXPRESSION"
            };

            printf(" %s\n", stmt_type_str[curr->as.stmt.kind]);
            ast_dump_node(curr->as.stmt.stmt, depth+1);
            ast_dump_node(curr->as.stmt.next_stmt, depth);
        } break;

        case NT_RET:
        {
            PRINTIT(curr); printf("\n");
            ast_dump_node(curr->as.ret.expr, depth+1);

        } break;

        case NT_COND:
        {
            PRINTIT(curr); printf("\n");
            ast_dump_node(curr->as.cond.if_part, depth+1);
            ast_dump_node(curr->as.cond.elif_part, depth+1);
            ast_dump_node(curr->as.cond.else_part, depth+1);
        } break;

        case NT_IF:
        {
            PRINTIT(curr); printf("\n");
            ast_dump_node(curr->as.if_cond.expr, depth+1);
            ast_dump_node(curr->as.if_cond.block, depth+1);
        } break;

        case NT_ELIF:
        {
            PRINTIT(curr); printf("\n");
            ast_dump_node(curr->as.elif_cond.expr, depth+1);
            ast_dump_node(curr->as.elif_cond.block, depth+1);
        } break;

        case NT_ELSE:
        {
            PRINTIT(curr); printf("\n");
            ast_dump_node(curr->as.else_cond.block, depth+1);
        } break;

        case NT_LOOP:
        {
            PRINTIT(curr); printf("\n");
            ast_dump_node(curr->as.loop.block, depth+1);
        } break;

        case NT_VAR_DECL:
        {
            PRINTIT(curr);
            printf(" `%s` - ", curr->as.var_decl.ident->as.ident);
            type_print_full = false;
            ast_dump_node(curr->as.var_decl.type, depth);
            if (curr->as.var_decl.init)
            { printf(" INIT\n"); ast_dump_node(curr->as.var_decl.init, depth+1); }
            else
            { printf("\n"); }

        } break;

        case NT_EXPR:
        {
            const static char *expr_type_str[] =
            {
                "IDENT", "BIN OP", "UNY OP",
                "FN CALL", "LITERAL", "EXPR", "BUILT IN"
            };
            PRINTIT(curr);
            printf(" %s\n", expr_type_str[curr->as.expr.kind]);
            ast_dump_node(curr->as.expr.expr, depth+1);
        } break;

        case NT_BIN_OP:
        {
            const static char *bin_op_str[] =
            {
                "ASSIGN", "PLUS", "MINUS", "MULT", "DIV",
                "MOD", "EQUAL", "NEQ", "LESS", "LEQ",
                "GREAT", "GEQ", "MEMBER"
            };
            PRINTIT(curr); printf(" %s\n", bin_op_str[curr->as.bin_op.kind]);
            ast_dump_node(curr->as.bin_op.left, depth+1);
            ast_dump_node(curr->as.bin_op.right, depth+1);
        } break;

        case NT_UNY_OP:
        {
            const static char *uny_op_str[] =
            { "DEREF", "REF", "NEG" };
            PRINTIT(curr);
            printf(" %s\n", uny_op_str[curr->as.uny_op.kind]);
            ast_dump_node(curr->as.uny_op.operand, depth+1);
        } break;

        case NT_FN_CALL:
        {
            PRINTIT(curr);
            printf(" `%s`\n", curr->as.fn_call.ident->as.ident);
            ast_dump_node(curr->as.fn_call.args, depth+1);
        } break;

        case NT_ARGUMENT:
        {
            PRINTIT(curr); printf("\n");
            ast_dump_node(curr->as.argument.argument, depth+1);
            ast_dump_node(curr->as.argument.next_arg, depth);
        } break;

        case NT_IDENT:
        {
            PRINTIT(curr);
            printf(" `%s`\n", curr->as.ident);
        } break;

        case NT_LITERAL:
        {
            const static char *lit_type_str[] =
            {
                "INTEGER", "FLOAT", "CHARACTER",
                "STRING", "BOOLEAN"
            };
            PRINTIT(curr);
            printf(" %s ", lit_type_str[curr->as.literal.kind]);
            switch (curr->as.literal.kind)
            {
                case LT_INTEGER:
                    printf("`%d`\n", curr->as.literal.as.int_lit);
                    break;
                case LT_BOOLEAN:
                    printf("%s\n", curr->as.literal.as.bool_lit ? "TRUE": "FALSE");
                    break;
                case LT_CHARACTER:
                    printf("`%c`\n", curr->as.literal.as.char_lit);
                    break;
                case LT_STRING:
                    printf("`%s`\n", curr->as.literal.as.str_lit);
                    break;
                case LT_FLOAT:
                    printf("`%f`\n", curr->as.literal.as.float_lit);
                    break;
            }

        } break;

        case NT_BUILTIN:
        {
            PRINTIT(curr);
            if (curr->as.builtin.kind != BI_SIZE)
            { assert(0 && "UNREACHABLE"); }

            printf(" SIZE OF `%s`\n", curr->as.builtin.as.size->as.ident);
        } break;

    //     case NT_TYPE:
    //     case NT_BASE_TYPE:
    //         break;

    //    default:
    //        assert(0 && "UNREACHABLE");
    }
}

DEFINE_DYNSTACK(ast_stack, ASTStack, ASTNode *)

