; small_syntax.pl -- compound bitwise assignment, enum values, blank and comment lines in records
I32 printf: [ @C1 fmt | ... ]

TYPE Reg: ENUM
 | CR = 0x40
 ; the next two follow on
 | SR

 | DR
 | NEG = -3
 | AFTER
 | TOP = 0xFFFF_FFFF
 \_

TYPE Point: STRUCT
 | I32 x

 ; y is the second one
 | I32 y
 \_

I32 main: []
 | U32 f = 0xF0
 | f &= 0x3C
 | f |= 1
 | f ^= 0x100
 | f <<= 2
 | f >>= 1
 | Point p
 | p.x = 1
 | p.x |= 6
 | (printf)[ "%x %d %d %d %d %d %u %d\n" | f | CR | SR | DR | NEG | AFTER | TOP AS U32 | p.x ]
 | (printf)[ "%d\n" | (7 | 8) ]
 | RET [ 0 ]
 \_
