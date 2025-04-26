; TEST OF ARYPHMETIC AND LOGIC OPERATIONS 

I32 main: []
 | @C1 str = "Hello from PLUM!"
 | (puts)[ str ]
 |
 | I32 a = 5
 | I32 b = 2
 | I32 plus = a + b
 | I32 minus = a - b
 | I32 multiply = a * b
 | I32 division = a / b
 |
 | IF [ a == b ]
 |  | (puts)[ "a & b are equal" ]
 |  \_
 | IF [ a != b ]
 |  | (puts)["a & b are NOT equal"]
 |  \_
 | IF [ a < b ]
 |  | (puts)["a is less then b"]
 |  \_
 | IF [ a <= b ]
 |  | (puts)["a <= b"]
 |  \_
 | IF [ a > b ]
 |  | (puts)["a > b"]
 |  \_
 | IF [ a >= b ]
 |  | (puts)["a >= b"]
 |  \_
 | RET [ multiply ]
 \_


I32 puts:    [ @C1 str ]

