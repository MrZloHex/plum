; BITWISE: & ^ ~ << >>  (| stays the separator, so bitwise-or has no spelling)

I32 printf: [ @C1 fmt | ... ]

I32 main: []
 | I32 a = 12
 | I32 b = 10
 | (printf)[ "and=%d\n"  | a & b ]
 | (printf)[ "xor=%d\n"  | a ^ b ]
 | (printf)[ "shl=%d\n"  | a << 2 ]
 | (printf)[ "shr=%d\n"  | a >> 2 ]
 | (printf)[ "not=%d\n"  | ~a ]
 | RET [ 0 ]
 \_
