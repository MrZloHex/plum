; the type has no such ANONYMOUS method
TYPE PointData: STRUCT
 | I32 x
 | I32 y
 \_
IFACE PointOps: [ @PointData me ]
 | I32 sum: []
 |  | RET [ me.x + me.y ]
 |  \_
 + ANONYMOUS:
 | Point at: [ I32 x | I32 y ]
 |  | Point p
 |  | p.x = x
 |  | p.y = y
 |  | RET [ p ]
 |  \_
 \_
CLASS Point: PointData IMPL [ PointOps ]
I32 main: []
 | Point p = (Point.nowhere)[]
 | RET [ 0 ]
 \_
