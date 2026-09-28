; fields go by name or in order, not both
TYPE Point: STRUCT
 | I32 x
 | I32 y
 \_
I32 main: []
 | Point p = [ .x = 1 | 2 ]
 | RET [ p.x ]
 \_
