; a generic type cannot be used without its arguments
TYPE Box<T>:
 | T value
 \_

I32 main: []
 | Box b
 | RET [ 0 ]
 \_
