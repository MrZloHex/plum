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
ABYSS unexpected: [ @Parser pr ]
 | (printf)[ "%d:%d: Unexpected %s\n" | pr.curr.loc.line | pr.curr.loc.col | (token_str)[ pr.curr.kind ] ]
 | (exit)[ 1 ]
 | RET
 \_

ABYSS expect: [ @Parser pr | I32 t ]
 | IF [ pr.curr.kind != t ]
 |  | @C1 got  = (token_str)[ pr.curr.kind ]
 |  | @C1 want = (token_str)[ t ]
 |  | (printf)[ "%d:%d: Unexpected %s, expected %s\n" | pr.curr.loc.line | pr.curr.loc.col | got | want ]
 |  | (exit)[ 1 ]
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
 |  | (printf)[ "%d:%d: Wrong indentation %d, needed %d\n" | pr.curr.loc.line | pr.curr.loc.col | tok.indent | pr.indent ]
 |  | (exit)[ 1 ]
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

@ASTNode parse_type: [ @Parser pr ]
 | @ASTNode type = (ast_node_new)[ pr.ast ]
 | type.kind = NT_TYPE
 | type.as.type.ptrs = 0
 |
 | Token start = pr.curr
 | WHILE [ (match)[ pr | TOK_AT ] ]
 |  | type.as.type.ptrs = type.as.type.ptrs + 1
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
 | RET [ type ]
 \_

@ASTNode parse_field: [ @Parser pr ]
 | @ASTNode field = (ast_node_new)[ pr.ast ]
 | field.kind = NT_FIELD
 | (set_loc)[ field | pr.curr ]
 | field.as.rcrd_flds.type = (parse_type)[ pr ]
 | field.as.rcrd_flds.ident = (parse_ident)[ pr ]
 | field.as.rcrd_flds.next_field = 0
 | RET [ field ]
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
 |  | (check_indent)[ pr | newline ]
 |  | @ASTNode f = (parse_field)[ pr ]
 |  | ?(tail) = f
 |  | tail = @(f.as.rcrd_flds.next_field)
 |  \_
 | (expect)[ pr | TOK_END_BLOCK ]
 | RET [ record ]
 \_

@ASTNode parse_enum_field: [ @Parser pr ]
 | @ASTNode field = (ast_node_new)[ pr.ast ]
 | field.kind = NT_ENUM_FIELDS
 | (set_loc)[ field | pr.curr ]
 | field.as.enum_flds.ident = (parse_ident)[ pr ]
 | field.as.enum_flds.next_field = 0
 | RET [ field ]
 \_

@ASTNode parse_enum: [ @Parser pr ]
 | @ASTNode en = (ast_node_new)[ pr.ast ]
 | en.kind = NT_ENUM
 | en.as.enumeration.fields = 0
 | (set_loc)[ en | pr.curr ]
 |
 | @@ASTNode tail = @(en.as.enumeration.fields)
 |
 | WHILE [ pr.curr.kind == TOK_NEWLINE ]
 |  | Token newline = pr.curr
 |  | (expect)[ pr | TOK_NEWLINE ]
 |  | (check_indent)[ pr | newline ]
 |  | @ASTNode f = (parse_enum_field)[ pr ]
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
 | ELIF [ pr.curr.kind == TOK_IDENTIFIER || pr.curr.kind == TOK_AT ]
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
 |  | ELIF [ pr.curr.kind == TOK_IDENTIFIER || pr.curr.kind == TOK_AT ]
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

@ASTNode parse_fn_decl: [ @Parser pr ]
 | @ASTNode fndecl = (ast_node_new)[ pr.ast ]
 | fndecl.kind = NT_FN_DECL
 | (set_loc)[ fndecl | pr.curr ]
 |
 | fndecl.as.fn_decl.type = (parse_type)[ pr ]
 | fndecl.as.fn_decl.ident = (parse_ident)[ pr ]
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
 | IF [ pr.curr.kind == TOK_DOT ]
 |  | RET [ 40 ]
 |  \_
 | IF [ pr.curr.kind == TOK_AS ]
 |  | RET [ 35 ]
 |  \_
 | IF [ pr.curr.kind == TOK_VBAR ]
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

B1 is_tu_var_decl: [ @Parser pr ]
 | Lexer lx = pr.lexer
 | Token tok = pr.curr
 | WHILE [ tok.kind == TOK_AT ]
 |  | tok = (lexer_next)[ @lx ]
 |  \_
 | IF [ tok.kind != TOK_IDENTIFIER ]
 |  | RET [ FALSE ]
 |  \_
 | Token t2 = (lexer_next)[ @lx ]
 | IF [ t2.kind != TOK_IDENTIFIER ]
 |  | RET [ FALSE ]
 |  \_
 | Token t3 = (lexer_next)[ @lx ]
 | RET [ t3.kind != TOK_COLON ]
 \_

B1 is_var_decl: [ @Parser pr ]
 | Lexer lx = pr.lexer
 | Token tok = pr.curr
 | WHILE [ tok.kind == TOK_AT ]
 |  | tok = (lexer_next)[ @lx ]
 |  \_
 | IF [ tok.kind != TOK_IDENTIFIER ]
 |  | RET [ FALSE ]
 |  \_
 | Token t2 = (lexer_next)[ @lx ]
 | RET [ t2.kind == TOK_IDENTIFIER ]
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
 |  | ; above VBAR's precedence: a bare `|` here separates arguments
 |  | arg.as.argument.argument = (parse_expr_prec)[ pr | 10 ]
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
 | I64 v = (strtoll)[ digits | 0 AS @@C1 | base ]
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
 | ELIF [ (match)[ pr | TOK_INTEGER ] ]
 |  | lit.as.literal.kind = LT_INTEGER
 |  | lit.as.literal.as.int_lit = (parse_int_lexeme)[ lex ] AS I32
 | ELIF [ (match)[ pr | TOK_CHARACTER ] ]
 |  | lit.as.literal.kind = LT_CHARACTER
 |  | lit.as.literal.as.char_lit = (unescape_char)[ lex ] AS C1
 | ELIF [ (match)[ pr | TOK_STRING ] ]
 |  | lit.as.literal.kind = LT_STRING
 |  | lit.as.literal.as.str_lit = lex
 | ELIF [ (match)[ pr | TOK_FLOAT ] ]
 |  | lit.as.literal.kind = LT_FLOAT
 |  | lit.as.literal.as.float_lit = (atof)[ lex ] AS F32
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
 |  | built.as.builtin.size = (parse_ident)[ pr ]
 |  | (expect)[ pr | TOK_RBRACKET ]
 | ELSE
 |  | (unexpected)[ pr ]
 |  \_
 | RET [ built ]
 \_

@ASTNode parse_primary: [ @Parser pr ]
 | IF [ pr.curr.kind == TOK_SIZE ]
 |  | RET [ (parse_builtin)[ pr ] ]
 |  \_
 | IF [ (is_fn_call)[ pr ] ]
 |  | RET [ (parse_fn_call)[ pr ] ]
 |  \_
 | IF [ (match)[ pr | TOK_LPAREN ] ]
 |  | @ASTNode e = (parse_expr)[ pr ]
 |  | (expect)[ pr | TOK_RPAREN ]
 |  | RET [ e ]
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
 | IF [ pr.curr.kind == TOK_TRUE || pr.curr.kind == TOK_FALSE ]
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
 |  | IF [ op_tok.kind == TOK_AS ]
 |  |  | @ASTNode cast = (ast_node_new)[ pr.ast ]
 |  |  | cast.kind = NT_CAST
 |  |  | (set_loc)[ cast | op_tok ]
 |  |  | cast.as.cast.type = (parse_type)[ pr ]
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
 | ELIF [ k == NT_IDENT ]
 |  | e.as.expr.kind = ET_IDENT
 | ELIF [ k == NT_BIN_OP ]
 |  | e.as.expr.kind = ET_BIN_OP
 | ELIF [ k == NT_LITERAL ]
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
 |  | (printf)[ "parse_expr: unexpected node kind %d\n" | k ]
 |  | (exit)[ 1 ]
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
 |  | IF [ pr.curr.kind == TOK_ELIF || pr.curr.kind == TOK_ELSE ]
 |  |  | BREAK
 |  |  \_
 |  \_
 |
 | RET [ block ]
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
 |
 | B1 is_decl_start = pr.curr.kind == TOK_AT || pr.curr.kind == TOK_IDENTIFIER
 |
 | IF [ is_decl_start && (is_tu_var_decl)[ pr ] ]
 |  | tu_stmt.as.tu_stmt.kind = TUST_VAR_DECL
 |  | tu_stmt.as.tu_stmt.tu_stmt = (parse_var_decl)[ pr ]
 |  | RET [ tu_stmt ]
 |  \_
 |
 | IF [ is_decl_start ]
 |  | @ASTNode decl = (parse_fn_decl)[ pr ]
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
 |  | IF [ has_block ]
 |  |  | @ASTNode def = (ast_node_new)[ pr.ast ]
 |  |  | def.kind = NT_FN_DEF
 |  |  | def.loc = decl.loc
 |  |  | def.as.fn_def.decl = decl
 |  |  | tu_stmt.as.tu_stmt.kind = TUST_FN_DEF
 |  |  | tu_stmt.as.tu_stmt.tu_stmt = def
 |  |  | def.as.fn_def.block = (parse_block)[ pr ]
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

ABYSS parse_unit: [ @AST ast | @String source ]
 | Parser parser
 | parser.ast = ast
 | parser.indent = 1
 | (lexer_init)[ @(parser.lexer) | source ]
 |
 | @@ASTNode tu_tail = @(ast.root.as.tu.tu_stmt)
 |
 | (parser_next)[ @parser ]
 |
 | WHILE [ parser.curr.kind != TOK_EOF ]
 |  | IF [ parser.curr.kind == TOK_NEWLINE ]
 |  |  | (parser_next)[ @parser ]
 |  |  | CONTINUE
 |  |  \_
 |  |
 |  | @ASTNode ts = (parse_tu_stmt)[ @parser ]
 |  | ?(tu_tail) = ts
 |  | tu_tail = @(ts.as.tu_stmt.next_tu_stmt)
 |  \_
 | RET
 \_
