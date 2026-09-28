; two CASEs for one value: the second could never run
I32 main: []
 | I32 k = 2
 | SWITCH [ k ]
 | CASE [ 1 | 2 ]
 |  | RET [ 1 ]
 | CASE [ 2 ]
 |  | RET [ 2 ]
 |  \_
 | RET [ 0 ]
 \_
