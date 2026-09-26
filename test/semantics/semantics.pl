; Language rules that were once silently wrong. Every line of the expected
; output is what the rule says, not what some compiler happened to print.

!USES <../../extern/stdio.pl>

; constant expressions as global initialisers
I32 NEG      = -1
I32 MASK     = (1 << 4) - 1
U64 BIG      = 0x1_0000_0000
I64 MINUS    = -5000000000
F64 NEG_HALF = -0.5
U64 WORD     = SIZE [ U64 ] * 8
@C1 GREETING = "hi"

; pointer globals take NULL, 0, or a string
TYPE Node:
 | I32   v
 | @Node next
 \_
@Node HEAD = NULL
@C1   NOTHING = 0

TYPE Kind: ENUM
 | K_A
 | K_B
 \_

I32 SECOND = K_B + 10

I32 main: []
 | ; a condition is `!= 0`, not the low bit
 | I32 two = 2
 | IF [ two ]
 |  | (printf)[ "IF [ 2 ] is true\n" ]
 |  \_
 | IF [ two && 4 ]
 |  | (printf)[ "2 && 4 is true\n" ]
 |  \_
 | B1 b = 256
 | (printf)[ "B1 from 256 = %d\n" | b ]
 | @C1 p = "x"
 | IF [ p ]
 |  | (printf)[ "a non-null pointer is true\n" ]
 |  \_
 | @C1 q = NULL
 | IF [ !q && !(q) ]
 |  | (printf)[ "NULL is false\n" ]
 |  \_
 |
 | ; integer literals keep all 64 bits
 | U64 big = 0x100000000
 | I64 neg = -5000000000
 | U32 all = 0xFFFFFFFF
 | U64 wide = 0xFFFFFFFF
 | (printf)[ "%lu %ld %u %lu\n" | big | neg | all | wide ]
 | (printf)[ "%lu\n" | 0xDEADBEEF_CAFEF00D ]
 |
 | (printf)[ "%d %d %lu %ld %.1f %lu %s %d\n" | NEG | MASK | BIG | MINUS | NEG_HALF | WORD | GREETING | SECOND ]
 | (printf)[ "%d %d\n" | HEAD == NULL | NOTHING == NULL ]
 | RET [ 0 ]
 \_
