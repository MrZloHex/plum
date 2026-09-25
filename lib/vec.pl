; vec.pl -- the PLUM counterpart of inc/dynarray.h
;
; dynarray.h is a macro that stamps out a type-safe array per element type.
; PLUM has neither macros nor generics, so there is one Vec that stores
; elements by byte size, the way C did it before templates.
;
; The buffer is @C1 so pointer arithmetic is already in bytes.

!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>

TYPE Vec: STRUCT
 | @C1 data
 | U64 len
 | U64 cap
 | U64 esz
 \_

I32 vec_init: [ @Vec v | U64 esz | U64 cap ]
 | v.data = 0
 | v.len  = 0
 | v.cap  = 0
 | v.esz  = esz
 |
 | IF [ cap == 0 ]
 |  | cap = 8
 |  \_
 |
 | @C1 d = (malloc)[ cap * esz ] AS @C1
 | IF [ d == 0 ]
 |  | RET [ -1 ]
 |  \_
 | v.data = d
 | v.cap  = cap
 | RET [ 0 ]
 \_

ABYSS vec_deinit: [ @Vec v ]
 | IF [ v.data != 0 ]
 |  | (free)[ v.data AS @ABYSS ]
 |  \_
 | v.data = 0
 | v.len  = 0
 | v.cap  = 0
 | RET
 \_

U64 vec_size: [ @Vec v ]
 | RET [ v.len ]
 \_

; Address of element i. No bounds check -- this is the `.data[i]` the C
; code reaches for directly.
@ABYSS vec_at: [ @Vec v | U64 i ]
 | RET [ (v.data + i * v.esz) AS @ABYSS ]
 \_

I32 vec_reserve: [ @Vec v | U64 need ]
 | IF [ v.cap >= need ]
 |  | RET [ 0 ]
 |  \_
 | U64 ncap = v.cap
 | IF [ ncap == 0 ]
 |  | ncap = 8
 |  \_
 | WHILE [ ncap < need ]
 |  | ncap = ncap * 2
 |  \_
 | @C1 nd = (realloc)[ v.data AS @ABYSS | ncap * v.esz ] AS @C1
 | IF [ nd == 0 ]
 |  | RET [ -1 ]
 |  \_
 | v.data = nd
 | v.cap  = ncap
 | RET [ 0 ]
 \_

I32 vec_append: [ @Vec v | @ABYSS elem ]
 | IF [ (vec_reserve)[ v | v.len + 1 ] != 0 ]
 |  | RET [ -1 ]
 |  \_
 | (memcpy)[ (vec_at)[ v | v.len ] | elem | v.esz ]
 | v.len = v.len + 1
 | RET [ 0 ]
 \_

; Copy element i out into `out`. 0 on success, -1 if out of range.
I32 vec_get: [ @Vec v | U64 i | @ABYSS out ]
 | IF [ i >= v.len ]
 |  | RET [ -1 ]
 |  \_
 | (memcpy)[ out | (vec_at)[ v | i ] | v.esz ]
 | RET [ 0 ]
 \_

I32 vec_set: [ @Vec v | U64 i | @ABYSS elem ]
 | IF [ i >= v.len ]
 |  | RET [ -1 ]
 |  \_
 | (memcpy)[ (vec_at)[ v | i ] | elem | v.esz ]
 | RET [ 0 ]
 \_

I32 vec_remove: [ @Vec v | U64 i ]
 | IF [ i >= v.len ]
 |  | RET [ -1 ]
 |  \_
 | U64 rest = v.len - i - 1
 | IF [ rest > 0 ]
 |  | (memmove)[ (vec_at)[ v | i ] | (vec_at)[ v | i + 1 ] | rest * v.esz ]
 |  \_
 | v.len = v.len - 1
 | RET [ 0 ]
 \_
