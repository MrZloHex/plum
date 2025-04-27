#include "preproc.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

void
preproc_uses(DynString *str, size_t start)
{
    DynString file; 
    dynstr_init(&file, 16);

    bool parse_file = false;
    size_t end = start;

    for (size_t i = start + 5; ; ++i)
    {
        if (i > start+100)
        { assert(!"SMTH WENT WRONG WITH USES EXPANSION");}

        if (str->data[i] == '>')
        { end = i+1; break; }

        if (parse_file)
        { dynstr_append(&file, str->data[i]); }

        if (str->data[i] == '<')
        { parse_file = true; }
    }

    FILE *f = fopen(file.data, "r");
    assert(f && "FAILED TO OPEN USES FILE");

    DynString uses;
    dynstr_init(&uses, f);

    dynstr_remove_range(str, start, end-start);
    dynstr_insert_str(str, start, uses.data);

    dynstr_deinit(&uses);
    dynstr_deinit(&file);

    fclose(f);
}

int
preprocess(DynString *src)
{
    if (!src)
    { return -1; }

    for (size_t i = 0; i < src->size; ++i)
    {
        if (src->data[i] == '!' && strncmp(&src->data[i], "!USES", 5) == 0)
        {
            size_t start = i;
            preproc_uses(src, start);
        }
    }

    return 0;
}

