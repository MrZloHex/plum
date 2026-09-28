; sensor.pl -- a temperature sensor, and the hardware behind it
;
; On a board SensorRegs would sit at a fixed address. Here the registers
; are ordinary memory, so the program runs anywhere, and hardware_produce
; plays the chip's part. The driver cannot tell the difference: either
; way it goes through a VOLATILE pointer, so every poll really reads.

!USES <../../extern/stdio.pl>
!USES <../option.pl>

TYPE SensorRegs: STRUCT
 | U32 CTRL          ; bit 0: enabled
 | U32 STATUS        ; bit 0: a sample waits in DATA
 | U32 DATA          ; the sample, in hundredths of a degree
 \_

CONST U32 SENSOR_ON    = 1
CONST U32 SAMPLE_READY = 1

TYPE Celsius: F32

SensorRegs sensor_silicon

@VOLATILE SensorRegs sensor_regs: []
 | RET [ @sensor_silicon AS @VOLATILE SensorRegs ]
 \_

; The chip's side: sample i appears, and the ready bit says so. Readings
; climb from 21.50 to 22.50 and fall back. A chip switched off does nothing.
ABYSS hardware_produce: [ I32 i ]
 | @VOLATILE SensorRegs r = (sensor_regs)[]
 | IF [ (r.CTRL & SENSOR_ON) == 0 ]
 |  | RET
 |  \_
 | I32 step = i
 | IF [ i > 4 ]
 |  | step = 7 - i
 |  \_
 | r.DATA = (2150 + 25 * step) AS U32
 | r.STATUS = r.STATUS | SAMPLE_READY
 \_

TYPE SensorData: STRUCT
 | @VOLATILE SensorRegs regs
 \_

; Using the sensor changes the chip, never the driver itself: so this
; interface takes a CONST `me`, and a CONST SensorDriver can call it.
IFACE SensorOps: [ @CONST SensorData me ]
 | ABYSS enable: []
 |  | me.regs.CTRL = me.regs.CTRL | SENSOR_ON
 |  \_
 |
 | B1 ready: []
 |  | RET [ (me.regs.STATUS & SAMPLE_READY) != 0 ]
 |  \_
 |
 | ; the next sample, polling at most `tries` times; nothing if none came
 | Option<Celsius> take: [ I32 tries ]
 |  | LOOP
 |  |  | IF [ (me.ready)[] ]
 |  |  |  | BREAK
 |  |  |  \_
 |  |  | tries -= 1
 |  |  | IF [ tries <= 0 ]
 |  |  |  | RET [ (Option<Celsius>.none)[] ]
 |  |  |  \_
 |  |  \_
 |  | U32 centi = me.regs.DATA
 |  | me.regs.STATUS = me.regs.STATUS & ~SAMPLE_READY
 |  | RET [ (Option<Celsius>.some)[ (centi AS F32) / 100.0 ] ]
 |  \_
 |
 + ANONYMOUS:
 | SensorDriver on: [ @VOLATILE SensorRegs regs ]
 |  | SensorDriver d
 |  | d.regs = regs
 |  | RET [ d ]
 |  \_
 \_

CLASS SensorDriver: SensorData IMPL [ SensorOps ]
