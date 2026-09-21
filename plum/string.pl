; string.pl -- the PLUM counterpart of inc/dynstr.h
;
; inc/dynstr.h dispatches dynstr_init through C11 _Generic; PLUM has no
; overloading, so the three initialisers are named separately here.
;
; Note on syntax: prefix binds tighter than `.`, so dereferencing a field
; is written ?(s.data), never ?s.data.

!USES <cstdlib.pl>
!USES <cstring.pl>
!USES <cstdio.pl>

TYPE String: STRUCT
 | @C1 data
 | U64 size
 | U64 cap
 \_

; Grow so that `need` bytes fit. Capacity doubles, as in dynstr_resize.
I32 str_reserve: [ @String s | U64 need ]
 | IF [ s.cap >= need ]
 |  | RET [ 0 ]
 |  \_
 |
 | U64 ncap = s.cap
 | IF [ ncap == 0 ]
 |  | ncap = 16
 |  \_
 | WHILE [ ncap < need ]
 |  | ncap = ncap * 2
 |  \_
 |
 | @C1 nd = (realloc)[ s.data AS @ABYSS | ncap ] AS @C1
 | IF [ nd == 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | s.data = nd
 | s.cap  = ncap
 | RET [ 0 ]
 \_

I32 str_init_cap: [ @String s | U64 cap ]
 | s.data = 0
 | s.size = 0
 | s.cap  = 0
 |
 | IF [ cap == 0 ]
 |  | cap = 16
 |  \_
 | IF [ (str_reserve)[ s | cap ] != 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | ?(s.data) = '\0'
 | RET [ 0 ]
 \_

I32 str_init_cstr: [ @String s | @C1 cstr ]
 | IF [ cstr == 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | U64 n = (strlen)[ cstr ]
 | IF [ (str_init_cap)[ s | n + 1 ] != 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | (memcpy)[ s.data AS @ABYSS | cstr AS @ABYSS | n ]
 | s.size = n
 | ?(s.data + n) = '\0'
 | RET [ 0 ]
 \_

; Slurp an entire open FILE*, the way the compiler reads a source file.
I32 str_init_file: [ @String s | @ABYSS f ]
 | (fseek)[ f | 0 | 2 ]
 | I64 len = (ftell)[ f ]
 | (fseek)[ f | 0 | 0 ]
 |
 | IF [ len < 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | U64 n = len AS U64
 | IF [ (str_init_cap)[ s | n + 1 ] != 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | U64 got = (fread)[ s.data AS @ABYSS | 1 | n | f ]
 | s.size = got
 | ?(s.data + got) = '\0'
 | RET [ 0 ]
 \_

ABYSS str_deinit: [ @String s ]
 | IF [ s.data != 0 ]
 |  | (free)[ s.data AS @ABYSS ]
 |  \_
 | s.data = 0
 | s.size = 0
 | s.cap  = 0
 | RET
 \_

I32 str_append_str: [ @String s | @C1 t ]
 | IF [ t == 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | U64 n = (strlen)[ t ]
 | IF [ (str_reserve)[ s | s.size + n + 1 ] != 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | (memcpy)[ (s.data + s.size) AS @ABYSS | t AS @ABYSS | n ]
 | s.size = s.size + n
 | ?(s.data + s.size) = '\0'
 | RET [ 0 ]
 \_

I32 str_append: [ @String s | C1 ch ]
 | IF [ (str_reserve)[ s | s.size + 2 ] != 0 ]
 |  | RET [ -1 ]
 |  \_
 | ?(s.data + s.size) = ch
 | s.size = s.size + 1
 | ?(s.data + s.size) = '\0'
 | RET [ 0 ]
 \_

I32 str_insert_str: [ @String s | U64 at | @C1 t ]
 | IF [ at > s.size ]
 |  | RET [ -1 ]
 |  \_
 |
 | U64 n = (strlen)[ t ]
 | IF [ (str_reserve)[ s | s.size + n + 1 ] != 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | ; shift the tail right, carrying the terminator with it
 | (memmove)[ (s.data + at + n) AS @ABYSS | (s.data + at) AS @ABYSS | s.size - at + 1 ]
 | (memcpy)[ (s.data + at) AS @ABYSS | t AS @ABYSS | n ]
 | s.size = s.size + n
 | RET [ 0 ]
 \_

I32 str_remove_range: [ @String s | U64 at | U64 count ]
 | IF [ at > s.size ]
 |  | RET [ -1 ]
 |  \_
 | IF [ at + count > s.size ]
 |  | count = s.size - at
 |  \_
 |
 | (memmove)[ (s.data + at) AS @ABYSS | (s.data + at + count) AS @ABYSS | s.size - at - count + 1 ]
 | s.size = s.size - count
 | RET [ 0 ]
 \_

; Caller owns the returned buffer, as dynstr_substr does.
@C1 str_substr: [ @String s | U64 at | U64 len ]
 | IF [ at > s.size ]
 |  | RET [ 0 ]
 |  \_
 | IF [ at + len > s.size ]
 |  | len = s.size - at
 |  \_
 |
 | @C1 out = (malloc)[ len + 1 ] AS @C1
 | IF [ out == 0 ]
 |  | RET [ 0 ]
 |  \_
 |
 | (memcpy)[ out AS @ABYSS | (s.data + at) AS @ABYSS | len ]
 | ?(out + len) = '\0'
 | RET [ out ]
 \_

C1 str_get: [ @String s | U64 i ]
 | IF [ i >= s.size ]
 |  | RET [ '\0' ]
 |  \_
 | RET [ ?(s.data + i) ]
 \_

U64 str_size: [ @String s ]
 | RET [ s.size ]
 \_
