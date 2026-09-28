; for_loop.pl -- FOR: the step runs after CONTINUE too, and its variable is the loop's
I32 printf: [ @C1 fmt | ... ]
I32 main: []
 | I32 sum = 0
 | FOR [ I32 i = 0 | i < 10 | i += 1 ]
 |  | IF [ i % 2 == 0 ]
 |  |  | CONTINUE
 |  |  \_
 |  | IF [ i > 7 ]
 |  |  | BREAK
 |  |  \_
 |  | sum += i
 |  \_
 | (printf)[ "sum %d\n" | sum ]
 | I32 j
 | FOR [ j = 3 | j > 0 | j -= 1 ]
 |  | FOR [ I32 i = 0 | i < j | i += 1 ]
 |  |  | (printf)[ "%d" | i ]
 |  |  \_
 |  | (printf)[ "|" ]
 |  \_
 | (printf)[ " j=%d\n" | j ]
 | FOR [ I32 i = 5 | i < 3 | i += 1 ]
 |  | (printf)[ "never\n" ]
 |  \_
 | RET [ 0 ]
 \_
