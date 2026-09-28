; diag.pl -- diagnostics, the way every stage reports a problem
;
;   error: cannot dereference @ABYSS; cast it to a typed pointer first
;    --> deref.pl:5:12
;     |
;   5 |  | I32 x = ?p
;     |            ^
;
; Locations are in the files the user wrote: the preprocessor marks where
; each included file begins and ends, and the lexer follows those marks.
; Everything goes to stderr, in colour only when that is a terminal --
; except under --emit=INDEX, where each diagnostic is one line on stdout
; for the language server:  E <tab> file <tab> line <tab> col <tab> message

!USES <token.pl>
!USES <../lib/string.pl>
!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>
!USES <../extern/unistd.pl>

I32 diag_count
B1  diag_machine     ; one tab-separated line per diagnostic, on stdout

; the last file an excerpt came from, kept for the next error
@C1    diag_file
String diag_text
B1     diag_loaded

B1 diag_color: []
 | RET [ (isatty)[ 2 ] != 0 ]
 \_

; Line `line` of `file`, or 0 when it cannot be read. Owned by the cache.
@C1 diag_line_of: [ @C1 file | I32 line ]
 | IF [ file == NULL || line < 1 ]
 |  | RET [ NULL ]
 |  \_
 |
 | IF [ !diag_loaded || (strcmp)[ diag_file | file ] != 0 ]
 |  | IF [ diag_loaded ]
 |  |  | (diag_text.deinit)[]
 |  |  | diag_loaded = FALSE
 |  |  \_
 |  | @ABYSS f = (fopen)[ file | "r" ]
 |  | IF [ f == NULL ]
 |  |  | RET [ NULL ]
 |  |  \_
 |  | (diag_text.init_file)[ f ]
 |  | (fclose)[ f ]
 |  | diag_file = (strdup)[ file ]
 |  | diag_loaded = TRUE
 |  \_
 |
 | ; find the line, and cut a copy of it at its end
 | U64 i = 0
 | I32 n = 1
 | WHILE [ n < line && i < diag_text.size ]
 |  | IF [ diag_text.data{i} == '\n' ]
 |  |  | n += 1
 |  |  \_
 |  | i += 1
 |  \_
 | IF [ n != line || i >= diag_text.size ]
 |  | RET [ NULL ]
 |  \_
 | U64 end = i
 | WHILE [ end < diag_text.size && diag_text.data{end} != '\n' && diag_text.data{end} != '\r' ]
 |  | end += 1
 |  \_
 | RET [ (diag_text.substr)[ i | end - i ] ]
 \_

I32 diag_digits: [ I32 n ]
 | I32 d = 1
 | WHILE [ n >= 10 ]
 |  | n = n / 10
 |  | d += 1
 |  \_
 | RET [ d ]
 \_

; The header alone, for problems that have no place in the source.
ABYSS diag_plain: [ @C1 msg ]
 | diag_count += 1
 | IF [ diag_machine ]
 |  | (dprintf)[ 1 | "E\t\t0\t0\t%s\n" | msg ]
 |  | RET
 |  \_
 | IF [ (diag_color)[] ]
 |  | (dprintf)[ 2 | "\x1b[1;31merror\x1b[0m\x1b[1m: %s\x1b[0m\n" | msg ]
 | ELSE
 |  | (dprintf)[ 2 | "error: %s\n" | msg ]
 |  \_
 \_

ABYSS diag_at: [ Location loc | @C1 msg ]
 | IF [ diag_machine && loc.file != NULL ]
 |  | diag_count += 1
 |  | (dprintf)[ 1 | "E\t%s\t%d\t%d\t%s\n" | loc.file | loc.line | loc.col | msg ]
 |  | RET
 |  \_
 | (diag_plain)[ msg ]
 | IF [ loc.file == NULL ]
 |  | RET
 |  \_
 |
 | I32 w = (diag_digits)[ loc.line ]
 | (dprintf)[ 2 | "%*s--> %s:%d:%d\n" | w | "" | loc.file | loc.line | loc.col ]
 |
 | @C1 text = (diag_line_of)[ loc.file | loc.line ]
 | IF [ text == NULL ]
 |  | RET
 |  \_
 | I32 caret = loc.col - 1
 | IF [ caret < 0 ]
 |  | caret = 0
 |  \_
 | (dprintf)[ 2 | "%*s |\n" | w | "" ]
 | (dprintf)[ 2 | "%d | %s\n" | loc.line | text ]
 | IF [ (diag_color)[] ]
 |  | (dprintf)[ 2 | "%*s | %*s\x1b[1;31m^\x1b[0m\n" | w | "" | caret | "" ]
 | ELSE
 |  | (dprintf)[ 2 | "%*s | %*s^\n" | w | "" | caret | "" ]
 |  \_
 | (free)[ text AS @ABYSS ]
 \_

; The same, with up to two strings put into a printf-style message.
ABYSS diag_at2: [ Location loc | @C1 fmt | @C1 a | @C1 b ]
 | @C1 buf = (malloc)[ 512 ] AS @C1
 | (snprintf)[ buf | 512 | fmt | a | b ]
 | (diag_at)[ loc | buf ]
 | (free)[ buf AS @ABYSS ]
 \_

; A problem the compiler cannot go on from: report it and stop.
ABYSS diag_fatal: [ Location loc | @C1 fmt | @C1 a | @C1 b ]
 | (diag_at2)[ loc | fmt | a | b ]
 | (exit)[ 1 ]
 \_

; After a stage that keeps going past errors: how many there were.
ABYSS diag_summary: []
 | IF [ diag_machine ]
 |  | RET
 |  \_
 | IF [ diag_count == 1 ]
 |  | (dprintf)[ 2 | "1 error\n" ]
 | ELIF [ diag_count > 1 ]
 |  | (dprintf)[ 2 | "%d errors\n" | diag_count ]
 |  \_
 \_

; A compiler bug, not the program's fault.
ABYSS diag_internal: [ @C1 fmt | @C1 a ]
 | IF [ diag_machine ]
 |  | (dprintf)[ 1 | "E\t\t0\t0\tinternal compiler error: " ]
 |  | (dprintf)[ 1 | fmt | a ]
 |  | (dprintf)[ 1 | "\n" ]
 |  | (exit)[ 2 ]
 |  \_
 | (dprintf)[ 2 | "internal compiler error: " ]
 | (dprintf)[ 2 | fmt | a ]
 | (dprintf)[ 2 | "\n" ]
 | (exit)[ 2 ]
 \_
