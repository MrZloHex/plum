; WHILE, CONTINUE, and compound assignment

I32 printf: [ @C1 fmt | ... ]
I32 puts:   [ @C1 str ]

I32 main: []
 | (puts)[ "while 0..4:" ]
 | I32 i = 0
 | WHILE [ i < 5 ]
 |  | (printf)[ "  i=%d\n" | i ]
 |  | i += 1
 |  \_
 |
 | (puts)[ "continue: skip odd" ]
 | I32 j = 0
 | WHILE [ j < 6 ]
 |  | j += 1
 |  | IF [ j % 2 == 1 ]
 |  |  | CONTINUE
 |  |  \_
 |  | (printf)[ "  even=%d\n" | j ]
 |  \_
 |
 | (puts)[ "compound assignment:" ]
 | I32 n = 10
 | n += 5
 | n -= 3
 | n *= 2
 | n /= 4
 | n %= 5
 | (printf)[ "  n=%d (expect 1)\n" | n ]
 |
 | ; a WHILE whose body never runs
 | I32 z = 0
 | WHILE [ z > 0 ]
 |  | (puts)[ "  unreachable" ]
 |  | z -= 1
 |  \_
 | (puts)[ "done" ]
 | RET [ 0 ]
 \_
