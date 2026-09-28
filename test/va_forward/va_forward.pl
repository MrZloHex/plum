; va_forward.pl -- passing `...` on to C's v-functions, as one va_list
I32 printf: [ @C1 fmt | ... ]
I32 vprintf: [ @C1 fmt | @ABYSS ap ]
I32 vsnprintf: [ @C1 buf | USIZE n | @C1 fmt | @ABYSS ap ]

; a diagnostic with any arguments: no more two-argument wrappers
ABYSS report: [ I32 line | @C1 fmt | ... ]
 | (printf)[ "line %d: " | line ]
 | (vprintf)[ fmt | ... ]
 | (printf)[ "\n" ]
 \_

@C1 fmt_into: [ @C1 buf | @C1 fmt | ... ]
 | (vsnprintf)[ buf | 64 | fmt | ... ]
 | RET [ buf ]
 \_

I32 main: []
 | (report)[ 3 | "expected %s, found %s (%d of %d)" | "`]`" | "`|`" | 1 | 2 ]
 | (report)[ 9 | "no arguments at all" ]
 | C1 b{64}
 | (printf)[ "%s|\n" | (fmt_into)[ b | "%05.1f %c %s" | 3.14159 | 'z' | "ok" ] ]
 | RET [ 0 ]
 \_
