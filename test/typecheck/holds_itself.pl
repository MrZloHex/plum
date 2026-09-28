; a struct holding itself by value would never end
TYPE Node: STRUCT
 | I32  v
 | Node next
 \_
I32 main: []
 | RET [ 0 ]
 \_
