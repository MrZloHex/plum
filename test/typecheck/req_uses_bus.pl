; BUS IMPL SPIBus<BUS> gives BUS SPIBus's methods, and no others
TYPE BusData: STRUCT
 | U8 last
 \_
IFACE SPIBus<T>: [ @T me ]
 | U8 transfer: [ U8 v ]
 |  | RET [ v ]
 |  \_
 \_
IFACE Resettable<T>: [ @T me ]
 | ABYSS reset: []
 |  | me.last = 0
 |  \_
 \_
CLASS Bus: BusData IMPL [ SPIBus<BusData> | Resettable<BusData> ]
TYPE ChipData<BUS>: STRUCT
 | @BUS bus
 \_
IFACE ChipOps<T | BUS>: [ @T me ] REQ [ @BUS bus | BUS IMPL SPIBus<BUS> ]
 | ABYSS wake: []
 |  | (me.bus.transfer)[ 1 ]
 |  | (me.bus.reset)[]
 |  \_
 \_
CLASS Chip<BUS>: ChipData<BUS> IMPL [ ChipOps<ChipData<BUS> | BUS> ]
I32 main: []
 | Bus b
 | Chip<Bus> c
 | c.bus = @b
 | (c.wake)[]
 | RET [ 0 ]
 \_
