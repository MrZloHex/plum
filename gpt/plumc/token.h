
#ifndef TOKEN_H
#define TOKEN_H

#include "common.h"

typedef enum TokenType
{
    TOK_EOF,
    TOK_NEWLINE,     /* carries indent */
    TOK_END_BLOCK,   /* '\_' line carries indent */

    /* punctuation / operators */
    TOK_COLON,       /* ':' */
    TOK_LBRACKET,    /* '[' */
    TOK_RBRACKET,    /* ']' */
    TOK_PIPE,        /* '|' (separator, not indent) */
    TOK_DOT,         /* '.' */
    TOK_AT,          /* '@' */
    TOK_QMARK,       /* '?' */
    TOK_ELLIPSIS,    /* '...' */
    TOK_OPERATOR,    /* generic binary/unary op (= + - * / % >> << < > <= >= == !=) */

    /* literals & identifiers */
    TOK_IDENTIFIER,
    TOK_INTEGER,
    TOK_FLOAT,
    TOK_STRING,
    TOK_CHAR,

    /* keywords */
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

typedef struct Token
{
    TokenType kind;
    char     *lexeme;    /* string content for identifiers, numbers, strings, ops */
    int       line;
    int       col;
    int       indent;    /* only for NEWLINE / END_BLOCK */
} Token;

typedef struct Lexer
{
    const char *src;
    size_t      pos;
    int         line;
    int         col;
} Lexer;

void  lexer_init(Lexer *lx, const char *src);
Token lexer_next(Lexer *lx);
const char *token_name(TokenType t);

#endif /* TOKEN_H */
