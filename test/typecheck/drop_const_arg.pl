; a pointer to CONST passed where a plain pointer is expected
ABYSS set: [ @I32 p ]
 | ?p = 1
 \_
I32 main: []
 | CONST I32 n = 5
 | (set)[ @n ]
 | RET [ 0 ]
 \_
