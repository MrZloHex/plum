#ifndef __PREPROC_H__
#define __PREPROC_H__

#include "dynstr.h"

typedef struct Macro
{
    char *name;
    char *replacement;
    struct Macro *next;
} Macro;

int
preprocess(DynString *src, const char *path);

#endif /* __PREPROC_H__ */
