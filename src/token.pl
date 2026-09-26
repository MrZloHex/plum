; token.pl -- the PLUM counterpart of inc/token.h
;
; The enum order must match inc/token.h exactly.

TYPE TokenType: ENUM
 | TOK_EOF
 | TOK_NEWLINE
 | TOK_COLON
 | TOK_LBRACKET
 | TOK_RBRACKET
 | TOK_LPAREN
 | TOK_RPAREN
 | TOK_VBAR
 | TOK_DOT
 | TOK_AT
 | TOK_QMARK
 | TOK_ELLIPSIS
 | TOK_OPERATOR
 | TOK_AS
 | TOK_END_BLOCK
 | TOK_IDENTIFIER
 | TOK_FLOAT
 | TOK_INTEGER
 | TOK_CHARACTER
 | TOK_STRING
 | TOK_TRUE
 | TOK_FALSE
 | TOK_TYPE
 | TOK_STRUCTURE
 | TOK_UNION
 | TOK_ENUMERATION
 | TOK_IF
 | TOK_ELIF
 | TOK_ELSE
 | TOK_LOOP
 | TOK_WHILE
 | TOK_BREAK
 | TOK_CONTINUE
 | TOK_RET
 | TOK_SIZE
 | TOK_IFACE
 | TOK_CLASS
 | TOK_IMPL
 | TOK_NULL
 | TOK_LBRACE
 | TOK_RBRACE
 \_

TYPE Location: STRUCT
 | I32 line
 | I32 col
 \_

TYPE Token: STRUCT
 | I32      kind
 | @C1      lexeme
 | I32      indent
 | Location loc
 \_

; inc/token.h keeps this as a static table. PLUM has no array initialisers
; and no switch, so it is an ELIF chain -- the documented workaround.
@C1 token_str: [ I32 t ]
 | IF [ t == TOK_EOF ]
 |  | RET [ "EOF" ]
 | ELIF [ t == TOK_NEWLINE ]
 |  | RET [ "NEWLINE" ]
 | ELIF [ t == TOK_COLON ]
 |  | RET [ "COLON" ]
 | ELIF [ t == TOK_LBRACKET ]
 |  | RET [ "LBRACKET" ]
 | ELIF [ t == TOK_RBRACKET ]
 |  | RET [ "RBRACKET" ]
 | ELIF [ t == TOK_LPAREN ]
 |  | RET [ "LPAREN" ]
 | ELIF [ t == TOK_RPAREN ]
 |  | RET [ "RPAREN" ]
 | ELIF [ t == TOK_VBAR ]
 |  | RET [ "VBAR" ]
 | ELIF [ t == TOK_DOT ]
 |  | RET [ "DOT" ]
 | ELIF [ t == TOK_AT ]
 |  | RET [ "AT" ]
 | ELIF [ t == TOK_QMARK ]
 |  | RET [ "QMARK" ]
 | ELIF [ t == TOK_ELLIPSIS ]
 |  | RET [ "ELLIPSIS" ]
 | ELIF [ t == TOK_OPERATOR ]
 |  | RET [ "OPERATOR" ]
 | ELIF [ t == TOK_AS ]
 |  | RET [ "AS" ]
 | ELIF [ t == TOK_END_BLOCK ]
 |  | RET [ "END BLOCK" ]
 | ELIF [ t == TOK_IDENTIFIER ]
 |  | RET [ "IDENTIFIER" ]
 | ELIF [ t == TOK_FLOAT ]
 |  | RET [ "FLOAT" ]
 | ELIF [ t == TOK_INTEGER ]
 |  | RET [ "INTEGER" ]
 | ELIF [ t == TOK_CHARACTER ]
 |  | RET [ "CHARACTER" ]
 | ELIF [ t == TOK_STRING ]
 |  | RET [ "STRING" ]
 | ELIF [ t == TOK_TRUE ]
 |  | RET [ "TRUE" ]
 | ELIF [ t == TOK_FALSE ]
 |  | RET [ "FALSE" ]
 | ELIF [ t == TOK_TYPE ]
 |  | RET [ "TYPE" ]
 | ELIF [ t == TOK_STRUCTURE ]
 |  | RET [ "STRUCTURE" ]
 | ELIF [ t == TOK_UNION ]
 |  | RET [ "UNION" ]
 | ELIF [ t == TOK_ENUMERATION ]
 |  | RET [ "ENUMERATION" ]
 | ELIF [ t == TOK_IF ]
 |  | RET [ "IF" ]
 | ELIF [ t == TOK_ELIF ]
 |  | RET [ "ELIF" ]
 | ELIF [ t == TOK_ELSE ]
 |  | RET [ "ELSE" ]
 | ELIF [ t == TOK_LOOP ]
 |  | RET [ "LOOP" ]
 | ELIF [ t == TOK_WHILE ]
 |  | RET [ "WHILE" ]
 | ELIF [ t == TOK_BREAK ]
 |  | RET [ "BREAK" ]
 | ELIF [ t == TOK_CONTINUE ]
 |  | RET [ "CONTINUE" ]
 | ELIF [ t == TOK_RET ]
 |  | RET [ "RET" ]
 | ELIF [ t == TOK_IFACE ]
 |  | RET [ "IFACE" ]
 | ELIF [ t == TOK_CLASS ]
 |  | RET [ "CLASS" ]
 | ELIF [ t == TOK_IMPL ]
 |  | RET [ "IMPL" ]
 | ELIF [ t == TOK_NULL ]
 |  | RET [ "NULL" ]
 | ELIF [ t == TOK_LBRACE ]
 |  | RET [ "LBRACE" ]
 | ELIF [ t == TOK_RBRACE ]
 |  | RET [ "RBRACE" ]
 | ELSE
 |  | RET [ "SIZE" ]
 |  \_
 \_
