; a LOOP with a BREAK can end
I32 b: []
 | LOOP
 |  | IF [ TRUE ]
 |  |  | BREAK
 |  |  \_
 |  \_
 \_
I32 main: []
 | RET [ 0 ]
 \_
