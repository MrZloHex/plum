; postlude.pl -- POSTLUDE: run on every way out of its block, last first, in its own scope
I32 printf: [ @C1 fmt | ... ]

I32 counter = 0

ABYSS say: [ @C1 what | I32 n ]
 | (printf)[ "%s%d " | what | n ]
 \_

I32 early: [ I32 k ]
 | I32 x = 10
 | POSTLUDE (say)[ "a" | x ]
 | POSTLUDE x = 99
 | IF [ k > 0 ]
 |  | I32 x = 5
 |  | POSTLUDE (say)[ "inner" | x ]
 |  | RET [ x + k ]
 |  \_
 | RET [ x ]
 \_

I32 main: []
 | (printf)[ "-> %d\n" | (early)[ 1 ] ]
 | (printf)[ "-> %d\n" | (early)[ 0 ] ]
 | FOR [ I32 i = 0 | i < 4 | i += 1 ]
 |  | POSTLUDE (say)[ "end" | i ]
 |  | IF [ i == 1 ]
 |  |  | CONTINUE
 |  |  \_
 |  | IF [ i == 2 ]
 |  |  | BREAK
 |  |  \_
 |  | (say)[ "body" | i ]
 |  \_
 | (printf)[ "\n" ]
 | POSTLUDE
 |  | IF [ counter == 0 ]
 |  |  | (printf)[ "main done\n" ]
 |  |  \_
 |  \_
 | RET [ 0 ]
 \_
