; a required method given, but with another signature
TYPE D:
 | I32 n
 \_
IFACE Needs: [ @D me ]
 | U8 transfer: [ U8 v ]
 \_
IFACE Gives: [ @D me ]
 | I32 transfer: [ U8 v ]
 |  | RET [ 0 ]
 |  \_
 \_
CLASS C: D IMPL [ Needs | Gives ]
I32 main: []
 | RET [ 0 ]
 \_
