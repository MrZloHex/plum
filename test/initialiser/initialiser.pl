; initialiser.pl -- [ ... ] for structs, arrays, unions, nested, local and global
I32 printf: [ @C1 fmt | ... ]

TYPE Point: STRUCT
 | I32 x
 | I32 y
 \_
TYPE Line: STRUCT
 | Point a
 | Point b
 | @C1   tag
 | U8    w{3}
 \_
TYPE Val: UNION
 | I32 i
 | F32 f
 \_
TYPE Pk: STRUCT
 + PACKED
 | U8  a
 | U32 b
 \_

CONST U32 TABLE{5} = [ 1 | 2 | 4 ]
CONST Line ORIGIN = [ .b = [ 7 | 8 ] | .tag = "origin" | .w = [ 9 ] ]
@C1 NAMES{3} = [
    "zero" |
    "one" |
    "two"
]

I32 main: []
 | Point p = [ .y = 2 | .x = 1 ]
 | Point q = [ 3 ]
 | Line l = [ p | [ .y = 6 ] | "line" | [ 1 | 2 | 3 ] ]
 | Val v = [ .f = 1.5 ]
 | Pk k = [ 1 | 0xDEADBEEF ]
 | I32 xs{4} = [ 10 | 20 ]
 | Point ps{2} = [ [ 1 | 2 ] | [ .y = 4 ] ]
 | (printf)[ "%d %d | %d %d\n" | p.x | p.y | q.x | q.y ]
 | (printf)[ "%d %d %d %d %s %d%d%d\n" | l.a.x | l.a.y | l.b.x | l.b.y | l.tag | l.w{0} | l.w{1} | l.w{2} ]
 | (printf)[ "%.1f %d %x\n" | v.f | k.a | k.b ]
 | (printf)[ "%d %d %d %d | %d %d %d %d\n" | xs{0} | xs{1} | xs{2} | xs{3} | ps{0}.x | ps{0}.y | ps{1}.x | ps{1}.y ]
 | (printf)[ "%u %u %u %u %u | %d %d %s %d | %s %s\n" | TABLE{0} | TABLE{1} | TABLE{2} | TABLE{3} | TABLE{4} | ORIGIN.b.x | ORIGIN.b.y | ORIGIN.tag | ORIGIN.w{0} | NAMES{0} | NAMES{2} ]
 | RET [ 0 ]
 \_
