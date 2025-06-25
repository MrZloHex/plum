#ifndef __LEXER_H__
#define __LEXER_H__

#include <stdlib.h>

typedef struct
{
    const char *src;
    size_t      pos;
    int         line;
    int         col;
} Lexer;

void
lexer_init(Lexer *, const char *);

#endif /* __LEXER_H__ */
