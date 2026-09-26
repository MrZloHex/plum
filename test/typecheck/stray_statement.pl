; a `|` line outside any function is not a global declaration
I32 main: []
 | RET [ 0 ]
 \_
 | I32 stray = 0
