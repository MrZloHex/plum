#ifndef __DYNMAP_H__
#define __DYNMAP_H__

/*
 * ----------------------------------------------------------------------------
 *  Dynamic HashMap Implementation (Macro-Based)
 *
 *  Author  : Zlobin Aleksey
 *  Created : 2025.07.06
 *
 * ----------------------------------------------------------------------------
 */

#include <stdlib.h>
#include <string.h>

#ifndef HASHMAP_DEFAULT_CAPACITY
#   define HASHMAP_DEFAULT_CAPACITY 16
#endif

/*
 * The DECLARE_DYNARRAY macro declares a type-safe dynamic array interface for
 * a specific element type T. It creates a struct (MT) representing the dynamic array
 * and a set of function prototypes to operate on it. PREFIX is used to build
 * function names uniquely for this element type, ensuring no naming conflicts.
 *
 * Parameters:
 *  - PREFIX: A prefix for the function names, e.g. 'intarray' for int arrays.
 *  - MT:     Master Type. The name of the struct type that will represent the dynamic array.
 *  - T:      The element type that this dynamic array will hold.
 *
 *
 * All functions with int return type
 *  On success,  0  is returned.
 *  On error,   -1  is returned.
 *
 * Functions with PTR return type
 *  On error,   NULL is returned,
 *    otherwise success.
 */
// Macro to define a typed hashmap:
// name        - prefix for types/functions
// KEY_TYPE    - type of the keys
// VALUE_TYPE  - type of the values
// HASH_FUNC   - function(KEY_TYPE) -> size_t hash
// EQUALS_FUNC - function(KEY_TYPE, KEY_TYPE) -> int (non-zero if equal)
#define DECLARE_DYNMAP(name, KEY_TYPE, VALUE_TYPE, HASH_FUNC, EQUALS_FUNC) \
                                                                        \
    typedef struct name##_entry                                         \
    {                                                                   \
        KEY_TYPE            key;                                        \
        VALUE_TYPE          value;                                      \
        struct name##_entry *next;                                      \
    } name##_entry;                                                     \
                                                                        \
    typedef struct                                                      \
    {                                                                   \
        name##_entry      **buckets;                                    \
        size_t              capacity;                                   \
    } name##_map;                                                       \
                                                                        \
    int                                                                 \
    name##_init(                                                        \
        name##_map *map,                                                \
        size_t      capacity                                            \
    );                                                                  \
                                                                        \
    void                                                                \
    name##_deinit(                                                      \
        name##_map *map                                                 \
    );                                                                  \
                                                                        \
    int                                                                 \
    name##_put(                                                         \
        name##_map  *map,                                               \
        KEY_TYPE     key,                                               \
        VALUE_TYPE   value                                              \
    );                                                                  \
                                                                        \
    int                                                                 \
    name##_get(                                                         \
        name##_map   *map,                                              \
        KEY_TYPE      key,                                              \
        VALUE_TYPE   *out_value                                         \
    );                                                                  \
                                                                        \
    int                                                                 \
    name##_remove(                                                      \
        name##_map  *map,                                               \
        KEY_TYPE     key                                                \
    );                                                                  


/*
 * The DEFINE_DYNARRAY macro defines the functions declared by DECLARE_DYNARRAY.
 * It generates implementations for the init, deinit, append, get, get_last_ptr,
 * size, and capacity functions for a given T and associated PREFIX/MT.
 */
#define DEFINE_DYNMAP(name, KEY_TYPE, VALUE_TYPE, HASH_FUNC, EQUALS_FUNC) \
                                                                        \
    int                                                                 \
    name##_init(name##_map *map, size_t capacity)                       \
    {                                                                   \
        map->capacity = capacity;                                       \
        map->buckets  = calloc(capacity, sizeof(name##_entry *));       \
        if (!map->buckets)                                              \
        { return -1; }                                                  \
        return 0;                                                       \
    }                                                                   \
                                                                        \
    void                                                                \
    name##_deinit(                                                      \
        name##_map *map                                                 \
    )                                                                   \
    {                                                                   \
        for (size_t i = 0; i < map->capacity; ++i)                      \
        {                                                               \
            name##_entry *entry = map->buckets[i];                      \
            while (entry)                                               \
            {                                                           \
                name##_entry *next = entry->next;                       \
                free(entry);                                            \
                entry = next;                                           \
            }                                                           \
        }                                                               \
        free(map->buckets);                                             \
    }                                                                   \
                                                                        \
    int                                                          \
    name##_put(                                                         \
        name##_map  *map,                                               \
        KEY_TYPE     key,                                               \
        VALUE_TYPE   value                                              \
    )                                                                   \
    {                                                                   \
        size_t idx = HASH_FUNC(key) % map->capacity;                    \
        name##_entry *entry = map->buckets[idx];                        \
        while (entry)                                                   \
        {                                                               \
            if (EQUALS_FUNC(entry->key, key))                           \
            {                                                           \
                entry->value = value;                                   \
                return 0;                                               \
            }                                                           \
            entry = entry->next;                                        \
        }                                                               \
        name##_entry *new_entry = malloc(sizeof(name##_entry));         \
        if (!new_entry) return -1;                                      \
        new_entry->key   = key;                                         \
        new_entry->value = value;                                       \
        new_entry->next  = map->buckets[idx];                           \
        map->buckets[idx] = new_entry;                                  \
        return 0;                                                       \
    }                                                                   \
                                                                        \
    int                                                          \
    name##_get(                                                         \
        name##_map   *map,                                              \
        KEY_TYPE      key,                                              \
        VALUE_TYPE   *out_value                                         \
    )                                                                   \
    {                                                                   \
        size_t idx = HASH_FUNC(key) % map->capacity;                    \
        name##_entry *entry = map->buckets[idx];                        \
        while (entry)                                                   \
        {                                                               \
            if (EQUALS_FUNC(entry->key, key))                           \
            {                                                           \
                *out_value = entry->value;                              \
                return 1;                                               \
            }                                                           \
            entry = entry->next;                                        \
        }                                                               \
        return 0;                                                       \
    }                                                                   \
                                                                        \
    int                                                          \
    name##_remove(                                                      \
        name##_map  *map,                                               \
        KEY_TYPE     key                                                \
    )                                                                   \
    {                                                                   \
        size_t idx = HASH_FUNC(key) % map->capacity;                    \
        name##_entry *entry = map->buckets[idx];                        \
        name##_entry *prev  = NULL;                                     \
        while (entry)                                                   \
        {                                                               \
            if (EQUALS_FUNC(entry->key, key))                           \
            {                                                           \
                if (prev)                                               \
                    prev->next = entry->next;                           \
                else                                                    \
                    map->buckets[idx] = entry->next;                    \
                free(entry);                                            \
                return 1;                                               \
            }                                                           \
            prev  = entry;                                              \
            entry = entry->next;                                        \
        }                                                               \
        return 0;                                                       \
    }                                                                   \
                                                                        \

#endif /* __DYNMAP_H__ */

