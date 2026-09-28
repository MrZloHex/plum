; string.pl -- String, a growable, NUL-terminated byte string
;
; A CLASS in the way of Vector: one buffer, the operations its methods.
;
;   String s
;   (s.init)[ 64 ]
;   (s.append)[ "hello" ]
;   (s.push)[ '!' ]
;   (puts)[ s.data ]
;   (s.deinit)[]
;
; data is always terminated, so s.data passes straight to C. Reading
; s.data and s.size directly is fine; change them through the methods.
;
; Note on syntax: prefix binds tighter than `.`, so dereferencing a field
; is written ?(me.data), never ?me.data.

!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>
!USES <../extern/stdio.pl>
!USES <../extern/unistd.pl>

TYPE StringStruct: STRUCT
 | @C1   data
 | USIZE size
 | USIZE cap
 \_

IFACE StringOps: [ @StringStruct me ]
 + PUBLIC:
 | ; empty, with room for `cap` bytes; 0, or -1 when out of memory
 | I32 init: [ USIZE cap ]
 |  | me.data = NULL
 |  | me.size = 0
 |  | me.cap = 0
 |  | IF [ cap == 0 ]
 |  |  | cap = 16
 |  |  \_
 |  | IF [ (me.reserve)[ cap ] != 0 ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | ?(me.data) = '\0'
 |  | RET [ 0 ]
 |  \_
 |
 | I32 init_cstr: [ @C1 cstr ]
 |  | IF [ cstr == NULL ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | USIZE n = (strlen)[ cstr ]
 |  | IF [ (me.init)[ n + 1 ] != 0 ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | (memcpy)[ me.data AS @ABYSS | cstr AS @ABYSS | n ]
 |  | me.size = n
 |  | ?(me.data + n) = '\0'
 |  | RET [ 0 ]
 |  \_
 |
 | ; the whole of an open FILE*, the way the compiler reads a source file
 | I32 init_file: [ @ABYSS f ]
 |  | (fseek)[ f | 0 | 2 ]
 |  | I64 len = (ftell)[ f ]
 |  | (fseek)[ f | 0 | 0 ]
 |  | IF [ len < 0 ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | USIZE n = len AS USIZE
 |  | IF [ (me.init)[ n + 1 ] != 0 ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | USIZE got = (fread)[ me.data AS @ABYSS | 1 | n | f ]
 |  | me.size = got
 |  | ?(me.data + got) = '\0'
 |  | RET [ 0 ]
 |  \_
 |
 | ; everything a file descriptor gives up to end of file: a pipe, which
 | ; init_file cannot measure first
 | I32 init_fd: [ I32 fd ]
 |  | IF [ (me.init)[ 4096 ] != 0 ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | LOOP
 |  |  | IF [ (me.reserve)[ me.size + 4097 ] != 0 ]
 |  |  |  | RET [ -1 ]
 |  |  |  \_
 |  |  | I64 got = (read)[ fd | (me.data + me.size) AS @ABYSS | 4096 ]
 |  |  | IF [ got <= 0 ]
 |  |  |  | BREAK
 |  |  |  \_
 |  |  | me.size = me.size + (got AS USIZE)
 |  |  \_
 |  | ?(me.data + me.size) = '\0'
 |  | RET [ 0 ]
 |  \_
 |
 | ABYSS deinit: []
 |  | IF [ me.data != NULL ]
 |  |  | (free)[ me.data AS @ABYSS ]
 |  |  \_
 |  | me.data = NULL
 |  | me.size = 0
 |  | me.cap = 0
 |  \_
 |
 | ; room for `need` bytes, the terminator included; capacity doubles
 | I32 reserve: [ USIZE need ]
 |  | IF [ me.cap >= need ]
 |  |  | RET [ 0 ]
 |  |  \_
 |  | USIZE ncap = me.cap
 |  | IF [ ncap == 0 ]
 |  |  | ncap = 16
 |  |  \_
 |  | WHILE [ ncap < need ]
 |  |  | ncap = ncap * 2
 |  |  \_
 |  | @C1 nd = (realloc)[ me.data AS @ABYSS | ncap ] AS @C1
 |  | IF [ nd == NULL ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | me.data = nd
 |  | me.cap = ncap
 |  | RET [ 0 ]
 |  \_
 |
 | I32 append: [ @C1 t ]
 |  | IF [ t == NULL ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | USIZE n = (strlen)[ t ]
 |  | IF [ (me.reserve)[ me.size + n + 1 ] != 0 ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | (memcpy)[ (me.data + me.size) AS @ABYSS | t AS @ABYSS | n ]
 |  | me.size = me.size + n
 |  | ?(me.data + me.size) = '\0'
 |  | RET [ 0 ]
 |  \_
 |
 | ; one byte on the end
 | I32 push: [ C1 ch ]
 |  | IF [ (me.reserve)[ me.size + 2 ] != 0 ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | ?(me.data + me.size) = ch
 |  | me.size = me.size + 1
 |  | ?(me.data + me.size) = '\0'
 |  | RET [ 0 ]
 |  \_
 |
 | I32 insert: [ USIZE at | @C1 t ]
 |  | IF [ at > me.size ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | USIZE n = (strlen)[ t ]
 |  | IF [ (me.reserve)[ me.size + n + 1 ] != 0 ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | ; shift the tail right, carrying the terminator with it
 |  | (memmove)[ (me.data + at + n) AS @ABYSS | (me.data + at) AS @ABYSS | me.size - at + 1 ]
 |  | (memcpy)[ (me.data + at) AS @ABYSS | t AS @ABYSS | n ]
 |  | me.size = me.size + n
 |  | RET [ 0 ]
 |  \_
 |
 | ; `count` bytes from `at`, or as many as there are
 | I32 remove: [ USIZE at | USIZE count ]
 |  | IF [ at > me.size ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | IF [ at + count > me.size ]
 |  |  | count = me.size - at
 |  |  \_
 |  | (memmove)[ (me.data + at) AS @ABYSS | (me.data + at + count) AS @ABYSS | me.size - at - count + 1 ]
 |  | me.size = me.size - count
 |  | RET [ 0 ]
 |  \_
 |
 | ABYSS clear: []
 |  | me.size = 0
 |  | IF [ me.data != NULL ]
 |  |  | ?(me.data) = '\0'
 |  |  \_
 |  \_
 |
 | ; a malloc'd copy of `len` bytes from `at`; the caller frees it
 | @C1 substr: [ USIZE at | USIZE len ]
 |  | IF [ at > me.size ]
 |  |  | RET [ NULL ]
 |  |  \_
 |  | IF [ at + len > me.size ]
 |  |  | len = me.size - at
 |  |  \_
 |  | @C1 out = (malloc)[ len + 1 ] AS @C1
 |  | IF [ out == NULL ]
 |  |  | RET [ NULL ]
 |  |  \_
 |  | (memcpy)[ out AS @ABYSS | (me.data + at) AS @ABYSS | len ]
 |  | ?(out + len) = '\0'
 |  | RET [ out ]
 |  \_
 |
 | ; byte i, or '\0' past the end
 | C1 get: [ USIZE i ]
 |  | IF [ i >= me.size ]
 |  |  | RET [ '\0' ]
 |  |  \_
 |  | RET [ me.data{i} ]
 |  \_
 \_

CLASS String: StringStruct IMPL [ StringOps ]
