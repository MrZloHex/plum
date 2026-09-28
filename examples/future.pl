; embedded_showcase.pl
; -----------------------------------------------------------------------------
; PLUM embedded / systems programming showcase + language roadmap
;
; PURPOSE
;   This file is intentionally one large "everything in one place" example.
;   Later it could be split approximately into:
;
;       core/compiler.pl
;       stm32/mmio.pl
;       stm32/gpio.pl
;       stm32/uart.pl
;       stm32/spi.pl
;       drivers/mram.pl
;       board.pl
;       main.pl
;
; The code is a DESIGN TARGET, not necessarily valid in the current compiler.
;
; Existing PLUM ideas used here:
;   - TYPE / STRUCT / UNION / ENUM
;   - raw pointers: @T
;   - dereference: ?ptr
;   - arrays/indexing
;   - IFACE
;   - CLASS ... IMPL [...]
;   - generic types
;   - Option / Result
;   - direct C ABI declarations
;   - explicit init/deinit style
;
; Proposed language features are marked:
;       ; FUTURE:
;
; Core design rule:
;
;   If the programmer did not write storage, the object should not secretly
;   contain storage.
;
;   If the programmer did not write a runtime operation, the language should
;   avoid silently creating one.
;
;   Every abstraction should have an obvious C / LLVM lowering.
;
; -----------------------------------------------------------------------------

!USES <option.pl>
!USES <result.pl>

; ============================================================================
; 0. EXTERNAL C ABI
; ============================================================================

; Existing-style C declarations.
ABYSS memcpy: [ @ABYSS dst | @ABYSS src | USIZE size ]
ABYSS memset: [ @ABYSS dst | I32 value | USIZE size ]


; ============================================================================
; 1. BASIC COMPILE-TIME / LAYOUT FACILITIES
; ============================================================================

; FUTURE:
; CONST means:
;   - immutable after initialization
;   - if initialized with a compile-time expression, no runtime init code

CONST U32 CPU_HZ = 64000000


; FUTURE:
; COMPTIME executes ordinary PLUM code during compilation.
; No runtime function needs to exist if every call is compile-time.

COMPTIME U32 BIT: [ U8 n ]
 | RET [ 1 << n ]
 \_


CONST U32 BIT0 = (BIT)[ 0 ]
CONST U32 BIT5 = (BIT)[ 5 ]


; FUTURE:
; PACKED controls physical layout.
;
; C-like meaning:
;
;   struct __attribute__((packed)) PersistentHeader { ... };

TYPE PersistentHeader: STRUCT
 + PACKED
 | U32 magic
 | U16 version
 | U8  flags
 | U32 crc
 \_


; FUTURE:
; STATIC_ASSERT disappears after compilation.

STATIC_ASSERT [ SIZE [ PersistentHeader ] == 11 ]


; FUTURE:
; OFFSET is a compile-time builtin.

STATIC_ASSERT [ OFFSET [ PersistentHeader.crc ] == 7 ]


; ============================================================================
; 2. MEMORY-MAPPED I/O
; ============================================================================

; FUTURE:
; VOLATILE applies to accesses through this pointer.
;
; It must lower to volatile LLVM load/store.
;
; No wrapper object.
; No constructor.
; No hidden synchronization.

TYPE GPIORegs: STRUCT
 | U32 MODER
 | U32 OTYPER
 | U32 OSPEEDR
 | U32 PUPDR
 | U32 IDR
 | U32 ODR
 | U32 BSRR
 | U32 LCKR
 | U32 AFRL
 | U32 AFRH
 \_


TYPE USARTRegs: STRUCT
 | U32 CR1
 | U32 CR2
 | U32 CR3
 | U32 BRR
 | U32 GTPR
 | U32 RTOR
 | U32 RQR
 | U32 ISR
 | U32 ICR
 | U32 RDR
 | U32 TDR
 \_


TYPE SPIRegs: STRUCT
 | U32 CR1
 | U32 CR2
 | U32 SR
 | U32 DR
 | U32 CRCPR
 | U32 RXCRCR
 | U32 TXCRCR
 \_


TYPE TIMRegs: STRUCT
 | U32 CR1
 | U32 CR2
 | U32 SMCR
 | U32 DIER
 | U32 SR
 | U32 EGR
 | U32 CCMR1
 | U32 CCMR2
 | U32 CCER
 | U32 CNT
 | U32 PSC
 | U32 ARR
 \_


; Addresses are illustrative STM32-like values.
; The important part is the language shape, not this exact register map.

CONST USIZE GPIOA_BASE  = 0x50000000
CONST USIZE GPIOB_BASE  = 0x50000400
CONST USIZE USART2_BASE = 0x40004400
CONST USIZE SPI1_BASE   = 0x40013000
CONST USIZE TIM3_BASE   = 0x40000400


; FUTURE:
VOLATILE @GPIORegs  GPIOA  = GPIOA_BASE  AS @GPIORegs
VOLATILE @GPIORegs  GPIOB  = GPIOB_BASE  AS @GPIORegs
VOLATILE @USARTRegs USART2 = USART2_BASE AS @USARTRegs
VOLATILE @SPIRegs   SPI1   = SPI1_BASE   AS @SPIRegs
VOLATILE @TIMRegs   TIM3   = TIM3_BASE   AS @TIMRegs


; ============================================================================
; 3. GPIO: ZERO-RUNTIME-OVERHEAD CLASS-LIKE API
; ============================================================================

TYPE PinData: STRUCT
 | VOLATILE @GPIORegs port
 | U8 pin
 \_


IFACE PinOps: [ @PinData me ]
 | ; FUTURE:
 | ; INLINE means "request/require inline", but adds no object state.
 | INLINE ABYSS high: []
 |  | ?me.port.BSRR = 1 << me.pin
 |  \_
 |
 | INLINE ABYSS low: []
 |  | ?me.port.BSRR = 1 << (me.pin + 16)
 |  \_
 |
 | INLINE B1 read: []
 |  | RET [ (?me.port.IDR & (1 << me.pin)) != 0 ]
 |  \_
 |
 | ABYSS output: []
 |  | U32 shift = me.pin * 2
 |  | ?me.port.MODER &= ~(3 << shift)
 |  | ?me.port.MODER |=   1 << shift
 |  \_
 |
 | ABYSS input: []
 |  | U32 shift = me.pin * 2
 |  | ?me.port.MODER &= ~(3 << shift)
 |  \_
 |
 \_


CLASS Pin: PinData IMPL [ PinOps ]


; A Pin is just:
;
;   {
;       GPIORegs* port;
;       U8        pin;
;   }
;
; No vptr.
; No RTTI.
; No constructor table.


; FUTURE:
; Constant aggregate initialization.
CONST Pin LED = [
    .port = GPIOA |
    .pin  = 5
]


CONST Pin USER_BUTTON = [
    .port = GPIOB |
    .pin  = 13
]


; ============================================================================
; 4. UART
; ============================================================================

TYPE UARTData: STRUCT
 | VOLATILE @USARTRegs regs
 \_


IFACE UARTOps: [ @UARTData me ]
 |
 | ABYSS init: [ U32 clock | U32 baud ]
 |  | ?me.regs.CR1 = 0
 |  | ?me.regs.BRR = clock / baud
 |  |
 |  | ; UE | RE | TE
 |  | ?me.regs.CR1 = (1 << 0) | (1 << 2) | (1 << 3)
 |  \_
 |
 | INLINE B1 tx_ready: []
 |  | RET [ (?me.regs.ISR & (1 << 7)) != 0 ]
 |  \_
 |
 | ABYSS write_byte: [ U8 value ]
 |  | WHILE [ !(me.tx_ready)[] ]
 |  | \_
 |  |
 |  | ?me.regs.TDR = value
 |  \_
 |
 | ABYSS write: [ @C1 text ]
 |  | USIZE i = 0
 |  |
 |  | WHILE [ text{i} != '\0' ]
 |  |  | (me.write_byte)[ text{i} AS U8 ]
 |  |  | i += 1
 |  |  \_
 |  \_
 |
 \_


CLASS UART: UARTData IMPL [ UARTOps ]


CONST UART DEBUG_UART = [
    .regs = USART2
]


; ============================================================================
; 5. TIMER
; ============================================================================

TYPE TimerData: STRUCT
 | VOLATILE @TIMRegs regs
 \_


IFACE TimerOps: [ @TimerData me ]
 |
 | INLINE ABYSS enable: []
 |  | ?me.regs.CR1 |= 1
 |  \_
 |
 |  INLINE ABYSS disable: []
 |  | ?me.regs.CR1 &= ~1
 |  \_
 |
 | INLINE ABYSS clear_update: []
 |  | ?me.regs.SR &= ~1
 |  \_
 |
 | ABYSS configure_periodic: [ U16 prescaler | U16 reload ]
 |  | ?me.regs.PSC = prescaler
 |  | ?me.regs.ARR = reload
 |  | ?me.regs.CNT = 0
 | \_
 |
 \_


CLASS Timer: TimerData IMPL [ TimerOps ]


CONST Timer SYSTEM_TIMER = [
    .regs = TIM3
]


; ============================================================================
; 6. INTERRUPTS / LINKER SECTIONS
; ============================================================================

VOLATILE U64 system_ticks = 0


; FUTURE:
;
; INTERRUPT:
;   target-specific interrupt calling convention / return instruction.
;
; USED:
;   compiler/linker must not discard the symbol.
;
; SECTION:
;   place symbol into exact ELF section.
;
; These attributes must NOT create runtime metadata.

ABYSS TIM3_IRQHandler: []
 + INTERRUPT
 + USED
 + SECTION ".text.TIM3_IRQHandler"
 |
 | (SYSTEM_TIMER.clear_update)[]
 | system_ticks += 1
 \_


; A vector table can also be represented explicitly.


TYPE VectorEntry: @ABYSS


; FUTURE:
; SECTION on data.
;
; This is intentionally explicit rather than compiler-created hidden startup
; machinery.

CONST VectorEntry INTERRUPT_VECTOR{4}
 + USED
 + SECTION ".isr_vector"
 =
 [
     0 AS @ABYSS             |
     0 AS @ABYSS             |
     0 AS @ABYSS             |
     TIM3_IRQHandler AS @ABYSS
 ]


; ============================================================================
; 7. SIMPLE SPI BUS
; ============================================================================

TYPE STM32SPIData: STRUCT
 | VOLATILE @SPIRegs regs
 \_


IFACE SPIBus<T>: [ @T me ]
 |
 | U8 transfer: [ U8 value ]
 |  | ; This interface is intentionally generic.
 |  | ; A concrete implementation may replace/override this method.
 |  | RET [ value ]
 |  \_
 |
 \_


IFACE STM32SPIOps: [ @STM32SPIData me ]
 |
 | ABYSS init: []
 |  | ?me.regs.CR1 = 0
 |  | ?me.regs.CR1 |= (1 << 2)
 |  | ?me.regs.CR1 |= (1 << 6)
 |  \_
 |
 | U8 transfer: [ U8 value ]
 |  | WHILE [ (?me.regs.SR & (1 << 1)) == 0 ]
 |  | \_
 |  |
 |  | ?me.regs.DR = value
 |  |
 |  | WHILE [ (?me.regs.SR & 1) == 0 ]
 |  | \_
 |  |
 |  | RET [ ?me.regs.DR AS U8 ]
 |  \_
 |
 \_


CLASS STM32SPI: STM32SPIData IMPL [ STM32SPIOps ]


CONST STM32SPI FLASH_SPI = [
    .regs = SPI1
]


; ============================================================================
; 8. REQUIRES: EXPLICIT COMPILE-TIME BEHAVIOUR CONTRACTS
; ============================================================================

; FUTURE:
;
; REQUIRES is intentionally NOT a runtime interface.
;
; No vtable.
; No trait object.
; No dynamic dispatch.
;
; It only says:
;   "this generic code may only be instantiated for a type satisfying X".


TYPE MRAMData<BUS>: STRUCT
 | @BUS bus
 | Pin  chip_select
 |\_


IFACE MRAMOps<T | BUS>: [ @T me ] REQ [ SPIBus<BUS> ]
 + PRIVATE
 |  ABYSS select: []
 |  | (me.chip_select.low)[]
 |  \_
 |
 | ABYSS deselect: []
 |  | (me.chip_select.high)[]
 |  \_
 |
 | Result<U8 | I8> read_status: []
 |  | (me.select)[]
 |  |
 |  | (me.bus.transfer)[ 0x05 ]
 |  | U8 status = (me.bus.transfer)[ 0x00 ]
 |  |
 |  | (me.deselect)[]
 |  |
 |  | RET [ (Result<U8 | I8>.ok)[ status ] ]
 |  \_
 |
 | Result<I8 | I8> write_byte: [ U32 address | U8 value ]
 |  | (me.select)[]
 |  |
 |  | (me.bus.transfer)[ 0x02 ]
 |  | (me.bus.transfer)[ (address >> 16) AS U8 ]
 |  | (me.bus.transfer)[ (address >> 8)  AS U8 ]
 |  | (me.bus.transfer)[ address         AS U8 ]
 |  | (me.bus.transfer)[ value ]
 |  |
 |  | (me.deselect)[]
 |  |
 |  | RET [ (Result<I8 | I8>.ok)[ 0 ] ]
 |  \_
 |
 | Result<I8 | I8> write:
 | [
 |     U32 address |
 |     @U8 data    |
 |     USIZE size
 | ]
 |  | USIZE i = 0
 |  |
 |  | WHILE [ i < size ]
 |  |  | Result<I8 | I8> r = (me.write_byte)[ address + i | data{i} ]
 |  |  |
 |  |  | IF [ (r.is_err)[] ]
 |  |  |  | RET [ r ]
 |  |  |  \_
 |  |  |
 |  |  | i += 1
 |  |  \_
 |  |
 |  | RET [ (Result<I8 | I8>.ok)[ 0 ] ]
 |  \_
 | 
 | Result<I8 | I8> read:
 | [
 |     U32 address |
 |     @U8 data    |
 |     USIZE size
 | ]
 |  | (me.select)[]
 |  |
 |  | (me.bus.transfer)[ 0x03 ]
 |  | (me.bus.transfer)[ (address >> 16) AS U8 ]
 |  | (me.bus.transfer)[ (address >> 8)  AS U8 ]
 |  | (me.bus.transfer)[ address         AS U8 ]
 |  |
 |  | USIZE i = 0
 |  | WHILE [ i < size ]
 |  |  | data{i} = (me.bus.transfer)[ 0 ]
 |  |  | i += 1
 |  |  \_
 |  |
 |  | (me.deselect)[]
 |  |
 |  | RET [ (Result<I8 | I8>.ok)[ 0 ] ]
 |  \_
 \_


; Conceptually:
;
; CLASS MRAM<BUS>: MRAMData<BUS> IMPL [ MRAMOps<MRAMData<BUS> | BUS> ]
;
; Exact generic CLASS syntax can be decided later.


; ============================================================================
; 9. GENERIC RAW PERSISTENCE
; ============================================================================

CONST U32 CONFIG_MAGIC   = 0x504C554D
CONST U16 CONFIG_VERSION = 1


TYPE DeviceConfig: STRUCT
 + PACKED
 | U32 magic
 | U16 version
 | U8  brightness
 | I16 sensor_offset_x
 | I16 sensor_offset_y
 | U32 crc
 \_


; FUTURE:
STATIC_ASSERT [ OFFSET [ DeviceConfig.magic ] == 0 ]


; A deliberately dumb checksum for the showcase.
; The point is compile-time/runtime syntax reuse.

U32 checksum: [ @U8 data | USIZE size ]
 | U32 value = 0
 | USIZE i = 0
 |
 | WHILE [ i < size ]
 |  | value = (value << 5) ^ data{i} ^ (value >> 2)
 |  | i += 1
 |  \_
 |
 | RET [ value ]
 \_

;; =========== VERY EXPERIMENTAL ================

; This is the kind of generic binary persistence the language should make
; possible without serialization frameworks.
;
; Object layout is intentionally visible and controllable.

Result<I8 | I8> save_object<T | STORAGE>:
[
    @STORAGE storage |
    U32      address |
    @T       object
]

 + REQUIRES [
     ; FUTURE:
     ; RawStorage<STORAGE>
   ]

 | RET [
     (storage.write)[
         address             |
         object AS @U8       |
         SIZE [ T ]
     ]
   ]
\_


Result<I8 | I8> load_object<T | STORAGE>:
[
    @STORAGE storage |
    U32      address |
    @T       object
]

 + REQUIRES [
     ; FUTURE:
     ; RawStorage<STORAGE>
   ]

 | RET [
     (storage.read)[
         address             |
         object AS @U8       |
         SIZE [ T ]
     ]
   ]
\_

;; =========== VERY EXPERIMENTAL ================


; ============================================================================
; 10. COMPTIME TABLE GENERATION
; ============================================================================

; FUTURE:
; Ordinary PLUM logic executed by the compiler.
;
; Desired guarantee:
;   only CRC_TABLE exists in the final image;
;   the generator loop itself does not.

COMPTIME U32 crc32_entry: [ U32 value ]
 | U32 crc = value
 | U8 i = 0
 |
 | WHILE [ i < 8 ]
 |  | IF [ crc & 1 ]
 |  |  | crc = (crc >> 1) ^ 0xEDB88320
 |  | ELSE
 |  |  | crc >>= 1
 |  |  \_
 |  |
 |  | i += 1
 |  \_
 |
 | RET [ crc ]
 \_


; Possible future syntax.
;
; Important semantic requirement:
;   compile-time generation, ordinary readonly data in the binary.

CONST U32 CRC_TABLE{256}
 + SECTION ".rodata.crc"
 =
 COMPTIME [
     U32 table{256}
     U32 i = 0

     WHILE [ i < 256 ]
      | table{i} = (crc32_entry)[ i ]
      | i += 1
      \_

     RET [ table ]
 ]




; ============================================================================
; 13. EXPLICIT RESOURCE LIFETIME
; ============================================================================

; No automatic Drop required.
;
; Resource management stays visible.

TYPE DMA_BufferData: STRUCT
 | @U8 data
 | USIZE size
 \_


IFACE DMA_BufferOps: [ @DMA_BufferData me ]
 |
 | Result<I8 | I8> init: [ USIZE size ]
 |  | me.data = (dma_alloc)[ size ]
 |  |
 |  | IF [ me.data == NULL ]
 |  |  | RET [ (Result<I8 | I8>.err)[ #-1 ] ]
 |  |  \_
 |  |
 |  | me.size = size
 |  | RET [ (Result<I8 | I8>.ok)[ #0 ] ]
 |  \_
 |
 | ABYSS deinit: []
 |  | IF [ me.data == NULL ]
 |  |  | RET
 |  |  \_
 |  |
 |  | (dma_free)[ me.data ]
 |  | me.data = NULL
 |  | me.size = 0
 |  \_
 \_


CLASS DMA_Buffer: DMA_BufferData IMPL [ DMA_BufferOps ]


@U8 dma_alloc: [ USIZE size ]
ABYSS dma_free: [ @U8 ptr ]


; ============================================================================
; 14. BOARD LAYER
; ============================================================================

ABYSS clock_init: []
 | ; hardware-specific clock configuration
 \_


ABYSS board_init: []
 |
 | (clock_init)[]
 |
 | (LED.output)[]
 | (USER_BUTTON.input)[]
 |
 | (DEBUG_UART.init)[ CPU_HZ | 115200 ]
 |
 | (SYSTEM_TIMER.configure_periodic)[ 63 | 999 ]
 | (SYSTEM_TIMER.enable)[]
 |
 | (DEBUG_UART.write)[ "PLUM board init\n" ]
 \_


; ============================================================================
; 15. APPLICATION
; ============================================================================

; This represents the final style we want:
;
;   readable like modern C++ embedded code,
;   physically understandable like C.

I32 main: []
 |
 | (board_init)[]
 |
 | DeviceConfig config
 | config.magic           = CONFIG_MAGIC
 | config.version         = CONFIG_VERSION
 | config.brightness      = 100
 | config.sensor_offset_x = 0
 | config.sensor_offset_y = 0
 | config.crc             = 0
 |
 | config.brightness =
 |     (clamp)[ config.brightness AS I32 | 0 | 100 ] AS U8
 |
 | (DEBUG_UART.write)[ "firmware started\n" ]
 |
 | DMA_Buffer dma
 | Result<I8 | I8> dma_result = (dma.init)[ 256 ]
 |
 | IF [ (dma_result.is_err)[] ]
 |  | (DEBUG_UART.write)[ "DMA allocation failed\n" ]
 | ELSE
 |  | (memset)[ dma.data AS @ABYSS | 0 | dma.size ]
 |  \_
 |
 | U64 previous_tick = system_ticks
 | B1 led_state = FALSE
 |
 | LOOP
 |  |
 |  | ; 1 Hz task without a hidden scheduler.
 |  | IF [ system_ticks - previous_tick >= 1000 ]
 |  |  | previous_tick = system_ticks
 |  |  |
 |  |  | IF [ led_state ]
 |  |  |  | (LED.low)[]
 |  |  |  | led_state = FALSE
 |  |  | ELSE
 |  |  |  | (LED.high)[]
 |  |  |  | led_state = TRUE
 |  |  |  \_
 |  |  \_
 |  |
 |  | IF [ (USER_BUTTON.read)[] ]
 |  |  | (DEBUG_UART.write)[ "button\n" ]
 |  |  \_
 |  |
 |  \_
 |
 | ; Explicit cleanup is visible.
 | ; In normal firmware this line is never reached.
 | (dma.deinit)[]
 |
 | RET [ 0 ]
 \_


; ============================================================================
; 16. PROPOSED FEATURE CHECKLIST
; ============================================================================
;
; [ ] CONST
;
;     Goal:
;       compile-time-known immutable values / aggregates.
;
;     Must NOT imply:
;       constructors
;       hidden startup work
;
;
; [ ] INLINE / NOINLINE
;
;     Goal:
;       direct control over code generation.
;
;
; [ ] VOLATILE
;
;     Goal:
;       correct MMIO semantics.
;
;     LLVM:
;       volatile load/store.
;
;
; [ ] PACKED
;
;     Goal:
;       exact binary layout.
;
;
; [ ] ALIGN
;
;     Example:
;
;       TYPE DMA_Block: STRUCT ALIGN 32
;
;
; [ ] OFFSET [ Type.field ]
;
;     Goal:
;       compile-time layout inspection.
;
;
; [ ] STATIC_ASSERT [...]
;
;     Goal:
;       compile-time validation only.
;
;
; [ ] SECTION "..."
;
;     Goal:
;       linker section control.
;
;
; [ ] USED
;
;     Goal:
;       prevent dead-code/data elimination.
;
;
; [ ] WEAK
;
;     Goal:
;       weak C / ELF symbol.
;
;
; [ ] NORETURN
;
;     Goal:
;       ABI / optimizer metadata.
;
;
; [ ] INTERRUPT
;
;     Goal:
;       architecture-specific IRQ calling convention.
;
;
; [ ] COMPTIME
;
;     Goal:
;       run normal PLUM code at compile time.
;
;     Important:
;       no template language
;       no second metaprogramming syntax
;       no runtime artifact unless explicitly emitted as data/code
;
;
; [ ] REQUIRES [...]
;
;     Goal:
;       compile-time generic behaviour requirements.
;
;     Important:
;       no runtime interface
;       no vtable
;       no dyn
;
; [ ] namespace/import aliasing
;
;     Possible syntax:
;
;       !USES <stm32/gpio.pl> AS gpio
;
;       gpio::Pin
;       gpio::Mode
;
;
; ============================================================================
; 17. NON-GOALS
; ============================================================================
;
; Intentionally NOT required for this language direction:
;
;   - garbage collection
;   - automatic ownership / borrow checker
;   - automatic Drop
;   - hidden constructors/destructors
;   - runtime trait objects
;   - mandatory RTTI
;   - mandatory exceptions
;   - pattern matching
;   - algebraic/tagged enums as a core requirement
;   - C++-style template metaprogramming language
;
;
; The intended sweet spot:
;
;   C-like machine transparency
;             +
;   C++-like organization and abstraction
;             +
;   generic compile-time interfaces
;             +
;   explicit ABI / layout / MMIO control
;
; -----------------------------------------------------------------------------

