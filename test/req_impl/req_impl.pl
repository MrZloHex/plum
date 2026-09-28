; REQ with all three kinds, written under the header and over several lines

!USES <../../extern/stdio.pl>

; --- a bus: here a fake one that remembers what went through it

TYPE FakeBusData: STRUCT
 | U8  last
 | I32 count
 \_

IFACE SPIBus<T>: [ @T me ]
    REQ [ U8 last | I32 count ]

 | U8 transfer: [ U8 v ]
 |  | U8 old = me.last
 |  | me.last = v
 |  | me.count += 1
 |  | RET [ old ]
 |  \_
 \_

CLASS FakeBus: FakeBusData IMPL [ SPIBus<FakeBusData> ]

; --- a device on any bus that IMPLs SPIBus

TYPE MRAMData<BUS>: STRUCT
 | @BUS bus
 | U32  writes
 \_

IFACE Named<T>: [ @T me ]
 | @C1 name: []
 |  | RET [ "mram" ]
 |  \_
 \_

IFACE MRAMOps<T | BUS>: [ @T me ]
    REQ [
        @BUS bus |
        U32 writes |
        Named<T> |
        BUS IMPL SPIBus<BUS>
    ]

 | ABYSS write_byte: [ U32 address | U8 value ]
 |  | (me.bus.transfer)[ 2 ]
 |  | (me.bus.transfer)[ (address >> 8) AS U8 ]
 |  | (me.bus.transfer)[ address AS U8 ]
 |  | (me.bus.transfer)[ value ]
 |  | me.writes += 1
 |  \_
 \_

; SPIBus<FakeBus> is met by FakeBus's SPIBus<FakeBusData>: a class and the
; struct it holds are one
CLASS MRAM<BUS>: MRAMData<BUS> IMPL [ Named<MRAMData<BUS>> | MRAMOps<MRAMData<BUS> | BUS> ]

I32 main: []
 | FakeBus bus
 | bus.last = 0
 | bus.count = 0
 | MRAM<FakeBus> m
 | m.bus = @bus
 | m.writes = 0
 | (m.write_byte)[ 0x1234 | 0x5A ]
 | (m.write_byte)[ 0x1235 | 0x07 ]
 | (printf)[ "%s: %d transfers, last %d, %u writes\n" | (m.name)[] | bus.count | bus.last AS I32 | m.writes ]
 | RET [ 0 ]
 \_
