TYPE S: STRUCT
 | I32 x
 \_
I32 f: [ I32 n ]
 | RET [ n ]
 \_
I32 main: []
 | S s
 | RET [ (f)[ s ] ]
 \_
