; Pointer arithmetic: p + n and n + p scale by the element, p - q counts
; elements, @ABYSS moves by bytes, and AS U64 gets at the address.

!USES <../../extern/stdio.pl>
!USES <../../extern/stdlib.pl>

TYPE P:
 | I32 a
 | I32 b
 | I32 c
 \_

I32 main: []
 | I32 a{8}
 | I32 i = 0
 | WHILE [ i < 8 ]
 |  | a{i} = i * 11
 |  | i += 1
 |  \_
 | @I32 p = a + 6
 | @I32 q = 2 + a
 | (printf)[ "%ld %ld %d %d\n" | p - a | p - q | ?(3 + a) | (p - 1){0} ]
 |
 | P ps{4}
 | @P e = ps + 3
 | @P f = e - 2
 | (printf)[ "%ld %ld %d\n" | e - ps | e - f | (f AS U64 - ps AS U64) AS I32 ]
 |
 | @ABYSS raw = (malloc)[ 16 ]
 | @ABYSS mid = raw + 5
 | (printf)[ "%d\n" | (mid AS U64 - raw AS U64) AS I32 ]
 | (free)[ raw ]
 |
 | @I32 back = p
 | back -= 4
 | back += 1
 | (printf)[ "%d %d\n" | ?back | back < p ]
 | RET [ 0 ]
 \_
