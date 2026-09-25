#ifndef __ARENA_H__
#define __ARENA_H__ 

#include <stddef.h>

typedef struct ArenaBlock ArenaBlock;

typedef struct Arena
{
    ArenaBlock *first;
    ArenaBlock *current;
    size_t      block_size;
} Arena;

void
arena_init
(
    Arena  *arena,
    size_t  block_size
);

void *
arena_alloc
(
    Arena  *arena,
    size_t  size
);

void
arena_reset(Arena *arena);

void
arena_destroy(Arena *arena);

#endif /* __ARENA_H__ */

#ifdef ARENA_IMPL

#include <stdlib.h>
#include <stdalign.h>

struct ArenaBlock
{
    size_t        used;
    size_t        size;
    ArenaBlock   *next;
    alignas(max_align_t) char data[];
};

static ArenaBlock *
arena_new_block
(
    size_t block_size
)
{
    size_t total = sizeof(ArenaBlock) + block_size;
    ArenaBlock *block = malloc(total);
    if (!block) { return NULL; }

    block->used = 0;
    block->size = block_size;
    block->next = NULL;
    return block;
}

void
arena_init
(
    Arena  *arena,
    size_t  block_size
)
{
    arena->first      = NULL;
    arena->current    = NULL;
    arena->block_size = block_size;
}

void *
arena_alloc
(
    Arena  *arena,
    size_t  size
)
{
    size_t align  = _Alignof(max_align_t);
    size_t used   = arena->current ? arena->current->used : 0;
    size_t offset = (align - (used % align)) % align;

    if
    (
        !arena->current ||
        used + offset + size > arena->current->size
    )
    {
        size_t bs       = arena->block_size;
        size_t new_size = size > bs ? size : bs;
        ArenaBlock *new_block = arena_new_block(new_size);
        if (!new_block)
        { return NULL; }

        if (!arena->first)
        { arena->first = new_block; }
        else
        { arena->current->next = new_block; }

        arena->current = new_block;
        used           = 0;
        offset         = 0;
    }

    void *ptr = arena->current->data + arena->current->used + offset;
    arena->current->used += offset + size;
    return ptr;
}

void
arena_reset
(
    Arena *arena
)
{
    for
    (
        ArenaBlock *block = arena->first;
        block;
        block = block->next
    )
    { block->used = 0; }

    arena->current = arena->first;
}

void
arena_destroy
(
    Arena *arena
)
{
    ArenaBlock *block = arena->first;
    while (block)
    {
        ArenaBlock *next = block->next;
        free(block);
        block = next;
    }
    arena->first   = NULL;
    arena->current = NULL;
}

#endif /* ARENA_IMPL */
