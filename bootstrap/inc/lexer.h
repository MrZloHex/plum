#ifndef __LEXER_H__
#define __LEXER_H__

#include <stdlib.h>
#include "dynstr.h"
#include "token.h"

typedef struct
{
    DynString *src;
    size_t     pos;
    int        line;
    int        col;
} Lexer;

void
lexer_init(Lexer *, DynString *source);

Token
lexer_next(Lexer *);

#endif /* __LEXER_H__ */
