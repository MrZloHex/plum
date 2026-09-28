; main.pl -- a temperature logger: sample, summarise, save to flash, load, check
;
; A small program that uses every part of PLUM; the modules say which.
;
;   make           build it with plc --emit=OBJ -O2
;   make check     run it, and compare with expected.out
;   make arm       compile it for a Cortex-M0+ too: the same layouts hold

!USES <sensor.pl>
!USES <bus.pl>
!USES <flash.pl>
!USES <record.pl>
!USES <stats.pl>
!USES <../../lib/string.pl>
!USES <../../extern/string.pl>

CONST I32   SAMPLES   = 8
CONST USIZE RECORD_AT = 16

TYPE App: STRUCT
 | Vector<Celsius>  samples
 | FlashChip        chip
 | Flash<FlashChip> flash
 \_

; --- commands, found by name, called through a pointer -------------------------

TYPE CommandFn: FN ABYSS [ @App ]

TYPE Command: STRUCT
 | @C1       name
 | CommandFn run
 \_

ABYSS cmd_stats: [ @App app ]
 | Option<Range<Celsius>> r = (range_of)[ @(app.samples) ]
 | IF [ (r.is_none)[] ]
 |  | (puts)[ "no samples" ]
 |  | RET
 |  \_
 | Range<Celsius> span = (r.unwrap)[]
 | (printf)[ "%lu samples, mean %.2f, from %.2f to %.2f\n" | (app.samples.size)[] | (mean_of)[ @(app.samples) ] | span.lo | span.hi ]
 \_

ABYSS cmd_save: [ @App app ]
 | RecordBytes rb = (make_record)[ (app.samples.size)[] AS U8 | (mean_of)[ @(app.samples) ] ]
 | Result<USIZE | @C1> w = (app.flash.write)[ RECORD_AT | rb.raw | SIZE [ Record ] ]
 | IF [ (w.is_ok)[] ]
 |  | (printf)[ "saved %lu bytes at %lu, checksum %x\n" | w.as.value | RECORD_AT | rb.rec.checksum ]
 |  \_
 |
 | ; and where it cannot go: Result says why
 | w = (app.flash.write)[ 250 | rb.raw | SIZE [ Record ] ]
 | IF [ (w.is_err)[] ]
 |  | (printf)[ "cannot save at 250: %s\n" | w.as.error ]
 |  \_
 \_

ABYSS cmd_load: [ @App app ]
 | RecordBytes rb
 | Result<USIZE | @C1> r = (app.flash.read)[ RECORD_AT | rb.raw | SIZE [ Record ] ]
 | IF [ (r.is_err)[] ]
 |  | (printf)[ "cannot load: %s\n" | r.as.error ]
 |  | RET
 |  \_
 | @C1 verdict = "checksum ok"
 | IF [ !(record_ok)[ @rb ] ]
 |  | verdict = "checksum BAD"
 |  \_
 | I32 m = rb.rec.mean_centi
 | (printf)[ "loaded: %u samples, mean %d.%02d, %s\n" | rb.rec.count AS U32 | m / 100 | m % 100 | verdict ]
 \_

ABYSS cmd_report: [ @App app ]
 | ; built up in a String, then printed once
 | String line
 | (line.init)[ 64 ]
 | C1 num{32}
 | (line.append)[ "report: record " ]
 | (snprintf)[ num | 32 | "%lu bytes, checksum at %lu" | SIZE [ Record ] | OFFSET [ Record.checksum ] ]
 | (line.append)[ num ]
 | (line.append)[ ", flash lines " ]
 | IF [ ((@(app.chip.cells) AS U64) % 32) == 0 ]
 |  | (line.append)[ "32-aligned" ]
 | ELSE
 |  | (line.append)[ "MISALIGNED" ]
 |  \_
 | (snprintf)[ num | 32 | ", chip moved %d bytes" | app.chip.moved ]
 | (line.append)[ num ]
 | (line.push)[ '\n' ]
 | (printf)[ "%s" | line.data ]
 | (line.deinit)[]
 \_

; where `name` is in the table -- or nothing, which is no error
Option<I32> find_command: [ @Command table | I32 count | @C1 name ]
 | I32 i = 0
 | WHILE [ i < count ]
 |  | IF [ (strcmp)[ table{i}.name | name ] == 0 ]
 |  |  | RET [ (Option<I32>.some)[ i ] ]
 |  |  \_
 |  | i += 1
 |  \_
 | RET [ (Option<I32>.none)[] ]
 \_

; --- the program ---------------------------------------------------------------


TYPE FooType: STRUCT
 | I32 x
 \_

IFACE FooFace: [ @FooType me ]
 + PUBLIC:
 | ABYSS bar: []
 |  | (printf)[ "Foo: %d\n" | me.x ]
 |  \_
 + ANONYMOUS:
 | ABYSS baz: []
 |  | (printf)[ "No me anon\n" ]
 |  \_
 \_

CLASS Foo: FooType IMPL [ FooFace ]

I32 main: []
;| Foo f
;| f.x = 32
;| FN ABYSS [] fn = f.bar
;| FN ABYSS [] fn = Foo.baz
;| (fn)[]
 | ; the driver never changes, only the chip does: it can be CONST
 | CONST SensorDriver sensor = (SensorDriver.on)[ (sensor_regs)[] ]
 |
 | ; before it is switched on, no sample comes
 | (hardware_produce)[ 0 ]
 | Option<Celsius> first = (sensor.take)[ 3 ]
 | IF [ (first.is_none)[] ]
 |  | (puts)[ "sensor off: no sample" ]
 |  \_
 | (sensor.enable)[]
 |
 | App app
 | (app.samples.init)[ 8 ]
 | app.chip.moved = 0
 | app.chip.selected = FALSE
 | app.flash = (Flash<FlashChip>.on)[ @(app.chip) | SIZE [ Cells ] ]
 |
 | I32 i = 0
 | WHILE [ i < SAMPLES ]
 |  | (hardware_produce)[ i ]
 |  | (app.samples.push)[ ((sensor.take)[ 100 ].expect)[ "the sensor went quiet" ] ]
 |  | i += 1
 |  \_
 |
 | ; one probe, two buses: only the loopback echoes
 | LoopbackBus loop
 | Probe<LoopbackBus> on_loop = (Probe<LoopbackBus>.on)[ @loop ]
 | Probe<FlashChip> on_chip = (Probe<FlashChip>.on)[ @(app.chip) ]
 | (printf)[ "loopback echoes: %d, flash chip echoes: %d\n" | (on_loop.echoes)[] | (on_chip.echoes)[] ]
 |
 | Command table{4}
 | table{0}.name = "stats"
 | table{0}.run = cmd_stats
 | table{1}.name = "save"
 | table{1}.run = cmd_save
 | table{2}.name = "load"
 | table{2}.run = cmd_load
 | table{3}.name = "report"
 | table{3}.run = cmd_report
 |
 | @C1 script{5}
 | script{0} = "stats"
 | script{1} = "save"
 | script{2} = "load"
 | script{3} = "reboot"
 | script{4} = "report"
 | i = 0
 | WHILE [ i < 5 ]
 |  | Option<I32> at = (find_command)[ table | 4 | script{i} ]
 |  | i += 1
 |  | IF [ (at.is_none)[] ]
 |  |  | (printf)[ "unknown command `%s`\n" | script{i - 1} ]
 |  |  | CONTINUE
 |  |  \_
 |  | (table{(at.unwrap)[]}.run)[ @app ]
 |  \_
 |
 | (app.samples.deinit)[]
 | RET [ 0 ]
 \_
