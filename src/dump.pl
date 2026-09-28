; dump.pl -- `plc --emit=AST`: the syntax tree, as the parser built it
;
; One line per node, indented by depth, ending in its line:col. It runs
; before generics, so templates, IFACEs and CLASSes appear as written,
; and before the checker, so a program with type errors still dumps.
; `a += b` shows as `a = a + b`: that is what the parser makes of it.
;
;   == blink.pl
;   FN_DEF ABYSS delay                      6:7
;     PARAM U32 n                           6:21
;     BLOCK                                 7:2

!USES <ast.pl>
!USES <generic.pl>
!USES <../lib/string.pl>
!USES <../extern/stdio.pl>
!USES <../extern/string.pl>

@C1 dump_file          ; the file of the last top-level node, for == headers

; --- pieces of a line --------------------------------------------------------

ABYSS dump_type: [ @String s | @ASTNode tn ]

; ` [ T a | U b ]`: a parameter list, on one line
ABYSS dump_params: [ @String s | @ASTNode p ]
 | (s.append)[ "[" ]
 | WHILE [ p != 0 ]
 |  | (s.push)[ ' ' ]
 |  | IF [ p.as.parametre.vaarg ]
 |  |  | (s.append)[ "..." ]
 |  | ELSE
 |  |  | (dump_type)[ s | p.as.parametre.type ]
 |  |  | (s.push)[ ' ' ]
 |  |  | (s.append)[ p.as.parametre.ident.as.ident ]
 |  |  \_
 |  | p = p.as.parametre.next_param
 |  | IF [ p != 0 ]
 |  |  | (s.append)[ " |" ]
 |  |  \_
 |  \_
 | (s.append)[ " ]" ]
 \_

; `<A | B>` after a name: type arguments, or a template's parameters
ABYSS dump_args: [ @String s | @ASTNode l | B1 names ]
 | IF [ l == 0 ]
 |  | RET
 |  \_
 | (s.push)[ '<' ]
 | WHILE [ l != 0 ]
 |  | IF [ names ]
 |  |  | (s.append)[ l.as.list.item.as.ident ]
 |  |  \_
 |  | IF [ !names ]
 |  |  | (dump_type)[ s | l.as.list.item ]
 |  |  \_
 |  | l = l.as.list.next
 |  | IF [ l != 0 ]
 |  |  | (s.append)[ " | " ]
 |  |  \_
 |  \_
 | (s.push)[ '>' ]
 \_

ABYSS dump_type: [ @String s | @ASTNode tn ]
 | IF [ tn == 0 ]
 |  | (s.append)[ "?" ]
 |  | RET
 |  \_
 | U64 i = 0
 | WHILE [ i < tn.as.type.ptrs ]
 |  | (s.push)[ '@' ]
 |  | i += 1
 |  \_
 |
 | IF [ tn.as.type.kind == TT_FN_TYPE ]
 |  | (s.append)[ "FN " ]
 |  | (dump_type)[ s | tn.as.type.type ]
 |  | (s.append)[ " [" ]
 |  | @ASTNode p = tn.as.type.args
 |  | WHILE [ p != 0 ]
 |  |  | (s.push)[ ' ' ]
 |  |  | IF [ p.as.list.item == 0 ]
 |  |  |  | (s.append)[ "..." ]
 |  |  | ELSE
 |  |  |  | (dump_type)[ s | p.as.list.item ]
 |  |  |  \_
 |  |  | p = p.as.list.next
 |  |  | IF [ p != 0 ]
 |  |  |  | (s.append)[ " |" ]
 |  |  |  \_
 |  |  \_
 |  | (s.append)[ " ]" ]
 | ELIF [ tn.as.type.kind == TT_BASE_TYPE ]
 |  | (s.append)[ (base_type_name)[ tn.as.type.type.as.base_type ] ]
 | ELSE
 |  | (s.append)[ tn.as.type.type.as.ident ]
 |  | (dump_args)[ s | tn.as.type.args | FALSE ]
 |  \_
 |
 | IF [ tn.as.type.arr > 0 ]
 |  | C1 buf{24}
 |  | (snprintf)[ buf | 24 | "{%u}" | tn.as.type.arr ]
 |  | (s.append)[ buf ]
 |  \_
 \_

@C1 dump_binop: [ I32 k ]
 | IF [ k == BOT_ASSIGN ]
 |  | RET [ "=" ]
 | ELIF [ k == BOT_PLUS ]
 |  | RET [ "+" ]
 | ELIF [ k == BOT_MINUS ]
 |  | RET [ "-" ]
 | ELIF [ k == BOT_MULT ]
 |  | RET [ "*" ]
 | ELIF [ k == BOT_DIV ]
 |  | RET [ "/" ]
 | ELIF [ k == BOT_MOD ]
 |  | RET [ "%" ]
 | ELIF [ k == BOT_EQUAL ]
 |  | RET [ "==" ]
 | ELIF [ k == BOT_NEQ ]
 |  | RET [ "!=" ]
 | ELIF [ k == BOT_LESS ]
 |  | RET [ "<" ]
 | ELIF [ k == BOT_LEQ ]
 |  | RET [ "<=" ]
 | ELIF [ k == BOT_GREAT ]
 |  | RET [ ">" ]
 | ELIF [ k == BOT_GEQ ]
 |  | RET [ ">=" ]
 | ELIF [ k == BOT_AND ]
 |  | RET [ "&&" ]
 | ELIF [ k == BOT_OR ]
 |  | RET [ "||" ]
 | ELIF [ k == BOT_BAND ]
 |  | RET [ "&" ]
 | ELIF [ k == BOT_BOR ]
 |  | RET [ "|" ]
 | ELIF [ k == BOT_BXOR ]
 |  | RET [ "^" ]
 | ELIF [ k == BOT_SHL ]
 |  | RET [ "<<" ]
 | ELIF [ k == BOT_SHR ]
 |  | RET [ ">>" ]
 | ELIF [ k == BOT_MEMBER ]
 |  | RET [ "." ]
 | ELIF [ k == BOT_INDEX ]
 |  | RET [ "{}" ]
 |  \_
 | RET [ "?" ]
 \_

@C1 dump_unyop: [ I32 k ]
 | IF [ k == UOT_DEREF ]
 |  | RET [ "?" ]
 | ELIF [ k == UOT_REF ]
 |  | RET [ "@" ]
 | ELIF [ k == UOT_NEG ]
 |  | RET [ "-" ]
 | ELIF [ k == UOT_NOT ]
 |  | RET [ "!" ]
 |  \_
 | RET [ "~" ]
 \_

; A literal as it could be written back.
ABYSS dump_literal: [ @String s | @ASTNode n ]
 | I32 k = n.as.literal.kind
 | C1 buf{64}
 | IF [ k == LT_INTEGER ]
 |  | (snprintf)[ buf | 64 | "INT %ld" | n.as.literal.as.int_lit ]
 |  | (s.append)[ buf ]
 | ELIF [ k == LT_FLOAT ]
 |  | (snprintf)[ buf | 64 | "FLOAT %g" | n.as.literal.as.float_lit ]
 |  | (s.append)[ buf ]
 | ELIF [ k == LT_BOOLEAN ]
 |  | IF [ n.as.literal.as.bool_lit ]
 |  |  | (s.append)[ "BOOL TRUE" ]
 |  | ELSE
 |  |  | (s.append)[ "BOOL FALSE" ]
 |  |  \_
 | ELIF [ k == LT_CHARACTER ]
 |  | I32 ch = (n.as.literal.as.char_lit AS I32) & 255
 |  | IF [ ch >= 32 && ch < 127 && ch != 39 && ch != 92 ]
 |  |  | (snprintf)[ buf | 64 | "CHAR '%c'" | ch ]
 |  | ELIF [ ch == 10 ]
 |  |  | (snprintf)[ buf | 64 | "CHAR '\\n'" ]
 |  | ELIF [ ch == 9 ]
 |  |  | (snprintf)[ buf | 64 | "CHAR '\\t'" ]
 |  | ELIF [ ch == 0 ]
 |  |  | (snprintf)[ buf | 64 | "CHAR '\\0'" ]
 |  | ELIF [ ch == 39 || ch == 92 ]
 |  |  | (snprintf)[ buf | 64 | "CHAR '\\%c'" | ch ]
 |  | ELSE
 |  |  | (snprintf)[ buf | 64 | "CHAR '\\x%02x'" | ch ]
 |  |  \_
 |  | (s.append)[ buf ]
 | ELSE
 |  | ; the parser keeps a string as written, quotes and escapes included
 |  | (s.append)[ "STRING " ]
 |  | (s.append)[ n.as.literal.as.str_lit ]
 |  \_
 \_

; --- lines -------------------------------------------------------------------

; Print one node's line: indent, text, and where it came from, aligned.
ABYSS dump_line: [ I32 depth | @String text | @ASTNode at ]
 | I32 w = depth * 2 + (text.size AS I32)
 | (printf)[ "%*s%s" | depth * 2 | "" | text.data ]
 | IF [ at != 0 && at.loc.line > 0 ]
 |  | I32 pad = 44 - w
 |  | IF [ pad < 2 ]
 |  |  | pad = 2
 |  |  \_
 |  | (printf)[ "%*s%d:%d" | pad | "" | at.loc.line | at.loc.col ]
 |  \_
 | (printf)[ "\n" ]
 | (text.clear)[]
 \_

ABYSS dump_node: [ @ASTNode n | I32 depth ]

; A labelled child: `init`, `then`, ... on a line of its own, the child under it.
ABYSS dump_child: [ @C1 label | @ASTNode n | I32 depth ]
 | IF [ n == 0 ]
 |  | RET
 |  \_
 | String s
 | (s.init_cstr)[ label ]
 | (dump_line)[ depth | @s | 0 ]
 | (s.deinit)[]
 | (dump_node)[ n | depth + 1 ]
 \_

ABYSS dump_block: [ @ASTNode blk | I32 depth ]
 | IF [ blk == 0 ]
 |  | RET
 |  \_
 | String s
 | (s.init_cstr)[ "BLOCK" ]
 | (dump_line)[ depth | @s | blk ]
 | (s.deinit)[]
 | @ASTNode st = blk.as.block.stmts
 | WHILE [ st != 0 ]
 |  | (dump_node)[ st | depth + 1 ]
 |  | st = st.as.stmt.next_stmt
 |  \_
 \_

; `ABYSS name: [ ... ]`, the header a function or method starts with
ABYSS dump_fn_head: [ @String s | @C1 what | @ASTNode decl ]
 | (s.append)[ what ]
 | IF [ decl.as.fn_decl.is_private ]
 |  | (s.append)[ " PRIVATE" ]
 |  \_
 | (s.push)[ ' ' ]
 | (dump_type)[ s | decl.as.fn_decl.type ]
 | (s.push)[ ' ' ]
 | (s.append)[ decl.as.fn_decl.ident.as.ident ]
 | (s.append)[ ": " ]
 | (dump_params)[ s | decl.as.fn_decl.params ]
 \_

ABYSS dump_node: [ @ASTNode n | I32 depth ]
 | IF [ n == 0 ]
 |  | RET
 |  \_
 | String s
 | (s.init)[ 128 ]
 | I32 k = n.kind
 |
 | IF [ k == NT_FN_DECL ]
 |  | ; declarations
 |  | (dump_fn_head)[ @s | "FN_DECL" | n ]
 |  | (dump_line)[ depth | @s | n.as.fn_decl.ident ]
 | ELIF [ k == NT_FN_DEF ]
 |  | (dump_fn_head)[ @s | "FN_DEF" | n.as.fn_def.decl ]
 |  | (dump_line)[ depth | @s | n.as.fn_def.decl.as.fn_decl.ident ]
 |  | (dump_block)[ n.as.fn_def.block | depth + 1 ]
 | ELIF [ k == NT_TYPE_DEF ]
 |  | (s.append)[ "TYPE " ]
 |  | (s.append)[ n.as.type_def.ident.as.ident ]
 |  | (dump_args)[ @s | n.as.type_def.gparams | TRUE ]
 |  | I32 tk = n.as.type_def.kind
 |  | IF [ tk == TD_ALIAS ]
 |  |  | (s.append)[ ": " ]
 |  |  | (dump_type)[ @s | n.as.type_def.tdef ]
 |  |  | (dump_line)[ depth | @s | n.as.type_def.ident ]
 |  | ELIF [ tk == TD_ENUM ]
 |  |  | (s.append)[ ": ENUM" ]
 |  |  | (dump_line)[ depth | @s | n.as.type_def.ident ]
 |  |  | @ASTNode e = n.as.type_def.tdef.as.enumeration.fields
 |  |  | I32 v = 0
 |  |  | WHILE [ e != 0 ]
 |  |  |  | C1 num{24}
 |  |  |  | (snprintf)[ num | 24 | " = %d" | v ]
 |  |  |  | (s.append)[ "CONST " ]
 |  |  |  | (s.append)[ e.as.enum_flds.ident.as.ident ]
 |  |  |  | (s.append)[ num ]
 |  |  |  | (dump_line)[ depth + 1 | @s | e.as.enum_flds.ident ]
 |  |  |  | v += 1
 |  |  |  | e = e.as.enum_flds.next_field
 |  |  |  \_
 |  | ELSE
 |  |  | IF [ n.as.type_def.tdef.as.record.kind == TDRT_UNION ]
 |  |  |  | (s.append)[ ": UNION" ]
 |  |  | ELSE
 |  |  |  | (s.append)[ ": STRUCT" ]
 |  |  |  \_
 |  |  | (dump_line)[ depth | @s | n.as.type_def.ident ]
 |  |  | @ASTNode f = n.as.type_def.tdef.as.record.fields
 |  |  | WHILE [ f != 0 ]
 |  |  |  | (s.append)[ "FIELD " ]
 |  |  |  | (dump_type)[ @s | f.as.rcrd_flds.type ]
 |  |  |  | (s.push)[ ' ' ]
 |  |  |  | (s.append)[ f.as.rcrd_flds.ident.as.ident ]
 |  |  |  | (dump_line)[ depth + 1 | @s | f.as.rcrd_flds.ident ]
 |  |  |  | f = f.as.rcrd_flds.next_field
 |  |  |  \_
 |  |  \_
 | ELIF [ k == NT_VAR_DECL ]
 |  | (s.append)[ "VAR " ]
 |  | (dump_type)[ @s | n.as.var_decl.type ]
 |  | (s.push)[ ' ' ]
 |  | (s.append)[ n.as.var_decl.ident.as.ident ]
 |  | (dump_line)[ depth | @s | n.as.var_decl.ident ]
 |  | (dump_node)[ n.as.var_decl.init | depth + 1 ]
 | ELIF [ k == NT_IFACE ]
 |  | (s.append)[ "IFACE " ]
 |  | (s.append)[ n.as.iface.ident.as.ident ]
 |  | (dump_args)[ @s | n.as.iface.gparams | TRUE ]
 |  | (s.append)[ ": " ]
 |  | (dump_params)[ @s | n.as.iface.recv ]
 |  | (dump_line)[ depth | @s | n.as.iface.ident ]
 |  | ; the `+ PUBLIC:`, `+ PRIVATE:` and `+ ANONYMOUS:` sections, where
 |  | ; the source switches between them
 |  | @ASTNode m = n.as.iface.methods
 |  | I32 section = 0
 |  | WHILE [ m != 0 ]
 |  |  | I32 sec = 0
 |  |  | IF [ m.as.method.is_private ]
 |  |  |  | sec = 1
 |  |  | ELIF [ m.as.method.is_anon ]
 |  |  |  | sec = 2
 |  |  |  \_
 |  |  | IF [ sec != section ]
 |  |  |  | section = sec
 |  |  |  | IF [ sec == 1 ]
 |  |  |  |  | (s.append)[ "PRIVATE:" ]
 |  |  |  | ELIF [ sec == 2 ]
 |  |  |  |  | (s.append)[ "ANONYMOUS:" ]
 |  |  |  | ELSE
 |  |  |  |  | (s.append)[ "PUBLIC:" ]
 |  |  |  |  \_
 |  |  |  | (dump_line)[ depth + 1 | @s | 0 ]
 |  |  |  \_
 |  |  | (dump_node)[ m.as.method.def | depth + 1 ]
 |  |  | m = m.as.method.next
 |  |  \_
 | ELIF [ k == NT_CLASS ]
 |  | (s.append)[ "CLASS " ]
 |  | (s.append)[ n.as.klass.ident.as.ident ]
 |  | (dump_args)[ @s | n.as.klass.gparams | TRUE ]
 |  | (s.append)[ ": " ]
 |  | (dump_type)[ @s | n.as.klass.base ]
 |  | (s.append)[ " IMPL [" ]
 |  | @ASTNode it = n.as.klass.ifaces
 |  | WHILE [ it != 0 ]
 |  |  | (s.push)[ ' ' ]
 |  |  | (dump_type)[ @s | it.as.list.item ]
 |  |  | it = it.as.list.next
 |  |  \_
 |  | (s.append)[ " ]" ]
 |  | (dump_line)[ depth | @s | n.as.klass.ident ]
 | ELIF [ k == NT_STMT ]
 |  | ; statements
 |  | I32 sk = n.as.stmt.kind
 |  | IF [ sk == ST_BREAK ]
 |  |  | (s.append)[ "BREAK" ]
 |  |  | (dump_line)[ depth | @s | n ]
 |  | ELIF [ sk == ST_CONTINUE ]
 |  |  | (s.append)[ "CONTINUE" ]
 |  |  | (dump_line)[ depth | @s | n ]
 |  | ELSE
 |  |  | (dump_node)[ n.as.stmt.stmt | depth ]
 |  |  \_
 | ELIF [ k == NT_RET ]
 |  | (s.append)[ "RET" ]
 |  | (dump_line)[ depth | @s | n ]
 |  | (dump_node)[ n.as.ret.expr | depth + 1 ]
 | ELIF [ k == NT_COND ]
 |  | @ASTNode ifp = n.as.cond.if_part
 |  | (s.append)[ "IF" ]
 |  | (dump_line)[ depth | @s | ifp ]
 |  | (dump_node)[ ifp.as.if_cond.expr | depth + 1 ]
 |  | (dump_block)[ ifp.as.if_cond.block | depth + 1 ]
 |  | @ASTNode el = n.as.cond.elif_part
 |  | WHILE [ el != 0 ]
 |  |  | (s.append)[ "ELIF" ]
 |  |  | (dump_line)[ depth | @s | el ]
 |  |  | (dump_node)[ el.as.elif_cond.expr | depth + 1 ]
 |  |  | (dump_block)[ el.as.elif_cond.block | depth + 1 ]
 |  |  | el = el.as.elif_cond.next_elif
 |  |  \_
 |  | IF [ n.as.cond.else_part != 0 ]
 |  |  | (s.append)[ "ELSE" ]
 |  |  | (dump_line)[ depth | @s | n.as.cond.else_part ]
 |  |  | (dump_block)[ n.as.cond.else_part.as.else_cond.block | depth + 1 ]
 |  |  \_
 | ELIF [ k == NT_LOOP ]
 |  | IF [ n.as.loop.expr == 0 ]
 |  |  | (s.append)[ "LOOP" ]
 |  |  | (dump_line)[ depth | @s | n ]
 |  | ELSE
 |  |  | (s.append)[ "WHILE" ]
 |  |  | (dump_line)[ depth | @s | n ]
 |  |  | (dump_node)[ n.as.loop.expr | depth + 1 ]
 |  |  \_
 |  | (dump_block)[ n.as.loop.block | depth + 1 ]
 | ELIF [ k == NT_EXPR ]
 |  | ; expressions. Parentheses: the tree already says how they group
 |  | (dump_node)[ n.as.expr.expr | depth ]
 | ELIF [ k == NT_TYPE ]
 |  | ; the class in an ANONYMOUS call
 |  | (s.append)[ "TYPE " ]
 |  | (dump_type)[ @s | n ]
 |  | (dump_line)[ depth | @s | n ]
 | ELIF [ k == NT_IDENT ]
 |  | (s.append)[ "IDENT " ]
 |  | (s.append)[ n.as.ident ]
 |  | (dump_line)[ depth | @s | n ]
 | ELIF [ k == NT_LITERAL ]
 |  | (dump_literal)[ @s | n ]
 |  | (dump_line)[ depth | @s | n ]
 | ELIF [ k == NT_BIN_OP ]
 |  | (s.append)[ "BINOP " ]
 |  | (s.append)[ (dump_binop)[ n.as.bin_op.kind ] ]
 |  | (dump_line)[ depth | @s | n ]
 |  | (dump_node)[ n.as.bin_op.left | depth + 1 ]
 |  | (dump_node)[ n.as.bin_op.right | depth + 1 ]
 | ELIF [ k == NT_UNY_OP ]
 |  | (s.append)[ "UNOP " ]
 |  | (s.append)[ (dump_unyop)[ n.as.uny_op.kind ] ]
 |  | (dump_line)[ depth | @s | n ]
 |  | (dump_node)[ n.as.uny_op.operand | depth + 1 ]
 | ELIF [ k == NT_CAST ]
 |  | (s.append)[ "AS " ]
 |  | (dump_type)[ @s | n.as.cast.type ]
 |  | (dump_line)[ depth | @s | n ]
 |  | (dump_node)[ n.as.cast.expr | depth + 1 ]
 | ELIF [ k == NT_BUILTIN ]
 |  | (s.append)[ "SIZE " ]
 |  | (dump_type)[ @s | n.as.builtin.size ]
 |  | (dump_line)[ depth | @s | n ]
 | ELIF [ k == NT_FN_CALL ]
 |  | ; (f)[ ... ], (obj.m)[ ... ] or (any expression)[ ... ]
 |  | @ASTNode id = n.as.fn_call.ident
 |  | IF [ id != 0 && n.as.fn_call.recv == 0 ]
 |  |  | (s.append)[ "CALL " ]
 |  |  | (s.append)[ id.as.ident ]
 |  |  | (dump_line)[ depth | @s | n ]
 |  | ELIF [ id != 0 ]
 |  |  | (s.append)[ "CALL ." ]
 |  |  | (s.append)[ id.as.ident ]
 |  |  | (dump_line)[ depth | @s | n ]
 |  |  | (dump_child)[ "on" | n.as.fn_call.recv | depth + 1 ]
 |  | ELSE
 |  |  | (s.append)[ "CALL" ]
 |  |  | (dump_line)[ depth | @s | n ]
 |  |  | (dump_child)[ "what" | n.as.fn_call.target | depth + 1 ]
 |  |  \_
 |  | @ASTNode a = n.as.fn_call.args
 |  | WHILE [ a != 0 ]
 |  |  | (dump_node)[ a.as.argument.argument | depth + 1 ]
 |  |  | a = a.as.argument.next_arg
 |  |  \_
 | ELSE
 |  | C1 buf{32}
 |  | (snprintf)[ buf | 32 | "<node kind %d>" | k ]
 |  | (s.append)[ buf ]
 |  | (dump_line)[ depth | @s | n ]
 |  \_
 | (s.deinit)[]
 \_

ABYSS dump_ast: [ @ASTNode root ]
 | dump_file = NULL
 | @ASTNode ts = root.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | @ASTNode n = ts.as.tu_stmt.tu_stmt
 |  | @C1 f = n.loc.file
 |  | IF [ f != NULL && (dump_file == NULL || (strcmp)[ f | dump_file ] != 0) ]
 |  |  | (printf)[ "== %s\n" | f ]
 |  |  | dump_file = f
 |  |  \_
 |  | (dump_node)[ n | 0 ]
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 \_
