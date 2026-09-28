; outside a declaration nothing says what [ ... ] should build
TYPE Point: STRUCT
 | I32 x
 | I32 y
 \_
I32 main: []
 | Point p
 | p = [ 1 | 2 ]
 | RET [ p.x ]
 \_
