; startup.pl -- what runs before main on the STM32G071, in PLUM
;
; The vector table is one global per entry. clang -fdata-sections puts
; each in a section of its own, .data.vector_NN_name, and g071.ld gathers
; them, sorted by name, at the start of flash. The zero-padded numbers are
; what keeps them in order.
;
; A handler the program does not define is Default_Handler: g071.ld
; PROVIDEs every name, which is what C's weak symbols would do. So a
; program takes over an interrupt just by defining it:
;     ABYSS SysTick_Handler: []

; Where the linker script put things. PLUM has no extern variables, but a
; function's name is its address, which is all these are wanted for.
ABYSS _sidata: []
ABYSS _sdata: []
ABYSS _edata: []
ABYSS _sbss: []
ABYSS _ebss: []

I32 main: []

ABYSS NMI_Handler: []
ABYSS HardFault_Handler: []
ABYSS SVC_Handler: []
ABYSS PendSV_Handler: []
ABYSS SysTick_Handler: []

ABYSS Default_Handler: []
 | LOOP
 |  \_
 \_

; Copy the initial values of globals from flash, clear the rest, run main.
ABYSS Reset_Handler: []
 | @U32 src = _sidata AS @U32
 | @U32 dst = _sdata AS @U32
 | WHILE [ dst < _edata AS @U32 ]
 |  | ?dst = ?src
 |  | dst = dst + 1
 |  | src = src + 1
 |  \_
 |
 | dst = _sbss AS @U32
 | WHILE [ dst < _ebss AS @U32 ]
 |  | ?dst = 0
 |  | dst = dst + 1
 |  \_
 |
 | (main)[]
 | LOOP
 |  \_
 \_

; The Cortex-M0+ system exceptions; the G071's 32 interrupts are not wired
; to anything yet. A reserved entry is never used, so it may hold anything
; but zero -- a zero would put it in .bss instead of the table.
U32         vector_00_sp       = 0x20009000     ; the top of the 36 KB of RAM
FN ABYSS [] vector_01_reset    = Reset_Handler
FN ABYSS [] vector_02_nmi      = NMI_Handler
FN ABYSS [] vector_03_hardfault = HardFault_Handler
FN ABYSS [] vector_04_reserved = Default_Handler
FN ABYSS [] vector_05_reserved = Default_Handler
FN ABYSS [] vector_06_reserved = Default_Handler
FN ABYSS [] vector_07_reserved = Default_Handler
FN ABYSS [] vector_08_reserved = Default_Handler
FN ABYSS [] vector_09_reserved = Default_Handler
FN ABYSS [] vector_10_reserved = Default_Handler
FN ABYSS [] vector_11_svc      = SVC_Handler
FN ABYSS [] vector_12_reserved = Default_Handler
FN ABYSS [] vector_13_reserved = Default_Handler
FN ABYSS [] vector_14_pendsv   = PendSV_Handler
FN ABYSS [] vector_15_systick  = SysTick_Handler
