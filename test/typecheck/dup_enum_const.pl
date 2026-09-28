; one enum constant name in two enums
TYPE E: ENUM
 | X
 | Y
 \_
TYPE F: ENUM
 | Y
 \_
I32 main: []
 | RET [ 0 ]
 \_
