; option.pl -- Option<T>: a T, or nothing
;
; What a function returns when "not found" is an answer, not an error:
;
;   Option<I32> index_of: [ ... ]
;    | RET [ (Option<I32>.some)[ i ] ]      ; or (Option<I32>.none)[]
;
;   I32 i = (((index_of)[ ... ]).unwrap_or)[ -1 ]
;
; some and none are ANONYMOUS: they make an Option rather than change one,
; so they are called on the type. Nothing stops reading .value without
; asking first; unwrap and expect are the checked way, and they stop the
; program on an empty Option.

!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>

TYPE OptionData<T>: STRUCT
 | B1 has
 | T  value
 \_

IFACE OptionOps<T>: [ @OptionData<T> me ]
 | B1 is_some: []
 |  | RET [ me.has ]
 |  \_
 |
 | B1 is_none: []
 |  | RET [ !(me.has) ]
 |  \_
 |
 | ; the value; an empty Option ends the program
 | T unwrap: []
 |  | RET [ (me.expect)[ "unwrap on an empty Option" ] ]
 |  \_
 |
 | ; the same, saying why it should not have been empty
 | T expect: [ @C1 why ]
 |  | IF [ !(me.has) ]
 |  |  | (dprintf)[ 2 | "panic: %s\n" | why ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  | RET [ me.value ]
 |  \_
 |
 | T unwrap_or: [ T dflt ]
 |  | IF [ me.has ]
 |  |  | RET [ me.value ]
 |  |  \_
 |  | RET [ dflt ]
 |  \_
 |
 + ANONYMOUS:
 | Option<T> some: [ T v ]
 |  | Option<T> r
 |  | r.has = TRUE
 |  | r.value = v
 |  | RET [ r ]
 |  \_
 |
 | Option<T> none: []
 |  | Option<T> r
 |  | r.has = FALSE
 |  | RET [ r ]
 |  \_
 \_

CLASS Option<T>: OptionData<T> IMPL [ OptionOps<T> ]
