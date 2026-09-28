; a CONST variable cannot be assigned
I32 main: []
 | CONST I32 n = 1
 | n = 2
 | RET [ 0 ]
 \_
