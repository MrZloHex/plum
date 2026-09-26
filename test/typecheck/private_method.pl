; a PRIVATE method is callable only from the class's own methods
TYPE Data:
 | I32 n
 \_

IFACE Ops: [ @Data me ]
 + PRIVATE:
 | ABYSS secret: []
 |  | me.n = 0
 |  \_
 \_

CLASS Box: Data IMPL [ Ops ]

I32 main: []
 | Box b
 | (b.secret)[]
 | RET [ 0 ]
 \_
