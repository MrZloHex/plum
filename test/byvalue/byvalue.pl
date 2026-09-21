; Patterns the real compiler leans on:
;   lexer_next returns Token BY VALUE
;   symtab_insert takes N_Type BY VALUE
;   meta.c takes the address of a struct field

I32 printf: [ @C1 fmt | ... ]

TYPE Loc: STRUCT
 | I32 line
 | I32 col
 \_

TYPE Token: STRUCT
 | I32 kind
 | @C1 lexeme
 | Loc loc
 \_

; returns a struct by value, like make_tok / lexer_next
Token make_tok: [ I32 k | @C1 lex | I32 line | I32 col ]
 | Token t
 | t.kind     = k
 | t.lexeme   = lex
 | t.loc.line = line
 | t.loc.col  = col
 | RET [ t ]
 \_

; takes a struct by value, like symtab_insert(..., N_Type type, ...)
ABYSS show: [ Token t ]
 | (printf)[ "  kind=%d lex=%s at %d:%d\n" | t.kind | t.lexeme | t.loc.line | t.loc.col ]
 | RET
 \_

; takes a pointer and mutates through it, like most of the compiler
ABYSS bump_line: [ @Token t ]
 | t.loc.line = t.loc.line + 100
 | RET
 \_

I32 main: []
 | Token a = (make_tok)[ 7 | "ident" | 3 | 14 ]
 | (show)[ a ]
 |
 | ; struct assignment (copy)
 | Token b = a
 | b.kind = 9
 | (printf)[ "copy independent: a.kind=%d b.kind=%d\n" | a.kind | b.kind ]
 |
 | ; address of a local struct, mutate through the pointer
 | @Token pa = @a
 | (bump_line)[ pa ]
 | (printf)[ "after bump: line=%d\n" | a.loc.line ]
 |
 | ; address of a nested field
 | @Loc pl = @(a.loc)
 | pl.col = 99
 | (printf)[ "field addr: col=%d\n" | a.loc.col ]
 | RET [ 0 ]
 \_
