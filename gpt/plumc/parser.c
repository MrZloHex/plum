
#include "parser.h"

/* ---------- helpers ---------- */
static void next(Parser *p) { p->current = lexer_next(&p->lx); }

static bool match(Parser *p, TokenType k)
{
    if (p->current.kind == k) { next(p); return true; }
    return false;
}

static void expect(Parser *p, TokenType k)
{
    if (p->current.kind != k)
    {
        fprintf(stderr, "Expected %s, got %s at line %d\n",
                token_name(k), token_name(p->current.kind), p->current.line);
        exit(EXIT_FAILURE);
    }
    next(p);
}

static char *dup_lex(const Token *t) { return t && t->lexeme ? strdup(t->lexeme) : NULL; }

/* ---------- forward decl ---------- */
static AST *parse_statement(Parser *p);
static AST *parse_block(Parser *p);

/* ---------- expressions (Pratt) ---------- */
static int precedence(Token *tok)
{
    if (!tok) return 0;
    if (tok->kind == TOK_DOT) return 14;        /* highest */
    if (tok->kind == TOK_AT || tok->kind == TOK_QMARK) return 13; /* unary */
    if (tok->kind == TOK_OPERATOR)
    {
        const char *op = tok->lexeme;
        if (!op) return 0;
        if (strcmp(op, "*")==0 || strcmp(op,"/")==0 || strcmp(op,"%")==0) return 12;
        if (strcmp(op, "+")==0 || strcmp(op,"-")==0) return 11;
        if (strcmp(op, ">>")==0 || strcmp(op,"<<")==0) return 10;
        if (strcmp(op, "<")==0 || strcmp(op,"<=")==0 || strcmp(op,">")==0 || strcmp(op,">=")==0) return 9;
        if (strcmp(op, "==")==0 || strcmp(op,"!=")==0) return 8;
        if (strcmp(op, "=")==0) return 2; /* assignment lowest handled separately */
    }
    return 0;
}

static AST *parse_expr(Parser *p, int min_prec);

static AST *parse_primary(Parser *p)
{
    Token tok = p->current;
    if (tok.kind == TOK_IDENTIFIER)
    {
        next(p);
        AST *id = ast_new(AST_IDENTIFIER, &tok, dup_lex(&tok));
        /* function call? */
        if (match(p, TOK_LBRACKET))
        {
            AST *call = ast_new(AST_CALL, &tok, dup_lex(&tok)); /* name in text */
            /* parse arg list */
            if (!match(p, TOK_RBRACKET))
            {
                while (true)
                {
                    ast_add(call, parse_expr(p, 0));
                    if (match(p, TOK_PIPE)) continue;
                    expect(p, TOK_RBRACKET);
                    break;
                }
            }
            return call;
        }
        return id;
    }
    else if (tok.kind == TOK_INTEGER || tok.kind == TOK_FLOAT ||
             tok.kind == TOK_STRING || tok.kind == TOK_CHAR)
    {
        next(p);
        return ast_new(AST_LITERAL, &tok, dup_lex(&tok));
    }
    else if (tok.kind == TOK_LBRACKET)
    {
        next(p);
        AST *e = parse_expr(p, 0);
        expect(p, TOK_RBRACKET);
        return e;
    }
    else if (tok.kind == TOK_SIZE)
    {
        next(p);
        expect(p, TOK_LBRACKET);
        AST *arg = parse_expr(p, 0);
        expect(p, TOK_RBRACKET);
        AST *sz = ast_new(AST_SIZEOF, &tok, NULL);
        ast_add(sz, arg);
        return sz;
    }
    die("unexpected token in expression");
    return NULL;
}

static AST *parse_unary(Parser *p)
{
    if (p->current.kind == TOK_AT || p->current.kind == TOK_QMARK)
    {
        Token tok = p->current; next(p);
        AST *u = ast_new(AST_UNARY, &tok, token_name(tok.kind));
        ast_add(u, parse_unary(p));
        return u;
    }
    return parse_primary(p);
}

static AST *parse_expr(Parser *p, int min_prec)
{
    AST *lhs = parse_unary(p);

    while (true)
    {
        Token tok = p->current;
        int prec = precedence(&tok);
        if (prec < min_prec || prec == 0) break;

        next(p); /* consume operator */

        if (tok.kind == TOK_DOT)
        {
            /* field access: lhs . ident */
            Token field_tok = p->current;
            expect(p, TOK_IDENTIFIER);
            AST *dot = ast_new(AST_DOT, &tok, dup_lex(&field_tok));
            ast_add(dot, lhs);
            lhs = dot;
            continue;
        }

        /* binary */
        AST *bin = ast_new(AST_BINARY, &tok, dup_lex(&tok));
        ast_add(bin, lhs);
        AST *rhs = parse_expr(p, prec + 1);
        ast_add(bin, rhs);
        lhs = bin;
    }
    return lhs;
}

/* ---------- type definitions ---------- */

static AST *parse_struct_union_body(Parser *p, ASTKind field_parent_kind)
{
    AST *parent = ast_new(field_parent_kind, NULL, NULL);
    expect(p, TOK_NEWLINE);

    while (p->current.kind != TOK_END_BLOCK)
    {
        if (p->current.kind == TOK_NEWLINE) { next(p); continue; }
        Token type_tok = p->current; expect(p, TOK_IDENTIFIER);
        Token name_tok = p->current; expect(p, TOK_IDENTIFIER);
        AST *field = ast_new(AST_FIELD, &type_tok, NULL);
        ast_add(field, ast_new(AST_IDENTIFIER, &type_tok, dup_lex(&type_tok)));
        ast_add(field, ast_new(AST_IDENTIFIER, &name_tok, dup_lex(&name_tok)));
        ast_add(parent, field);
        expect(p, TOK_NEWLINE);
    }
    expect(p, TOK_END_BLOCK);
    return parent;
}

static AST *parse_enum_body(Parser *p)
{
    AST *en = ast_new(AST_ENUM, NULL, NULL);
    expect(p, TOK_NEWLINE);
    int value = 0;
    char valbuf[32];
    while (p->current.kind != TOK_END_BLOCK)
    {
        if (p->current.kind == TOK_NEWLINE) { next(p); continue; }
        Token name_tok = p->current; expect(p, TOK_IDENTIFIER);
        snprintf(valbuf, sizeof(valbuf), "%d", value++);
        AST *field = ast_new(AST_FIELD, &name_tok, dup_lex(&name_tok));
        ast_add(field, ast_new(AST_LITERAL, &name_tok, valbuf));
        ast_add(en, field);
        expect(p, TOK_NEWLINE);
    }
    expect(p, TOK_END_BLOCK);
    return en;
}

static AST *parse_type_definition(Parser *p)
{
    Token type_kw = p->current; expect(p, TOK_TYPE);
    Token name_tok = p->current; expect(p, TOK_IDENTIFIER);
    char *name = dup_lex(&name_tok);

    bool has_colon = match(p, TOK_COLON);

    if (has_colon)
    {
        if (match(p, TOK_STRUCTURE))
        {
            AST *struc = ast_new(AST_STRUCT, &name_tok, name);
            ast_add(struc, parse_struct_union_body(p, AST_STRUCT));
            return struc;
        }
        else if (match(p, TOK_UNION))
        {
            AST *un = ast_new(AST_UNION, &name_tok, name);
            ast_add(un, parse_struct_union_body(p, AST_UNION));
            return un;
        }
        else
        {
            /* alias */
            Token target_tok = p->current; expect(p, TOK_IDENTIFIER);
            AST *alias = ast_new(AST_TYPEDEF, &name_tok, name);
            ast_add(alias, ast_new(AST_IDENTIFIER, &target_tok, dup_lex(&target_tok)));
            /* rest of line to newline */
            while (p->current.kind != TOK_NEWLINE && p->current.kind != TOK_EOF)
                next(p);
            match(p, TOK_NEWLINE);
            return alias;
        }
    }
    else
    {
        /* ENUMERATION */
        expect(p, TOK_ENUMERATION);
        AST *en = ast_new(AST_ENUM, &name_tok, name);
        ast_add(en, parse_enum_body(p));
        return en;
    }
}

/* ---------- parameters ---------- */
static AST *parse_param_list(Parser *p)
{
    AST *params = ast_new(AST_PARAM, NULL, NULL); /* container */
    expect(p, TOK_LBRACKET);
    if (match(p, TOK_RBRACKET))
        return params;

    while (true)
    {
        if (p->current.kind == TOK_ELLIPSIS)
        {
            Token tok = p->current; next(p);
            ast_add(params, ast_new(AST_PARAM, &tok, "..."));
        }
        else
        {
            Token type_tok = p->current; expect(p, TOK_IDENTIFIER);
            Token name_tok = p->current; expect(p, TOK_IDENTIFIER);
            AST *param = ast_new(AST_PARAM, &type_tok, NULL);
            ast_add(param, ast_new(AST_IDENTIFIER, &type_tok, dup_lex(&type_tok)));
            ast_add(param, ast_new(AST_IDENTIFIER, &name_tok, dup_lex(&name_tok)));
            ast_add(params, param);
        }
        if (match(p, TOK_PIPE)) continue;
        expect(p, TOK_RBRACKET);
        break;
    }
    return params;
}

/* ---------- statements ---------- */

static AST *parse_if_statement(Parser *p)
{
    Token if_tok = p->current; expect(p, TOK_IF);
    expect(p, TOK_LBRACKET);
    AST *cond = parse_expr(p, 0);
    expect(p, TOK_RBRACKET);
    AST *ifnode = ast_new(AST_IF, &if_tok, NULL);
    expect(p, TOK_NEWLINE);
    ast_add(ifnode, parse_block(p)); /* then */

    /* zero or more ELIF */
    while (p->current.kind == TOK_ELIF)
    {
        Token el_tok = p->current; next(p);
        expect(p, TOK_LBRACKET);
        AST *cond2 = parse_expr(p, 0);
        expect(p, TOK_RBRACKET);
        AST *elifnode = ast_new(AST_ELIF, &el_tok, NULL);
        expect(p, TOK_NEWLINE);
        ast_add(elifnode, cond2);
        ast_add(elifnode, parse_block(p));
        ast_add(ifnode, elifnode);
    }

    /* optional ELSE */
    if (p->current.kind == TOK_ELSE)
    {
        Token else_tok = p->current; next(p);
        AST *elsenode = ast_new(AST_ELSE, &else_tok, NULL);
        expect(p, TOK_NEWLINE);
        ast_add(elsenode, parse_block(p));
        ast_add(ifnode, elsenode);
    }

    return ifnode;
}

static AST *parse_loop_statement(Parser *p)
{
    Token tok = p->current; expect(p, TOK_LOOP);
    AST *loop = ast_new(AST_LOOP, &tok, NULL);
    expect(p, TOK_NEWLINE);
    ast_add(loop, parse_block(p));
    return loop;
}

static AST *parse_return_statement(Parser *p)
{
    Token tok = p->current; expect(p, TOK_RET);
    AST *ret = ast_new(AST_RETURN, &tok, NULL);
    if (p->current.kind == TOK_LBRACKET)
    {
        expect(p, TOK_LBRACKET);
        if (p->current.kind != TOK_RBRACKET)
            ast_add(ret, parse_expr(p,0));
        expect(p, TOK_RBRACKET);
    }
    return ret;
}

static AST *parse_var_decl(Parser *p)
{
    Token type_tok = p->current; expect(p, TOK_IDENTIFIER);
    Token name_tok = p->current; expect(p, TOK_IDENTIFIER);
    AST *decl = ast_new(AST_VAR_DECL, &type_tok, NULL);
    ast_add(decl, ast_new(AST_IDENTIFIER, &type_tok, dup_lex(&type_tok)));
    ast_add(decl, ast_new(AST_IDENTIFIER, &name_tok, dup_lex(&name_tok)));

    if (match(p, TOK_OPERATOR) && p->current.lexeme && strcmp(p->current.lexeme,"=")==0)
    {
        /* consume '=' token already matched; parse RHS expr */
        AST *assign = ast_new(AST_ASSIGN, &type_tok, "=");
        ast_add(assign, decl);
        ast_add(assign, parse_expr(p, 0));
        return assign;
    }
    return decl;
}

static AST *parse_expr_statement(Parser *p)
{
    AST *e = parse_expr(p, 0);
    AST *st = ast_new(AST_EXPR_STMT, NULL, NULL);
    ast_add(st, e);
    return st;
}

static AST *parse_one_line_statement(Parser *p)
{
    if (p->current.kind == TOK_IF)      return parse_if_statement(p);
    if (p->current.kind == TOK_LOOP)    return parse_loop_statement(p);
    if (p->current.kind == TOK_BREAK)   { Token t=p->current; next(p); return ast_new(AST_BREAK,&t,NULL); }
    if (p->current.kind == TOK_RET)     return parse_return_statement(p);

    /* try var-decl heuristic: IDENT IDENT ... */
    if (p->current.kind == TOK_IDENTIFIER)
    {
        Token look1 = lexer_next(&p->lx);
        if (look1.kind == TOK_IDENTIFIER)
        {
            /* restore pos */
            p->lx.pos -= strlen(look1.lexeme ? look1.lexeme : "");
            p->lx.pos -= (look1.lexeme ? 0 : 0); /* pos already subtracted */
            /* Actually easier: we can't easily restore lexer's state here; so simpler heuristic: duplicate data with copy of current and lookahead indices. We'll cheat: fallback to var_decl if second token is IDENT */
        }
    }

    /* default: expr statement */
    return parse_expr_statement(p);
}

/* parse block until END_BLOCK */
static AST *parse_block(Parser *p)
{
    AST *blk = ast_new(AST_BLOCK, NULL, NULL);
    while (p->current.kind != TOK_END_BLOCK && p->current.kind != TOK_EOF)
    {
        if (p->current.kind == TOK_NEWLINE) { next(p); continue; }
        AST *st = parse_one_line_statement(p);
        ast_add(blk, st);
        /* consume trailing newline if any */
        if (p->current.kind == TOK_NEWLINE) next(p);
    }
    match(p, TOK_END_BLOCK);
    return blk;
}

/* ---------- function ---------- */
static AST *parse_function(Parser *p)
{
    Token ret_type_tok = p->current; expect(p, TOK_IDENTIFIER);
    char *ret_name = dup_lex(&ret_type_tok);

    Token func_name_tok = p->current; expect(p, TOK_IDENTIFIER);
    char *func_name = dup_lex(&func_name_tok);

    expect(p, TOK_COLON);
    AST *params = parse_param_list(p);

    AST *fn;
    if (p->current.kind == TOK_NEWLINE)
    {
        /* Possibly definition or just declaration; lookahead END_BLOCK? */
        Token save = p->current;
        size_t save_pos = p->lx.pos;
        next(p);
        if (p->current.kind == TOK_PIPE || p->current.kind == TOK_NEWLINE)
        {
            /* definition expected because body starts with indent marker '|' */
            /* restore */
            p->lx.pos = save_pos;
            p->current = save;
            expect(p, TOK_NEWLINE);
            fn = ast_new(AST_FUNC_DEF, &func_name_tok, func_name);
            ast_add(fn, ast_new(AST_IDENTIFIER, &ret_type_tok, ret_name));
            ast_add(fn, params);
            ast_add(fn, parse_block(p));
        }
        else
        {
            /* declaration only */
            p->lx.pos = save_pos;
            p->current = save;
            match(p, TOK_NEWLINE);
            fn = ast_new(AST_FUNC_DECL, &func_name_tok, func_name);
            ast_add(fn, ast_new(AST_IDENTIFIER, &ret_type_tok, ret_name));
            ast_add(fn, params);
        }
    }
    else
    {
        die("expected newline after function header");
    }
    return fn;
}

/* ---------- top-level ---------- */
static AST *parse_toplevel(Parser *p)
{
    if (p->current.kind == TOK_TYPE)
        return parse_type_definition(p);
    else if (p->current.kind == TOK_IDENTIFIER)
        return parse_function(p);
    else
    {
        fprintf(stderr, "Unexpected token %s at line %d\n", token_name(p->current.kind), p->current.line);
        exit(EXIT_FAILURE);
    }
    return NULL;
}

AST *parse_program(const char *src)
{
    Parser p;
    lexer_init(&p.lx, src);
    next(&p);
    AST *prog = ast_new(AST_PROGRAM, NULL, NULL);

    while (p.current.kind != TOK_EOF)
    {
        if (p.current.kind == TOK_NEWLINE) { next(&p); continue; }
        AST *top = parse_toplevel(&p);
        ast_add(prog, top);
        /* consume trailing newline(s) */
        while (p.current.kind == TOK_NEWLINE)
            next(&p);
    }
    return prog;
}
