; CONST and VOLATILE, at every level they can be written

!USES <../../extern/stdio.pl>

TYPE Regs: STRUCT
 | U32 ctrl
 | U32 data
 \_

CONST I32 LIMIT = 10                 ; read-only memory
CONST @CONST C1 NAME = "plum"        ; a constant pointer to constant chars
U32 backing{2}                       ; stands in for a device's registers

; an interface written for a CONST `me`: callable on a CONST object
TYPE PinData: STRUCT
 | I32 pin
 \_

IFACE PinRead: [ @CONST PinData me ]
 | I32 number: []
 |  | RET [ me.pin ]
 |  \_
 \_

CLASS Pin: PinData IMPL [ PinRead ]

Pin pin_at: [ I32 n ]
 | Pin p
 | p.pin = n
 | RET [ p ]
 \_

I32 twice: [ @CONST I32 p ]          ; promises not to write through p
 | RET [ ?p * 2 ]
 \_

I32 main: []
 | ; C's `volatile Regs *const r`: the pointer fixed, the registers volatile
 | CONST @VOLATILE Regs r = backing AS @VOLATILE Regs
 | r.ctrl = 5
 | r.data = r.ctrl + 1
 | (printf)[ "%u %u\n" | backing{0} | backing{1} ]      ; 5 6
 |
 | VOLATILE U32 ticks = 0
 | ticks += 1
 | ticks += 1
 | (printf)[ "%u\n" | ticks ]                            ; 2
 |
 | @CONST I32 lp = @LIMIT                                ; @ of a CONST is @CONST
 | (printf)[ "%d %d\n" | ?lp | (twice)[ lp ] ]           ; 10 20
 |
 | I32 n = 21
 | (printf)[ "%d\n" | (twice)[ @n ] ]                    ; 42: adding CONST is fine
 |
 | @I32 w = lp AS @I32                                   ; AS says dropping it is meant
 | (printf)[ "%d %s\n" | ?w | NAME ]                     ; 10 plum
 |
 | CONST Pin led = (pin_at)[ 5 ]
 | (printf)[ "%d\n" | (led.number)[] ]                   ; 5
 | RET [ 0 ]
 \_
