#include "preproc.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <errno.h>


#define MAX_INCLUDE_DEPTH 32

int
preproc_internal(DynString *str, int depth, const char *dir);

/* Directory part of a path, or "." -- returned in a caller-owned buffer. */
static char *
dir_of(const char *path)
{
    const char *slash = path ? strrchr(path, '/') : NULL;
    if (!slash)
    { return strdup("."); }

    size_t n = (size_t)(slash - path);
    char *d = malloc(n + 1);
    if (!d)
    { return NULL; }
    memcpy(d, path, n);
    d[n] = '\0';
    return d;
}

static int
insert_file(DynString *dst, size_t at, const char *path, int depth, const char *dir)
{
    if (depth > MAX_INCLUDE_DEPTH)
    {
        fprintf(stderr, "preproc: include depth exceeded (%s)\n", path);
        return -1;
    }

    /* Resolve against the including file's directory, the way C resolves
       #include "..." -- otherwise a library can only be used from the one
       directory the compiler happens to be run from. */
    char *full = NULL;
    if (path[0] == '/')
    { full = strdup(path); }
    else
    {
        size_t n = strlen(dir) + 1 + strlen(path) + 1;
        full = malloc(n);
        if (full)
        { snprintf(full, n, "%s/%s", dir, path); }
    }
    if (!full)
    { return -1; }

    FILE *f = fopen(full, "r");
    if (!f)
    {
        fprintf(stderr, "preproc: cannot open \"%s\": %s\n", full, strerror(errno));
        free(full);
        return -1;
    }

    DynString buf;
    dynstr_init(&buf, f);
    fclose(f);

    char *sub_dir = dir_of(full);
    free(full);
    if (!sub_dir)
    { dynstr_deinit(&buf); return -1; }

    int rc = preproc_internal(&buf, depth + 1, sub_dir);
    free(sub_dir);

    if (rc != 0)
    {
        dynstr_deinit(&buf);
        return -1;
    }

    dynstr_insert_str(dst, at, buf.data);
    dynstr_deinit(&buf);
    return 0;
}

static int
preproc_uses(DynString *s, size_t pos, int depth, const char *dir)
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

    if (insert_file(s, pos, fname, depth, dir) != 0)
    {
        free(fname);
        return -1;
    }

    free(fname);
    return 0;
}


int
preproc_internal(DynString *src, int depth, const char *dir)
{
    for (size_t i = 0; i < src->size; ++i)
    {
        char c = src->data[i];

        /* Skip comments and literals: a directive only counts as one when
           it is actually code. Without this, `;!USES <x>` in a comment
           expands, and a source file cannot even mention the directive in
           a string -- which the PLUM port of this file needs to do. */
        if (c == ';')
        {
            while (i < src->size && src->data[i] != '\n')
            { ++i; }
            continue;
        }
        if (c == '"' || c == '\'')
        {
            char quote = c;
            ++i;
            while (i < src->size && src->data[i] != quote)
            {
                if (src->data[i] == '\\')
                { ++i; }
                ++i;
            }
            continue;
        }

        if (c == '!' && i + 5 < src->size &&
            strncmp(&src->data[i], "!USES", 5) == 0)
        {
            if (preproc_uses(src, i, depth, dir) != 0)
            { return -1; }
            i = (size_t)-1;
        }
    }
    return 0;
}

int
preprocess(DynString *src, const char *path)
{
    if (!src)
    { return -1; }

    char *dir = dir_of(path);
    if (!dir)
    { return -1; }

    int rc = preproc_internal(src, 0, dir);
    free(dir);
    return rc;
}

