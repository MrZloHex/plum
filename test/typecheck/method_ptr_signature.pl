; an ordinary method takes `me` first: its pointer type must say so
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
 | FN I32 [] f = Point.get
 | RET [ 0 ]
 \_
