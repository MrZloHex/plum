; a SWITCH on an enum, with no ELSE, names every constant
TYPE Color: ENUM
 | RED
 | GREEN
 | BLUE
 \_
I32 f: [ Color c ]
 | SWITCH [ c ]
 | CASE [ RED | GREEN ]
 |  | RET [ 1 ]
 |  \_
 | RET [ 0 ]
 \_
I32 main: []
 | RET [ (f)[ RED ] ]
 \_
