; Numbers as written: exponents, `_` separators in both kinds, hex that
; contains an E, 64-bit literals, and unsigned values through floats.

!USES <../../extern/stdio.pl>

F64 KILO = 1e3

I32 main: []
 | F64 a = 1e3
 | F64 b = 2.5e-2
 | F64 c = 1_000.5
 | F64 d = 6.02E+23
 | I32 h = 0xE5
 | I32 bits = 0b1010_1010
 | (printf)[ "%g %g %g %g %d %d %g\n" | a | b | c | d | h | bits | KILO ]
 |
 | U64 big = 0xFFFF_FFFF_FFFF_FFFF
 | F64 fd = big
 | F64 e = 1.8e19
 | U64 back = e AS U64
 | U8 small = 250
 | F32 fs = small
 | I32 neg = -7.9 AS I32
 | U8 wrap = 200.7 AS U8
 | (printf)[ "%g %lu %g %.1f %d %d\n" | fd | back | big AS F64 | fs | neg | wrap ]
 |
 | I64 k = 5000000000
 | I32 n = 3
 | (printf)[ "%ld %ld\n" | k + n | n * 3000000000 ]
 | RET [ 0 ]
 \_
