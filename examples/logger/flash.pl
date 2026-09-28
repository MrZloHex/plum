; flash.pl -- storage on any SPI bus that speaks the chip's commands
;
; Flash<BUS> knows nothing of the bus but its contract, SPIBus; REQ says
; so, and a Flash on something that is no bus is an error at compile time.
; A write or read that does not fit says why, as a Result.

!USES <bus.pl>
!USES <../result.pl>

TYPE FlashData<BUS>: STRUCT
 | @BUS  bus
 | USIZE size
 \_

IFACE FlashOps<T | BUS>: [ @T me ]
    REQ [
        @BUS bus |
        USIZE size |
        BUS IMPL SPIBus<BUS>
    ]

 | Result<USIZE | @C1> write: [ USIZE at | @CONST U8 data | USIZE n ]
 |  | IF [ at + n > me.size ]
 |  |  | RET [ (Result<USIZE | @C1>.err)[ "past the end of the flash" ] ]
 |  |  \_
 |  | (me.begin)[ CMD_WRITE | at ]
 |  | (me.bus.send)[ data | n ]
 |  | (me.bus.select)[ FALSE ]
 |  | RET [ (Result<USIZE | @C1>.ok)[ n ] ]
 |  \_
 |
 | Result<USIZE | @C1> read: [ USIZE at | @U8 into | USIZE n ]
 |  | IF [ at + n > me.size ]
 |  |  | RET [ (Result<USIZE | @C1>.err)[ "past the end of the flash" ] ]
 |  |  \_
 |  | (me.begin)[ CMD_READ | at ]
 |  | USIZE i = 0
 |  | WHILE [ i < n ]
 |  |  | into{i} = (me.bus.transfer)[ 0 ]
 |  |  | i += 1
 |  |  \_
 |  | (me.bus.select)[ FALSE ]
 |  | RET [ (Result<USIZE | @C1>.ok)[ n ] ]
 |  \_
 |
 + PRIVATE:
 | ; select the chip, then say what and where
 | ABYSS begin: [ U8 cmd | USIZE at ]
 |  | (me.bus.select)[ TRUE ]
 |  | (me.bus.transfer)[ cmd ]
 |  | (me.bus.transfer)[ at AS U8 ]
 |  \_
 |
 + ANONYMOUS:
 | Flash<BUS> on: [ @BUS bus | USIZE size ]
 |  | Flash<BUS> f
 |  | f.bus = bus
 |  | f.size = size
 |  | RET [ f ]
 |  \_
 \_

CLASS Flash<BUS>: FlashData<BUS> IMPL [ FlashOps<FlashData<BUS> | BUS> ]
