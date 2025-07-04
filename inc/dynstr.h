#ifndef __DYNSTRING_H__
#define __DYNSTRING_H__

/*
 * ----------------------------------------------------------------------------
 *  Dynamic String Implementation
 *
 *  Author  : Zlobin Aleksey
 *  Created : 2025.02.26
 *
 *  Description:
 *    This header defines macros to declare and define a type-safe dynamic
 *    string in C. It is modeled after a vector implementation: each string
 *    is implemented as a dynamic array of char that always maintains a null
 *    terminator.
 *
 * ----------------------------------------------------------------------------
 */


#include <stdlib.h>
#include <stdio.h>

typedef struct
{
    char   *data;
    size_t  size;
    size_t  capacity;
} DynString;

#define dynstr_init(str, src) _Generic((src),               \
    size_t:         dynstr_init_with_cap,                   \
    int:            dynstr_init_with_cap,                   \
    char *:         dynstr_init_with_cstr,                  \
    const char *:   dynstr_init_with_cstr,                  \
    FILE *:         dynstr_init_with_file                   \
)(str, src)

int
dynstr_init_with_cap(DynString *str, size_t initial_capacity);

int
dynstr_init_with_cstr(DynString *str, const char *cstr);

int
dynstr_init_with_file(DynString *str, FILE *f);

void
dynstr_deinit(DynString *str);

int
dynstr_append(DynString *str, char c);

int
dynstr_append_str(DynString *str, const char *s);

int
dynstr_append_fstr(DynString *str, const char *f, ...);

int
dynstr_insert(DynString *str, size_t index, char c);

int
dynstr_insert_str(DynString *str, size_t index, const char *s);

int
dynstr_get(const DynString *str, size_t index, char *out);

char *
dynstr_substr(const DynString *str, size_t start, size_t len);

int
dynstr_set(DynString *str, size_t index, char c);

char *
dynstr_get_last_ptr(const DynString *str);

size_t
dynstr_size(const DynString *str);

size_t
dynstr_capacity(const DynString *str);

int
dynstr_remove(DynString *str, size_t index);

int
dynstr_remove_range(DynString *str, size_t start, size_t count);

#endif /* __DYNSTRING_H__ */

#ifdef DYNSTR_IMPL

#include <stdarg.h>


int
dynstr_init_with_cstr(DynString *str, const char *cstr)
{
    if (!cstr)
    { return -1; }
    size_t len = strlen(cstr);
    if (dynstr_init_with_cap(str, len+10) < 0)
    { return -1; }
    return dynstr_append_str(str, cstr);
}

int
dynstr_init_with_file(DynString *str, FILE *f)
{
    if (!str || !f)
    { return -1; }

    if (fseek(f, 0, SEEK_END) != 0)
    { return -1; }
    long filesize = ftell(f);
    if (filesize < 0)
    { return -1; }
    rewind(f);
    
    /* Allocate memory to hold the file content */
    str->data = (char *)malloc(sizeof(char) * (filesize + 1));
    if (!str->data)
    { return -1; }
    
    size_t read_bytes = fread(str->data, 1, filesize, f);
    if (read_bytes != (size_t)filesize)
    {
        free(str->data);
        return -1;
    }
    
    str->data[filesize] = '\0';
    str->size = filesize;
    str->capacity = filesize;
    return 0;
}

int
dynstr_init_with_cap(DynString *str, size_t initial_capacity)
{
    if (!str || initial_capacity == 0)
    { return -1; }
    /* Allocate space for initial_capacity characters plus one for '\0' */
    str->data = (char *)malloc(sizeof(char) * (initial_capacity + 1));
    if (!str->data)
    { return -1; }
    memset(str->data, 0, initial_capacity);
    str->size = 0;
    str->capacity = initial_capacity;
    return 0;
}

void
dynstr_deinit(DynString *str)
{
    if (!str)
    { return; }
    free(str->data);
    str->data = NULL;
    str->size = 0;
    str->capacity = 0;
}

/* Helper function: resize the internal buffer */
static int
dynstr_resize(DynString *str, size_t new_capacity)
{
    if (!str)
    { return -1; }
    char *temp = (char *)realloc(str->data, sizeof(char) * (new_capacity + 1));
    if (!temp)
    { return -1; }
    str->data = temp;
    str->capacity = new_capacity;
    return 0;
}

int
dynstr_append(DynString *str, char c)
{
    if (!str)
    { return -1; }
    if (str->size == str->capacity)
    {
        size_t new_capacity = str->capacity * 2;
        if (dynstr_resize(str, new_capacity) != 0)
        { return -1; }
    }
    str->data[str->size] = c;
    str->size++;
    str->data[str->size] = '\0';  /* maintain null terminator */
    return 0;
}

int
dynstr_append_str(DynString *str, const char *s)
{
    if (!str || !s)
    { return -1; }
    size_t len = strlen(s);
    while (str->size + len > str->capacity)
    {
        size_t new_capacity = str->capacity * 2;
        if (dynstr_resize(str, new_capacity) != 0)
        { return -1; }
    }
    memcpy(str->data + str->size, s, len);
    str->size += len;
    str->data[str->size] = '\0';
    return 0;
}

int
dynstr_append_fstr(DynString *str, const char *f, ...)
{
    char buf[512];
    va_list args;
    va_start(args, f);
    vsnprintf(buf, sizeof(buf), f, args);
    va_end(args);

    return dynstr_append_str(str, buf);
}

int
dynstr_insert(DynString *str, size_t index, char c)
{
    if (!str || index > str->size)
    { return -1; }
    if (str->size == str->capacity)
    {
        size_t new_capacity = str->capacity * 2;
        if (dynstr_resize(str, new_capacity) != 0)
        { return -1; }
    }
    /* Shift right including the null terminator */
    for (size_t i = str->size + 1; i > index; --i)
    {
        str->data[i] = str->data[i - 1];
    }
    str->data[index] = c;
    str->size++;
    return 0;
}

int
dynstr_insert_str(DynString *str, size_t index, const char *s)
{
    if (!str || !s || index > str->size)
    { return -1; }
    size_t len = strlen(s);
    while (str->size + len > str->capacity)
    {
        size_t new_capacity = str->capacity * 2;
        if (dynstr_resize(str, new_capacity) != 0)
        { return -1; }
    }
    /* Shift existing characters (including '\0') to make space */
    memmove(str->data + index + len,
            str->data + index,
            str->size - index + 1);  /* +1 to include '\0' */
    memcpy(str->data + index, s, len);
    str->size += len;
    return 0;
}

int
dynstr_get(const DynString *str, size_t index, char *out)
{
    if (!str || !out || index >= str->size)
    { return -1; }
    *out = str->data[index];
    return 0;
}

char *
dynstr_substr(const DynString *str, size_t start, size_t len)
{
    if (!str || !str->data || start >= str->size)
    { return NULL; }

    /* clamp len if it runs past the end */
    if (start + len > str->size)
    { len = str->size - start; }

    char *out = (char *)malloc(len + 1);
    if (!out)
    { return NULL; }

    memcpy(out, str->data + start, len);
    out[len] = '\0';
    return out;
}

int
dynstr_set(DynString *str, size_t index, char c)
{
    if (!str || index >= str->size)
    { return -1; }
    str->data[index] = c;
    return 0;
}

char *
dynstr_get_last_ptr(const DynString *str)
{
    if (!str || str->size == 0)
    { return NULL; }
    return &str->data[str->size - 1];
}

size_t
dynstr_size(const DynString *str)
{
    return str ? str->size : 0;
}

size_t
dynstr_capacity(const DynString *str)
{
    return str ? str->capacity : 0;
}

int
dynstr_remove(DynString *str, size_t index)
{
    if (!str || index >= str->size)
    { return -1; }
    /* Shift left including the null terminator */
    for (size_t i = index; i <= str->size; ++i)
    {
        str->data[i] = str->data[i + 1];
    }
    str->size--;
    return 0;
}

int
dynstr_remove_range(DynString *str, size_t start, size_t count)
{
    if (!str || start >= str->size)
    { return -1; }

    if (start + count > str->size)
    { count = str->size - start; }

    /* Shift left the characters after the removed range */
    for (size_t i = start; i <= str->size - count; ++i)
    {
        str->data[i] = str->data[i + count];
    }
    str->size -= count;
    return 0;
}

#endif /* DYNSTR_IMPL */
