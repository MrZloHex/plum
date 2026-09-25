; trace.pl -- the PLUM counterpart of src/trace.c and inc/trace.h
;
; Two things in the C version cannot carry over:
;
;   * tracer_trace is variadic and hands its va_list to vsnprintf. PLUM can
;     *call* a variadic function but cannot *consume* varargs, so the level
;     here takes an already-formatted message and callers run snprintf
;     themselves. That is the whole of the difference.
;
;   * TRACE_DEBUG(...) is a macro that captures __FILENAME__, __func__ and
;     __LINE__. PLUM has no macros and no such builtins, so callers pass
;     the three explicitly.

!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>
!USES <../extern/time.pl>

TYPE Trace_Level: ENUM
 | TRC_DEBUG
 | TRC_INFO
 | TRC_WARN
 | TRC_ERROR
 | TRC_FATAL
 \_

TYPE Tracer: STRUCT
 | I32 base_level
 | I32 params
 \_

; inc/trace.h spells these 0b0001 .. 0b1111
I32 TP_FILE = 0b0001
I32 TP_FUNC = 0b0010
I32 TP_LINE = 0b0100
I32 TP_TIME = 0b1000
I32 TP_ALL  = 0b1111

I32 MAX_ENTRY_DSCR_LEN = 512

; The single global the C compiler has.
Tracer tracer

ABYSS tracer_init: [ I32 level | I32 params ]
 | tracer.base_level = level
 | tracer.params     = params
 | RET
 \_

ABYSS tracer_set_level: [ I32 level ]
 | tracer.base_level = level
 | RET
 \_

B1 trace_enabled: [ I32 flag ]
 | RET [ (tracer.params & flag) != 0 ]
 \_

@C1 trace_level_name: [ I32 level ]
 | IF [ level == TRC_DEBUG ]
 |  | RET [ "DEBUG" ]
 | ELIF [ level == TRC_INFO ]
 |  | RET [ "INFO" ]
 | ELIF [ level == TRC_WARN ]
 |  | RET [ "WARN" ]
 | ELIF [ level == TRC_ERROR ]
 |  | RET [ "ERROR" ]
 | ELSE
 |  | RET [ "FATAL" ]
 |  \_
 \_

@C1 trace_level_colour: [ I32 level ]
 | IF [ level == TRC_DEBUG ]
 |  | RET [ "\x1b[34m" ]
 | ELIF [ level == TRC_INFO ]
 |  | RET [ "\x1b[32m" ]
 | ELIF [ level == TRC_WARN ]
 |  | RET [ "\x1b[33m" ]
 | ELIF [ level == TRC_ERROR ]
 |  | RET [ "\x1b[31m" ]
 | ELSE
 |  | RET [ "\x1b[35m" ]
 |  \_
 \_

I32 trace_datetime: [ @C1 buf | U64 size ]
 | I64    t  = (time)[ 0 ]
 | @ABYSS tm = (localtime)[ @t AS @ABYSS ]
 | IF [ tm == 0 ]
 |  | ?(buf) = '\0'
 |  | RET [ 0 ]
 |  \_
 | RET [ (strftime)[ buf | size | "%Y-%m-%d %H:%M:%S" | tm ] AS I32 ]
 \_

; `msg` is already formatted; see the note at the top of this file.
ABYSS tracer_trace: [ I32 level | @C1 file | @C1 func | I32 line | @C1 msg ]
 | IF [ tracer.base_level > level ]
 |  | RET
 |  \_
 |
 | @C1 entry = (malloc)[ MAX_ENTRY_DSCR_LEN AS U64 ] AS @C1
 | IF [ entry == 0 ]
 |  | RET
 |  \_
 | ?(entry) = '\0'
 |
 | I32 pc = 0
 |
 | IF [ (trace_enabled)[ TP_TIME ] ]
 |  | @C1 dt = (malloc)[ 64 ] AS @C1
 |  | (trace_datetime)[ dt | 64 ]
 |  | pc += (snprintf)[ entry + pc | (MAX_ENTRY_DSCR_LEN - pc) AS U64 | "[%s]" | dt ]
 |  | (free)[ dt AS @ABYSS ]
 |  \_
 |
 | @C1 col = (trace_level_colour)[ level ]
 | @C1 nam = (trace_level_name)[ level ]
 | pc += (snprintf)[ entry + pc | (MAX_ENTRY_DSCR_LEN - pc) AS U64 | " %s%5s\x1b[0m " | col | nam ]
 |
 | IF [ (trace_enabled)[ TP_FILE ] ]
 |  | pc += (snprintf)[ entry + pc | (MAX_ENTRY_DSCR_LEN - pc) AS U64 | "%s:" | file ]
 |  \_
 | IF [ (trace_enabled)[ TP_FUNC ] ]
 |  | pc += (snprintf)[ entry + pc | (MAX_ENTRY_DSCR_LEN - pc) AS U64 | "%s:" | func ]
 |  \_
 | IF [ (trace_enabled)[ TP_LINE ] ]
 |  | pc += (snprintf)[ entry + pc | (MAX_ENTRY_DSCR_LEN - pc) AS U64 | "%d: " | line ]
 |  \_
 |
 | (snprintf)[ entry + pc | (MAX_ENTRY_DSCR_LEN - pc) AS U64 | "%s" | msg ]
 |
 | (puts)[ entry ]
 | (free)[ entry AS @ABYSS ]
 | RET
 \_
