; Functions that do end in RET, in every shape the checker must accept:
; ELSE chains, a LOOP only RET leaves, a nested BREAK that leaves an inner
; loop only, and exit().

!USES <../../extern/stdio.pl>
!USES <../../extern/stdlib.pl>

I32 sign: [ I32 x ]
 | IF [ x > 0 ]
 |  | RET [ 1 ]
 | ELIF [ x < 0 ]
 |  | RET [ -1 ]
 | ELSE
 |  | RET [ 0 ]
 |  \_
 \_

I32 first_square_over: [ I32 n ]
 | I32 i = 0
 | LOOP
 |  | I32 j = 0
 |  | LOOP
 |  |  | IF [ j == 3 ]
 |  |  |  | BREAK
 |  |  |  \_
 |  |  | j += 1
 |  |  \_
 |  | IF [ i * i > n ]
 |  |  | RET [ i ]
 |  |  \_
 |  | i += 1
 |  \_
 \_

I32 must_be_small: [ I32 x ]
 | IF [ x < 10 ]
 |  | RET [ x ]
 | ELSE
 |  | (printf)[ "too big\n" ]
 |  | (exit)[ 3 ]
 |  \_
 \_

ABYSS nothing: [ I32 x ]
 | IF [ x ]
 |  | RET
 |  \_
 \_

I32 main: []
 | (printf)[ "%d %d %d\n" | (sign)[ 5 ] | (sign)[ -2 ] | (sign)[ 0 ] ]
 | (printf)[ "%d\n" | (first_square_over)[ 50 ] ]
 | (nothing)[ 1 ]
 | (printf)[ "%d\n" | (must_be_small)[ 4 ] ]
 | (must_be_small)[ 40 ]
 | (printf)[ "not reached\n" ]
 | ; main alone may end without RET
 \_
