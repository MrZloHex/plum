; a method taken from an object would need the object too: no C pointer
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
 | Point p
 | FN I32 [ @Point ] f = p.get
 | RET [ 0 ]
 \_
