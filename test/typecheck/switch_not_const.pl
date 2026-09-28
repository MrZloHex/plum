; a CASE value must be known while compiling
I32 main: []
 | I32 k = 2
 | I32 m = 3
 | SWITCH [ k ]
 | CASE [ m ]
 |  | RET [ 1 ]
 |  \_
 | RET [ 0 ]
 \_
