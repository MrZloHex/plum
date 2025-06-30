#ifndef __TOKEN_H__
#define __TOKEN_H__ 

#include "location.h"

typedef enum
{
    TOK_EOF,
    TOK_NEWLINE,
    
    TOK_COLON,
    TOK_LBRACKET,
    TOK_RBRACKET,
    TOK_LPAREN,
    TOK_RPAREN,
    TOK_VBAR,
    TOK_DOT,
    TOK_AT,
    TOK_QMARK,
    TOK_ELLIPSIS,
    TOK_OPERATOR,
    TOK_END_BLOCK,

    TOK_IDENTIFIER,
    TOK_FLOAT,
    TOK_INTEGER,
    TOK_CHARACTER,
    TOK_STRING,
    TOK_TRUE,
    TOK_FALSE,

    TOK_TYPE,
    TOK_STRUCTURE,
    TOK_UNION,
    TOK_ENUMERATION,

    TOK_IF,
    TOK_ELIF,
    TOK_ELSE,
    TOK_LOOP,
    TOK_BREAK,
    TOK_RET,
    TOK_SIZE
} TokenType;


typedef struct
{
    TokenType kind;
    char     *lexeme;
    int       indent;
    Location  loc;
} Token;

void
token_dump(Token);

#endif /* __TOKEN_H__ */
#ifdef TOKEN_DUMP

#include "trace.h"
#define _POSIX_C_SOURCE  200809L
#include <string.h>

const static char *type_str[TOK_SIZE+1] =
{
    "EOF", "NEWLINE", "COLON", "LBRACKET", "RBRACKET",
    "LPAREN", "RPAREN", "VBAR", "DOT", "AT", "QMARK",
    "ELLIPSIS", "OPERATOR", "END BLOCK", "IDENTIFIER",
    "FLOAT", "INTEGER", "CHARACTER", "STRING", "TYPE",
    "STRUCTURE", "UNION", "ENUMERATION", "IF", "ELIF",
    "ELSE", "LOOP", "BREAK", "RET", "SIZE"
};

const char *
token_str(TokenType t)
{ return type_str[t]; }

char *
token_dup_lex(Token *t)
{ return (t && t->lexeme) ? strdup(t->lexeme) : NULL; }

void
token_dump(Token tok)
{
    if (tok.lexeme)
    {
        TRACE_DEBUG("TOKEN: %s on %d:%d with `%s`", type_str[tok.kind], tok.loc.line, tok.loc.col, tok.lexeme);
    }
    else
    {
        TRACE_DEBUG("TOKEN: %s on %d:%d at %d", type_str[tok.kind], tok.loc.line, tok.loc.col, tok.indent);
    }
}

#endif /* TOKEN_DUMP */
