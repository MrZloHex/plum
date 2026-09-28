; a name the struct does not have
TYPE Point: STRUCT
 | I32 x
 | I32 y
 \_
I32 main: []
 | Point p = [ .z = 1 ]
 | RET [ p.x ]
 \_
