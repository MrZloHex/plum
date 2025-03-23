; TEST OF ARYPHMETIC AND LOGIC OPERATIONS 

I32 main: []
 | @C1 str = "Hello from PLUM!"
 | (puts)[ str ]
 |
 | I32 a = 2
 | I32 b = 5
 | I32 plus = a + b
 | I32 minus = a - b
 | I32 multiply = a * b
 | I32 division = a / b
 |
 | B1 eq  = a == b
 | B1 neq = a != b
 | B1 les = a <  b
 | B1 leq = a <= b
 | B1 grt = a >  b
 | B1 geq = a >= b
 |
 | IF [ eq ]
 |  | str = "a & b are equal"
 |  | (puts)[str]
 |  \_
 | IF [ neq ]
 |  | str = "a & b are NOT equal"
 |  | (puts)[str]
 |  \_
 | IF [ les]
 |  | str = "a is less then b"
 |  | (puts)[str]
 |  \_
 | IF [ leq ]
 |  | str = "a <= b"
 |  | (puts)[str]
 |  \_
 | IF [ grt ]
 |  | str = "a > b"
 |  | (puts)[str]
 |  \_
 | IF [ geq ]
 |  | str = "a >= b"
 |  | (puts)[str]
 |  \_
 | RET [ multiply ]
 \_


I32 puts:    [ @C1 str ]

