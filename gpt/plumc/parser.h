
#ifndef PARSER_H
#define PARSER_H

#include "ast.h"

typedef struct Parser
{
    Lexer lx;
    Token current;
} Parser;

AST *parse_program(const char *src);

#endif /* PARSER_H */
