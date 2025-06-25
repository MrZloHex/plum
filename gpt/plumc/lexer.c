
#include "token.h"

static bool is_ident_start(int c) { return isalpha(c) || c == '_'; }
static bool is_ident(int c)       { return isalnum(c) || c == '_'; }

static const struct { const char *kw; TokenType tk; } kw_table[] = {
    {"TYPE",        TOK_TYPE},
    {"STRUCTURE",   TOK_STRUCTURE},
    {"UNION",       TOK_UNION},
    {"ENUMERATION", TOK_ENUMERATION},
    {"IF",          TOK_IF},
    {"ELIF",        TOK_ELIF},
    {"ELSE",        TOK_ELSE},
    {"LOOP",        TOK_LOOP},
    {"BREAK",       TOK_BREAK},
    {"RET",         TOK_RET},
    {"SIZE",        TOK_SIZE},
    {NULL,          TOK_EOF}
};

static Token make(TokenType k, char *lex, int line, int col, int indent)
{
    Token t = {.kind = k, .lexeme = lex, .line = line, .col = col, .indent = indent};
    return t;
}

static char peek(Lexer *lx) { return lx->src[lx->pos]; }
static char look(Lexer *lx, size_t n) { return lx->src[lx->pos + n]; }
static char nextc(Lexer *lx) { 
    char c = lx->src[lx->pos]; 
    if (c) { lx->pos++; lx->col++; }
    return c; 
}

static void skip_spaces(Lexer *lx)
{
    while (peek(lx) == ' ')
        nextc(lx);
}

void lexer_init(Lexer *lx, const char *src)
{
    lx->src = src;
    lx->pos = 0;
    lx->line = 1;
    lx->col = 1;
}

/* helper to duplicate substring */
static char *substr(const char *src, size_t start, size_t len)
{
    char *s = (char *)xmalloc(len + 1);
    memcpy(s, src + start, len);
    s[len] = '\0';
    return s;
}

/* lexing numeric literal */
static Token lex_number(Lexer *lx)
{
    int line = lx->line, col = lx->col;
    size_t start = lx->pos;
    bool is_float = false;

    /* optional 0x,0b,0o prefix already part of stream, just consume alnum/_/. */
    while (isalnum(peek(lx)) || peek(lx) == '_' || peek(lx) == '.')
    {
        if (peek(lx) == '.') is_float = true;
        nextc(lx);
    }
    size_t len = lx->pos - start;
    char *lex = substr(lx->src, start, len);
    return make(is_float ? TOK_FLOAT : TOK_INTEGER, lex, line, col, -1);
}

static Token lex_identifier_or_keyword(Lexer *lx)
{
    int line = lx->line, col = lx->col;
    size_t start = lx->pos;
    nextc(lx);
    while (is_ident(peek(lx)))
        nextc(lx);
    size_t len = lx->pos - start;
    char *lex = substr(lx->src, start, len);

    for (int i = 0; kw_table[i].kw; ++i)
        if (strcmp(kw_table[i].kw, lex) == 0)
        {
            free(lex);
            return make(kw_table[i].tk, NULL, line, col, -1);
        }
    return make(TOK_IDENTIFIER, lex, line, col, -1);
}

static Token lex_string(Lexer *lx, char term, TokenType kind)
{
    int line = lx->line, col = lx->col;
    size_t start = lx->pos;
    nextc(lx); /* consume quote */

    while (peek(lx) && peek(lx) != term)
    {
        if (peek(lx) == '\\')
            nextc(lx); /* escape next */
        nextc(lx);
    }
    if (peek(lx) != term)
        die("unterminated string/char literal");
    nextc(lx); /* closing quote */

    size_t len = lx->pos - start;
    char *lex = substr(lx->src, start, len);
    return make(kind, lex, line, col, -1);
}

const char *token_name(TokenType t)
{
    switch (t)
    {
#define CASE(x) case x: return #x;
        CASE(TOK_EOF) CASE(TOK_NEWLINE) CASE(TOK_END_BLOCK) CASE(TOK_COLON)
        CASE(TOK_LBRACKET) CASE(TOK_RBRACKET) CASE(TOK_PIPE) CASE(TOK_DOT)
        CASE(TOK_AT) CASE(TOK_QMARK) CASE(TOK_ELLIPSIS) CASE(TOK_OPERATOR)
        CASE(TOK_IDENTIFIER) CASE(TOK_INTEGER) CASE(TOK_FLOAT) CASE(TOK_STRING)
        CASE(TOK_CHAR) CASE(TOK_TYPE) CASE(TOK_STRUCTURE) CASE(TOK_UNION)
        CASE(TOK_ENUMERATION) CASE(TOK_IF) CASE(TOK_ELIF) CASE(TOK_ELSE)
        CASE(TOK_LOOP) CASE(TOK_BREAK) CASE(TOK_RET) CASE(TOK_SIZE)
#undef CASE
    default: return "UNKNOWN";
    }
}

Token lexer_next(Lexer *lx)
{
    while (true)
    {
        char c = peek(lx);
        /* end of input */
        if (c == '\0')
            return make(TOK_EOF, NULL, lx->line, lx->col, -1);

        /* newline handling */
        if (c == '\n' || c == '\r')
        {
            /* universal newline */
            if (c == '\r' && look(lx,1) == '\n')
                nextc(lx);
            nextc(lx); /* consume newline */
            lx->line++;
            lx->col = 1;

            int indent = 0;
            /* count bars after leading spaces */
            while (peek(lx) == ' ')
                nextc(lx);
            while (peek(lx) == '|')
            {
                indent++;
                nextc(lx);
            }

            /* check for \_ */
            size_t save_pos = lx->pos;
            int save_col = lx->col;
            skip_spaces(lx);
            if (peek(lx) == '\\' && look(lx,1) == '_')
            {
                lx->pos += 2;
                lx->col += 2;
                /* skip rest of line to newline */
                while (peek(lx) && peek(lx) != '\n' && peek(lx) != '\r')
                    nextc(lx);
                return make(TOK_END_BLOCK, NULL, lx->line, 1, indent);
            }
            else
            {
                /* restore */
                lx->pos = save_pos;
                lx->col = save_col;
            }
            return make(TOK_NEWLINE, NULL, lx->line, 1, indent);
        }

        /* skip spaces/tabs inside line (tabs forbidden) */
        if (c == ' ')
        {
            nextc(lx);
            continue;
        }
        if (c == '\t')
            die("tabs are not allowed, use '|' for indent");

        /* comment */
        if (c == ';')
        {
            while (peek(lx) && peek(lx) != '\n' && peek(lx) != '\r')
                nextc(lx);
            continue; /* newline will be handled */
        }

        /* punctuation */
        if (c == ':') { nextc(lx); return make(TOK_COLON, NULL, lx->line, lx->col-1, -1); }
        if (c == '[') { nextc(lx); return make(TOK_LBRACKET, NULL, lx->line, lx->col-1, -1); }
        if (c == ']') { nextc(lx); return make(TOK_RBRACKET, NULL, lx->line, lx->col-1, -1); }
        if (c == '|') { nextc(lx); return make(TOK_PIPE, NULL, lx->line, lx->col-1, -1); }
        if (c == '@') { nextc(lx); return make(TOK_AT, NULL, lx->line, lx->col-1, -1); }
        if (c == '?') { nextc(lx); return make(TOK_QMARK, NULL, lx->line, lx->col-1, -1); }
        if (c == '.' && look(lx,1)=='.' && look(lx,2)=='.')
        {
            /* ellipsis */
            nextc(lx); nextc(lx); nextc(lx);
            return make(TOK_ELLIPSIS, NULL, lx->line, lx->col-3, -1);
        }
        if (c == '.') { nextc(lx); return make(TOK_DOT, NULL, lx->line, lx->col-1, -1); }

        /* string / char */
        if (c == '"') return lex_string(lx, '"', TOK_STRING);
        if (c == '\'') return lex_string(lx, '\'', TOK_CHAR);

        /* number */
        if (isdigit(c)) return lex_number(lx);

        /* identifier / keyword */
        if (is_ident_start(c)) return lex_identifier_or_keyword(lx);

        /* operators */
        if (strchr("+-*/%<>=!", c))
        {
            int line = lx->line, col = lx->col;
            size_t start = lx->pos;
            nextc(lx);
            if (strchr("=<>", peek(lx))) nextc(lx);
            size_t len = lx->pos - start;
            char *lex = substr(lx->src, start, len);
            return make(TOK_OPERATOR, lex, line, col, -1);
        }

        die("unknown character");
    }
}
