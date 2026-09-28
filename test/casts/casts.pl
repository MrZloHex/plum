; AS casts, and | for bitwise-or

I32    printf: [ @C1 fmt | ... ]
@ABYSS malloc: [ U64 size ]
ABYSS  free:   [ @ABYSS ptr ]

TYPE Flags: ENUM
 | F_FILE
 | F_FUNC
 | F_LINE
 | F_TIME
 \_

I32 main: []
 | ; BOR, the trace.h flag pattern: 1 | 2 | 4 == 7
 | I32 mask = 1 | 2 | 4
 | (printf)[ "mask=%d\n" | mask ]
 | (printf)[ "masked=%d\n" | mask & 4 ]
 |
 | ; narrowing and widening
 | I64 big = 300
 | U8  small = big AS U8
 | (printf)[ "narrow 300->u8 = %d\n" | small ]
 |
 | I8  neg = -1
 | I64 wide = neg AS I64
 | (printf)[ "widen -1->i64 = %d\n" | wide ]
 |
 | ; pointer <-> integer, and void* to a typed pointer
 | @ABYSS raw = (malloc)[ 8 ]
 | @I32   ip  = raw AS @I32
 | ?ip = 12345
 | (printf)[ "through cast = %d\n" | ?ip ]
 |
 | U64 addr = raw AS U64
 | (printf)[ "addr nonzero = %d\n" | addr != 0 ]
 |
 | ; casts bind tighter than arithmetic
 | I32 r = big AS I32 + 5
 | (printf)[ "precedence = %d (expect 305)\n" | r ]
 |
 | ; widening by AS keeps an unsigned value's value, a signed one's sign
 | U8 ub = 200
 | I8 sb = -56
 | (printf)[ "widen U8 200 = %d, I8 -56 = %d\n" | ub AS I32 | sb AS I32 ]
 |
 | (free)[ raw ]
 | RET [ 0 ]
 \_
