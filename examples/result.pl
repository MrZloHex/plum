; result.pl -- Result<T | E>: a T, or an error E saying why not
;
;   Result<I64 | @C1> parse_int: [ @C1 s ]
;    | RET [ (Result<I64 | @C1>.err)[ "not a digit" ] ]     ; or .ok, with a value
;
;   Result<I64 | @C1> n = (parse_int)[ text ]
;   IF [ (n.is_ok)[] ]  ... n.as.value ...  ELSE  ... n.as.error ...
;
; The value and the error share memory, a union, as only one of them is
; ever there: Result<F64 | @C1> is 16 bytes, not 24. As with Option,
; nothing stops reading the wrong one; unwrap and expect check.
;
; There is no `?` either. Passing an error up is written out:
;
;   IF [ (x.is_err)[] ]
;    | RET [ x ]                      ; when the types are the same
;    \_

!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>

TYPE ResultValue<T | E>: UNION
 | T value
 | E error
 \_

TYPE ResultData<T | E>: STRUCT
 | B1                  good
 | ResultValue<T | E>  as
 \_

IFACE ResultOps<T | E>: [ @ResultData<T | E> me ]
 | B1 is_ok: []
 |  | RET [ me.good ]
 |  \_
 |
 | B1 is_err: []
 |  | RET [ !(me.good) ]
 |  \_
 |
 | ; the value; an error ends the program
 | T unwrap: []
 |  | RET [ (me.expect)[ "unwrap on an error" ] ]
 |  \_
 |
 | T expect: [ @C1 why ]
 |  | IF [ !(me.good) ]
 |  |  | (dprintf)[ 2 | "panic: %s\n" | why ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  | RET [ me.as.value ]
 |  \_
 |
 | T unwrap_or: [ T dflt ]
 |  | IF [ me.good ]
 |  |  | RET [ me.as.value ]
 |  |  \_
 |  | RET [ dflt ]
 |  \_
 |
 + ANONYMOUS:
 | Result<T | E> ok: [ T v ]
 |  | Result<T | E> r
 |  | r.good = TRUE
 |  | r.as.value = v
 |  | RET [ r ]
 |  \_
 |
 | Result<T | E> err: [ E e ]
 |  | Result<T | E> r
 |  | r.good = FALSE
 |  | r.as.error = e
 |  | RET [ r ]
 |  \_
 \_

CLASS Result<T | E>: ResultData<T | E> IMPL [ ResultOps<T | E> ]
