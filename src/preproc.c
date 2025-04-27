#include "preproc.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <errno.h>


#define MAX_INCLUDE_DEPTH 32

int
preproc_internal(DynString *str, int depth);

static int
insert_file(DynString *dst, size_t at, const char *path, int depth)
{
    if (depth > MAX_INCLUDE_DEPTH)
    {
        fprintf(stderr, "preproc: include depth exceeded (%s)\n", path);
        return -1;
    }

    FILE *f = fopen(path, "r");
    if (!f)
    {
        fprintf(stderr, "preproc: cannot open \"%s\": %s\n", path, strerror(errno));
        return -1;
    }

    DynString buf;
    dynstr_init(&buf, f);
    fclose(f);

    if (preproc_internal(&buf, depth + 1) != 0)
    {
        dynstr_deinit(&buf);
        return -1;
    }

    dynstr_insert_str(dst, at, buf.data);
    dynstr_deinit(&buf);
    return 0;
}

static int
preproc_uses(DynString *s, size_t pos, int depth)
{
    size_t i = pos + 5;

    while (i < s->size && (s->data[i] == ' ' || s->data[i] == '\t'))
    { ++i; }

    if (i >= s->size || s->data[i] != '<')
    {
        fprintf(stderr, "preproc: expected '<' after !USES\n");
        return -1;
    }
    ++i;

    size_t name_begin = i;
    while (i < s->size && s->data[i] != '>') { ++i; }

    if (i >= s->size)
    {
        fprintf(stderr, "preproc: missing '>' for !USES\n");
        return -1;
    }

    size_t name_len = i - name_begin;
    char *fname = strndup(&s->data[name_begin], name_len);
    if (!fname) { perror("strdup"); return -1; }

    size_t directive_len = (i + 1) - pos;

    dynstr_remove_range(s, pos, directive_len);

    if (insert_file(s, pos, fname, depth) != 0)
    {
        free(fname);
        return -1;
    }

    free(fname);
    return 0;
}


int
preproc_internal(DynString *src, int depth)
{
   for (size_t i = 0; i < src->size; ++i)
   {
        if (src->data[i] == '!' && i + 5 < src->size &&
            strncmp(&src->data[i], "!USES", 5) == 0)
        {
            if (preproc_uses(src, i, depth) != 0)
            { return -1; }
            i = (size_t)-1;
        }
    }
    return 0;
}

int
preprocess(DynString *src)
{
    if (!src)
    { return -1; }

    return preproc_internal(src, 0);
}

