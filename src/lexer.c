#include "lexer.h"
#include "trace.h"

#include <ctype.h>
#include <string.h>

void
lexer_init(Lexer *lexer, DynString *source)
{
    *lexer = (Lexer)
    {
        .col  = 1,
        .line = 1,
        .pos  = 0,
        .src  = source
    };
    // FOR SAFE LOOKING MAYBE DO SMTH WITH THAT
    dynstr_append_str(lexer->src, "\0\0\0\0\0\0\0\0\0\0");
}


static char
lex_peek(Lexer *lx)
{ return lx->src->data[lx->pos]; }

static char
lex_look(Lexer *lx, size_t n)
{ return lx->src->data[lx->pos + n]; }

static char
lex_nextc(Lexer *lx)
{
    char c = lex_peek(lx);
    if (c)
    { lx->pos++; lx->col++; }
    return c;
}

static Token
make_tok
(
    TokenType type, char *lexeme,
    int line, int col, int indent
)
{
    return (Token)
    {
        .kind = type,
        .lexeme = lexeme,
        .loc =
        {
            .col = col, .line = line
        },
        .indent = indent
    };
}


static int
lex_count_indent(Lexer *lx)
{
    int indent = 0;
    bool is_indent =
    (
        lex_peek(lx)    == ' ' &&
        lex_look(lx, 1) == '|' &&
        lex_look(lx, 2) == ' '
    );

    while (is_indent)
    {
        indent++;
        lx->col += 3;
        lx->pos += 3;
        is_indent =
        (
            lex_peek(lx)    == ' ' &&
            lex_look(lx, 1) == '|' &&
            lex_look(lx, 2) == ' '
        );
    }

    return indent;
}

static bool
lex_is_block_end(Lexer *lx)
{
    return
    (
        lex_peek(lx)    == ' '  &&
        lex_look(lx, 1) == '\\' &&
        lex_look(lx, 2) == '_'
    );
}

static Token
lex_string(Lexer *lx, char term, TokenType kind)
{
    int line = lx->line, col = lx->col;
    size_t start = lx->pos;
    
    lex_nextc(lx); // ate `"`
    
    while (lex_peek(lx) && lex_peek(lx) != term)
    {
        if (lex_peek(lx) == '\\')
        { lex_nextc(lx); }
        lex_nextc(lx);
    }

    if (lex_peek(lx) != term)
    { TRACE_FATAL("UNTERMINATED SYMBOLIC LITERAL! At %d:%d", lx->line, lx->col); }
    lex_nextc(lx);

    size_t len = lx->pos - start;
    char *lex = dynstr_substr(lx->src, start, len);
    if (!lex)
    { TRACE_ERROR("FAILED TO GET SUBSTR"); }

    return make_tok(kind, lex, line, col, -1);
}

static Token
lex_number(Lexer *lx)
{
    int line = lx->line, col = lx->col;
    size_t start = lx->pos;
    bool is_float = false;

    while (isalnum(lex_peek(lx)) || lex_peek(lx) == '_' || lex_peek(lx) == '.')
    {
        if (lex_peek(lx) == '.')
        { is_float = true; }
        lex_nextc(lx);
    }

    size_t len = lx->pos - start;
    char *lex = dynstr_substr(lx->src, start, len);
    if (!lex)
    { TRACE_ERROR("FAILED TO GET SUBSTR"); }

    return make_tok(is_float ? TOK_FLOAT : TOK_INTEGER, lex, line, col, -1);
}

const static struct { const char *kw; TokenType tk; } kw_table[] =
{
    { "TYPE",   TOK_TYPE        },
    { "STRUCT", TOK_STRUCTURE   },
    { "UNION",  TOK_UNION       },
    { "ENUM",   TOK_ENUMERATION },
    { "IF",     TOK_IF          },
    { "ELIF",   TOK_ELIF        },
    { "ELSE",   TOK_ELSE        },
    { "LOOP",   TOK_LOOP        },
    { "BREAK",  TOK_BREAK       },
    { "RET",    TOK_RET         },
    { "SIZE",   TOK_SIZE        },
    { "TRUE",   TOK_TRUE        },
    { "FALSE",  TOK_FALSE       },
    { NULL,     TOK_EOF         },
};

static Token
lex_indent_or_keyword(Lexer *lx)
{
    int line = lx->line, col = lx->col;
    size_t start = lx->pos;
    
    lex_nextc(lx);
    while (isalnum(lex_peek(lx)) || lex_peek(lx) == '_')
    { lex_nextc(lx); }

    size_t len = lx->pos - start;
    char *lex = dynstr_substr(lx->src, start, len);
    if (!lex)
    { TRACE_ERROR("FAILED TO GET SUBSTR"); }

    for (size_t i = 0; kw_table[i].kw; ++i)
    {
        if (strcmp(kw_table[i].kw, lex) == 0)
        {
            free(lex);
            return make_tok(kw_table[i].tk, NULL, line, col, -1);
        }
    }

    return make_tok(TOK_IDENTIFIER, lex, line, col, -1);
}

Token
lexer_next(Lexer *lx)
{
    //TRACE_INFO("LEX NEXT");
    while (1)
    {
        char c = lex_peek(lx);

        if (c == '\0')
        { return make_tok(TOK_EOF, NULL, lx->line, lx->col, -1); }

        if (c == '\n' || c == '\r')
        {
            if (c == '\r' && lex_look(lx, 1) == '\n')
            { lex_nextc(lx); }
            lex_nextc(lx);
            lx->line++;
            lx->col = 1;

            int indent = lex_count_indent(lx);
            //TRACE_INFO("FOUND %d indent on line %d", indent, lx->line);
            if (lex_is_block_end(lx))
            {
                // TRACE_INFO("FOUND BLOCK END %d:%d", lx->line, lx->col);
                lx->col += 3;
                lx->pos += 3;
                return make_tok(TOK_END_BLOCK, NULL, lx->line, 1, indent);
            }
            
            return make_tok(TOK_NEWLINE, NULL, lx->line, 1, indent);
        }

        if (c == ' ')
        {
            lex_nextc(lx);
            continue;
        }

        if (c == '\t')
        {
            TRACE_FATAL("TABS ARE RESTRICTED! Tab at %d:%d", lx->line, lx->col);
            exit(33);
        }

        if (c == ';')
        {
            while (lex_peek(lx) && lex_peek(lx) != '\n' && lex_peek(lx) != '\r')
            { lex_nextc(lx); }
            continue;
        }

        if (c == ':')
        { lex_nextc(lx); return make_tok(TOK_COLON, NULL, lx->line, lx->col-1, -1); }
        if (c == '[')
        { lex_nextc(lx); return make_tok(TOK_LBRACKET, NULL, lx->line, lx->col-1, -1); }
        if (c == ']')
        { lex_nextc(lx); return make_tok(TOK_RBRACKET, NULL, lx->line, lx->col-1, -1); }
        if (c == '(')
        { lex_nextc(lx); return make_tok(TOK_LPAREN, NULL, lx->line, lx->col-1, -1); }
        if (c == ')')
        { lex_nextc(lx); return make_tok(TOK_RPAREN, NULL, lx->line, lx->col-1, -1); }
        if (c == '|')
        { lex_nextc(lx); return make_tok(TOK_VBAR, NULL, lx->line, lx->col-1, -1); }
        if (c == '?')
        { lex_nextc(lx); return make_tok(TOK_QMARK, NULL, lx->line, lx->col-1, -1); }
        if (c == '@')
        { lex_nextc(lx); return make_tok(TOK_AT, NULL, lx->line, lx->col-1, -1); }
        if (c == '.' && lex_look(lx, 1) == '.' && lex_look(lx, 2) == '.')
        { lx->col += 3; lx->pos += 3; return make_tok(TOK_ELLIPSIS, NULL, lx->line, lx->col-3, -1); }
        if (c == '.')
        { lex_nextc(lx); return make_tok(TOK_DOT, NULL, lx->line, lx->col-1, -1); }

        if (c == '"')
        { return lex_string(lx, '"', TOK_STRING); }
        if (c == '\'')
        { return lex_string(lx, '\'', TOK_CHARACTER); }

        if (isdigit(c))
        { return lex_number(lx); }

        if (isalpha(c) || c == '_')
        { return lex_indent_or_keyword(lx); }

        if (strchr("+-*/%<>=!", c))
        {
            int line = lx->line, col = lx->col;
            size_t start = lx->pos;

            lex_nextc(lx);
            if (strchr("=<>", lex_peek(lx)))
            { lex_nextc(lx); }

            size_t len = lx->pos - start;
            char *lex = dynstr_substr(lx->src, start, len);
            if (!lex)
            { TRACE_ERROR("FAILED TO GET SUBSTR"); }

            return make_tok(TOK_OPERATOR, lex, line, col, -1);
        }

        TRACE_FATAL("UNKNOWN CHARACTER ENCOUNTER!!! %d:%d:`%c`", lx->line, lx->col, c);
    }
}

