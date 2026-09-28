; the REQ says nothing of T, so the interface may not look inside one
TYPE Point: STRUCT
 | I32 x
 \_
TYPE CellData<T>: STRUCT
 | T value
 \_
IFACE Show<T>: [ @CellData<T> me ] REQ [ T value ]
 | I32 first: []
 |  | RET [ me.value.x ]
 |  \_
 \_
CLASS Cell<T>: CellData<T> IMPL [ Show<T> ]
I32 main: []
 | Cell<Point> c
 | RET [ (c.first)[] ]
 \_
