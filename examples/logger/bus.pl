; bus.pl -- the SPI contract, and two very different things that meet it
;
; SPIBus states what a bus must do, select and transfer, without doing
; it: those methods have no body, so they are required. Each bus gives
; them in an interface of its own, and SPIBus builds `send` on top.
; Everything is settled at compile time: no function pointers, no vtable.

!USES <../../extern/stdio.pl>

IFACE SPIBus<T>: [ @T me ]
 | ABYSS select: [ B1 on ]
 | U8 transfer: [ U8 out ]
 |
 | ; given, for every bus, on the two above
 | ABYSS send: [ @CONST U8 data | USIZE n ]
 |  | USIZE i = 0
 |  | WHILE [ i < n ]
 |  |  | (me.transfer)[ data{i} ]
 |  |  | i += 1
 |  |  \_
 |  \_
 \_

; --- a loopback: hands back the byte sent before -------------------------------

TYPE LoopData: STRUCT
 | U8 held
 \_

IFACE LoopOps<T>: [ @T me ] REQ [ U8 held | SPIBus<T> ]
 | ABYSS select: [ B1 on ]
 |  | me.held = 0
 |  \_
 |
 | U8 transfer: [ U8 out ]
 |  | U8 back = me.held
 |  | me.held = out
 |  | RET [ back ]
 |  \_
 \_

CLASS LoopbackBus: LoopData IMPL [ SPIBus<LoopData> | LoopOps<LoopData> ]

; --- a flash chip: 256 bytes, written and read by command ---------------------

CONST U8 CMD_WRITE = 2
CONST U8 CMD_READ  = 3

TYPE ChipState: ENUM
 | CHIP_IDLE          ; selected, waiting for a command
 | CHIP_ADDR_WRITE    ; the next byte says where to write
 | CHIP_WRITING
 | CHIP_ADDR_READ     ; the next byte says where to read
 | CHIP_READING
 \_

; the cells come in 32-byte lines, as a DMA engine would want them
TYPE Cells: STRUCT
 + ALIGN 32
 | U8 byte{256}
 \_

STATIC_ASSERT [ SIZE [ Cells ] == 256 | "the flash is 256 bytes" ]

TYPE ChipData: STRUCT
 | Cells     cells
 | ChipState state
 | U8        at
 | B1        selected
 | I32       moved        ; bytes through the bus, while selected
 \_

IFACE ChipOps<T>: [ @T me ]
    REQ [
        Cells cells |
        ChipState state |
        U8 at |
        B1 selected |
        I32 moved |
        SPIBus<T>
    ]

 | ABYSS select: [ B1 on ]
 |  | me.selected = on
 |  | me.state = CHIP_IDLE
 |  \_
 |
 | U8 transfer: [ U8 out ]
 |  | U8 back = 255
 |  | IF [ !(me.selected) ]
 |  |  | RET [ back ]
 |  |  \_
 |  | me.moved += 1
 |  |
 |  | IF [ me.state == CHIP_IDLE ]
 |  |  | IF [ out == CMD_WRITE ]
 |  |  |  | me.state = CHIP_ADDR_WRITE
 |  |  | ELIF [ out == CMD_READ ]
 |  |  |  | me.state = CHIP_ADDR_READ
 |  |  |  \_
 |  | ELIF [ me.state == CHIP_ADDR_WRITE ]
 |  |  | me.at = out
 |  |  | me.state = CHIP_WRITING
 |  | ELIF [ me.state == CHIP_ADDR_READ ]
 |  |  | me.at = out
 |  |  | me.state = CHIP_READING
 |  | ELIF [ me.state == CHIP_WRITING ]
 |  |  | me.cells.byte{me.at} = out
 |  |  | me.at += 1
 |  | ELSE
 |  |  | back = me.cells.byte{me.at}
 |  |  | me.at += 1
 |  |  \_
 |  | RET [ back ]
 |  \_
 \_

CLASS FlashChip: ChipData IMPL [ SPIBus<ChipData> | ChipOps<ChipData> ]

; --- a probe that works on any bus --------------------------------------------

TYPE ProbeData<BUS>: STRUCT
 | @BUS bus
 \_

IFACE ProbeOps<T | BUS>: [ @T me ]
    REQ [
        @BUS bus |
        BUS IMPL SPIBus<BUS>
    ]

 | ; a loopback hands the first byte back on the second transfer
 | B1 echoes: []
 |  | (me.bus.select)[ TRUE ]
 |  | (me.bus.transfer)[ 165 ]
 |  | U8 back = (me.bus.transfer)[ 0 ]
 |  | (me.bus.select)[ FALSE ]
 |  | RET [ back == 165 ]
 |  \_
 |
 + ANONYMOUS:
 | Probe<BUS> on: [ @BUS bus ]
 |  | Probe<BUS> p
 |  | p.bus = bus
 |  | RET [ p ]
 |  \_
 \_

CLASS Probe<BUS>: ProbeData<BUS> IMPL [ ProbeOps<ProbeData<BUS> | BUS> ]
