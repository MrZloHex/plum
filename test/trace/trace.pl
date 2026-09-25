; Exercises plum/trace.pl against what src/trace.c does.

!USES <../../src/trace.pl>

I32 main: []
 | ; TP_FUNC | TP_LINE -- the combination src/main.c uses
 | (tracer_init)[ TRC_DEBUG | (TP_FUNC | TP_LINE) ]
 |
 | @C1 msg = (malloc)[ 256 ] AS @C1
 |
 | (snprintf)[ msg | 256 | "plain message" ]
 | (tracer_trace)[ TRC_DEBUG | "trace.pl" | "main" | 11 | msg ]
 |
 | (snprintf)[ msg | 256 | "TOKEN: %s at %d:%d" | "IDENT" | 3 | 14 ]
 | (tracer_trace)[ TRC_INFO | "lexer.pl" | "lex_next" | 42 | msg ]
 |
 | (snprintf)[ msg | 256 | "unexpected %s" | "RBRACKET" ]
 | (tracer_trace)[ TRC_ERROR | "parser.pl" | "expect" | 99 | msg ]
 |
 | (tracer_trace)[ TRC_FATAL | "codegen.pl" | "gen" | 7 | "it died" ]
 |
 | ; level filtering: raise the floor and DEBUG must vanish
 | (puts)[ "-- raising level to WARN --" ]
 | (tracer_set_level)[ TRC_WARN ]
 | (tracer_trace)[ TRC_DEBUG | "x.pl" | "f" | 1 | "should NOT appear" ]
 | (tracer_trace)[ TRC_INFO  | "x.pl" | "f" | 2 | "should NOT appear" ]
 | (tracer_trace)[ TRC_WARN  | "x.pl" | "f" | 3 | "warn appears" ]
 |
 | ; params control which fields are printed
 | (puts)[ "-- TP_ALL (adds file and time) --" ]
 | (tracer_init)[ TRC_DEBUG | TP_ALL ]
 | (tracer_trace)[ TRC_DEBUG | "meta.pl" | "collect" | 55 | "everything on" ]
 |
 | (puts)[ "-- no params --" ]
 | (tracer_init)[ TRC_DEBUG | 0 ]
 | (tracer_trace)[ TRC_DEBUG | "meta.pl" | "collect" | 55 | "bare" ]
 |
 | (free)[ msg AS @ABYSS ]
 | RET [ 0 ]
 \_
