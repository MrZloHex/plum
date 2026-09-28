; an interface with a REQ uses only the fields its REQ lists
TYPE UnitData: STRUCT
 | I32 hp
 | I32 armour
 \_
IFACE Mortal<T>: [ @T me ] REQ [ I32 hp ]
 | ABYSS hit: [ I32 d ]
 |  | me.hp -= d - me.armour
 |  \_
 \_
CLASS Unit: UnitData IMPL [ Mortal<UnitData> ]
I32 main: []
 | Unit u
 | (u.hit)[ 3 ]
 | RET [ 0 ]
 \_
