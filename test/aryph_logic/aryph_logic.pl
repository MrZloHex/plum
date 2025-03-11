; TEST OF ARYPHMETIC AND LOGIC OPERATIONS 

I32 main: []
 | @C1 str
 | str = "Hello from PLUM!"
 | (puts)[ str ]
 |
 | I32 a
 | I32 b
 | a = 2
 | b = 5
 | I32 plus
 | I32 minus
 | I32 division
 | I32 multiply
 | plus = a + b
 | minus = a - b
 | multiply = a * b
 | division = a / b
 |
 | B1 eq
 | B1 neq
 | B1 les
 | B1 leq
 | B1 grt
 | B1 geq
 | eq  = a == b
 | neq = a != b
 | les = a <  b
 | leq = a <= b
 | grt = a >  b
 | geq = a >= b
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

