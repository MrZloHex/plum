; a function name is already its address
I32 f: []
 | RET [ 1 ]
 \_
I32 main: []
 | FN I32 [] g = @f
 | RET [ (g)[] ]
 \_
