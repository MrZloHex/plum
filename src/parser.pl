; parser.pl -- the PLUM counterpart of src/parser.c
;
; Recursive descent with one-token lookahead, plus precedence climbing for
; expressions. Blocks are validated against Parser.indent by check_indent.
; There is no error recovery: every diagnostic exits, as in the C version.

!USES <ast.pl>
!USES <lexer.pl>
!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>

TYPE Parser: STRUCT
 | Lexer lexer
 | Token curr
 | @AST  ast
 | I32   indent
 | B1    in_cast      ; parsing the type after AS
 | B1    in_list      ; in [ a | b ]: a bare `|` separates, it is no operator
 | I32   depth        ; how deep the expression being parsed nests
 \_

ABYSS parser_next: [ @Parser pr ]
 | pr.curr = (lexer_next)[ @(pr.lexer) ]
 | RET
 \_

Token parser_peek: [ @Parser pr | I32 ahead ]
 | Lexer save = pr.lexer
 | Token tok
 | WHILE [ ahead > 0 ]
 |  | tok = (lexer_next)[ @save ]
 |  | ahead -= 1
 |  \_
 | RET [ tok ]
 \_

; The C version is a macro capturing __LINE__/__func__; PLUM has neither.
@C1 itoa: [ I64 n ]
 | @C1 buf = (malloc)[ 24 ] AS @C1
 | (snprintf)[ buf | 24 | "%ld" | n ]
 | RET [ buf ]
 \_

ABYSS unexpected: [ @Parser pr ]
 | (diag_fatal)[ pr.curr.loc | "unexpected %s here%s" | (tok_desc)[ pr.curr ] | "" ]
 \_

ABYSS expect: [ @Parser pr | I32 t ]
 | IF [ pr.curr.kind != t ]
 |  | (diag_fatal)[ pr.curr.loc | "expected %s, found %s" | (tok_kind_desc)[ t ] | (tok_desc)[ pr.curr ] ]
 |  \_
 | (parser_next)[ pr ]
 | RET
 \_

B1 match: [ @Parser pr | I32 t ]
 | IF [ pr.curr.kind == t ]
 |  | (parser_next)[ pr ]
 |  | RET [ TRUE ]
 |  \_
 | RET [ FALSE ]
 \_

ABYSS set_loc: [ @ASTNode node | Token tok ]
 | node.loc = tok.loc
 | RET
 \_

ABYSS check_indent: [ @Parser pr | Token tok ]
 | IF [ tok.indent != pr.indent && tok.indent != 0 ]
 |  | ; the NEWLINE sits at the end of the line before the offending one
 |  | Location at = tok.loc
 |  | at.line = at.line + 1
 |  | at.col = 1
 |  | (diag_fatal)[ at | "this line is %s `|` deep, but the block it is in needs %s" | (itoa)[ tok.indent ] | (itoa)[ pr.indent ] ]
 |  \_
 | RET
 \_

@ASTNode parse_ident: [ @Parser pr ]
 | Token ident = pr.curr
 | (expect)[ pr | TOK_IDENTIFIER ]
 | @ASTNode id = (ast_node_new)[ pr.ast ]
 | id.kind = NT_IDENT
 | id.as.ident = ident.lexeme
 | (set_loc)[ id | ident ]
 | RET [ id ]
 \_

; src/parser.c keeps a base_types table; PLUM has no array initialisers.
I32 base_type_of: [ @C1 s ]
 | IF [ (strcmp)[ s | "ABYSS" ] == 0 ]
 |  | RET [ BT_ABYSS ]
 | ELIF [ (strcmp)[ s | "B1" ] == 0 ]
 |  | RET [ BT_B1 ]
 | ELIF [ (strcmp)[ s | "C1" ] == 0 ]
 |  | RET [ BT_C1 ]
 | ELIF [ (strcmp)[ s | "U8" ] == 0 ]
 |  | RET [ BT_U8 ]
 | ELIF [ (strcmp)[ s | "U16" ] == 0 ]
 |  | RET [ BT_U16 ]
 | ELIF [ (strcmp)[ s | "U32" ] == 0 ]
 |  | RET [ BT_U32 ]
 | ELIF [ (strcmp)[ s | "U64" ] == 0 ]
 |  | RET [ BT_U64 ]
 | ELIF [ (strcmp)[ s | "I8" ] == 0 ]
 |  | RET [ BT_I8 ]
 | ELIF [ (strcmp)[ s | "I16" ] == 0 ]
 |  | RET [ BT_I16 ]
 | ELIF [ (strcmp)[ s | "I32" ] == 0 ]
 |  | RET [ BT_I32 ]
 | ELIF [ (strcmp)[ s | "I64" ] == 0 ]
 |  | RET [ BT_I64 ]
 | ELIF [ (strcmp)[ s | "USIZE" ] == 0 ]
 |  | RET [ BT_USIZE ]
 | ELIF [ (strcmp)[ s | "ISIZE" ] == 0 ]
 |  | RET [ BT_ISIZE ]
 | ELIF [ (strcmp)[ s | "F32" ] == 0 ]
 |  | RET [ BT_F32 ]
 | ELIF [ (strcmp)[ s | "F64" ] == 0 ]
 |  | RET [ BT_F64 ]
 | ELSE
 |  | RET [ -1 ]
 |  \_
 \_

B1 is_op: [ Token t | @C1 op ]
 | RET [ t.kind == TOK_OPERATOR && (strcmp)[ t.lexeme | op ] == 0 ]
 \_

; Having just read a `<` from a scratch lexer, consume a balanced run of
; type arguments: only `@`, names, `|` and angle brackets may appear. This
; is what tells `Vec<I32> v` apart from `a AS I32 < b`.
B1 scan_type_args: [ @Lexer lx ]
 | I32 depth = 1
 | WHILE [ depth > 0 ]
 |  | Token t = (lexer_next)[ lx ]
 |  | IF [ t.kind == TOK_AT || t.kind == TOK_IDENTIFIER || t.kind == TOK_VBAR ]
 |  |  | CONTINUE
 |  |  \_
 |  | IF [ t.kind == TOK_CONST || t.kind == TOK_VOLATILE ]
 |  |  | CONTINUE
 |  |  \_
 |  | ; FN I32 [ I32 ] as an argument
 |  | IF [ t.kind == TOK_FN || t.kind == TOK_LBRACKET || t.kind == TOK_RBRACKET || t.kind == TOK_ELLIPSIS ]
 |  |  | CONTINUE
 |  |  \_
 |  | IF [ t.kind != TOK_OPERATOR ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | IF [ (strcmp)[ t.lexeme | "<" ] == 0 ]
 |  |  | depth += 1
 |  | ELIF [ (strcmp)[ t.lexeme | ">" ] == 0 ]
 |  |  | depth -= 1
 |  | ELIF [ (strcmp)[ t.lexeme | ">>" ] == 0 ]
 |  |  | depth -= 2
 |  | ELSE
 |  |  | RET [ FALSE ]
 |  |  \_
 |  \_
 | ; -1: a `>>` closed this list and the one around it
 | RET [ depth == 0 || depth == -1 ]
 \_

; `tok` came from a scratch lexer, right after a type's name. Step over
; any `<...>` so the caller sees what follows the whole type.
Token skip_type_args: [ @Lexer lx | Token tok ]
 | IF [ !(is_op)[ tok | "<" ] ]
 |  | RET [ tok ]
 |  \_
 | IF [ !(scan_type_args)[ lx ] ]
 |  | RET [ tok ]
 |  \_
 | RET [ (lexer_next)[ lx ] ]
 \_

; A type can begin here: a name, a pointer, FN, or a qualifier.
B1 starts_type: [ Token t ]
 | I32 k = t.kind
 | RET [ k == TOK_IDENTIFIER || k == TOK_AT || k == TOK_FN || k == TOK_CONST || k == TOK_VOLATILE ]
 \_

B1 starts_operand: [ Token t ]
 | I32 k = t.kind
 | IF [ k == TOK_IDENTIFIER || k == TOK_INTEGER || k == TOK_FLOAT || k == TOK_CHARACTER || k == TOK_STRING ]
 |  | RET [ TRUE ]
 |  \_
 | RET [ k == TOK_LPAREN || k == TOK_TRUE || k == TOK_FALSE || k == TOK_NULL || k == TOK_AT || k == TOK_QMARK ]
 \_

B1 at_type_args: [ @Parser pr ]
 | IF [ !(is_op)[ pr.curr | "<" ] ]
 |  | RET [ FALSE ]
 |  \_
 | Lexer lx = pr.lexer
 | IF [ !(scan_type_args)[ @lx ] ]
 |  | RET [ FALSE ]
 |  \_
 | ; after AS, `x AS T < a | b > c` is two comparisons: a type there is
 | ; followed by an operator or a delimiter, never by another operand
 | IF [ pr.in_cast ]
 |  | RET [ !(starts_operand)[ (lexer_next)[ @lx ] ] ]
 |  \_
 | RET [ TRUE ]
 \_

; Inside a bracketed list that may span lines: REQ [ ... ].
ABYSS skip_newlines: [ @Parser pr ]
 | WHILE [ pr.curr.kind == TOK_NEWLINE ]
 |  | (parser_next)[ pr ]
 |  \_
 \_

; At `Name<...>.`: a generic type in an expression, which only an ANONYMOUS
; method call puts there, as (Option<I32>.some)[ 5 ]. The `.` after the
; closing `>` is what no comparison can be followed by.
B1 at_type_ref: [ @Parser pr ]
 | Lexer lx = pr.lexer
 | Token lt = (lexer_next)[ @lx ]
 | IF [ !(is_op)[ lt | "<" ] ]
 |  | RET [ FALSE ]
 |  \_
 | IF [ !(scan_type_args)[ @lx ] ]
 |  | RET [ FALSE ]
 |  \_
 | RET [ (lexer_next)[ @lx ].kind == TOK_DOT ]
 \_

; At `name<...>` followed by what ends an operand: a generic function
; with its type arguments, as (max<I32>)[ a | b ] or f = max<I32>. After
; a comparison `a < b > c` an operand would follow.
B1 at_fn_inst: [ @Parser pr ]
 | Lexer lx = pr.lexer
 | Token lt = (lexer_next)[ @lx ]
 | IF [ !(is_op)[ lt | "<" ] ]
 |  | RET [ FALSE ]
 |  \_
 | IF [ !(scan_type_args)[ @lx ] ]
 |  | RET [ FALSE ]
 |  \_
 | Token nx = (lexer_next)[ @lx ]
 | I32 k = nx.kind
 | IF [ k == TOK_RPAREN || k == TOK_RBRACKET || k == TOK_VBAR || k == TOK_NEWLINE || k == TOK_EOF ]
 |  | RET [ TRUE ]
 |  \_
 | RET [ (is_op)[ nx | "==" ] || (is_op)[ nx | "!=" ] ]
 \_

; `>>` closes two lists at once: eat one `>` and leave the other.
ABYSS expect_close_angle: [ @Parser pr ]
 | IF [ pr.curr.kind != TOK_OPERATOR || ?(pr.curr.lexeme) != '>' ]
 |  | (diag_fatal)[ pr.curr.loc | "expected `>` to close the type arguments, found %s%s" | (tok_desc)[ pr.curr ] | "" ]
 |  \_
 | IF [ ?(pr.curr.lexeme + 1) == 0 ]
 |  | (parser_next)[ pr ]
 |  | RET
 |  \_
 | pr.curr.lexeme = pr.curr.lexeme + 1
 | pr.curr.loc.col = pr.curr.loc.col + 1
 | RET
 \_

@ASTNode parse_type: [ @Parser pr ]

; < T | U >  in a TYPE, IFACE or CLASS header
@ASTNode parse_gparams: [ @Parser pr ]
 | IF [ !(is_op)[ pr.curr | "<" ] ]
 |  | RET [ 0 ]
 |  \_
 | (parser_next)[ pr ]
 |
 | @ASTNode head = 0
 | @@ASTNode tail = @head
 | LOOP
 |  | @ASTNode item = (ast_node_new)[ pr.ast ]
 |  | item.kind = NT_LIST
 |  | (set_loc)[ item | pr.curr ]
 |  | item.as.list.item = (parse_ident)[ pr ]
 |  | ?(tail) = item
 |  | tail = @(item.as.list.next)
 |  | IF [ !(match)[ pr | TOK_VBAR ] ]
 |  |  | BREAK
 |  |  \_
 |  \_
 | (expect_close_angle)[ pr ]
 | RET [ head ]
 \_

; < I32 | @C1 >  after a type's name
@ASTNode parse_type_args: [ @Parser pr ]
 | (parser_next)[ pr ]
 |
 | @ASTNode head = 0
 | @@ASTNode tail = @head
 | LOOP
 |  | @ASTNode item = (ast_node_new)[ pr.ast ]
 |  | item.kind = NT_LIST
 |  | (set_loc)[ item | pr.curr ]
 |  | item.as.list.item = (parse_type)[ pr ]
 |  | ?(tail) = item
 |  | tail = @(item.as.list.next)
 |  | IF [ !(match)[ pr | TOK_VBAR ] ]
 |  |  | BREAK
 |  |  \_
 |  \_
 | (expect_close_angle)[ pr ]
 | RET [ head ]
 \_

; CONST and VOLATILE at one level of a type, as its bits of N_Type.quals.
U32 parse_quals: [ @Parser pr | U32 level ]
 | U32 q = 0
 | LOOP
 |  | U32 bit = 0
 |  | IF [ pr.curr.kind == TOK_CONST ]
 |  |  | bit = QUAL_CONST
 |  | ELIF [ pr.curr.kind == TOK_VOLATILE ]
 |  |  | bit = QUAL_VOLATILE
 |  | ELSE
 |  |  | BREAK
 |  |  \_
 |  | IF [ level > 15 ]
 |  |  | (diag_fatal)[ pr.curr.loc | "CONST and VOLATILE reach 15 pointers deep, and this is deeper%s%s" | "" | "" ]
 |  |  \_
 |  | q = q | (bit << (level * 2))
 |  | (parser_next)[ pr ]
 |  \_
 | RET [ q ]
 \_

@ASTNode parse_type: [ @Parser pr ]
 | @ASTNode type = (ast_node_new)[ pr.ast ]
 | type.kind = NT_TYPE
 | type.as.type.ptrs = 0
 |
 | ; CONST and VOLATILE belong to the level they are written at: before the
 | ; type, the thing declared; after an `@`, what that pointer points at
 | Token start = pr.curr
 | type.as.type.quals = (parse_quals)[ pr | 0 ]
 | WHILE [ (match)[ pr | TOK_AT ] ]
 |  | type.as.type.ptrs = type.as.type.ptrs + 1
 |  | type.as.type.quals = type.as.type.quals | (parse_quals)[ pr | type.as.type.ptrs ]
 |  \_
 |
 | ; FN R [ P | Q ] -- a pointer to a function; parameter names optional
 | IF [ (match)[ pr | TOK_FN ] ]
 |  | type.as.type.kind = TT_FN_TYPE
 |  | (set_loc)[ type | start ]
 |  | type.as.type.type = (parse_type)[ pr ]
 |  | (expect)[ pr | TOK_LBRACKET ]
 |  | IF [ (match)[ pr | TOK_RBRACKET ] ]
 |  |  | RET [ type ]
 |  |  \_
 |  | @@ASTNode tail = @(type.as.type.args)
 |  | LOOP
 |  |  | @ASTNode item = (ast_node_new)[ pr.ast ]
 |  |  | item.kind = NT_LIST
 |  |  | (set_loc)[ item | pr.curr ]
 |  |  | IF [ !(match)[ pr | TOK_ELLIPSIS ] ]
 |  |  |  | item.as.list.item = (parse_type)[ pr ]
 |  |  |  | IF [ pr.curr.kind == TOK_IDENTIFIER ]
 |  |  |  |  | (parser_next)[ pr ]
 |  |  |  |  \_
 |  |  |  \_
 |  |  | ?(tail) = item
 |  |  | tail = @(item.as.list.next)
 |  |  | IF [ !(match)[ pr | TOK_VBAR ] ]
 |  |  |  | BREAK
 |  |  |  \_
 |  |  \_
 |  | (expect)[ pr | TOK_RBRACKET ]
 |  | RET [ type ]
 |  \_
 |
 | Token ident = pr.curr
 | (expect)[ pr | TOK_IDENTIFIER ]
 |
 | @ASTNode int_type = (ast_node_new)[ pr.ast ]
 | int_type.kind = NT_IDENT
 |
 | I32 bt = (base_type_of)[ ident.lexeme ]
 | IF [ bt >= 0 ]
 |  | type.as.type.kind = TT_BASE_TYPE
 |  | int_type.kind = NT_BASE_TYPE
 |  | int_type.as.base_type = bt
 | ELSE
 |  | type.as.type.kind = TT_USER_TYPE
 |  | int_type.as.ident = ident.lexeme
 |  \_
 |
 | (set_loc)[ int_type | ident ]
 | (set_loc)[ type | start ]
 | type.as.type.type = int_type
 |
 | ; a base type never has arguments, so after AS, `I32 <` is a comparison
 | IF [ !(bt >= 0 && pr.in_cast) && (at_type_args)[ pr ] ]
 |  | IF [ bt >= 0 ]
 |  |  | (diag_fatal)[ ident.loc | "`%s` takes no type arguments%s" | ident.lexeme | "" ]
 |  |  \_
 |  | type.as.type.args = (parse_type_args)[ pr ]
 |  \_
 | RET [ type ]
 \_

I64 parse_int_lexeme: [ @C1 lex ]

; `name{N}` after a variable or field makes it an array of N
ABYSS parse_array_len: [ @Parser pr | @ASTNode type ]
 | IF [ !(match)[ pr | TOK_LBRACE ] ]
 |  | RET
 |  \_
 | Token n = pr.curr
 | (expect)[ pr | TOK_INTEGER ]
 | I64 len = (parse_int_lexeme)[ n.lexeme ]
 | IF [ len <= 0 ]
 |  | (diag_fatal)[ n.loc | "an array needs a positive length%s%s" | "" | "" ]
 |  \_
 | IF [ len > 4294967295 ]
 |  | (diag_fatal)[ n.loc | "an array can have at most 4294967295 elements%s%s" | "" | "" ]
 |  \_
 | type.as.type.arr = len AS U32
 | (expect)[ pr | TOK_RBRACE ]
 | RET
 \_

@ASTNode parse_field: [ @Parser pr ]
 | @ASTNode field = (ast_node_new)[ pr.ast ]
 | field.kind = NT_FIELD
 | (set_loc)[ field | pr.curr ]
 | field.as.rcrd_flds.type = (parse_type)[ pr ]
 | field.as.rcrd_flds.ident = (parse_ident)[ pr ]
 | (parse_array_len)[ pr | field.as.rcrd_flds.type ]
 | field.as.rcrd_flds.next_field = 0
 | RET [ field ]
 \_

; `+ PACKED` or `+ ALIGN N`, a line of a STRUCT or UNION body.
ABYSS parse_record_attr: [ @Parser pr | @ASTNode record ]
 | (parser_next)[ pr ]
 | Token what = pr.curr
 | (expect)[ pr | TOK_IDENTIFIER ]
 | IF [ (strcmp)[ what.lexeme | "PACKED" ] == 0 ]
 |  | record.as.record.packed = TRUE
 | ELIF [ (strcmp)[ what.lexeme | "ALIGN" ] == 0 ]
 |  | Token n = pr.curr
 |  | (expect)[ pr | TOK_INTEGER ]
 |  | I64 a = (parse_int_lexeme)[ n.lexeme ]
 |  | IF [ a < 1 || a > 4096 || (a & (a - 1)) != 0 ]
 |  |  | (diag_fatal)[ n.loc | "ALIGN takes a power of two from 1 to 4096, not %s%s" | n.lexeme | "" ]
 |  |  \_
 |  | record.as.record.align = a AS U32
 | ELSE
 |  | (diag_fatal)[ what.loc | "a STRUCT or UNION takes + PACKED or + ALIGN N, not `%s`%s" | what.lexeme | "" ]
 |  \_
 \_

@ASTNode parse_record: [ @Parser pr | I32 kind ]
 | @ASTNode record = (ast_node_new)[ pr.ast ]
 | record.kind = NT_RECORD
 | record.as.record.kind = kind
 | record.as.record.fields = 0
 | (set_loc)[ record | pr.curr ]
 |
 | @@ASTNode tail = @(record.as.record.fields)
 |
 | WHILE [ pr.curr.kind == TOK_NEWLINE ]
 |  | Token newline = pr.curr
 |  | (expect)[ pr | TOK_NEWLINE ]
 |  | ; a blank line, or one holding only a comment
 |  | IF [ pr.curr.kind == TOK_NEWLINE ]
 |  |  | CONTINUE
 |  |  \_
 |  | (check_indent)[ pr | newline ]
 |  | IF [ (is_op)[ pr.curr | "+" ] ]
 |  |  | (parse_record_attr)[ pr | record ]
 |  | ELSE
 |  |  | @ASTNode f = (parse_field)[ pr ]
 |  |  | ?(tail) = f
 |  |  | tail = @(f.as.rcrd_flds.next_field)
 |  |  \_
 |  \_
 | (expect)[ pr | TOK_END_BLOCK ]
 | RET [ record ]
 \_

; NAME, or NAME = 4, = -1, = 0x8000_0000: one past the constant before
; unless given, as in C. Any 32-bit pattern, signed or not.
@ASTNode parse_enum_field: [ @Parser pr | I64 next ]
 | @ASTNode field = (ast_node_new)[ pr.ast ]
 | field.kind = NT_ENUM_FIELDS
 | (set_loc)[ field | pr.curr ]
 | field.as.enum_flds.ident = (parse_ident)[ pr ]
 | field.as.enum_flds.next_field = 0
 | field.as.enum_flds.value = next
 | IF [ (is_op)[ pr.curr | "=" ] ]
 |  | (parser_next)[ pr ]
 |  | B1 neg = (is_op)[ pr.curr | "-" ]
 |  | IF [ neg ]
 |  |  | (parser_next)[ pr ]
 |  |  \_
 |  | Token n = pr.curr
 |  | (expect)[ pr | TOK_INTEGER ]
 |  | I64 v = (parse_int_lexeme)[ n.lexeme ]
 |  | IF [ neg ]
 |  |  | v = -v
 |  |  \_
 |  | IF [ v < -2147483648 || v > 4294967295 ]
 |  |  | (diag_fatal)[ n.loc | "an enum constant is 32 bits, and %s does not fit%s" | n.lexeme | "" ]
 |  |  \_
 |  | field.as.enum_flds.value = v
 |  \_
 | RET [ field ]
 \_

@ASTNode parse_enum: [ @Parser pr ]
 | @ASTNode en = (ast_node_new)[ pr.ast ]
 | en.kind = NT_ENUM
 | en.as.enumeration.fields = 0
 | (set_loc)[ en | pr.curr ]
 |
 | @@ASTNode tail = @(en.as.enumeration.fields)
 | I64 next = 0
 |
 | WHILE [ pr.curr.kind == TOK_NEWLINE ]
 |  | Token newline = pr.curr
 |  | (expect)[ pr | TOK_NEWLINE ]
 |  | IF [ pr.curr.kind == TOK_NEWLINE ]
 |  |  | CONTINUE
 |  |  \_
 |  | (check_indent)[ pr | newline ]
 |  | @ASTNode f = (parse_enum_field)[ pr | next ]
 |  | next = f.as.enum_flds.value + 1
 |  | ?(tail) = f
 |  | tail = @(f.as.enum_flds.next_field)
 |  \_
 | (expect)[ pr | TOK_END_BLOCK ]
 | RET [ en ]
 \_

@ASTNode parse_type_def: [ @Parser pr ]
 | @ASTNode td = (ast_node_new)[ pr.ast ]
 | td.kind = NT_TYPE_DEF
 | (set_loc)[ td | pr.curr ]
 |
 | (expect)[ pr | TOK_TYPE ]
 | td.as.type_def.ident = (parse_ident)[ pr ]
 | td.as.type_def.gparams = (parse_gparams)[ pr ]
 | (expect)[ pr | TOK_COLON ]
 |
 | IF [ (match)[ pr | TOK_STRUCTURE ] ]
 |  | td.as.type_def.kind = TD_RECORD
 |  | td.as.type_def.tdef = (parse_record)[ pr | TDRT_STRUCTURE ]
 | ELIF [ (match)[ pr | TOK_UNION ] ]
 |  | td.as.type_def.kind = TD_RECORD
 |  | td.as.type_def.tdef = (parse_record)[ pr | TDRT_UNION ]
 | ELIF [ (match)[ pr | TOK_ENUMERATION ] ]
 |  | td.as.type_def.kind = TD_ENUM
 |  | td.as.type_def.tdef = (parse_enum)[ pr ]
 | ELIF [ pr.curr.kind == TOK_NEWLINE ]
 |  | ; `TYPE Foo:` straight into fields is a STRUCT
 |  | td.as.type_def.kind = TD_RECORD
 |  | td.as.type_def.tdef = (parse_record)[ pr | TDRT_STRUCTURE ]
 | ELIF [ (starts_type)[ pr.curr ] ]
 |  | td.as.type_def.kind = TD_ALIAS
 |  | td.as.type_def.tdef = (parse_type)[ pr ]
 | ELSE
 |  | (unexpected)[ pr ]
 |  \_
 |
 | RET [ td ]
 \_

@ASTNode parse_params: [ @Parser pr ]
 | (expect)[ pr | TOK_LBRACKET ]
 | IF [ (match)[ pr | TOK_RBRACKET ] ]
 |  | RET [ 0 ]
 |  \_
 |
 | @ASTNode head = 0
 | @@ASTNode tail = @head
 |
 | B1 is_param = TRUE
 | WHILE [ is_param ]
 |  | @ASTNode param = (ast_node_new)[ pr.ast ]
 |  | param.kind = NT_PARAMETRE
 |  | param.as.parametre.next_param = 0
 |  | (set_loc)[ param | pr.curr ]
 |  |
 |  | IF [ (match)[ pr | TOK_ELLIPSIS ] ]
 |  |  | param.as.parametre.vaarg = TRUE
 |  | ELIF [ (starts_type)[ pr.curr ] ]
 |  |  | param.as.parametre.type = (parse_type)[ pr ]
 |  |  | param.as.parametre.ident = (parse_ident)[ pr ]
 |  | ELSE
 |  |  | (unexpected)[ pr ]
 |  |  \_
 |  |
 |  | ?(tail) = param
 |  | tail = @(param.as.parametre.next_param)
 |  |
 |  | IF [ !(match)[ pr | TOK_VBAR ] ]
 |  |  | is_param = FALSE
 |  |  \_
 |  \_
 |
 | (expect)[ pr | TOK_RBRACKET ]
 | RET [ head ]
 \_

; `gparams`, when not 0, takes a generic function's <T | U>.
@ASTNode parse_fn_decl: [ @Parser pr | @@ASTNode gparams ]
 | @ASTNode fndecl = (ast_node_new)[ pr.ast ]
 | fndecl.kind = NT_FN_DECL
 | (set_loc)[ fndecl | pr.curr ]
 |
 | fndecl.as.fn_decl.type = (parse_type)[ pr ]
 | fndecl.as.fn_decl.ident = (parse_ident)[ pr ]
 | IF [ gparams != 0 ]
 |  | ?(gparams) = (parse_gparams)[ pr ]
 |  \_
 | (expect)[ pr | TOK_COLON ]
 | fndecl.as.fn_decl.params = (parse_params)[ pr ]
 | RET [ fndecl ]
 \_

I32 prefix_precendence: [ @Parser pr ]
 | IF [ pr.curr.kind == TOK_QMARK || pr.curr.kind == TOK_AT ]
 |  | RET [ 50 ]
 |  \_
 | IF [ pr.curr.kind == TOK_OPERATOR ]
 |  | @C1 op = pr.curr.lexeme
 |  | IF [ (strcmp)[ op | "-" ] == 0 || (strcmp)[ op | "!" ] == 0 || (strcmp)[ op | "~" ] == 0 ]
 |  |  | RET [ 50 ]
 |  |  \_
 |  \_
 | RET [ -1 ]
 \_

I32 infix_precendence: [ @Parser pr ]
 | IF [ pr.curr.kind == TOK_DOT || pr.curr.kind == TOK_LBRACE ]
 |  | RET [ 40 ]
 |  \_
 | IF [ pr.curr.kind == TOK_AS ]
 |  | RET [ 35 ]
 |  \_
 | IF [ pr.curr.kind == TOK_VBAR ]
 |  | IF [ pr.in_list ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | RET [ 9 ]
 |  \_
 | IF [ pr.curr.kind != TOK_OPERATOR ]
 |  | RET [ -1 ]
 |  \_
 |
 | @C1 op = pr.curr.lexeme
 | IF [ (strcmp)[ op | "*" ] == 0 || (strcmp)[ op | "/" ] == 0 || (strcmp)[ op | "%" ] == 0 ]
 |  | RET [ 30 ]
 |  \_
 | IF [ (strcmp)[ op | "+" ] == 0 || (strcmp)[ op | "-" ] == 0 ]
 |  | RET [ 20 ]
 |  \_
 | IF [ (strcmp)[ op | "<<" ] == 0 || (strcmp)[ op | ">>" ] == 0 ]
 |  | RET [ 17 ]
 |  \_
 | IF [ (strcmp)[ op | "<" ] == 0 || (strcmp)[ op | "<=" ] == 0 ]
 |  | RET [ 15 ]
 |  \_
 | IF [ (strcmp)[ op | ">" ] == 0 || (strcmp)[ op | ">=" ] == 0 ]
 |  | RET [ 15 ]
 |  \_
 | IF [ (strcmp)[ op | "==" ] == 0 || (strcmp)[ op | "!=" ] == 0 ]
 |  | RET [ 10 ]
 |  \_
 | IF [ (strcmp)[ op | "&" ] == 0 ]
 |  | RET [ 12 ]
 |  \_
 | IF [ (strcmp)[ op | "^" ] == 0 ]
 |  | RET [ 11 ]
 |  \_
 | IF [ (strcmp)[ op | "&&" ] == 0 ]
 |  | RET [ 8 ]
 |  \_
 | IF [ (strcmp)[ op | "||" ] == 0 ]
 |  | RET [ 7 ]
 |  \_
 | IF [ (strcmp)[ op | "=" ] == 0 ]
 |  | RET [ 5 ]
 |  \_
 | IF [ ?(op + 1) == '=' && ?(op + 2) == 0 ]
 |  | C1 c0 = ?(op)
 |  | IF [ c0 == '+' || c0 == '-' || c0 == '*' || c0 == '/' || c0 == '%' ]
 |  |  | RET [ 5 ]
 |  |  \_
 |  | IF [ c0 == '&' || c0 == '^' || c0 == '|' ]
 |  |  | RET [ 5 ]
 |  |  \_
 |  \_
 | IF [ (strcmp)[ op | "<<=" ] == 0 || (strcmp)[ op | ">>=" ] == 0 ]
 |  | RET [ 5 ]
 |  \_
 | RET [ -1 ]
 \_

B1 is_fn_call: [ @Parser pr ]
 | IF [ pr.curr.kind != TOK_LPAREN ]
 |  | RET [ FALSE ]
 |  \_
 | Token t1 = (parser_peek)[ pr | 1 ]
 | IF [ t1.kind != TOK_IDENTIFIER ]
 |  | RET [ FALSE ]
 |  \_
 | Token t2 = (parser_peek)[ pr | 2 ]
 | IF [ t2.kind != TOK_RPAREN ]
 |  | RET [ FALSE ]
 |  \_
 | Token t3 = (parser_peek)[ pr | 3 ]
 | RET [ t3.kind == TOK_LBRACKET ]
 \_

; In a scratch lexer, step over a whole type starting at `tok` -- pointers,
; FN signatures, type arguments -- and hand back the token after it. `ok`
; is FALSE when what is there cannot be a type at all.
Token skip_type: [ @Lexer lx | Token tok | @B1 ok ]
 | ?(ok) = TRUE
 | WHILE [ tok.kind == TOK_AT || tok.kind == TOK_CONST || tok.kind == TOK_VOLATILE ]
 |  | tok = (lexer_next)[ lx ]
 |  \_
 |
 | IF [ tok.kind == TOK_FN ]
 |  | tok = (skip_type)[ lx | (lexer_next)[ lx ] | ok ]
 |  | IF [ !?(ok) || tok.kind != TOK_LBRACKET ]
 |  |  | ?(ok) = FALSE
 |  |  | RET [ tok ]
 |  |  \_
 |  | I32 depth = 1
 |  | WHILE [ depth > 0 ]
 |  |  | tok = (lexer_next)[ lx ]
 |  |  | IF [ tok.kind == TOK_LBRACKET ]
 |  |  |  | depth += 1
 |  |  | ELIF [ tok.kind == TOK_RBRACKET ]
 |  |  |  | depth -= 1
 |  |  | ELIF [ tok.kind == TOK_EOF ]
 |  |  |  | ?(ok) = FALSE
 |  |  |  | RET [ tok ]
 |  |  |  \_
 |  |  \_
 |  | RET [ (lexer_next)[ lx ] ]
 |  \_
 |
 | IF [ tok.kind != TOK_IDENTIFIER ]
 |  | ?(ok) = FALSE
 |  | RET [ tok ]
 |  \_
 | RET [ (skip_type_args)[ lx | (lexer_next)[ lx ] ] ]
 \_

B1 is_tu_var_decl: [ @Parser pr ]
 | Lexer lx = pr.lexer
 | B1 ok = FALSE
 | Token t2 = (skip_type)[ @lx | pr.curr | @ok ]
 | IF [ !ok ]
 |  | RET [ FALSE ]
 |  \_
 | IF [ t2.kind != TOK_IDENTIFIER ]
 |  | RET [ FALSE ]
 |  \_
 | ; max<T>: a generic function's name, with its parameters
 | Token t3 = (skip_type_args)[ @lx | (lexer_next)[ @lx ] ]
 | RET [ t3.kind != TOK_COLON ]
 \_

B1 is_var_decl: [ @Parser pr ]
 | Lexer lx = pr.lexer
 | B1 ok = FALSE
 | Token t2 = (skip_type)[ @lx | pr.curr | @ok ]
 | RET [ ok && t2.kind == TOK_IDENTIFIER ]
 \_

@ASTNode parse_expr: [ @Parser pr ]
@ASTNode parse_expr_prec: [ @Parser pr | I32 min_prec ]
@ASTNode parse_expression: [ @Parser pr | I32 min_prec ]

@ASTNode parse_arguments: [ @Parser pr ]
 | (expect)[ pr | TOK_LBRACKET ]
 | IF [ (match)[ pr | TOK_RBRACKET ] ]
 |  | RET [ 0 ]
 |  \_
 |
 | @ASTNode head = 0
 | @@ASTNode tail = @head
 |
 | B1 is_arg = TRUE
 | WHILE [ is_arg ]
 |  | @ASTNode arg = (ast_node_new)[ pr.ast ]
 |  | arg.kind = NT_ARGUMENT
 |  | arg.as.argument.next_arg = 0
 |  | (set_loc)[ arg | pr.curr ]
 |  |
 |  | ; `...`: a variadic function passes on its own, as a va_list
 |  | IF [ pr.curr.kind == TOK_ELLIPSIS ]
 |  |  | @ASTNode va = (ast_node_new)[ pr.ast ]
 |  |  | va.kind = NT_VA_ARGS
 |  |  | (set_loc)[ va | pr.curr ]
 |  |  | (parser_next)[ pr ]
 |  |  | arg.as.argument.argument = va
 |  |  | IF [ pr.curr.kind == TOK_VBAR ]
 |  |  |  | (diag_fatal)[ pr.curr.loc | "`...` passes on the rest, so it comes last%s%s" | "" | "" ]
 |  |  |  \_
 |  | ELSE
 |  |  | ; a bare `|` here separates arguments; everything else is an operator
 |  |  | B1 was = pr.in_list
 |  |  | pr.in_list = TRUE
 |  |  | arg.as.argument.argument = (parse_expr)[ pr ]
 |  |  | pr.in_list = was
 |  |  \_
 |  |
 |  | ?(tail) = arg
 |  | tail = @(arg.as.argument.next_arg)
 |  |
 |  | IF [ !(match)[ pr | TOK_VBAR ] ]
 |  |  | is_arg = FALSE
 |  |  \_
 |  \_
 |
 | (expect)[ pr | TOK_RBRACKET ]
 | RET [ head ]
 \_

@ASTNode parse_fn_call: [ @Parser pr ]
 | @ASTNode call = (ast_node_new)[ pr.ast ]
 | call.kind = NT_FN_CALL
 | (set_loc)[ call | pr.curr ]
 |
 | (expect)[ pr | TOK_LPAREN ]
 | call.as.fn_call.ident = (parse_ident)[ pr ]
 | (expect)[ pr | TOK_RPAREN ]
 | call.as.fn_call.args = (parse_arguments)[ pr ]
 | RET [ call ]
 \_

I32 unescape_char: [ @C1 lex ]
 | IF [ ?(lex + 1) != '\\' ]
 |  | RET [ ?(lex + 1) AS I32 ]
 |  \_
 | C1 e = ?(lex + 2)
 | IF [ e == 'n' ]
 |  | RET [ 10 ]
 |  \_
 | IF [ e == 't' ]
 |  | RET [ 9 ]
 |  \_
 | IF [ e == 'r' ]
 |  | RET [ 13 ]
 |  \_
 | IF [ e == '0' ]
 |  | RET [ 0 ]
 |  \_
 | ; '\x1b': up to two hex digits, as in a string
 | IF [ e == 'x' ]
 |  | I32 v = 0
 |  | I32 i = 3
 |  | WHILE [ i < 5 ]
 |  |  | C1 h = ?(lex + i)
 |  |  | I32 d = -1
 |  |  | IF [ h >= '0' && h <= '9' ]
 |  |  |  | d = (h AS I32) - 48
 |  |  | ELIF [ h >= 'a' && h <= 'f' ]
 |  |  |  | d = (h AS I32) - 87
 |  |  | ELIF [ h >= 'A' && h <= 'F' ]
 |  |  |  | d = (h AS I32) - 55
 |  |  |  \_
 |  |  | IF [ d < 0 ]
 |  |  |  | BREAK
 |  |  |  \_
 |  |  | v = v * 16 + d
 |  |  | i += 1
 |  |  \_
 |  | RET [ v ]
 |  \_
 | RET [ e AS I32 ]
 \_

; Bases and `_` separators, matching the C parse_literal.
I64 parse_int_lexeme: [ @C1 lex ]
 | @C1 clean = (malloc)[ 64 ] AS @C1
 | U64 k = 0
 | @C1 c = lex
 | WHILE [ ?(c) != 0 && k < 63 ]
 |  | IF [ ?(c) != '_' ]
 |  |  | ?(clean + k) = ?(c)
 |  |  | k = k + 1
 |  |  \_
 |  | c = c + 1
 |  \_
 | ?(clean + k) = '\0'
 |
 | @C1 digits = clean
 | I32 base = 10
 | IF [ ?(clean) == '0' && (?(clean + 1) == 'b' || ?(clean + 1) == 'B') ]
 |  | digits = clean + 2
 |  | base = 2
 | ELIF [ ?(clean) == '0' && (?(clean + 1) == 'x' || ?(clean + 1) == 'X') ]
 |  | digits = clean + 2
 |  | base = 16
 |  \_
 |
 | ; unsigned, so the full 64 bits survive: 0xFFFF_FFFF_FFFF_FFFF
 | I64 v = (strtoull)[ digits | 0 AS @@C1 | base ] AS I64
 | (free)[ clean AS @ABYSS ]
 | RET [ v ]
 \_

@ASTNode parse_literal: [ @Parser pr ]
 | @ASTNode lit = (ast_node_new)[ pr.ast ]
 | lit.kind = NT_LITERAL
 | (set_loc)[ lit | pr.curr ]
 |
 | @C1 lex = pr.curr.lexeme
 |
 | IF [ (match)[ pr | TOK_TRUE ] ]
 |  | lit.as.literal.kind = LT_BOOLEAN
 |  | lit.as.literal.as.bool_lit = TRUE
 | ELIF [ (match)[ pr | TOK_FALSE ] ]
 |  | lit.as.literal.kind = LT_BOOLEAN
 |  | lit.as.literal.as.bool_lit = FALSE
 | ELIF [ (match)[ pr | TOK_NULL ] ]
 |  | lit.as.literal.kind = LT_INTEGER
 |  | lit.as.literal.as.int_lit = 0
 | ELIF [ (match)[ pr | TOK_INTEGER ] ]
 |  | lit.as.literal.kind = LT_INTEGER
 |  | lit.as.literal.as.int_lit = (parse_int_lexeme)[ lex ]
 | ELIF [ (match)[ pr | TOK_CHARACTER ] ]
 |  | lit.as.literal.kind = LT_CHARACTER
 |  | lit.as.literal.as.char_lit = (unescape_char)[ lex ] AS C1
 | ELIF [ (match)[ pr | TOK_STRING ] ]
 |  | lit.as.literal.kind = LT_STRING
 |  | lit.as.literal.as.str_lit = lex
 | ELIF [ (match)[ pr | TOK_FLOAT ] ]
 |  | lit.as.literal.kind = LT_FLOAT
 |  | ; 1_000.5: drop the separators atof would stop at
 |  | @C1 clean = (strdup)[ lex ]
 |  | U64 w = 0
 |  | U64 r = 0
 |  | WHILE [ ?(lex + r) != 0 ]
 |  |  | IF [ ?(lex + r) != '_' ]
 |  |  |  | ?(clean + w) = ?(lex + r)
 |  |  |  | w = w + 1
 |  |  |  \_
 |  |  | r = r + 1
 |  |  \_
 |  | ?(clean + w) = '\0'
 |  | lit.as.literal.as.float_lit = (atof)[ clean ]
 |  | (free)[ clean AS @ABYSS ]
 | ELSE
 |  | (unexpected)[ pr ]
 |  \_
 |
 | RET [ lit ]
 \_

@ASTNode parse_builtin: [ @Parser pr ]
 | @ASTNode built = (ast_node_new)[ pr.ast ]
 | built.kind = NT_BUILTIN
 | (set_loc)[ built | pr.curr ]
 |
 | IF [ (match)[ pr | TOK_SIZE ] ]
 |  | built.as.builtin.kind = BI_SIZE
 |  | (expect)[ pr | TOK_LBRACKET ]
 |  | built.as.builtin.size = (parse_type)[ pr ]
 |  | (expect)[ pr | TOK_RBRACKET ]
 | ELIF [ (match)[ pr | TOK_OFFSET ] ]
 |  | ; OFFSET [ Type.field ], through nested structs: Outer.inner.x
 |  | built.as.builtin.kind = BI_OFFSET
 |  | (expect)[ pr | TOK_LBRACKET ]
 |  | built.as.builtin.size = (parse_type)[ pr ]
 |  | @@ASTNode ptail = @(built.as.builtin.path)
 |  | (expect)[ pr | TOK_DOT ]
 |  | LOOP
 |  |  | @ASTNode step = (ast_node_new)[ pr.ast ]
 |  |  | step.kind = NT_LIST
 |  |  | step.as.list.item = (parse_ident)[ pr ]
 |  |  | ?(ptail) = step
 |  |  | ptail = @(step.as.list.next)
 |  |  | IF [ !(match)[ pr | TOK_DOT ] ]
 |  |  |  | BREAK
 |  |  |  \_
 |  |  \_
 |  | (expect)[ pr | TOK_RBRACKET ]
 | ELSE
 |  | (unexpected)[ pr ]
 |  \_
 | RET [ built ]
 \_

; (obj.method)[ args ] or (expr)[ args ] -- the part in parentheses was
; parsed as an ordinary expression; a member access is split into the
; object and the method's name.
@ASTNode parse_method_call: [ @Parser pr | Token open | @ASTNode e ]
 | @ASTNode m = e
 | WHILE [ m.kind == NT_EXPR ]
 |  | m = m.as.expr.expr
 |  \_
 |
 | @ASTNode call = (ast_node_new)[ pr.ast ]
 | call.kind = NT_FN_CALL
 | (set_loc)[ call | open ]
 | call.as.fn_call.target = m
 |
 | ; obj.name: a method, or a function pointer stored in a field. Anything
 | ; else must itself be a function pointer.
 | IF [ m.kind == NT_BIN_OP && m.as.bin_op.kind == BOT_MEMBER && m.as.bin_op.right.kind == NT_IDENT ]
 |  | call.as.fn_call.ident = m.as.bin_op.right
 |  | call.as.fn_call.recv = m.as.bin_op.left
 |  \_
 | call.as.fn_call.args = (parse_arguments)[ pr ]
 | RET [ call ]
 \_

; [ 1 | 2 | 3 ], [ .x = 1 | .y = 2 ], nested, over lines if need be: what
; a declaration's `=` may take for a struct or an array.
@ASTNode parse_init: [ @Parser pr ]
 | @ASTNode init = (ast_node_new)[ pr.ast ]
 | init.kind = NT_INIT
 | (set_loc)[ init | pr.curr ]
 | (expect)[ pr | TOK_LBRACKET ]
 | B1 was = pr.in_list
 | pr.in_list = TRUE
 | (skip_newlines)[ pr ]
 | @@ASTNode tail = @(init.as.list.item)
 | WHILE [ pr.curr.kind != TOK_RBRACKET ]
 |  | @ASTNode it = (ast_node_new)[ pr.ast ]
 |  | it.kind = NT_INIT_ITEM
 |  | (set_loc)[ it | pr.curr ]
 |  | IF [ (match)[ pr | TOK_DOT ] ]
 |  |  | it.as.init_item.name = (parse_ident)[ pr ]
 |  |  | IF [ !(is_op)[ pr.curr | "=" ] ]
 |  |  |  | (diag_fatal)[ pr.curr.loc | "expected `=` after the field's name, found %s%s" | (tok_desc)[ pr.curr ] | "" ]
 |  |  |  \_
 |  |  | (parser_next)[ pr ]
 |  |  \_
 |  | it.as.init_item.value = (parse_expr)[ pr ]
 |  | ?(tail) = it
 |  | tail = @(it.as.init_item.next)
 |  | (skip_newlines)[ pr ]
 |  | IF [ !(match)[ pr | TOK_VBAR ] ]
 |  |  | BREAK
 |  |  \_
 |  | (skip_newlines)[ pr ]
 |  \_
 | pr.in_list = was
 | (expect)[ pr | TOK_RBRACKET ]
 | RET [ init ]
 \_

@ASTNode parse_primary: [ @Parser pr ]
 | IF [ pr.curr.kind == TOK_SIZE || pr.curr.kind == TOK_OFFSET ]
 |  | RET [ (parse_builtin)[ pr ] ]
 |  \_
 | IF [ pr.curr.kind == TOK_LBRACKET ]
 |  | RET [ (parse_init)[ pr ] ]
 |  \_
 | IF [ (is_fn_call)[ pr ] ]
 |  | RET [ (parse_fn_call)[ pr ] ]
 |  \_
 | Token open = pr.curr
 | IF [ (match)[ pr | TOK_LPAREN ] ]
 |  | ; in parentheses `|` is the operator again, even inside a list
 |  | B1 was = pr.in_list
 |  | pr.in_list = FALSE
 |  | @ASTNode e = (parse_expr)[ pr ]
 |  | pr.in_list = was
 |  | (expect)[ pr | TOK_RPAREN ]
 |  | IF [ pr.curr.kind == TOK_LBRACKET ]
 |  |  | RET [ (parse_method_call)[ pr | open | e ] ]
 |  |  \_
 |  | RET [ e ]
 |  \_
 | IF [ pr.curr.kind == TOK_IDENTIFIER && (at_type_ref)[ pr ] ]
 |  | RET [ (parse_type)[ pr ] ]
 |  \_
 | IF [ pr.curr.kind == TOK_IDENTIFIER && (at_fn_inst)[ pr ] ]
 |  | @ASTNode fi = (parse_type)[ pr ]
 |  | fi.kind = NT_FN_INST
 |  | RET [ fi ]
 |  \_
 | IF [ pr.curr.kind == TOK_IDENTIFIER ]
 |  | RET [ (parse_ident)[ pr ] ]
 |  \_
 | IF [ pr.curr.kind == TOK_INTEGER || pr.curr.kind == TOK_FLOAT ]
 |  | RET [ (parse_literal)[ pr ] ]
 |  \_
 | IF [ pr.curr.kind == TOK_CHARACTER || pr.curr.kind == TOK_STRING ]
 |  | RET [ (parse_literal)[ pr ] ]
 |  \_
 | IF [ pr.curr.kind == TOK_TRUE || pr.curr.kind == TOK_FALSE || pr.curr.kind == TOK_NULL ]
 |  | RET [ (parse_literal)[ pr ] ]
 |  \_
 |
 | (unexpected)[ pr ]
 | RET [ 0 ]
 \_

I32 binop_kind_of: [ Token op_tok ]
 | IF [ op_tok.kind == TOK_DOT ]
 |  | RET [ BOT_MEMBER ]
 |  \_
 | IF [ op_tok.kind == TOK_VBAR ]
 |  | RET [ BOT_BOR ]
 |  \_
 | @C1 op = op_tok.lexeme
 | IF [ (strcmp)[ op | "+" ] == 0 ]
 |  | RET [ BOT_PLUS ]
 |  \_
 | IF [ (strcmp)[ op | "-" ] == 0 ]
 |  | RET [ BOT_MINUS ]
 |  \_
 | IF [ (strcmp)[ op | "*" ] == 0 ]
 |  | RET [ BOT_MULT ]
 |  \_
 | IF [ (strcmp)[ op | "/" ] == 0 ]
 |  | RET [ BOT_DIV ]
 |  \_
 | IF [ (strcmp)[ op | "%" ] == 0 ]
 |  | RET [ BOT_MOD ]
 |  \_
 | IF [ (strcmp)[ op | "==" ] == 0 ]
 |  | RET [ BOT_EQUAL ]
 |  \_
 | IF [ (strcmp)[ op | "!=" ] == 0 ]
 |  | RET [ BOT_NEQ ]
 |  \_
 | IF [ (strcmp)[ op | "<" ] == 0 ]
 |  | RET [ BOT_LESS ]
 |  \_
 | IF [ (strcmp)[ op | "<=" ] == 0 ]
 |  | RET [ BOT_LEQ ]
 |  \_
 | IF [ (strcmp)[ op | ">" ] == 0 ]
 |  | RET [ BOT_GREAT ]
 |  \_
 | IF [ (strcmp)[ op | ">=" ] == 0 ]
 |  | RET [ BOT_GEQ ]
 |  \_
 | IF [ (strcmp)[ op | "&&" ] == 0 ]
 |  | RET [ BOT_AND ]
 |  \_
 | IF [ (strcmp)[ op | "||" ] == 0 ]
 |  | RET [ BOT_OR ]
 |  \_
 | IF [ (strcmp)[ op | "&" ] == 0 ]
 |  | RET [ BOT_BAND ]
 |  \_
 | IF [ (strcmp)[ op | "^" ] == 0 ]
 |  | RET [ BOT_BXOR ]
 |  \_
 | IF [ (strcmp)[ op | "<<" ] == 0 ]
 |  | RET [ BOT_SHL ]
 |  \_
 | IF [ (strcmp)[ op | ">>" ] == 0 ]
 |  | RET [ BOT_SHR ]
 |  \_
 | IF [ (strcmp)[ op | "=" ] == 0 ]
 |  | RET [ BOT_ASSIGN ]
 |  \_
 | RET [ -1 ]
 \_

@ASTNode parse_expression: [ @Parser pr | I32 min_prec ]
 | ; each level of nesting is a level of this recursion, and of the
 | ; checker's and codegen's after it: past this, the stack would give out
 | pr.depth += 1
 | IF [ pr.depth > 1000 ]
 |  | (diag_fatal)[ pr.curr.loc | "this expression nests more than %s deep%s" | "1000" | "" ]
 |  \_
 | @ASTNode lhs = 0
 |
 | I32 pfx = (prefix_precendence)[ pr ]
 | IF [ pfx > 0 ]
 |  | Token op_tok = pr.curr
 |  | (parser_next)[ pr ]
 |  |
 |  | @ASTNode node = (ast_node_new)[ pr.ast ]
 |  | node.kind = NT_UNY_OP
 |  | node.as.uny_op.operand = (parse_expression)[ pr | pfx ]
 |  | (set_loc)[ node | op_tok ]
 |  |
 |  | IF [ op_tok.kind == TOK_QMARK ]
 |  |  | node.as.uny_op.kind = UOT_DEREF
 |  | ELIF [ op_tok.kind == TOK_AT ]
 |  |  | node.as.uny_op.kind = UOT_REF
 |  | ELIF [ (strcmp)[ op_tok.lexeme | "!" ] == 0 ]
 |  |  | node.as.uny_op.kind = UOT_NOT
 |  | ELIF [ (strcmp)[ op_tok.lexeme | "~" ] == 0 ]
 |  |  | node.as.uny_op.kind = UOT_BNOT
 |  | ELSE
 |  |  | node.as.uny_op.kind = UOT_NEG
 |  |  \_
 |  |
 |  | lhs = node
 | ELSE
 |  | lhs = (parse_primary)[ pr ]
 |  \_
 |
 | LOOP
 |  | I32 prec = (infix_precendence)[ pr ]
 |  | IF [ prec < min_prec ]
 |  |  | BREAK
 |  |  \_
 |  |
 |  | Token op_tok = pr.curr
 |  | (parser_next)[ pr ]
 |  |
 |  | ; x{i} -- the element i places past what x points at
 |  | IF [ op_tok.kind == TOK_LBRACE ]
 |  |  | @ASTNode idx = (ast_node_new)[ pr.ast ]
 |  |  | idx.kind = NT_BIN_OP
 |  |  | (set_loc)[ idx | op_tok ]
 |  |  | idx.as.bin_op.kind = BOT_INDEX
 |  |  | idx.as.bin_op.left = lhs
 |  |  | B1 was = pr.in_list
 |  |  | pr.in_list = FALSE
 |  |  | idx.as.bin_op.right = (parse_expr)[ pr ]
 |  |  | pr.in_list = was
 |  |  | (expect)[ pr | TOK_RBRACE ]
 |  |  | lhs = idx
 |  |  | CONTINUE
 |  |  \_
 |  |
 |  | IF [ op_tok.kind == TOK_AS ]
 |  |  | @ASTNode cast = (ast_node_new)[ pr.ast ]
 |  |  | cast.kind = NT_CAST
 |  |  | (set_loc)[ cast | op_tok ]
 |  |  | B1 was = pr.in_cast
 |  |  | pr.in_cast = TRUE
 |  |  | cast.as.cast.type = (parse_type)[ pr ]
 |  |  | pr.in_cast = was
 |  |  | cast.as.cast.expr = lhs
 |  |  | lhs = cast
 |  |  | CONTINUE
 |  |  \_
 |  |
 |  | I32 next_min = prec + 1
 |  | @ASTNode rhs = (parse_expression)[ pr | next_min ]
 |  |
 |  | @ASTNode node = (ast_node_new)[ pr.ast ]
 |  | node.kind = NT_BIN_OP
 |  | (set_loc)[ node | op_tok ]
 |  |
 |  | I32 bk = (binop_kind_of)[ op_tok ]
 |  | IF [ bk >= 0 ]
 |  |  | node.as.bin_op.kind = bk
 |  |  | node.as.bin_op.left = lhs
 |  |  | node.as.bin_op.right = rhs
 |  | ELSE
 |  |  | ; compound assignment: a op= b becomes a = a op b
 |  |  | @ASTNode inner = (ast_node_new)[ pr.ast ]
 |  |  | inner.kind = NT_BIN_OP
 |  |  | (set_loc)[ inner | op_tok ]
 |  |  | inner.as.bin_op.left = lhs
 |  |  | inner.as.bin_op.right = rhs
 |  |  | C1 c0 = ?(op_tok.lexeme)
 |  |  | IF [ c0 == '+' ]
 |  |  |  | inner.as.bin_op.kind = BOT_PLUS
 |  |  | ELIF [ c0 == '-' ]
 |  |  |  | inner.as.bin_op.kind = BOT_MINUS
 |  |  | ELIF [ c0 == '*' ]
 |  |  |  | inner.as.bin_op.kind = BOT_MULT
 |  |  | ELIF [ c0 == '/' ]
 |  |  |  | inner.as.bin_op.kind = BOT_DIV
 |  |  | ELIF [ c0 == '&' ]
 |  |  |  | inner.as.bin_op.kind = BOT_BAND
 |  |  | ELIF [ c0 == '^' ]
 |  |  |  | inner.as.bin_op.kind = BOT_BXOR
 |  |  | ELIF [ c0 == '|' ]
 |  |  |  | inner.as.bin_op.kind = BOT_BOR
 |  |  | ELIF [ c0 == '<' ]
 |  |  |  | inner.as.bin_op.kind = BOT_SHL
 |  |  | ELIF [ c0 == '>' ]
 |  |  |  | inner.as.bin_op.kind = BOT_SHR
 |  |  | ELSE
 |  |  |  | inner.as.bin_op.kind = BOT_MOD
 |  |  |  \_
 |  |  |
 |  |  | @ASTNode wrap = (ast_node_new)[ pr.ast ]
 |  |  | wrap.kind = NT_EXPR
 |  |  | wrap.as.expr.kind = ET_BIN_OP
 |  |  | wrap.as.expr.expr = inner
 |  |  | (set_loc)[ wrap | op_tok ]
 |  |  |
 |  |  | node.as.bin_op.kind = BOT_ASSIGN
 |  |  | node.as.bin_op.left = lhs
 |  |  | node.as.bin_op.right = wrap
 |  |  \_
 |  |
 |  | lhs = node
 |  \_
 |
 | pr.depth -= 1
 | RET [ lhs ]
 \_

@ASTNode parse_expr_prec: [ @Parser pr | I32 min_prec ]
 | @ASTNode e = (ast_node_new)[ pr.ast ]
 | e.kind = NT_EXPR
 | (set_loc)[ e | pr.curr ]
 |
 | e.as.expr.expr = (parse_expression)[ pr | min_prec ]
 | I32 k = e.as.expr.expr.kind
 |
 | IF [ k == NT_UNY_OP ]
 |  | e.as.expr.kind = ET_UNY_OP
 | ELIF [ k == NT_IDENT || k == NT_FN_INST ]
 |  | ; max<I32> becomes a name once generic.pl has made it
 |  | e.as.expr.kind = ET_IDENT
 | ELIF [ k == NT_BIN_OP ]
 |  | e.as.expr.kind = ET_BIN_OP
 | ELIF [ k == NT_LITERAL || k == NT_INIT ]
 |  | e.as.expr.kind = ET_LITERAL
 | ELIF [ k == NT_FN_CALL ]
 |  | e.as.expr.kind = ET_FN_CALL
 | ELIF [ k == NT_EXPR ]
 |  | e.as.expr.kind = ET_EXPR
 | ELIF [ k == NT_BUILTIN ]
 |  | e.as.expr.kind = ET_BUILTIN
 | ELIF [ k == NT_CAST ]
 |  | e.as.expr.kind = ET_CAST
 | ELSE
 |  | (diag_internal)[ "parse_expr: unexpected node kind %s" | (itoa)[ k ] ]
 |  \_
 |
 | RET [ e ]
 \_

@ASTNode parse_expr: [ @Parser pr ]
 | RET [ (parse_expr_prec)[ pr | 0 ] ]
 \_

@ASTNode parse_stmt: [ @Parser pr ]
@ASTNode parse_block: [ @Parser pr ]

@ASTNode parse_return: [ @Parser pr ]
 | @ASTNode ret = (ast_node_new)[ pr.ast ]
 | ret.kind = NT_RET
 | ret.as.ret.expr = 0
 | (set_loc)[ ret | pr.curr ]
 |
 | (expect)[ pr | TOK_RET ]
 | IF [ !(match)[ pr | TOK_LBRACKET ] ]
 |  | RET [ ret ]
 |  \_
 |
 | ; RET [] -- void return
 | IF [ (match)[ pr | TOK_RBRACKET ] ]
 |  | RET [ ret ]
 |  \_
 |
 | ret.as.ret.expr = (parse_expr)[ pr ]
 | (expect)[ pr | TOK_RBRACKET ]
 | RET [ ret ]
 \_

@ASTNode parse_var_decl: [ @Parser pr ]
 | @ASTNode decl = (ast_node_new)[ pr.ast ]
 | decl.kind = NT_VAR_DECL
 | (set_loc)[ decl | pr.curr ]
 |
 | decl.as.var_decl.type = (parse_type)[ pr ]
 | decl.as.var_decl.ident = (parse_ident)[ pr ]
 | decl.as.var_decl.init = 0
 | (parse_array_len)[ pr | decl.as.var_decl.type ]
 |
 | IF [ pr.curr.kind == TOK_OPERATOR ]
 |  | IF [ (strcmp)[ pr.curr.lexeme | "=" ] == 0 ]
 |  |  | (parser_next)[ pr ]
 |  |  | decl.as.var_decl.init = (parse_expr)[ pr ]
 |  |  \_
 |  \_
 |
 | RET [ decl ]
 \_

@ASTNode parse_block_if: [ @Parser pr ]
 | Token start = pr.curr
 | (expect)[ pr | TOK_NEWLINE ]
 | (check_indent)[ pr | start ]
 |
 | @ASTNode block = (ast_node_new)[ pr.ast ]
 | block.kind = NT_BLOCK
 | block.as.block.stmts = 0
 | (set_loc)[ block | start ]
 |
 | @@ASTNode tail = @(block.as.block.stmts)
 |
 | LOOP
 |  | WHILE [ pr.curr.kind == TOK_NEWLINE ]
 |  |  | (check_indent)[ pr | pr.curr ]
 |  |  | (parser_next)[ pr ]
 |  |  \_
 |  |
 |  | @ASTNode st = (parse_stmt)[ pr ]
 |  | ?(tail) = st
 |  | tail = @(st.as.stmt.next_stmt)
 |  |
 |  | LOOP
 |  |  | IF [ pr.curr.kind != TOK_NEWLINE ]
 |  |  |  | BREAK
 |  |  |  \_
 |  |  | IF [ pr.curr.indent == pr.indent || pr.curr.indent == 0 ]
 |  |  |  | (parser_next)[ pr ]
 |  |  | ELIF [ pr.curr.indent == pr.indent - 1 ]
 |  |  |  | (parser_next)[ pr ]
 |  |  |  | BREAK
 |  |  | ELSE
 |  |  |  | (unexpected)[ pr ]
 |  |  |  \_
 |  |  \_
 |  |
 |  | IF [ pr.curr.kind == TOK_END_BLOCK ]
 |  |  | BREAK
 |  |  \_
 |  | IF [ pr.curr.kind == TOK_ELIF || pr.curr.kind == TOK_ELSE || pr.curr.kind == TOK_CASE ]
 |  |  | BREAK
 |  |  \_
 |  \_
 |
 | RET [ block ]
 \_

; SWITCH [ expr ]
; CASE [ A | B ]        its lines sit at the SWITCH's own depth
;  | ...
; ELSE
;  | ...
;  \_
@ASTNode parse_switch: [ @Parser pr ]
 | @ASTNode sw = (ast_node_new)[ pr.ast ]
 | sw.kind = NT_SWITCH
 | (set_loc)[ sw | pr.curr ]
 | (expect)[ pr | TOK_SWITCH ]
 | (expect)[ pr | TOK_LBRACKET ]
 | sw.as.switch.expr = (parse_expr)[ pr ]
 | (expect)[ pr | TOK_RBRACKET ]
 | WHILE [ pr.curr.kind == TOK_NEWLINE ]
 |  | (check_indent)[ pr | pr.curr ]
 |  | (parser_next)[ pr ]
 |  \_
 | IF [ pr.curr.kind != TOK_CASE ]
 |  | (diag_fatal)[ pr.curr.loc | "a SWITCH goes on with CASE [ ... ], found %s%s" | (tok_desc)[ pr.curr ] | "" ]
 |  \_
 |
 | @@ASTNode tail = @(sw.as.switch.cases)
 | LOOP
 |  | IF [ (match)[ pr | TOK_ELSE ] ]
 |  |  | pr.indent = pr.indent + 1
 |  |  | sw.as.switch.else_block = (parse_block)[ pr ]
 |  |  | pr.indent = pr.indent - 1
 |  |  | RET [ sw ]
 |  |  \_
 |  | @ASTNode cs = (ast_node_new)[ pr.ast ]
 |  | cs.kind = NT_CASE
 |  | (set_loc)[ cs | pr.curr ]
 |  | (expect)[ pr | TOK_CASE ]
 |  | (expect)[ pr | TOK_LBRACKET ]
 |  | B1 was = pr.in_list
 |  | pr.in_list = TRUE
 |  | @@ASTNode vtail = @(cs.as.case.values)
 |  | LOOP
 |  |  | @ASTNode item = (ast_node_new)[ pr.ast ]
 |  |  | item.kind = NT_LIST
 |  |  | (set_loc)[ item | pr.curr ]
 |  |  | item.as.list.item = (parse_expr)[ pr ]
 |  |  | ?(vtail) = item
 |  |  | vtail = @(item.as.list.next)
 |  |  | IF [ !(match)[ pr | TOK_VBAR ] ]
 |  |  |  | BREAK
 |  |  |  \_
 |  |  \_
 |  | pr.in_list = was
 |  | (expect)[ pr | TOK_RBRACKET ]
 |  | pr.indent = pr.indent + 1
 |  | cs.as.case.block = (parse_block_if)[ pr ]
 |  | pr.indent = pr.indent - 1
 |  | ?(tail) = cs
 |  | tail = @(cs.as.case.next)
 |  | IF [ (match)[ pr | TOK_END_BLOCK ] ]
 |  |  | RET [ sw ]
 |  |  \_
 |  | IF [ pr.curr.kind != TOK_CASE && pr.curr.kind != TOK_ELSE ]
 |  |  | (diag_fatal)[ pr.curr.loc | "expected CASE, ELSE or the end of the SWITCH, found %s%s" | (tok_desc)[ pr.curr ] | "" ]
 |  |  \_
 |  \_
 | RET [ sw ]
 \_

@ASTNode parse_cond_stmt: [ @Parser pr ]
 | @ASTNode cond = (ast_node_new)[ pr.ast ]
 | cond.kind = NT_COND
 | cond.as.cond.elif_part = 0
 | cond.as.cond.else_part = 0
 | (set_loc)[ cond | pr.curr ]
 |
 | @ASTNode if_p = (ast_node_new)[ pr.ast ]
 | if_p.kind = NT_IF
 | (set_loc)[ if_p | pr.curr ]
 | (expect)[ pr | TOK_IF ]
 | (expect)[ pr | TOK_LBRACKET ]
 | if_p.as.if_cond.expr = (parse_expr)[ pr ]
 | (expect)[ pr | TOK_RBRACKET ]
 |
 | pr.indent = pr.indent + 1
 | if_p.as.if_cond.block = (parse_block_if)[ pr ]
 | pr.indent = pr.indent - 1
 |
 | cond.as.cond.if_part = if_p
 |
 | IF [ (match)[ pr | TOK_END_BLOCK ] ]
 |  | RET [ cond ]
 |  \_
 |
 | @@ASTNode elif_tail = @(cond.as.cond.elif_part)
 | WHILE [ (match)[ pr | TOK_ELIF ] ]
 |  | @ASTNode elif_p = (ast_node_new)[ pr.ast ]
 |  | elif_p.kind = NT_ELIF
 |  | (set_loc)[ elif_p | pr.curr ]
 |  | (expect)[ pr | TOK_LBRACKET ]
 |  | elif_p.as.elif_cond.expr = (parse_expr)[ pr ]
 |  | (expect)[ pr | TOK_RBRACKET ]
 |  |
 |  | pr.indent = pr.indent + 1
 |  | elif_p.as.elif_cond.block = (parse_block_if)[ pr ]
 |  | pr.indent = pr.indent - 1
 |  |
 |  | ?(elif_tail) = elif_p
 |  | elif_tail = @(elif_p.as.elif_cond.next_elif)
 |  |
 |  | IF [ (match)[ pr | TOK_END_BLOCK ] ]
 |  |  | RET [ cond ]
 |  |  \_
 |  \_
 |
 | IF [ (match)[ pr | TOK_ELSE ] ]
 |  | @ASTNode else_p = (ast_node_new)[ pr.ast ]
 |  | else_p.kind = NT_ELSE
 |  | (set_loc)[ else_p | pr.curr ]
 |  |
 |  | pr.indent = pr.indent + 1
 |  | else_p.as.else_cond.block = (parse_block)[ pr ]
 |  | pr.indent = pr.indent - 1
 |  |
 |  | cond.as.cond.else_part = else_p
 |  \_
 |
 | RET [ cond ]
 \_

@ASTNode parse_while: [ @Parser pr ]
 | @ASTNode loop = (ast_node_new)[ pr.ast ]
 | loop.kind = NT_LOOP
 | (set_loc)[ loop | pr.curr ]
 |
 | (expect)[ pr | TOK_WHILE ]
 | (expect)[ pr | TOK_LBRACKET ]
 | loop.as.loop.expr = (parse_expr)[ pr ]
 | (expect)[ pr | TOK_RBRACKET ]
 |
 | pr.indent = pr.indent + 1
 | loop.as.loop.block = (parse_block)[ pr ]
 | pr.indent = pr.indent - 1
 | RET [ loop ]
 \_

; FOR [ I32 i = 0 | i < n | i += 1 ]: the first part a declaration or
; an expression, scoped to the loop.
@ASTNode parse_for: [ @Parser pr ]
 | @ASTNode loop = (ast_node_new)[ pr.ast ]
 | loop.kind = NT_LOOP
 | (set_loc)[ loop | pr.curr ]
 |
 | (expect)[ pr | TOK_FOR ]
 | (expect)[ pr | TOK_LBRACKET ]
 | B1 was = pr.in_list
 | pr.in_list = TRUE
 | @ASTNode init = (ast_node_new)[ pr.ast ]
 | init.kind = NT_STMT
 | (set_loc)[ init | pr.curr ]
 | IF [ (is_var_decl)[ pr ] ]
 |  | init.as.stmt.kind = ST_VAR_DECL
 |  | init.as.stmt.stmt = (parse_var_decl)[ pr ]
 | ELSE
 |  | init.as.stmt.kind = ST_EXPR
 |  | init.as.stmt.stmt = (parse_expr)[ pr ]
 |  \_
 | loop.as.loop.init = init
 | (expect)[ pr | TOK_VBAR ]
 | loop.as.loop.expr = (parse_expr)[ pr ]
 | (expect)[ pr | TOK_VBAR ]
 | loop.as.loop.step = (parse_expr)[ pr ]
 | pr.in_list = was
 | (expect)[ pr | TOK_RBRACKET ]
 |
 | pr.indent = pr.indent + 1
 | loop.as.loop.block = (parse_block)[ pr ]
 | pr.indent = pr.indent - 1
 | RET [ loop ]
 \_

@ASTNode parse_loop: [ @Parser pr ]
 | @ASTNode loop = (ast_node_new)[ pr.ast ]
 | loop.kind = NT_LOOP
 | loop.as.loop.expr = 0
 | (set_loc)[ loop | pr.curr ]
 |
 | (expect)[ pr | TOK_LOOP ]
 | pr.indent = pr.indent + 1
 | loop.as.loop.block = (parse_block)[ pr ]
 | pr.indent = pr.indent - 1
 | RET [ loop ]
 \_

@ASTNode parse_stmt: [ @Parser pr ]
 | @ASTNode stmt = (ast_node_new)[ pr.ast ]
 | stmt.kind = NT_STMT
 | stmt.as.stmt.next_stmt = 0
 | (set_loc)[ stmt | pr.curr ]
 |
 | IF [ pr.curr.kind == TOK_RET ]
 |  | stmt.as.stmt.kind = ST_RET
 |  | stmt.as.stmt.stmt = (parse_return)[ pr ]
 | ELIF [ (match)[ pr | TOK_BREAK ] ]
 |  | stmt.as.stmt.kind = ST_BREAK
 |  | stmt.as.stmt.stmt = 0
 | ELIF [ (match)[ pr | TOK_CONTINUE ] ]
 |  | stmt.as.stmt.kind = ST_CONTINUE
 |  | stmt.as.stmt.stmt = 0
 | ELIF [ pr.curr.kind == TOK_WHILE ]
 |  | stmt.as.stmt.kind = ST_LOOP
 |  | stmt.as.stmt.stmt = (parse_while)[ pr ]
 | ELIF [ pr.curr.kind == TOK_FOR ]
 |  | stmt.as.stmt.kind = ST_LOOP
 |  | stmt.as.stmt.stmt = (parse_for)[ pr ]
 | ELIF [ pr.curr.kind == TOK_SWITCH ]
 |  | stmt.as.stmt.kind = ST_SWITCH
 |  | stmt.as.stmt.stmt = (parse_switch)[ pr ]
 | ELIF [ (match)[ pr | TOK_POSTLUDE ] ]
 |  | ; one statement on its line, or a block under it
 |  | stmt.as.stmt.kind = ST_POSTLUDE
 |  | IF [ pr.curr.kind == TOK_NEWLINE ]
 |  |  | pr.indent = pr.indent + 1
 |  |  | stmt.as.stmt.stmt = (parse_block)[ pr ]
 |  |  | pr.indent = pr.indent - 1
 |  | ELSE
 |  |  | stmt.as.stmt.stmt = (parse_stmt)[ pr ]
 |  |  \_
 | ELIF [ (is_var_decl)[ pr ] ]
 |  | stmt.as.stmt.kind = ST_VAR_DECL
 |  | stmt.as.stmt.stmt = (parse_var_decl)[ pr ]
 | ELIF [ pr.curr.kind == TOK_IF ]
 |  | stmt.as.stmt.kind = ST_COND
 |  | stmt.as.stmt.stmt = (parse_cond_stmt)[ pr ]
 | ELIF [ pr.curr.kind == TOK_LOOP ]
 |  | stmt.as.stmt.kind = ST_LOOP
 |  | stmt.as.stmt.stmt = (parse_loop)[ pr ]
 | ELSE
 |  | stmt.as.stmt.kind = ST_EXPR
 |  | stmt.as.stmt.stmt = (parse_expr)[ pr ]
 |  \_
 |
 | RET [ stmt ]
 \_

@ASTNode parse_block: [ @Parser pr ]
 | @ASTNode block = (ast_node_new)[ pr.ast ]
 | block.kind = NT_BLOCK
 | block.as.block.stmts = 0
 | (set_loc)[ block | pr.curr ]
 |
 | Token start = pr.curr
 | IF [ (match)[ pr | TOK_END_BLOCK ] ]
 |  | RET [ block ]
 |  \_
 |
 | (expect)[ pr | TOK_NEWLINE ]
 | (check_indent)[ pr | start ]
 |
 | @@ASTNode tail = @(block.as.block.stmts)
 |
 | LOOP
 |  | WHILE [ pr.curr.kind == TOK_NEWLINE ]
 |  |  | (check_indent)[ pr | pr.curr ]
 |  |  | (parser_next)[ pr ]
 |  |  \_
 |  |
 |  | @ASTNode st = (parse_stmt)[ pr ]
 |  | ?(tail) = st
 |  | tail = @(st.as.stmt.next_stmt)
 |  |
 |  | WHILE [ pr.curr.kind == TOK_NEWLINE ]
 |  |  | (check_indent)[ pr | pr.curr ]
 |  |  | (parser_next)[ pr ]
 |  |  \_
 |  |
 |  | IF [ (match)[ pr | TOK_END_BLOCK ] ]
 |  |  | BREAK
 |  |  \_
 |  \_
 |
 | RET [ block ]
 \_

; IFACE Name<T>: [ @Data<T> me ]
;  + PUBLIC:
;  | I32 method: [ ... ]
;  |  | ...
;  |  \_
;  + PRIVATE:
;  | ...
;  \_
; REQ [ ... ] after an IFACE's receiver or a generic function's
; parameters, on that line or on the lines under it; it may span several.
;   I32 hp                 a field of the class's struct
;   Named<T>               another interface the class takes
;   BUS IMPL SPIBus<BUS>   an interface the type put for BUS takes
; 0 when there is none.
@ASTNode parse_reqs: [ @Parser pr ]
 | IF [ pr.curr.kind == TOK_NEWLINE ]
 |  | I32 ahead = 1
 |  | WHILE [ (parser_peek)[ pr | ahead ].kind == TOK_NEWLINE ]
 |  |  | ahead += 1
 |  |  \_
 |  | Token nx = (parser_peek)[ pr | ahead ]
 |  | IF [ nx.kind == TOK_IDENTIFIER && (strcmp)[ nx.lexeme | "REQ" ] == 0 ]
 |  |  | WHILE [ ahead > 0 ]
 |  |  |  | (parser_next)[ pr ]
 |  |  |  | ahead -= 1
 |  |  |  \_
 |  |  \_
 |  \_
 | IF [ pr.curr.kind != TOK_IDENTIFIER || (strcmp)[ pr.curr.lexeme | "REQ" ] != 0 ]
 |  | RET [ 0 ]
 |  \_
 | (parser_next)[ pr ]
 | (expect)[ pr | TOK_LBRACKET ]
 | @ASTNode head = 0
 | @@ASTNode rtail = @head
 | LOOP
 |  | (skip_newlines)[ pr ]
 |  | @ASTNode item = (ast_node_new)[ pr.ast ]
 |  | item.kind = NT_LIST
 |  | (set_loc)[ item | pr.curr ]
 |  | @ASTNode ty = (parse_type)[ pr ]
 |  | IF [ pr.curr.kind == TOK_IDENTIFIER ]
 |  |  | @ASTNode f = (ast_node_new)[ pr.ast ]
 |  |  | f.kind = NT_FIELD
 |  |  | f.loc = ty.loc
 |  |  | f.as.rcrd_flds.type = ty
 |  |  | f.as.rcrd_flds.ident = (parse_ident)[ pr ]
 |  |  | item.as.list.item = f
 |  | ELIF [ (match)[ pr | TOK_IMPL ] ]
 |  |  | @ASTNode ri = (ast_node_new)[ pr.ast ]
 |  |  | ri.kind = NT_REQ_IMPL
 |  |  | ri.loc = ty.loc
 |  |  | ri.as.req_impl.subject = ty
 |  |  | ri.as.req_impl.iface = (parse_type)[ pr ]
 |  |  | item.as.list.item = ri
 |  | ELSE
 |  |  | item.as.list.item = ty
 |  |  \_
 |  | ?(rtail) = item
 |  | rtail = @(item.as.list.next)
 |  | (skip_newlines)[ pr ]
 |  | IF [ !(match)[ pr | TOK_VBAR ] ]
 |  |  | BREAK
 |  |  \_
 |  \_
 | (expect)[ pr | TOK_RBRACKET ]
 | RET [ head ]
 \_

@ASTNode parse_iface: [ @Parser pr ]
 | @ASTNode ifc = (ast_node_new)[ pr.ast ]
 | ifc.kind = NT_IFACE
 | (set_loc)[ ifc | pr.curr ]
 |
 | (expect)[ pr | TOK_IFACE ]
 | ifc.as.iface.ident = (parse_ident)[ pr ]
 | ifc.as.iface.gparams = (parse_gparams)[ pr ]
 | (expect)[ pr | TOK_COLON ]
 |
 | Token at = pr.curr
 | @ASTNode recv = (parse_params)[ pr ]
 | IF [ recv == 0 || recv.as.parametre.vaarg || recv.as.parametre.next_param != 0 ]
 |  | (diag_fatal)[ at.loc | "an IFACE takes exactly one receiver, as in [ @Data me ]%s%s" | "" | "" ]
 |  \_
 | ifc.as.iface.recv = recv
 |
 | ifc.as.iface.reqs = (parse_reqs)[ pr ]
 |
 | B1 private = FALSE
 | B1 anon = FALSE
 | @@ASTNode tail = @(ifc.as.iface.methods)
 |
 | LOOP
 |  | WHILE [ pr.curr.kind == TOK_NEWLINE ]
 |  |  | IF [ pr.curr.indent > 1 ]
 |  |  |  | Location at = pr.curr.loc
 |  |  |  | at.line = at.line + 1
 |  |  |  | at.col = 1
 |  |  |  | (diag_fatal)[ at | "this line is %s `|` deep, but a method starts at one%s" | (itoa)[ pr.curr.indent ] | "" ]
 |  |  |  \_
 |  |  | (parser_next)[ pr ]
 |  |  \_
 |  |
 |  | IF [ (match)[ pr | TOK_END_BLOCK ] ]
 |  |  | BREAK
 |  |  \_
 |  |
 |  | IF [ (is_op)[ pr.curr | "+" ] ]
 |  |  | (parser_next)[ pr ]
 |  |  | Token sec = pr.curr
 |  |  | (expect)[ pr | TOK_IDENTIFIER ]
 |  |  | anon = FALSE
 |  |  | IF [ (strcmp)[ sec.lexeme | "PUBLIC" ] == 0 ]
 |  |  |  | private = FALSE
 |  |  | ELIF [ (strcmp)[ sec.lexeme | "PRIVATE" ] == 0 ]
 |  |  |  | private = TRUE
 |  |  | ELIF [ (strcmp)[ sec.lexeme | "ANONYMOUS" ] == 0 ]
 |  |  |  | ; no `me`: called on the type, as (Option<I32>.some)[ 5 ]
 |  |  |  | private = FALSE
 |  |  |  | anon = TRUE
 |  |  | ELSE
 |  |  |  | (diag_fatal)[ sec.loc | "expected PUBLIC, PRIVATE or ANONYMOUS, found `%s`%s" | sec.lexeme | "" ]
 |  |  |  \_
 |  |  | (expect)[ pr | TOK_COLON ]
 |  |  | CONTINUE
 |  |  \_
 |  |
 |  | @ASTNode m = (ast_node_new)[ pr.ast ]
 |  | m.kind = NT_METHOD
 |  | (set_loc)[ m | pr.curr ]
 |  | m.as.method.is_private = private
 |  | m.as.method.is_anon = anon
 |  |
 |  | @ASTNode decl = (parse_fn_decl)[ pr | 0 ]
 |  | ; a body is a run of `|  |` lines, or an empty `|  \_`; the IFACE's
 |  | ; own `\_` right after the header means there is none
 |  | B1 has_block = pr.curr.kind == TOK_END_BLOCK && pr.curr.indent == 1
 |  | IF [ pr.curr.kind == TOK_NEWLINE && pr.curr.indent == 2 ]
 |  |  | has_block = TRUE
 |  |  \_
 |  | ; with no body, the method is required: the interface needs it, and
 |  | ; another interface of the same class must give it
 |  | @ASTNode def = (ast_node_new)[ pr.ast ]
 |  | def.kind = NT_FN_DEF
 |  | def.loc = decl.loc
 |  | def.as.fn_def.decl = decl
 |  | IF [ has_block ]
 |  |  | pr.indent = 2
 |  |  | def.as.fn_def.block = (parse_block)[ pr ]
 |  |  | pr.indent = 1
 |  | ELSE
 |  |  | m.as.method.is_req = TRUE
 |  |  \_
 |  |
 |  | m.as.method.def = def
 |  | ?(tail) = m
 |  | tail = @(m.as.method.next)
 |  \_
 |
 | RET [ ifc ]
 \_

; CLASS Name<T>: Data<T> IMPL [ Face<T> | Other<T> ]
@ASTNode parse_class: [ @Parser pr ]
 | @ASTNode cls = (ast_node_new)[ pr.ast ]
 | cls.kind = NT_CLASS
 | (set_loc)[ cls | pr.curr ]
 |
 | (expect)[ pr | TOK_CLASS ]
 | cls.as.klass.ident = (parse_ident)[ pr ]
 | cls.as.klass.gparams = (parse_gparams)[ pr ]
 | (expect)[ pr | TOK_COLON ]
 | cls.as.klass.base = (parse_type)[ pr ]
 |
 | IF [ (match)[ pr | TOK_IMPL ] ]
 |  | (expect)[ pr | TOK_LBRACKET ]
 |  | @@ASTNode tail = @(cls.as.klass.ifaces)
 |  | LOOP
 |  |  | @ASTNode item = (ast_node_new)[ pr.ast ]
 |  |  | item.kind = NT_LIST
 |  |  | (set_loc)[ item | pr.curr ]
 |  |  | item.as.list.item = (parse_type)[ pr ]
 |  |  | ?(tail) = item
 |  |  | tail = @(item.as.list.next)
 |  |  | IF [ !(match)[ pr | TOK_VBAR ] ]
 |  |  |  | BREAK
 |  |  |  \_
 |  |  \_
 |  | (expect)[ pr | TOK_RBRACKET ]
 |  \_
 | RET [ cls ]
 \_

@ASTNode parse_tu_stmt: [ @Parser pr ]
 | @ASTNode tu_stmt = (ast_node_new)[ pr.ast ]
 | tu_stmt.kind = NT_TU_STMT
 | (set_loc)[ tu_stmt | pr.curr ]
 |
 | IF [ pr.curr.kind == TOK_TYPE ]
 |  | tu_stmt.as.tu_stmt.kind = TUST_TYPE_DEF
 |  | tu_stmt.as.tu_stmt.tu_stmt = (parse_type_def)[ pr ]
 |  | RET [ tu_stmt ]
 |  \_
 | IF [ pr.curr.kind == TOK_IFACE ]
 |  | tu_stmt.as.tu_stmt.kind = TUST_IFACE
 |  | tu_stmt.as.tu_stmt.tu_stmt = (parse_iface)[ pr ]
 |  | RET [ tu_stmt ]
 |  \_
 | IF [ pr.curr.kind == TOK_CLASS ]
 |  | tu_stmt.as.tu_stmt.kind = TUST_CLASS
 |  | tu_stmt.as.tu_stmt.tu_stmt = (parse_class)[ pr ]
 |  | RET [ tu_stmt ]
 |  \_
 | ; STATIC_ASSERT [ cond ] or [ cond | "why" ]: checked while compiling,
 | ; leaves nothing behind
 | IF [ pr.curr.kind == TOK_STATIC_ASSERT ]
 |  | @ASTNode sa = (ast_node_new)[ pr.ast ]
 |  | sa.kind = NT_STATIC_ASSERT
 |  | (set_loc)[ sa | pr.curr ]
 |  | (parser_next)[ pr ]
 |  | (expect)[ pr | TOK_LBRACKET ]
 |  | ; as in an argument list, a bare `|` starts the message
 |  | pr.in_list = TRUE
 |  | sa.as.assert.cond = (parse_expr)[ pr ]
 |  | pr.in_list = FALSE
 |  | IF [ (match)[ pr | TOK_VBAR ] ]
 |  |  | IF [ pr.curr.kind != TOK_STRING ]
 |  |  |  | (diag_fatal)[ pr.curr.loc | "after `|`, STATIC_ASSERT takes a message in quotes, not %s%s" | (tok_desc)[ pr.curr ] | "" ]
 |  |  |  \_
 |  |  | sa.as.assert.msg = (parse_literal)[ pr ]
 |  |  \_
 |  | (expect)[ pr | TOK_RBRACKET ]
 |  | tu_stmt.as.tu_stmt.kind = TUST_STATIC_ASSERT
 |  | tu_stmt.as.tu_stmt.tu_stmt = sa
 |  | RET [ tu_stmt ]
 |  \_
 |
 | B1 is_decl_start = (starts_type)[ pr.curr ]
 |
 | IF [ is_decl_start && (is_tu_var_decl)[ pr ] ]
 |  | tu_stmt.as.tu_stmt.kind = TUST_VAR_DECL
 |  | tu_stmt.as.tu_stmt.tu_stmt = (parse_var_decl)[ pr ]
 |  | RET [ tu_stmt ]
 |  \_
 |
 | IF [ is_decl_start ]
 |  | @ASTNode gparams = 0
 |  | @ASTNode decl = (parse_fn_decl)[ pr | @gparams ]
 |  | @ASTNode reqs = 0
 |  | IF [ gparams != 0 ]
 |  |  | reqs = (parse_reqs)[ pr ]
 |  |  \_
 |  |
 |  | WHILE [ pr.curr.kind == TOK_NEWLINE && pr.curr.indent == 0 ]
 |  |  | (expect)[ pr | TOK_NEWLINE ]
 |  |  \_
 |  |
 |  | B1 has_block = FALSE
 |  | IF [ pr.curr.kind == TOK_NEWLINE && pr.curr.indent == 1 ]
 |  |  | has_block = TRUE
 |  | ELIF [ pr.curr.kind == TOK_END_BLOCK ]
 |  |  | has_block = TRUE
 |  |  \_
 |  |
 |  | IF [ gparams != 0 && !has_block ]
 |  |  | (diag_fatal)[ decl.loc | "generic function `%s` needs a body: it is copied for each use%s" | decl.as.fn_decl.ident.as.ident | "" ]
 |  |  \_
 |  | IF [ has_block ]
 |  |  | @ASTNode def = (ast_node_new)[ pr.ast ]
 |  |  | def.kind = NT_FN_DEF
 |  |  | def.loc = decl.loc
 |  |  | def.as.fn_def.decl = decl
 |  |  | tu_stmt.as.tu_stmt.kind = TUST_FN_DEF
 |  |  | tu_stmt.as.tu_stmt.tu_stmt = def
 |  |  | def.as.fn_def.block = (parse_block)[ pr ]
 |  |  | IF [ gparams != 0 ]
 |  |  |  | @ASTNode ft = (ast_node_new)[ pr.ast ]
 |  |  |  | ft.kind = NT_FN_TMPL
 |  |  |  | ft.loc = decl.loc
 |  |  |  | ft.as.fn_tmpl.def = def
 |  |  |  | ft.as.fn_tmpl.gparams = gparams
 |  |  |  | ft.as.fn_tmpl.reqs = reqs
 |  |  |  | tu_stmt.as.tu_stmt.kind = TUST_FN_TMPL
 |  |  |  | tu_stmt.as.tu_stmt.tu_stmt = ft
 |  |  |  \_
 |  | ELSE
 |  |  | tu_stmt.as.tu_stmt.kind = TUST_FN_DECL
 |  |  | tu_stmt.as.tu_stmt.tu_stmt = decl
 |  |  \_
 |  |
 |  | RET [ tu_stmt ]
 |  \_
 |
 | (unexpected)[ pr ]
 | RET [ 0 ]
 \_

ABYSS parse_file: [ @AST ast | @String source | @C1 name ]

ABYSS parse_unit: [ @AST ast | @String source ]
 | (parse_file)[ ast | source | NULL ]
 \_

; `name` is how diagnostics call the root file.
ABYSS parse_file: [ @AST ast | @String source | @C1 name ]
 | Parser parser
 | parser.ast = ast
 | parser.indent = 1
 | parser.in_cast = FALSE
 | parser.in_list = FALSE
 | parser.depth = 0
 | (lexer_init)[ @(parser.lexer) | source ]
 | (lexer_set_file)[ @(parser.lexer) | name ]
 |
 | @@ASTNode tu_tail = @(ast.root.as.tu.tu_stmt)
 |
 | (parser_next)[ @parser ]
 |
 | I32 line_indent = 0
 | WHILE [ parser.curr.kind != TOK_EOF ]
 |  | IF [ parser.curr.kind == TOK_NEWLINE ]
 |  |  | line_indent = parser.curr.indent
 |  |  | (parser_next)[ @parser ]
 |  |  | CONTINUE
 |  |  \_
 |  | ; a `|` line out here belongs to no block
 |  | IF [ line_indent != 0 ]
 |  |  | (diag_fatal)[ parser.curr.loc | "a statement outside any block; top-level declarations start in column 1%s%s" | "" | "" ]
 |  |  \_
 |  |
 |  | @ASTNode ts = (parse_tu_stmt)[ @parser ]
 |  | ?(tu_tail) = ts
 |  | tu_tail = @(ts.as.tu_stmt.next_tu_stmt)
 |  \_
 | RET
 \_
