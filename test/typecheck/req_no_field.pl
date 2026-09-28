; a REQ field the struct does not have
TYPE D: STRUCT
 | I32 hp
 | I32 mp
 \_
IFACE Named: [ @D me ] REQ [ @C1 name ]
 | I32 f: []
 |  | RET [ 1 ]
 |  \_
 \_
IFACE Mortal: [ @D me ] REQ [ I32 hp | Named ]
 | I32 g: []
 |  | RET [ me.hp ]
 |  \_
 \_
CLASS C: D IMPL [ Named | Mortal ]
I32 main: []
 | RET [ 0 ]
 \_
