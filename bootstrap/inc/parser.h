#ifndef __PARSER_H__
#define __PARSER_H__

#include "ast.h"
#include "dynstr.h"

#include "lexer.h"

typedef struct
{
    Lexer lexer;
    Token curr;
    AST  *ast;
    int indent;
} Parser;

void
parse_unit(AST *, DynString *source);

#endif /* __PARSER_H__ */

