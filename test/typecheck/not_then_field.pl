TYPE P: STRUCT
 | B1 vaarg
 \_
I32 main: [ @P p ]
 | IF [ !p.vaarg ]
 |  | RET [ 1 ]
 |  \_
 | RET [ 0 ]
 \_
