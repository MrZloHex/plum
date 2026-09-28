; req_contract.pl -- what a REQ lets an interface's methods use, all of it
I32 printf: [ @C1 fmt | ... ]

TYPE BusData: STRUCT
 | U8 last
 \_

; no REQ: its methods may use anything
IFACE SPIBus<T>: [ @T me ]
 | U8 transfer: [ U8 v ]
 |  | U8 old = me.last
 |  | me.last = v
 |  | RET [ old ]
 |  \_
 \_

CLASS Bus: BusData IMPL [ SPIBus<BusData> ]

TYPE ChipData<BUS>: STRUCT
 | @BUS bus
 | I32  moved
 | I32  unused
 \_

IFACE Named<T>: [ @T me ]
 | ABYSS hello: [ @C1 what ]
 |  | (printf)[ "chip: %s\n" | what ]
 |  \_
 \_

IFACE Counted<T>: [ @T me ]
 | I32 count: []
 |  | RET [ 7 ]
 |  \_
 \_

IFACE ChipOps<T | BUS>: [ @T me ]
    REQ [
        @BUS bus |
        I32 moved |
        Named<T> |
        BUS IMPL SPIBus<BUS>
    ]
 | ; the REQ's fields, the REQ's interfaces, and what BUS IMPLs
 | ABYSS send: [ U8 v ]
 |  | (me.hello)[ "send" ]
 |  | U8 back = (me.bus.transfer)[ v ]
 |  | me.moved += 1
 |  | (printf)[ "sent %u, got %u back, moved %d\n" | v AS U32 | back AS U32 | me.moved ]
 |  \_
 |
 | ; its own methods, required ones too, and through a pointer
 | ABYSS twice: [ U8 v ]
 |  | FN ABYSS [ @Chip<Bus> | U8 ] f = Chip<Bus>.send
 |  | (f)[ me | v ]
 |  | (me.send)[ (me.total)[] AS U8 ]
 |  \_
 | I32 total: []
 |
 | ; its own ANONYMOUS ones, and OFFSET of a field it lists
 + ANONYMOUS:
 | Chip<Bus> on: [ @Bus b ]
 |  | Chip<Bus> c
 |  | c.bus = b
 |  | c.moved = 0
 |  | (printf)[ "moved at %lu\n" | OFFSET [ ChipData<Bus>.moved ] ]
 |  | RET [ c ]
 |  \_
 \_

; gives ChipOps its required `total`; it has no REQ, so it may read `unused`
IFACE Totals<T>: [ @T me ]
 | I32 total: []
 |  | RET [ me.moved + me.unused ]
 |  \_
 \_

CLASS Chip<BUS>: ChipData<BUS> IMPL [ ChipOps<ChipData<BUS> | BUS> | Named<ChipData<BUS>> | Totals<ChipData<BUS>> | Counted<ChipData<BUS>> ]

I32 main: []
 | Bus b
 | b.last = 9
 | Chip<Bus> c = (Chip<Bus>.on)[ @b ]
 | c.unused = 40
 | (c.twice)[ 3 ]
 | (printf)[ "count %d\n" | (c.count)[] ]
 | RET [ 0 ]
 \_
