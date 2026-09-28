!USES <startup.pl>

U32 RCC_IOPENR  = 0x40021034     ; I/O port clocks, bit 0 = GPIOA
U32 GPIOA_MODER = 0x50000000     ; two bits of mode per pin
U32 GPIOA_ODR   = 0x50000014     ; output levels

ABYSS delay: [ U32 n ]
 | U32 i = 0
 | WHILE [ i < n ]
 |  | i += 1
 |  \_
 \_

I32 main: []
 | @U32 iopenr = RCC_IOPENR AS @U32
 | @U32 moder = GPIOA_MODER AS @U32
 | @U32 odr = GPIOA_ODR AS @U32
 |
 | ?iopenr = ?iopenr | 1
 |
 | ?moder = (?moder & ~(3 << 10)) | (1 << 10)
 |
 | LOOP
 |  | ?odr = ?odr ^ (1 << 5)
 |  | (delay)[ 200000 ]
 |  \_
 \_
