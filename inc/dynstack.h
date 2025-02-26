#ifndef __DYNSTACK_H__
#define __DYNSTACK_H__

/*
 * ----------------------------------------------------------------------------
 *  Dynamic Stack Implementation (Macro-Based)
 *
 *  Author  : Zlobin Aleksey
 *  Created : 2025.02.09
 *
 *  Description:
 *    This header defines macros to declare and define a type-safe dynamic
 *    stack in C. The stack is built on a dynamic array that resizes as needed.
 *    It supports typical stack operations: initialization, push, pop, and top.
 *
 *  Usage:
 *    1) In your header or C file, use DECLARE_STACK(PREFIX, ST, T) to declare
 *       a stack structure (ST) and function prototypes for type T.
 *    2) In exactly one C file, include this header and call
 *       DEFINE_STACK(PREFIX, ST, T) to implement the functions.
 *    3) Use PREFIX##_init, PREFIX##_push, PREFIX##_pop, PREFIX##_top, etc.
 *
 * ----------------------------------------------------------------------------
 */

#include <stdlib.h>

/* Declaration of the dynamic stack interface.
 *
 * Parameters:
 *  - PREFIX: A prefix for the function names, e.g. 'intstack'
 *  - ST:     The struct type name, e.g. IntStack
 *  - T:      The element type that the stack will hold, e.g. int
 */
#define DECLARE_DYNSTACK(PREFIX, ST, T)                                     \
    typedef struct                                                          \
    {                                                                       \
        T    *data;                                                         \
        size_t size;                                                        \
        size_t capacity;                                                    \
    } ST;                                                                   \
                                                                            \
    int                                                                     \
    PREFIX##_init(ST *stack, size_t initial_capacity);                      \
                                                                            \
    void                                                                    \
    PREFIX##_deinit(ST *stack);                                             \
                                                                            \
    int                                                                     \
    PREFIX##_push(ST *stack, T element);                                    \
                                                                            \
    int                                                                     \
    PREFIX##_pop(ST *stack, T *out);                                        \
                                                                            \
    T *                                                                     \
    PREFIX##_top(const ST *stack);                                          \
                                                                            \
    size_t                                                                  \
    PREFIX##_size(const ST *stack);                                         \
                                                                            \
    size_t                                                                  \
    PREFIX##_capacity(const ST *stack);

/*
 * Definition of the dynamic stack functions.
 *
 * Parameters:
 *  - PREFIX: A prefix for the function names, e.g. 'intstack'
 *  - ST:     The struct type name, e.g. IntStack
 *  - T:      The element type that the stack will hold, e.g. int
 */
#define DEFINE_DYNSTACK(PREFIX, ST, T)                                      \
    int                                                                     \
    PREFIX##_init(ST *stack, size_t initial_capacity)                       \
    {                                                                       \
        if (!stack || initial_capacity == 0)                                \
        { return -1; }                                                      \
        stack->data = (T *)malloc(sizeof(T) * initial_capacity);            \
        if (!stack->data)                                                   \
        { return -1; }                                                      \
        stack->size = 0;                                                    \
        stack->capacity = initial_capacity;                                 \
        return 0;                                                           \
    }                                                                       \
                                                                            \
    void                                                                    \
    PREFIX##_deinit(ST *stack)                                              \
    {                                                                       \
        if (!stack)                                                         \
        { return; }                                                         \
        free(stack->data);                                                  \
        stack->data = NULL;                                                 \
        stack->size = 0;                                                    \
        stack->capacity = 0;                                                \
    }                                                                       \
                                                                            \
    int                                                                     \
    PREFIX##_push(ST *stack, T element)                                     \
    {                                                                       \
        if (!stack)                                                         \
        { return -1; }                                                      \
        if (stack->size == stack->capacity)                                 \
        {                                                                   \
            size_t new_capacity = stack->capacity * 2;                      \
            T *temp = (T *)realloc(stack->data, sizeof(T) * new_capacity);  \
            if (!temp)                                                      \
            { return -1; }                                                  \
            stack->data = temp;                                             \
            stack->capacity = new_capacity;                                 \
        }                                                                   \
        stack->data[stack->size++] = element;                               \
        return 0;                                                           \
    }                                                                       \
                                                                            \
    int                                                                     \
    PREFIX##_pop(ST *stack, T *out)                                         \
    {                                                                       \
        if (!stack || stack->size == 0)                                     \
        { return -1; }                                                      \
        if (out)                                                            \
        { *out = stack->data[stack->size - 1]; }                            \
        stack->size--;                                                      \
        return 0;                                                           \
    }                                                                       \
                                                                            \
    T *                                                                     \
    PREFIX##_top(const ST *stack)                                           \
    {                                                                       \
        if (!stack || stack->size == 0)                                     \
        { return NULL; }                                                    \
        return &stack->data[stack->size - 1];                               \
    }                                                                       \
                                                                            \
    size_t                                                                  \
    PREFIX##_size(const ST *stack)                                          \
    {                                                                       \
        return stack ? stack->size : 0;                                     \
    }                                                                       \
                                                                            \
    size_t                                                                  \
    PREFIX##_capacity(const ST *stack)                                      \
    {                                                                       \
        return stack ? stack->capacity : 0;                                 \
    }

#endif /* __STACK_H__ */

