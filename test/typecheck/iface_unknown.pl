; IMPL names an interface that does not exist
TYPE D:
 | I32 n
 \_
CLASS C: D IMPL [ Nope ]
I32 main: []
 | RET [ 0 ]
 \_
