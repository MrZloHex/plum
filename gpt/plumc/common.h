
#ifndef COMMON_H
#define COMMON_H

/* for strdup, getline, etc. */
#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <ctype.h>

#define die(msg)   do { fprintf(stderr, "Error: %s\n", msg); exit(EXIT_FAILURE); } while (0)
#define xmalloc(z) ({ void *p = malloc(z); if (!p) die("out of memory"); p; })

#endif /* COMMON_H */
