; a required method no interface of the class gives -- and the function
; after the interface is not taken for its body
TYPE D:
 | I32 n
 \_
IFACE F: [ @D me ]
 | I32 g: []
 \_
CLASS C: D IMPL [ F ]
I32 main: []
 | RET [ 0 ]
 \_
