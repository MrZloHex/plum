; a REQ interface the class does not take
TYPE D: STRUCT
 | I32 hp
 | @C1 name
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
CLASS C: D IMPL [ Mortal ]
I32 main: []
 | RET [ 0 ]
 \_
