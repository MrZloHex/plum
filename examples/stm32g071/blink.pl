!USES <startup.pl>

; The registers, as C would write them:
;   volatile uint32_t *const RCC_IOPENR = (volatile uint32_t *)0x40021034;
; CONST: the address never changes, so -O2 folds it into the code.
; VOLATILE: every read and write reaches the hardware, in order.

TYPE GPIORegs: STRUCT
 | U32 MODER      ; two bits of mode per pin
 | U32 OTYPER
 | U32 OSPEEDR
 | U32 PUPDR
 | U32 IDR
 | U32 ODR        ; output levels
 \_

CONST @VOLATILE U32      RCC_IOPENR = 0x40021034 AS @VOLATILE U32    ; bit 0: GPIOA's clock
CONST @VOLATILE GPIORegs GPIOA      = 0x50000000 AS @VOLATILE GPIORegs

; VOLATILE, or the optimiser sees a loop that does nothing and drops it
ABYSS delay: [ U32 n ]
 | VOLATILE U32 i = 0
 | WHILE [ i < n ]
 |  | i += 1
 |  \_
 \_

I32 main: []
 | ?RCC_IOPENR = ?RCC_IOPENR | 1
 |
 | ; PA5 resets to analog (11); output is 01
 | GPIOA.MODER = (GPIOA.MODER & ~(3 << 10)) | (1 << 10)
 |
 | LOOP
 |  | GPIOA.ODR = GPIOA.ODR ^ (1 << 5)
 |  | (delay)[ 400000 ]
 |  \_
 \_
