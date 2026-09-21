#define TOKEN_DUMP
#include "parser.h"
#include "trace.h"


#define IS_EOF(p) ((p).curr.kind == TOK_EOF)


static inline void
parser_next(Parser *parser)
{ parser->curr = lexer_next(&parser->lexer); }

static inline Token
parser_peek(Parser *pr, int ahead)
{
    Lexer save = pr->lexer;
    Token tok;
    while (ahead > 0)
    { tok = lexer_next(&save); --ahead; }
    return tok;
}

#define unexpected(pr) unexpected_fn(pr, __LINE__, __func__)

static inline void
unexpected_fn(Parser *pr, int line, const char *fn)
{
    TRACE_ERROR
    (
        "%s:%d %d:%d: Unexpected %s", fn, line,
        pr->curr.loc.line, pr->curr.loc.col,
        token_str(pr->curr.kind)
    );
    exit(1);
}

#define expect(pr, t) expect_fn(pr, t, __LINE__, __func__)

static inline void
expect_fn(Parser *pr, TokenType t, int line, const char *fn)
{
    if (pr->curr.kind != t)
    {
        TRACE_ERROR
        (
            "%s:%d %d:%d: Unexpected %s, expected %s", fn, line,
            pr->curr.loc.line, pr->curr.loc.col,
            token_str(pr->curr.kind), token_str(t)
        );
        exit(1);
    }
    parser_next(pr);
}

static inline bool
match(Parser *pr, TokenType t)
{
    if (pr->curr.kind == t)
    { parser_next(pr); return true; }
    else
    { return false; }
}

static inline void
set_loc(ASTNode *node, Token tok)
{ node->loc = tok.loc; }


static inline void
check_indent(Parser *pr, Token tok)
{
    if (tok.indent != pr->indent && tok.indent != 0)
    {
        TRACE_ERROR
        (
            "%d:%d: Wrong indentation %d, needed %d",
            pr->curr.loc.line, pr->curr.loc.col,
            tok.indent, pr->indent
        );
        exit(1);
    }
}




static ASTNode * // N_Ident
parse_ident(Parser *pr)
{
    Token ident = pr->curr; expect(pr, TOK_IDENTIFIER);
    ASTNode *id = ast_node_new(pr->ast);
    id->kind = NT_IDENT;
    id->as.ident = ident.lexeme;
    set_loc(id, ident);
    return id;
}

const static struct { char *lex; N_BaseType type; } base_types[] =
{
    { "ABYSS", BT_ABYSS },
    { "B1",    BT_B1    },
    { "C1",    BT_C1    },
    { "U8",    BT_U8    },
    { "U16",   BT_U16   },
    { "U32",   BT_U32   },
    { "U64",   BT_U64   },
    { "I8",    BT_I8    },
    { "I16",   BT_I16   },
    { "I32",   BT_I32   },
    { "I64",   BT_I64   },
    { "USIZE", BT_USIZE },
    { "ISIZE", BT_ISIZE },
    { "F32",   BT_F32   },
    { "F64",   BT_F64   },
    { NULL,    BT_QUANTITY }
};

static ASTNode * // N_Type
parse_type(Parser *pr)
{
    ASTNode *type = ast_node_new(pr->ast);
    type->kind = NT_TYPE;
    type->as.type.ptrs = 0;

    Token start = pr->curr;
    while (match(pr, TOK_AT))
    { type->as.type.ptrs += 1; }

    Token ident = pr->curr; expect(pr, TOK_IDENTIFIER);
    ASTNode *int_type = ast_node_new(pr->ast); // internal type
    int_type->kind = NT_IDENT;

    for (size_t i = 0; base_types[i].lex; ++i)
    {
        if (strcmp(base_types[i].lex, ident.lexeme) == 0)
        {
            type->as.type.kind = TT_BASE_TYPE;
            int_type->kind = NT_BASE_TYPE;
            int_type->as.base_type = base_types[i].type;
        }
    }
    if (int_type->kind != NT_BASE_TYPE) // SO IT IS USER TYPE
    {
        type->as.type.kind = TT_USER_TYPE;
        int_type->as.ident = ident.lexeme;
    }
    set_loc(int_type, ident);
    set_loc(type, start);
    type->as.type.type = int_type;

    return type;
}

static ASTNode * // N_Field
parse_field(Parser *pr)
{
    ASTNode *field = ast_node_new(pr->ast);
    field->kind = NT_FIELD;
    set_loc(field, pr->curr);
    field->as.rcrd_flds.type = parse_type(pr);
    field->as.rcrd_flds.ident = parse_ident(pr);
    field->as.rcrd_flds.next_field = NULL;
    return field;
}

static ASTNode * // N_Record
parse_record(Parser *pr, int kind)
{
    ASTNode *record = ast_node_new(pr->ast);
    record->kind = NT_RECORD;
    record->as.record.kind = kind;
    record->as.record.fields = NULL;
    set_loc(record, pr->curr);

    ASTNode **fields_tail = &record->as.record.fields;

    while (pr->curr.kind == TOK_NEWLINE)
    {
        Token newline = pr->curr; expect(pr, TOK_NEWLINE);
        check_indent(pr, newline);
        ASTNode *field = parse_field(pr);
        *fields_tail = field;
        fields_tail = &field->as.rcrd_flds.next_field;
    }
    expect(pr, TOK_END_BLOCK);
    
    return record;
}

static ASTNode * // N_EnumField
parse_enum_field(Parser *pr)
{
    ASTNode *field = ast_node_new(pr->ast);
    field->kind = NT_ENUM_FIELDS;
    set_loc(field, pr->curr);
    field->as.enum_flds.ident = parse_ident(pr);
    field->as.enum_flds.next_field = NULL;
    return field;
}

static ASTNode * // N_Enum
parse_enum(Parser *pr)
{
    ASTNode *enumer = ast_node_new(pr->ast);
    enumer->kind = NT_ENUM;
    enumer->as.enumeration.fields = NULL;
    set_loc(enumer, pr->curr);

    ASTNode **fields_tail = &enumer->as.enumeration.fields;

    while (pr->curr.kind == TOK_NEWLINE)
    {
        Token newline = pr->curr; expect(pr, TOK_NEWLINE);
        check_indent(pr, newline);
        ASTNode *field = parse_enum_field(pr);
        *fields_tail = field;
        fields_tail = &field->as.enum_flds.next_field;
    }
    expect(pr, TOK_END_BLOCK);
    
    return enumer;
}

static ASTNode * // N_TypeDef
parse_type_def(Parser *pr)
{
    ASTNode *type_def = ast_node_new(pr->ast);
    type_def->kind = NT_TYPE_DEF;
    set_loc(type_def, pr->curr);

    expect(pr, TOK_TYPE);
    type_def->as.type_def.ident = parse_ident(pr);
    expect(pr, TOK_COLON);

    if (match(pr, TOK_STRUCTURE))
    {
        type_def->as.type_def.kind = TD_RECORD;
        type_def->as.type_def.tdef = parse_record(pr, TDRT_STRUCTURE);
    }
    else if (match(pr, TOK_UNION))
    {
        type_def->as.type_def.kind = TD_RECORD;
        type_def->as.type_def.tdef = parse_record(pr, TDRT_UNION);
    }
    else if (match(pr, TOK_ENUMERATION))
    {
        type_def->as.type_def.kind = TD_ENUM;
        type_def->as.type_def.tdef = parse_enum(pr);
    }
    else if (pr->curr.kind == TOK_IDENTIFIER || pr->curr.kind == TOK_AT)
    {
        type_def->as.type_def.kind = TD_ALIAS;
        type_def->as.type_def.tdef = parse_type(pr);
    }
    else
    {
        unexpected(pr);
    }

    return type_def;
}

#include "ast.h"

#define TokType(parser) (parser->curr.kind)

static ASTNode * // N_Params
parse_params(Parser *pr)
{
    expect(pr, TOK_LBRACKET);
    if (match(pr, TOK_RBRACKET))
    { return NULL; }

    ASTNode *head = NULL;
    ASTNode **tail = &head;

    bool is_param = true;
    while (is_param)
    {
        ASTNode *param = ast_node_new(pr->ast);
        param->kind = NT_PARAMETRE;
        param->as.parametre.next_param = NULL;
        set_loc(param, pr->curr);

        if (match(pr, TOK_ELLIPSIS))
        {
            param->as.parametre.vaarg = true;
        }
        else if (TokType(pr) == TOK_IDENTIFIER || TokType(pr) == TOK_AT)
        {
            param->as.parametre.type = parse_type(pr);
            param->as.parametre.ident = parse_ident(pr);
        }
        else
        {
            unexpected(pr);
        }

        *tail = param;
        tail = &param->as.parametre.next_param;

        if (!match(pr, TOK_VBAR))
        { is_param = false; }
    }

    expect(pr, TOK_RBRACKET);
    return head;
}

static ASTNode * // N_FnDecl
parse_fn_decl(Parser *pr)
{
    ASTNode *fndecl = ast_node_new(pr->ast);
    fndecl->kind = NT_FN_DECL;
    set_loc(fndecl, pr->curr);

    fndecl->as.fn_decl.type = parse_type(pr);
    fndecl->as.fn_decl.ident = parse_ident(pr);
    expect(pr, TOK_COLON);
    fndecl->as.fn_decl.params = parse_params(pr);

    return fndecl;
}

static inline int
prefix_precendence(Parser *pr)
{
    if (TokType(pr) == TOK_QMARK || TokType(pr) == TOK_AT ||
        (TokType(pr) == TOK_OPERATOR &&
         (strcmp(pr->curr.lexeme, "-") == 0 ||
          strcmp(pr->curr.lexeme, "!") == 0 ||
          strcmp(pr->curr.lexeme, "~") == 0)))
    { return 50; }
    else
    { return -1; }
}

static inline int
infix_precendence(Parser *pr)
{
    if (pr->curr.kind == TOK_DOT)
    { return 40; }

    // a cast binds tighter than arithmetic but looser than `.` and prefix
    if (pr->curr.kind == TOK_AS)
    { return 35; }

    // Bitwise-or. `|` also separates arguments, so parse_arguments asks for
    // a min_prec above this and a top-level `|` breaks out to the list;
    // inside parens it binds as an operator, as it does everywhere else.
    if (pr->curr.kind == TOK_VBAR)
    { return 9; }

    if (pr->curr.kind != TOK_OPERATOR)
    { return -1; }

    char *op = pr->curr.lexeme;
    if (strcmp(op, "*") == 0 ||
        strcmp(op, "/") == 0 ||
        strcmp(op, "%") == 0)
    { return 30; }
    if (strcmp(op, "+") == 0 ||
        strcmp(op, "-") == 0)
    { return 20; }
    if (strcmp(op, "<<") == 0 ||
        strcmp(op, ">>") == 0)
    { return 17; }
    if (strcmp(op, "<")  == 0 ||
        strcmp(op, "<=") == 0 ||
        strcmp(op, ">")  == 0 ||
        strcmp(op, ">=") == 0)
    { return 15; }
    if (strcmp(op, "==") == 0 ||
        strcmp(op, "!=") == 0)
    { return 10; }
    if (strcmp(op, "||") == 0)
    { return 7; }
    if (strcmp(op, "&&") == 0)
    { return 8; }
    if (strcmp(op, "^") == 0)
    { return 11; }
    if (strcmp(op, "&") == 0)
    { return 12; }
    if (strcmp(op, "=") == 0)
    { return 5; }
    if (op[0] && op[1] == '=' && op[2] == '\0' && strchr("+-*/%", op[0]))
    { return 5; }

    return -1;
}

static bool
is_fn_call(Parser *pr)
{
    if (pr->curr.kind != TOK_LPAREN)
    { return false; }
    if (parser_peek(pr, 1).kind != TOK_IDENTIFIER)
    { return false; }
    if (parser_peek(pr, 2).kind != TOK_RPAREN)
    { return false; }

    return parser_peek(pr, 3).kind == TOK_LBRACKET;
}

// At top level a declaration is a function only if a `:` follows the name.
static bool
is_tu_var_decl(Parser *pr)
{
    Lexer lx  = pr->lexer;
    Token tok = pr->curr;

    while (tok.kind == TOK_AT)
    { tok = lexer_next(&lx); }

    if (tok.kind != TOK_IDENTIFIER)
    { return false; }
    if (lexer_next(&lx).kind != TOK_IDENTIFIER)
    { return false; }

    return lexer_next(&lx).kind != TOK_COLON;
}

static bool
is_var_decl(Parser *pr)
{
    Lexer lx = pr->lexer;
    Token tok = pr->curr;
    while (tok.kind == TOK_AT)
    { tok = lexer_next(&lx); }
    
    if (tok.kind != TOK_IDENTIFIER)
    { return false; }

    return lexer_next(&lx).kind == TOK_IDENTIFIER;
}

static ASTNode *parse_expr(Parser *);
static ASTNode *parse_expr_prec(Parser *, int);

static ASTNode * // N_Argument
parse_arguments(Parser *pr)
{
    expect(pr, TOK_LBRACKET);
    if (match(pr, TOK_RBRACKET))
    { return NULL; }

    ASTNode *head = NULL;
    ASTNode **tail = &head;

    bool is_arg = true;
    while (is_arg)
    {
        ASTNode *arg = ast_node_new(pr->ast);
        arg->kind = NT_ARGUMENT;
        arg->as.argument.next_arg = NULL;
        set_loc(arg, pr->curr);

        // VBAR_PREC + 1: a bare `|` here separates arguments; `(a | b)`
        // is how you pass a bitwise-or as one argument.
        arg->as.argument.argument = parse_expr_prec(pr, 10);

        *tail = arg;
        tail = &arg->as.argument.next_arg;

        if (!match(pr, TOK_VBAR))
        { is_arg = false; }
    }

    expect(pr, TOK_RBRACKET);
    return head;
}

static ASTNode * // N_FnCall
parse_fn_call(Parser *pr)
{
    ASTNode *call = ast_node_new(pr->ast);
    call->kind = NT_FN_CALL;
    set_loc(call, pr->curr);

    expect(pr, TOK_LPAREN);
    call->as.fn_call.ident = parse_ident(pr);
    expect(pr, TOK_RPAREN);

    call->as.fn_call.args = parse_arguments(pr);

    return call;
}


static ASTNode * // N_Literal
parse_literal(Parser *pr)
{
    ASTNode *lit = ast_node_new(pr->ast);
    lit->kind = NT_LITERAL;
    set_loc(lit, pr->curr);

    char *lex = pr->curr.lexeme;
    if (match(pr, TOK_TRUE))
    {
        lit->as.literal.kind = LT_BOOLEAN;
        lit->as.literal.as.bool_lit = true;
    }
    else if (match(pr, TOK_FALSE))
    {
        lit->as.literal.kind = LT_BOOLEAN;
        lit->as.literal.as.bool_lit = false;
    }
    else if (match(pr, TOK_INTEGER))
    {
        lit->as.literal.kind = LT_INTEGER;
        lit->as.literal.as.int_lit = atoi(lex);
    }
    else if (match(pr, TOK_CHARACTER))
    {
        // lex still carries both quotes: 'a' -> lex[1] is the character
        lit->as.literal.kind = LT_CHARACTER;
        if (lex[1] == '\\')
        {
            switch (lex[2])
            {
                case 'n':  lit->as.literal.as.char_lit = '\n'; break;
                case 't':  lit->as.literal.as.char_lit = '\t'; break;
                case 'r':  lit->as.literal.as.char_lit = '\r'; break;
                case '0':  lit->as.literal.as.char_lit = '\0'; break;
                case '\\': lit->as.literal.as.char_lit = '\\'; break;
                case '\'': lit->as.literal.as.char_lit = '\''; break;
                case '"':  lit->as.literal.as.char_lit = '"';  break;
                default:
                    TRACE_FATAL("UNKNOWN ESCAPE `\\%c` at %d:%d",
                                lex[2], lit->loc.line, lit->loc.col);
            }
        }
        else
        { lit->as.literal.as.char_lit = lex[1]; }
    }
    else if (match(pr, TOK_STRING))
    {
        lit->as.literal.kind = LT_STRING;
        lit->as.literal.as.str_lit = lex;
    }
    else if (match(pr, TOK_FLOAT))
    {
        lit->as.literal.kind = LT_FLOAT;
        lit->as.literal.as.float_lit = atof(lex);
    }
    else
    {
        TRACE_FATAL("UNREACHABLE");
        exit(1);
    }

    return lit;
}

static ASTNode * // N_BuiltIn
parse_builtin(Parser *pr)
{
    ASTNode *built = ast_node_new(pr->ast);
    built->kind = NT_BUILTIN;
    set_loc(built, pr->curr);

    if (match(pr, TOK_SIZE))
    {
        built->as.builtin.kind = BI_SIZE;
        expect(pr, TOK_LBRACKET);
        built->as.builtin.as.size = parse_ident(pr);
        expect(pr, TOK_RBRACKET);
    }
    else
    {
        unexpected(pr);
    }

    return built;
}

static ASTNode *
parse_primary(Parser *pr)
{
    if (TokType(pr) == TOK_SIZE)
    {
        return parse_builtin(pr);
    }

    if (is_fn_call(pr))
    {
        return parse_fn_call(pr);
    }

    if (match(pr, TOK_LPAREN))
    {
        ASTNode *expr = parse_expr(pr);
        expect(pr, TOK_RPAREN);
        return expr;
    }

    if (TokType(pr) == TOK_IDENTIFIER)
    {
        return parse_ident(pr);
    }
    
    if (TokType(pr) == TOK_INTEGER   ||
        TokType(pr) == TOK_FLOAT     ||
        TokType(pr) == TOK_CHARACTER ||
        TokType(pr) == TOK_STRING    || 
        TokType(pr) == TOK_TRUE      ||
        TokType(pr) == TOK_FALSE)
    {
        return parse_literal(pr);
    }

    unexpected(pr);
    return NULL;
}

static ASTNode *
parse_expression(Parser *pr, int min_prec)
{
    ASTNode *lhs;

    // prefix_precendence is the single source of truth for what can lead
    // an expression; duplicating the token test here drifts out of sync.
    int pfx = prefix_precendence(pr);
    if (pfx > 0)
    {
        Token op_tok = pr->curr;
        parser_next(pr);

        ASTNode *node = ast_node_new(pr->ast);
        node->kind = NT_UNY_OP;
        node->as.uny_op.operand = parse_expression(pr, pfx);
        set_loc(node, op_tok);

        if (op_tok.kind == TOK_QMARK)
        { node->as.uny_op.kind = UOT_DEREF; }
        else if (op_tok.kind == TOK_AT)
        { node->as.uny_op.kind = UOT_REF; }
        else if (op_tok.lexeme && strcmp(op_tok.lexeme, "!") == 0)
        { node->as.uny_op.kind = UOT_NOT; }
        else if (op_tok.lexeme && strcmp(op_tok.lexeme, "~") == 0)
        { node->as.uny_op.kind = UOT_BNOT; }
        else
        { node->as.uny_op.kind = UOT_NEG; }

        lhs = node;
    }
    else
    {
        lhs = parse_primary(pr);
    }

    while (1)
    {
        int prec = infix_precendence(pr);
        if (prec < min_prec)
        { break; }

        Token op_tok = pr->curr;
        parser_next(pr);

        if (op_tok.kind == TOK_AS)
        {
            ASTNode *cast = ast_node_new(pr->ast);
            cast->kind = NT_CAST;
            set_loc(cast, op_tok);
            cast->as.cast.type = parse_type(pr);
            cast->as.cast.expr = lhs;
            lhs = cast;
            continue;
        }

        int next_min = prec + 1;
        ASTNode *rhs = parse_expression(pr, next_min);

        ASTNode *node = ast_node_new(pr->ast);
        node->kind = NT_BIN_OP;
        node->as.bin_op.left = lhs;
        node->as.bin_op.right = rhs;
        set_loc(node, op_tok);

        if (op_tok.kind == TOK_DOT)
        { node->as.bin_op.kind = BOT_MEMBER; }
        else if (op_tok.kind == TOK_VBAR)
        { node->as.bin_op.kind = BOT_BOR; }
        else if (strcmp(op_tok.lexeme, "+") == 0)
        { node->as.bin_op.kind = BOT_PLUS; }
        else if (strcmp(op_tok.lexeme, "-") == 0)
        { node->as.bin_op.kind = BOT_MINUS; }
        else if (strcmp(op_tok.lexeme, "*") == 0)
        { node->as.bin_op.kind = BOT_MULT; }
        else if (strcmp(op_tok.lexeme, "/") == 0)
        { node->as.bin_op.kind = BOT_DIV; }
        else if (strcmp(op_tok.lexeme, "%") == 0)
        { node->as.bin_op.kind = BOT_MOD; }
        else if (strcmp(op_tok.lexeme, "==") == 0)
        { node->as.bin_op.kind = BOT_EQUAL; }
        else if (strcmp(op_tok.lexeme, "!=") == 0)
        { node->as.bin_op.kind = BOT_NEQ; }
        else if (strcmp(op_tok.lexeme, "<") == 0)
        { node->as.bin_op.kind = BOT_LESS; }
        else if (strcmp(op_tok.lexeme, "<=") == 0)
        { node->as.bin_op.kind = BOT_LEQ; }
        else if (strcmp(op_tok.lexeme, ">") == 0)
        { node->as.bin_op.kind = BOT_GREAT; }
        else if (strcmp(op_tok.lexeme, ">=") == 0)
        { node->as.bin_op.kind = BOT_GEQ; }
        else if (strcmp(op_tok.lexeme, "&") == 0)
        { node->as.bin_op.kind = BOT_BAND; }
        else if (strcmp(op_tok.lexeme, "|") == 0)
        { node->as.bin_op.kind = BOT_BOR; }
        else if (strcmp(op_tok.lexeme, "^") == 0)
        { node->as.bin_op.kind = BOT_BXOR; }
        else if (strcmp(op_tok.lexeme, "<<") == 0)
        { node->as.bin_op.kind = BOT_SHL; }
        else if (strcmp(op_tok.lexeme, ">>") == 0)
        { node->as.bin_op.kind = BOT_SHR; }
        else if (strcmp(op_tok.lexeme, "&&") == 0)
        { node->as.bin_op.kind = BOT_AND; }
        else if (strcmp(op_tok.lexeme, "||") == 0)
        { node->as.bin_op.kind = BOT_OR; }
        else if (strcmp(op_tok.lexeme, "=") == 0)
        { node->as.bin_op.kind = BOT_ASSIGN; }
        else if (op_tok.lexeme[1] == '=' && strchr("+-*/%", op_tok.lexeme[0]))
        {
            // a += b  is  a = a + b. PLUM has no side-effecting lvalues,
            // so evaluating the left side twice is safe.
            ASTNode *inner = ast_node_new(pr->ast);
            inner->kind = NT_BIN_OP;
            set_loc(inner, op_tok);
            inner->as.bin_op.left  = node->as.bin_op.left;
            inner->as.bin_op.right = node->as.bin_op.right;
            switch (op_tok.lexeme[0])
            {
                case '+': inner->as.bin_op.kind = BOT_PLUS;  break;
                case '-': inner->as.bin_op.kind = BOT_MINUS; break;
                case '*': inner->as.bin_op.kind = BOT_MULT;  break;
                case '/': inner->as.bin_op.kind = BOT_DIV;   break;
                default:  inner->as.bin_op.kind = BOT_MOD;   break;
            }

            ASTNode *wrap = ast_node_new(pr->ast);
            wrap->kind = NT_EXPR;
            wrap->as.expr.kind = ET_BIN_OP;
            wrap->as.expr.expr = inner;
            set_loc(wrap, op_tok);

            node->as.bin_op.kind  = BOT_ASSIGN;
            node->as.bin_op.right = wrap;
        }
        else
        { TRACE_FATAL("UNIMPL"); }

        lhs = node;
    }

    return lhs;
}

static ASTNode * // N_Expr
parse_expr_prec(Parser *pr, int min_prec)
{
    // PRATT PARSING
    ASTNode *expr = ast_node_new(pr->ast);
    expr->kind = NT_EXPR;
    set_loc(expr, pr->curr);

    expr->as.expr.expr = parse_expression(pr, min_prec);
    if (expr->as.expr.expr->kind == NT_UNY_OP)
    { expr->as.expr.kind = ET_UNY_OP; }
    else if (expr->as.expr.expr->kind == NT_IDENT)
    { expr->as.expr.kind = ET_IDENT; }
    else if (expr->as.expr.expr->kind == NT_BIN_OP)
    { expr->as.expr.kind = ET_BIN_OP; }
    else if (expr->as.expr.expr->kind == NT_LITERAL)
    { expr->as.expr.kind = ET_LITERAL; }
    else if (expr->as.expr.expr->kind == NT_FN_CALL)
    { expr->as.expr.kind = ET_FN_CALL; }
    else if (expr->as.expr.expr->kind == NT_EXPR)
    { expr->as.expr.kind = ET_EXPR; }
    else if (expr->as.expr.expr->kind == NT_BUILTIN)
    { expr->as.expr.kind = ET_BUILTIN; }
    else if (expr->as.expr.expr->kind == NT_CAST)
    { expr->as.expr.kind = ET_CAST; }
    else
    { TRACE_FATAL("FUCKY WACKY %u", expr->as.expr.expr->kind); }

    return expr;
}

static ASTNode * // N_Expr
parse_expr(Parser *pr)
{ return parse_expr_prec(pr, 0); }

static ASTNode * // N_Ret
parse_return(Parser *pr)
{
    ASTNode *ret = ast_node_new(pr->ast);
    ret->kind = NT_RET;
    ret->as.ret.expr = NULL;
    set_loc(ret, pr->curr);

    expect(pr, TOK_RET);
    if (!match(pr, TOK_LBRACKET))
    { return ret; }

    // RET [] -- void return, as in syntax/plum.ebnf and plum/main.pl
    if (match(pr, TOK_RBRACKET))
    { return ret; }

    ret->as.ret.expr = parse_expr(pr);

    expect(pr, TOK_RBRACKET);
    return ret;
}

static ASTNode * // N_VarDecl
parse_var_decl(Parser *pr)
{
    ASTNode *decl = ast_node_new(pr->ast);
    decl->kind = NT_VAR_DECL;
    set_loc(decl, pr->curr);

    decl->as.var_decl.type = parse_type(pr);
    decl->as.var_decl.ident = parse_ident(pr);
    decl->as.var_decl.init = NULL;

    if (TokType(pr) == TOK_OPERATOR && strcmp(pr->curr.lexeme, "=") == 0)
    {
        parser_next(pr);
        decl->as.var_decl.init = parse_expr(pr);
    }

    return decl;
}

static ASTNode * // N_Stmt
parse_stmt(Parser *pr);

static ASTNode * // N_Block
parse_block_if(Parser *pr)
{
    TRACE_DEBUG("PARSING IF BLOCK %d", pr->indent);

    Token start = pr->curr; expect(pr, TOK_NEWLINE);
    check_indent(pr, start);

    ASTNode *block = ast_node_new(pr->ast);
    block->kind = NT_BLOCK;
    block->as.block.stmts = NULL;
    set_loc(block, start);

    ASTNode **stmts_tail = &block->as.block.stmts;

    while (1)
    {
        while (TokType(pr) == TOK_NEWLINE)
        { check_indent(pr, pr->curr); parser_next(pr); }

        ASTNode *stmt = parse_stmt(pr);

        *stmts_tail = stmt;
        stmts_tail = &stmt->as.stmt.next_stmt;

        while (TokType(pr) == TOK_NEWLINE)
        {
            if (pr->curr.indent == pr->indent || pr->curr.indent == 0)
            { parser_next(pr); }
            else if (pr->curr.indent == pr->indent -1)
            { parser_next(pr); break; }
            else
            { unexpected(pr); }
        }

        if (TokType(pr) == TOK_END_BLOCK ||
            TokType(pr) == TOK_ELIF      ||
            TokType(pr) == TOK_ELSE)
        { break; }
    }

    return block;
}

static ASTNode * // N_Block
parse_block(Parser *pr);

static ASTNode * // N_Cond
parse_cond_stmt(Parser *pr)
{
    ASTNode *cond = ast_node_new(pr->ast);
    cond->kind = NT_COND;
    cond->as.cond.elif_part = NULL;
    cond->as.cond.else_part = NULL;
    set_loc(cond, pr->curr);

    ASTNode *if_p = ast_node_new(pr->ast);
    if_p->kind = NT_IF;
    set_loc(if_p, pr->curr);
    expect(pr, TOK_IF);
    expect(pr, TOK_LBRACKET);
    if_p->as.if_cond.expr = parse_expr(pr);
    expect(pr, TOK_RBRACKET);

    pr->indent += 1;
    if_p->as.if_cond.block = parse_block_if(pr);
    pr->indent -= 1;

    cond->as.cond.if_part = if_p;

    if (match(pr, TOK_END_BLOCK))
    {
        return cond;
    }
    ASTNode **elif_tail = &cond->as.cond.elif_part;
    while (match(pr, TOK_ELIF))
    {
        ASTNode *elif_p = ast_node_new(pr->ast);
        elif_p->kind = NT_ELIF;
        set_loc(elif_p, pr->curr);
        expect(pr, TOK_LBRACKET);
        elif_p->as.elif_cond.expr = parse_expr(pr);
        expect(pr, TOK_RBRACKET);

        pr->indent += 1;
        elif_p->as.elif_cond.block = parse_block_if(pr);
        pr->indent -= 1;

        *elif_tail = elif_p;
        elif_tail = &elif_p->as.elif_cond.next_elif;

        // a chain with no ELSE is closed by \_ , as the bare IF case is
        if (match(pr, TOK_END_BLOCK))
        { return cond; }
    }
    if (match(pr, TOK_ELSE))
    {
        ASTNode *else_p = ast_node_new(pr->ast);
        else_p->kind = NT_ELSE;
        set_loc(else_p, pr->curr);
            
        pr->indent += 1;
        else_p->as.else_cond.block = parse_block(pr);
        pr->indent -= 1;
        
        cond->as.cond.else_part = else_p;
    }

    return cond;
}


static ASTNode * // N_Loop
parse_while(Parser *pr)
{
    ASTNode *loop = ast_node_new(pr->ast);
    loop->kind = NT_LOOP;
    set_loc(loop, pr->curr);

    expect(pr, TOK_WHILE);
    expect(pr, TOK_LBRACKET);
    loop->as.loop.expr = parse_expr(pr);
    expect(pr, TOK_RBRACKET);

    pr->indent += 1;
    loop->as.loop.block = parse_block(pr);
    pr->indent -= 1;

    return loop;
}

static ASTNode * // N_Loop
parse_loop(Parser *pr)
{
    ASTNode *loop = ast_node_new(pr->ast);
    loop->kind = NT_LOOP;
    set_loc(loop, pr->curr);
    expect(pr, TOK_LOOP);

    pr->indent += 1;
    loop->as.loop.block = parse_block(pr);
    pr->indent -= 1;

    return loop;
}

static ASTNode * // N_Stmt
parse_stmt(Parser *pr)
{
    ASTNode *stmt = ast_node_new(pr->ast);
    stmt->kind = NT_STMT;
    stmt->as.stmt.next_stmt = NULL;
    set_loc(stmt, pr->curr);

    if (TokType(pr) == TOK_RET)
    {
        stmt->as.stmt.kind = ST_RET;
        stmt->as.stmt.stmt = parse_return(pr);
    }
    else if (match(pr, TOK_BREAK))
    {
        stmt->as.stmt.kind = ST_BREAK;
        stmt->as.stmt.stmt = NULL;
    }
    else if (match(pr, TOK_CONTINUE))
    {
        stmt->as.stmt.kind = ST_CONTINUE;
        stmt->as.stmt.stmt = NULL;
    }
    else if (TokType(pr) == TOK_WHILE)
    {
        stmt->as.stmt.kind = ST_LOOP;
        stmt->as.stmt.stmt = parse_while(pr);
    }
    else if (is_var_decl(pr))
    {
        stmt->as.stmt.kind = ST_VAR_DECL;
        stmt->as.stmt.stmt = parse_var_decl(pr);
    }
    else if (TokType(pr) == TOK_IF)
    {
        stmt->as.stmt.kind = ST_COND;
        stmt->as.stmt.stmt = parse_cond_stmt(pr);
    }
    else if (TokType(pr) == TOK_LOOP)
    {
        stmt->as.stmt.kind = ST_LOOP;
        stmt->as.stmt.stmt = parse_loop(pr);
    }
    else
    {
        stmt->as.stmt.kind = ST_EXPR;
        stmt->as.stmt.stmt = parse_expr(pr);
    }

    return stmt;
}

static ASTNode * // N_Block
parse_block(Parser *pr)
{
    TRACE_DEBUG("PARSING BLOCK %d", pr->indent);
    //token_dump(pr->curr);

    ASTNode *block = ast_node_new(pr->ast);
    block->kind = NT_BLOCK;
    block->as.block.stmts = NULL;
    set_loc(block, pr->curr);

    Token start = pr->curr;
    if (match(pr, TOK_END_BLOCK))
    { return block; }

    expect(pr, TOK_NEWLINE);
    check_indent(pr, start);

    ASTNode **stmts_tail = &block->as.block.stmts;

    while (1)
    {

        while (TokType(pr) == TOK_NEWLINE)
        { check_indent(pr, pr->curr); parser_next(pr); }

        ASTNode *stmt = parse_stmt(pr);

        *stmts_tail = stmt;
        stmts_tail = &stmt->as.stmt.next_stmt;

        while (TokType(pr) == TOK_NEWLINE)
        { check_indent(pr, pr->curr); parser_next(pr); }
        if (match(pr, TOK_END_BLOCK))
        { break; }
    }

    return block;
}

static ASTNode * // N_TUStmt
parse_tu_stmt(Parser *pr)
{
    ASTNode *tu_stmt = ast_node_new(pr->ast);
    tu_stmt->kind = NT_TU_STMT;
    set_loc(tu_stmt, pr->curr);

    if (pr->curr.kind == TOK_TYPE)
    {
        tu_stmt->as.tu_stmt.kind = TUST_TYPE_DEF;
        tu_stmt->as.tu_stmt.tu_stmt = parse_type_def(pr);
    }
    else if ((pr->curr.kind == TOK_AT || pr->curr.kind == TOK_IDENTIFIER)
             && is_tu_var_decl(pr))
    {
        tu_stmt->as.tu_stmt.kind = TUST_VAR_DECL;
        tu_stmt->as.tu_stmt.tu_stmt = parse_var_decl(pr);
    }
    else if (pr->curr.kind == TOK_AT || pr->curr.kind == TOK_IDENTIFIER)
    {
        ASTNode *decl = parse_fn_decl(pr);

        // SKIP TO CHECK ON START OF BLOCK
        while (pr->curr.kind == TOK_NEWLINE && pr->curr.indent == 0)
        { expect(pr, TOK_NEWLINE); }

        if ((pr->curr.kind == TOK_NEWLINE && pr->curr.indent == 1) || pr->curr.kind == TOK_END_BLOCK)
        {
            ASTNode *def = ast_node_new(pr->ast);
            def->kind = NT_FN_DEF;
            def->loc = decl->loc;
            def->as.fn_def.decl = decl;
            tu_stmt->as.tu_stmt.kind = TUST_FN_DEF;
            tu_stmt->as.tu_stmt.tu_stmt = def;

            def->as.fn_def.block = parse_block(pr);
        }
        else
        {
            tu_stmt->as.tu_stmt.kind = TUST_FN_DECL;
            tu_stmt->as.tu_stmt.tu_stmt = decl;
        }
    }
    else
    {
        unexpected(pr);
    }

    return tu_stmt;
}

void
parse_unit(AST *ast, DynString *source)
{
    Parser parser;
    parser.ast = ast;
    parser.indent = 1;
    lexer_init(&parser.lexer, source);

    ASTNode **tu_tail = &parser.ast->root->as.tu.tu_stmt;

    parser_next(&parser);

    while (!IS_EOF(parser))
    {
        // token_dump(parser.current);
        // parser_next(&parser);   
        
        if (parser.curr.kind == TOK_NEWLINE)
        { parser_next(&parser); continue; }

        ASTNode *tu_stmt = parse_tu_stmt(&parser);
        *tu_tail = tu_stmt;
        tu_tail = &tu_stmt->as.tu_stmt.next_tu_stmt;
    }
}
