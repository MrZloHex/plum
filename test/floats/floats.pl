; Float arithmetic: every operator, mixing with integers, both widths,
; conversions, and floats through varargs.

!USES <../../extern/stdio.pl>

F64 PI = 3.141592653589793
F32 HALF = 0.5
F64 TWO = 2

TYPE Vec2:
 | F32 x
 | F32 y
 \_

F32 dot: [ Vec2 a | Vec2 b ]
 | RET [ a.x * b.x + a.y * b.y ]
 \_

F64 area: [ F64 r ]
 | RET [ PI * r * r ]
 \_

; Newton's method, in PLUM itself
F64 my_sqrt: [ F64 x ]
 | F64 g = x / 2
 | I32 i = 0
 | WHILE [ i < 30 ]
 |  | g = (g + x / g) / 2
 |  | i += 1
 |  \_
 | RET [ g ]
 \_

I32 main: []
 | F64 a = 7.5
 | F64 b = 2
 | (printf)[ "%.2f %.2f %.2f %.2f %.2f\n" | a + b | a - b | a * b | a / b | a % b ]
 | (printf)[ "neg %.2f, mixed %.2f, unsigned %.1f\n" | -a | a * 2 + 1 | (4000000000 AS U32) + 0.5 ]
 |
 | F32 f = 1.25
 | f *= 4
 | f += HALF
 | (printf)[ "f32 %f, widened %.3f\n" | f | f * PI ]
 |
 | Vec2 u
 | u.x = 3
 | u.y = 4
 | (printf)[ "dot %.1f, |u| %.1f\n" | (dot)[ u | u ] | (my_sqrt)[ (dot)[ u | u ] ] ]
 | (printf)[ "area(2) %.4f, sqrt(2) %.10f\n" | (area)[ TWO ] | (my_sqrt)[ 2 ] ]
 |
 | IF [ a > b && b >= 2 && a != b && !(a == b) && a <= 7.5 && b < a ]
 |  | (printf)[ "comparisons ok\n" ]
 |  \_
 |
 | F64 zero = 0
 | F64 nan = zero / zero
 | IF [ nan != nan && !(nan == nan) && !(nan < 1) ]
 |  | (printf)[ "NaN compares as in C\n" ]
 |  \_
 | IF [ !zero && a ]
 |  | (printf)[ "truthiness ok\n" ]
 |  \_
 |
 | I32 t = (a * 10) AS I32
 | I32 fl = -7.9 AS I32
 | (printf)[ "to int: %d %d\n" | t | fl ]
 | RET [ 0 ]
 \_
