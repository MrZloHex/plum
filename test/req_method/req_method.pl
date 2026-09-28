; Required methods: an interface states what it needs, other interfaces
; of the same class give it. One contract, two different buses, and a
; device that works on either -- all resolved at compile time.

!USES <../../extern/stdio.pl>

; the contract: a bus moves a byte. `ping`, built on it, SPIBus gives
IFACE SPIBus<T>: [ @T me ]
 | U8 transfer: [ U8 value ]

 | U8 ping: []
 |  | (me.transfer)[ 170 ]
 |  | RET [ (me.transfer)[ 0 ] ]
 |  \_
 \_

; a loopback bus: hands back the byte sent before
TYPE LoopData: STRUCT
 | U8 held
 \_

IFACE LoopOps<T>: [ @T me ] REQ [ U8 held ]
 | U8 transfer: [ U8 value ]
 |  | U8 out = me.held
 |  | me.held = value
 |  | RET [ out ]
 |  \_
 \_

CLASS LoopBus: LoopData IMPL [ SPIBus<LoopData> | LoopOps<LoopData> ]

; an inverting bus: answers every byte with its complement, and counts
TYPE InvData: STRUCT
 | I32 moved
 \_

IFACE InvOps<T>: [ @T me ] REQ [ I32 moved ]
 | U8 transfer: [ U8 value ]
 |  | me.moved += 1
 |  | RET [ (~value) AS U8 ]
 |  \_
 \_

CLASS InvBus: InvData IMPL [ SPIBus<InvData> | InvOps<InvData> ]

; a device on any bus that takes SPIBus
TYPE DevData<BUS>: STRUCT
 | @BUS bus
 \_

IFACE DevOps<T | BUS>: [ @T me ]
    REQ [
        @BUS bus |
        BUS IMPL SPIBus<BUS>
    ]
 | U8 status: []
 |  | RET [ (me.bus.ping)[] ]
 |  \_
 \_

CLASS Dev<BUS>: DevData<BUS> IMPL [ DevOps<DevData<BUS> | BUS> ]

I32 main: []
 | LoopBus lb
 | lb.held = 7
 | InvBus ib
 | ib.moved = 0
 | Dev<LoopBus> a
 | a.bus = @lb
 | Dev<InvBus> b
 | b.bus = @ib
 | ; loopback: ping sends 170 (gets 7), then 0 (gets 170)
 | ; inverting: ping gets ~170, then ~0 = 255, after 2 transfers
 | (printf)[ "%d %d %d\n" | (a.status)[] AS I32 | (b.status)[] AS I32 | ib.moved ]
 | RET [ 0 ]
 \_
