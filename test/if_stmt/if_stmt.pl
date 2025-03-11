; TEST OF CALLING EXTERNAL FUNCTION FROM C

I32 main: []
 | @C1 str
 | str = "Hello from PLUM!"
 |
 | @C1 hello
 | B1 why
 | B1 why_not
 | why = TRUE
 | why_not = TRUE
 | 
 | IF [ why ]
 |  | hello = "if working"
 |  | (puts)[ hello ]
;|  | IF [ why_not ]
;|  |  | hello = "inner if"
;|  |  | (println)[ hello ]
;|  |  \
;|  | ELSE
;|  |  | hello = "inner else"
;|  |  | (println)[ hello ]
;|  |  \_
;|  \
;| ELSE
;|  | hello = "else working"
;|  | (puts)[ hello ]
;|  | IF [ why_not ]
;|  |  | hello = "inner if"
;|  |  | (println)[ hello ]
;|  |  \
;|  | ELSE
;|  |  | hello = "inner else"
;|  |  | (println)[ hello ]
;|  |  \_
 |  \_
 | (puts)[ str ]
 | RET [ 0 ]
 \_


I32 puts:    [ @C1 str ]

