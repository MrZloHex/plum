; a method of another interface of the class, which the REQ does not name
TYPE UnitData: STRUCT
 | I32 hp
 \_
IFACE Loud<T>: [ @T me ]
 | ABYSS shout: []
 |  | RET
 |  \_
 \_
IFACE Mortal<T>: [ @T me ] REQ [ I32 hp ]
 | ABYSS hit: [ I32 d ]
 |  | me.hp -= d
 |  | (me.shout)[]
 |  \_
 \_
CLASS Unit: UnitData IMPL [ Loud<UnitData> | Mortal<UnitData> ]
I32 main: []
 | Unit u
 | (u.hit)[ 3 ]
 | RET [ 0 ]
 \_
