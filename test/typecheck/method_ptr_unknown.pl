; the type has no such method
TYPE PointData: STRUCT
 | I32 x
 \_
IFACE PointOps: [ @PointData me ]
 | I32 get: []
 |  | RET [ me.x ]
 |  \_
 \_
CLASS Point: PointData IMPL [ PointOps ]
I32 main: []
 | FN I32 [ @Point ] f = Point.put
 | RET [ 0 ]
 \_
