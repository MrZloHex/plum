; PRIVATE belongs to one class, even when another shares its base
TYPE D:
 | I32 n
 \_
IFACE A: [ @D me ]
 + PRIVATE:
 | I32 secret: []
 |  | RET [ 1 ]
 |  \_
 \_
IFACE B: [ @D me ]
 | I32 peek: [ @CA other ]
 |  | RET [ (other.secret)[] ]
 |  \_
 \_
CLASS CA: D IMPL [ A ]
CLASS CB: D IMPL [ B ]
I32 main: []
 | RET [ 0 ]
 \_
