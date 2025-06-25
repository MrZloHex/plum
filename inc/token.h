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
    TOK_TYPE,
    TOK_INTEGER,
    TOK_CHARACTER,
    TOK_STRING,

    TOK_KW_TYPE,
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

#endif /* __TOKEN_H__ */
