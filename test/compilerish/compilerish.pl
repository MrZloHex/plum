; The remaining unknowns: union member access, file I/O, string work.

I32    printf: [ @C1 fmt | ... ]
@ABYSS malloc: [ U64 size ]
ABYSS  free:   [ @ABYSS ptr ]
@ABYSS fopen:  [ @C1 path | @C1 mode ]
U64    fread:  [ @ABYSS buf | U64 sz | U64 n | @ABYSS f ]
I32    fclose: [ @ABYSS f ]
U64    strlen: [ @C1 s ]
I32    strcmp: [ @C1 a | @C1 b ]

TYPE Payload: UNION
 | I32  num
 | @C1  text
 \_

TYPE Tok: STRUCT
 | I32     kind
 | Payload as
 \_

I32 main: []
 | ; union members share one address
 | Tok t
 | t.kind   = 1
 | t.as.num = 77
 | (printf)[ "union num=%d\n" | t.as.num ]
 | t.as.text = "hello"
 | (printf)[ "union text=%s\n" | t.as.text ]
 |
 | ; strings through libc
 | @C1 s = "abcdef"
 | (printf)[ "strlen=%d cmp=%d\n" | (strlen)[ s ] | (strcmp)[ s | "abcdef" ] ]
 |
 | ; walking a string byte by byte
 | @C1 p = s
 | I32 n = 0
 | WHILE [ ?p != 0 ]
 |  | n += 1
 |  | p = p + 1
 |  \_
 | (printf)[ "walked=%d\n" | n ]
 |
 | ; reading a file, which is how the compiler gets its input
 | @ABYSS f = (fopen)[ "compilerish.pl" | "r" ]
 | IF [ f == 0 ]
 |  | (printf)[ "fopen failed\n" ]
 |  | RET [ 1 ]
 |  \_
 | @C1 buf = (malloc)[ 64 ]
 | U64 got = (fread)[ buf | 1 | 16 | f ]
 | ?(buf + got) = 0
 | (printf)[ "read %d bytes: %s\n" | got | buf ]
 | (fclose)[ f ]
 | (free)[ buf ]
 | RET [ 0 ]
 \_
