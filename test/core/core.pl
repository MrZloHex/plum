; The core language: precedence, signed and unsigned arithmetic, compound
; assignment on every kind of place, escapes, shadowing, short-circuit
; guards, and AS followed by comparisons that look like type arguments.

!USES <../../extern/stdio.pl>

TYPE Inner:
 | I32 v
 | @Inner next
 \_
TYPE Outer:
 | Inner in
 | @Inner pin
 \_

I32 fact: [ I32 n ]
 | IF [ n <= 1 ]
 |  | RET [ 1 ]
 |  \_
 | RET [ n * (fact)[ n - 1 ] ]
 \_

I32 main: []
 | ; precedence
 | (printf)[ "%d %d %d %d\n" | 2 + 3 * 4 | (2 + 3) * 4 | 1 << 2 + 1 | 10 - 4 - 3 ]
 | (printf)[ "%d %d %d\n" | 7 / 2 | -7 / 2 | -7 % 3 ]
 | (printf)[ "%d %d %d\n" | (6 & 3) | (6 | 3) | 6 ^ 3 ]
 | U32 u = 3000000000 AS U32
 | (printf)[ "%u %u %d\n" | u / 2 | u >> 1 | u > 5 ]
 | I32 neg = -8
 | (printf)[ "%d\n" | neg >> 1 ]
 | ; mixing signs: a U8 of 200 compares as 200
 | U8 b = 200
 | I8 s = -1
 | (printf)[ "%d %d %d\n" | b > 100 | s < 0 | b + s ]
 | ; compound assignment on every kind of place
 | Outer o
 | Inner other
 | o.pin = @other
 | o.in.v = 1
 | o.in.v += 4
 | o.pin.v = 10
 | o.pin.v *= 3
 | I32 arr{3}
 | arr{1} = 5
 | arr{1} -= 2
 | (printf)[ "%d %d %d\n" | o.in.v | other.v | arr{1} ]
 | ; chains through pointers
 | other.next = @(o.in)
 | (printf)[ "%d\n" | o.pin.next.v ]
 | ; escapes
 | (printf)[ "[%s] %d %d %d\n" | "tab\there \"q\" back\\slash \x41" | '\n' | '\\' | '\x7f' ]
 | (printf)[ "%d\n" | (fact)[ 10 ] ]
 | ; shadowing in nested blocks
 | I32 x = 1
 | IF [ TRUE ]
 |  | I32 x = 2
 |  | (printf)[ "inner %d\n" | x ]
 |  \_
 | (printf)[ "outer %d\n" | x ]
 | ; short circuit guards a NULL
 | @Inner np = NULL
 | IF [ np != NULL && np.v == 3 ]
 |  | (printf)[ "wrong\n" ]
 | ELSE
 |  | (printf)[ "guarded\n" ]
 |  \_
 | ; a cast inside an argument list, then a comparison
 | I32 y = 3
 | (printf)[ "%d %d\n" | y AS I64 < 5 | y > 2 ]
 | I32 z = 5
 | I32 w = 4
 | I32 v = 1
 | (printf)[ "%d %d\n" | y AS I32 < z | w > v ]
 | (printf)[ "%d %d %d\n" | '\x7f' | '\x1b' | '\0' ]
 | RET [ 0 ]
 \_
