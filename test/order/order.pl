; Order does not matter at the top level: main uses a class, IFACE and
; TYPE defined after it. Also BREAK and CONTINUE in nested WHILE loops.

!USES <../../extern/stdio.pl>
I32 main: []
 | @Later<I32> p = NULL
 | Later<I32> l
 | (l.put)[ 3 ]
 | p = @l
 | I32 i = 0
 | I32 hits = 0
 | WHILE [ i < 4 ]
 |  | i += 1
 |  | I32 j = 0
 |  | WHILE [ j < 4 ]
 |  |  | j += 1
 |  |  | IF [ j == 2 ]
 |  |  |  | CONTINUE
 |  |  |  \_
 |  |  | IF [ j == 4 ]
 |  |  |  | BREAK
 |  |  |  \_
 |  |  | hits += 1
 |  |  \_
 |  | IF [ i == 3 ]
 |  |  | CONTINUE
 |  |  \_
 |  | hits += 10
 |  \_
 | (printf)[ "%d %d\n" | (p.get)[] | hits ]
 | RET [ 0 ]
 \_
CLASS Later<T>: LaterData<T> IMPL [ LaterOps<T> ]
IFACE LaterOps<T>: [ @LaterData<T> me ]
 | ABYSS put: [ T v ]
 |  | me.v = v
 |  \_
 | T get: []
 |  | RET [ me.v ]
 |  \_
 \_
TYPE LaterData<T>:
 | T v
 \_
