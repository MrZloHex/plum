; index.pl -- what `plc --emit=INDEX` prints for the language server
;
; The checker notes every name it resolves (check.pl, Checker.ix); this
; adds what it never looks up -- type names, and every declaration's own
; name -- and prints one line per use, tab-separated:
;
;   R  file line col  file line col  hover
;
; the first place is the name as written, the second its declaration.
; Diagnostics come out on the same stream as E lines (diag.pl).

!USES <check.pl>
!USES <../lib/map.pl>
!USES <../lib/string.pl>
!USES <../extern/stdio.pl>
!USES <../extern/string.pl>

; --- collecting what the checker does not ---------------------------------

ABYSS ix_walk: [ @Index ix | @Meta m | @ASTNode n ]

ABYSS ix_type: [ @Index ix | @Meta m | @ASTNode tn ]
 | IF [ tn == 0 ]
 |  | RET
 |  \_
 | IF [ tn.as.type.kind == TT_FN_TYPE ]
 |  | (ix_type)[ ix | m | tn.as.type.type ]
 |  | @ASTNode p = tn.as.type.args
 |  | WHILE [ p != 0 ]
 |  |  | (ix_type)[ ix | m | p.as.list.item ]
 |  |  | p = p.as.list.next
 |  |  \_
 |  | RET
 |  \_
 | IF [ tn.as.type.kind != TT_USER_TYPE ]
 |  | RET
 |  \_
 |
 | @ABYSS d = 0
 | IF [ (map_get)[ @(m.types) | tn.as.type.type.as.ident | @d AS @@ABYSS ] == 1 ]
 |  | (ix_add)[ ix | tn.as.type.type | d AS @ASTNode | 0 ]
 |  \_
 |
 | ; Vec<Node>: generics has renamed the reference, but kept the arguments
 | @ASTNode a = tn.as.type.written
 | WHILE [ a != 0 ]
 |  | (ix_type)[ ix | m | a.as.list.item ]
 |  | a = a.as.list.next
 |  \_
 | RET
 \_

ABYSS ix_walk: [ @Index ix | @Meta m | @ASTNode n ]
 | IF [ n == 0 ]
 |  | RET
 |  \_
 | I32 k = n.kind
 |
 | IF [ k == NT_TRANSLATION_UNIT ]
 |  | @ASTNode ts = n.as.tu.tu_stmt
 |  | WHILE [ ts != 0 ]
 |  |  | (ix_walk)[ ix | m | ts.as.tu_stmt.tu_stmt ]
 |  |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  |  \_
 |  | RET
 |  \_
 |
 | ; declarations: the name points at itself, so hovering it shows the type
 | IF [ k == NT_FN_DEF ]
 |  | (ix_walk)[ ix | m | n.as.fn_def.decl ]
 |  | (ix_walk)[ ix | m | n.as.fn_def.block ]
 |  | RET
 |  \_
 | IF [ k == NT_FN_DECL ]
 |  | (ix_add)[ ix | n.as.fn_decl.ident | n | 0 ]
 |  | (ix_type)[ ix | m | n.as.fn_decl.type ]
 |  | @ASTNode p = n.as.fn_decl.params
 |  | WHILE [ p != 0 ]
 |  |  | IF [ !(p.as.parametre.vaarg) ]
 |  |  |  | (ix_add)[ ix | p.as.parametre.ident | p | 0 ]
 |  |  |  | (ix_type)[ ix | m | p.as.parametre.type ]
 |  |  |  \_
 |  |  | p = p.as.parametre.next_param
 |  |  \_
 |  | RET
 |  \_
 | IF [ k == NT_TYPE_DEF ]
 |  | (ix_add)[ ix | n.as.type_def.ident | n | 0 ]
 |  | I32 tk = n.as.type_def.kind
 |  | IF [ tk == TD_RECORD ]
 |  |  | @ASTNode f = n.as.type_def.tdef.as.record.fields
 |  |  | WHILE [ f != 0 ]
 |  |  |  | (ix_add)[ ix | f.as.rcrd_flds.ident | f | n ]
 |  |  |  | (ix_type)[ ix | m | f.as.rcrd_flds.type ]
 |  |  |  | f = f.as.rcrd_flds.next_field
 |  |  |  \_
 |  | ELIF [ tk == TD_ENUM ]
 |  |  | @ASTNode e = n.as.type_def.tdef.as.enumeration.fields
 |  |  | WHILE [ e != 0 ]
 |  |  |  | (ix_add)[ ix | e.as.enum_flds.ident | e | n ]
 |  |  |  | e = e.as.enum_flds.next_field
 |  |  |  \_
 |  | ELSE
 |  |  | (ix_type)[ ix | m | n.as.type_def.tdef ]
 |  |  \_
 |  | RET
 |  \_
 | IF [ k == NT_VAR_DECL ]
 |  | (ix_add)[ ix | n.as.var_decl.ident | n | 0 ]
 |  | (ix_type)[ ix | m | n.as.var_decl.type ]
 |  | (ix_walk)[ ix | m | n.as.var_decl.init ]
 |  | RET
 |  \_
 |
 | ; statements and expressions: only to reach the types inside them
 | ; a POSTLUDE's statement
 | IF [ k == NT_STMT ]
 |  | (ix_walk)[ ix | m | n.as.stmt.stmt ]
 |  | RET
 |  \_
 | IF [ k == NT_BLOCK ]
 |  | @ASTNode s = n.as.block.stmts
 |  | WHILE [ s != 0 ]
 |  |  | (ix_walk)[ ix | m | s.as.stmt.stmt ]
 |  |  | s = s.as.stmt.next_stmt
 |  |  \_
 |  | RET
 |  \_
 | IF [ k == NT_COND ]
 |  | (ix_walk)[ ix | m | n.as.cond.if_part ]
 |  | (ix_walk)[ ix | m | n.as.cond.elif_part ]
 |  | (ix_walk)[ ix | m | n.as.cond.else_part ]
 |  | RET
 |  \_
 | IF [ k == NT_IF ]
 |  | (ix_walk)[ ix | m | n.as.if_cond.expr ]
 |  | (ix_walk)[ ix | m | n.as.if_cond.block ]
 |  | RET
 |  \_
 | IF [ k == NT_ELIF ]
 |  | (ix_walk)[ ix | m | n.as.elif_cond.expr ]
 |  | (ix_walk)[ ix | m | n.as.elif_cond.block ]
 |  | (ix_walk)[ ix | m | n.as.elif_cond.next_elif ]
 |  | RET
 |  \_
 | IF [ k == NT_ELSE ]
 |  | (ix_walk)[ ix | m | n.as.else_cond.block ]
 |  | RET
 |  \_
 | IF [ k == NT_INIT ]
 |  | @ASTNode it = n.as.list.item
 |  | WHILE [ it != 0 ]
 |  |  | (ix_walk)[ ix | m | it.as.init_item.value ]
 |  |  | it = it.as.init_item.next
 |  |  \_
 |  | RET
 |  \_
 | IF [ k == NT_SWITCH ]
 |  | (ix_walk)[ ix | m | n.as.switch.expr ]
 |  | @ASTNode cs = n.as.switch.cases
 |  | WHILE [ cs != 0 ]
 |  |  | @ASTNode vl = cs.as.case.values
 |  |  | WHILE [ vl != 0 ]
 |  |  |  | (ix_walk)[ ix | m | vl.as.list.item ]
 |  |  |  | vl = vl.as.list.next
 |  |  |  \_
 |  |  | (ix_walk)[ ix | m | cs.as.case.block ]
 |  |  | cs = cs.as.case.next
 |  |  \_
 |  | (ix_walk)[ ix | m | n.as.switch.else_block ]
 |  | RET
 |  \_
 | IF [ k == NT_LOOP ]
 |  | IF [ n.as.loop.init != 0 ]
 |  |  | (ix_walk)[ ix | m | n.as.loop.init.as.stmt.stmt ]
 |  |  \_
 |  | (ix_walk)[ ix | m | n.as.loop.expr ]
 |  | (ix_walk)[ ix | m | n.as.loop.block ]
 |  | (ix_walk)[ ix | m | n.as.loop.step ]
 |  | RET
 |  \_
 | IF [ k == NT_RET ]
 |  | (ix_walk)[ ix | m | n.as.ret.expr ]
 |  | RET
 |  \_
 | IF [ k == NT_EXPR ]
 |  | (ix_walk)[ ix | m | n.as.expr.expr ]
 |  | RET
 |  \_
 | IF [ k == NT_CAST ]
 |  | (ix_type)[ ix | m | n.as.cast.type ]
 |  | (ix_walk)[ ix | m | n.as.cast.expr ]
 |  | RET
 |  \_
 | IF [ k == NT_BUILTIN ]
 |  | (ix_type)[ ix | m | n.as.builtin.size ]
 |  | RET
 |  \_
 | IF [ k == NT_STATIC_ASSERT ]
 |  | (ix_walk)[ ix | m | n.as.assert.cond ]
 |  | RET
 |  \_
 | ; the class of an ANONYMOUS call, (Option<I32>.some)
 | IF [ k == NT_TYPE ]
 |  | (ix_type)[ ix | m | n ]
 |  | RET
 |  \_
 | IF [ k == NT_BIN_OP ]
 |  | (ix_walk)[ ix | m | n.as.bin_op.left ]
 |  | (ix_walk)[ ix | m | n.as.bin_op.right ]
 |  | RET
 |  \_
 | IF [ k == NT_UNY_OP ]
 |  | (ix_walk)[ ix | m | n.as.uny_op.operand ]
 |  | RET
 |  \_
 | IF [ k == NT_FN_CALL ]
 |  | IF [ n.as.fn_call.ident == 0 ]
 |  |  | (ix_walk)[ ix | m | n.as.fn_call.target ]
 |  |  \_
 |  | (ix_walk)[ ix | m | n.as.fn_call.recv ]
 |  | @ASTNode a = n.as.fn_call.args
 |  | WHILE [ a != 0 ]
 |  |  | (ix_walk)[ ix | m | a.as.argument.argument ]
 |  |  | a = a.as.argument.next_arg
 |  |  \_
 |  | RET
 |  \_
 | RET
 \_

; --- printing -------------------------------------------------------------

; The name a declaration introduces.
@ASTNode ix_decl_ident: [ @ASTNode d ]
 | I32 k = d.kind
 | IF [ k == NT_VAR_DECL ]
 |  | RET [ d.as.var_decl.ident ]
 | ELIF [ k == NT_PARAMETRE ]
 |  | RET [ d.as.parametre.ident ]
 | ELIF [ k == NT_FIELD ]
 |  | RET [ d.as.rcrd_flds.ident ]
 | ELIF [ k == NT_FN_DECL ]
 |  | RET [ d.as.fn_decl.ident ]
 | ELIF [ k == NT_TYPE_DEF ]
 |  | RET [ d.as.type_def.ident ]
 | ELIF [ k == NT_ENUM_FIELDS ]
 |  | RET [ d.as.enum_flds.ident ]
 |  \_
 | RET [ NULL ]
 \_

; `T name`, with `{N}` for an array.
ABYSS ix_typed_name: [ @String s | @ASTNode tn | @C1 name ]
 | (append_tn)[ s | tn ]
 | (s.push)[ ' ' ]
 | (s.append)[ name ]
 | IF [ tn != 0 && tn.as.type.arr > 0 ]
 |  | C1 buf{24}
 |  | (snprintf)[ buf | 24 | "{%u}" | tn.as.type.arr ]
 |  | (s.append)[ buf ]
 |  \_
 | RET
 \_

; A declaration as it would be written, on one line: what hover shows.
ABYSS ix_hover: [ @String s | @ASTNode d | @ASTNode owner ]
 | I32 k = d.kind
 | @C1 name = (ix_decl_ident)[ d ].as.ident
 |
 | IF [ k == NT_VAR_DECL ]
 |  | (ix_typed_name)[ s | d.as.var_decl.type | name ]
 | ELIF [ k == NT_PARAMETRE ]
 |  | (ix_typed_name)[ s | d.as.parametre.type | name ]
 | ELIF [ k == NT_FIELD ]
 |  | (ix_typed_name)[ s | d.as.rcrd_flds.type | name ]
 | ELIF [ k == NT_FN_DECL ]
 |  | (append_tn)[ s | d.as.fn_decl.type ]
 |  | (s.push)[ ' ' ]
 |  | (s.append)[ name ]
 |  | (s.append)[ ": [" ]
 |  | @ASTNode p = d.as.fn_decl.params
 |  | WHILE [ p != 0 ]
 |  |  | (s.push)[ ' ' ]
 |  |  | IF [ p.as.parametre.vaarg ]
 |  |  |  | (s.append)[ "..." ]
 |  |  | ELSE
 |  |  |  | (ix_typed_name)[ s | p.as.parametre.type | p.as.parametre.ident.as.ident ]
 |  |  |  \_
 |  |  | p = p.as.parametre.next_param
 |  |  | IF [ p != 0 ]
 |  |  |  | (s.append)[ " |" ]
 |  |  |  \_
 |  |  \_
 |  | (s.append)[ " ]" ]
 | ELIF [ k == NT_TYPE_DEF ]
 |  | (s.append)[ "TYPE " ]
 |  | (s.append)[ name ]
 |  | (s.append)[ ": " ]
 |  | I32 tk = d.as.type_def.kind
 |  | IF [ tk == TD_ENUM ]
 |  |  | (s.append)[ "ENUM" ]
 |  | ELIF [ tk == TD_RECORD && d.as.type_def.tdef.as.record.kind == TDRT_UNION ]
 |  |  | (s.append)[ "UNION" ]
 |  | ELIF [ tk == TD_RECORD ]
 |  |  | (s.append)[ "STRUCT" ]
 |  | ELSE
 |  |  | (append_tn)[ s | d.as.type_def.tdef ]
 |  |  \_
 | ELIF [ k == NT_ENUM_FIELDS ]
 |  | ; its value is its place in the enum
 |  | I32 v = 0
 |  | IF [ owner != 0 ]
 |  |  | @ASTNode e = owner.as.type_def.tdef.as.enumeration.fields
 |  |  | WHILE [ e != 0 && e != d ]
 |  |  |  | v += 1
 |  |  |  | e = e.as.enum_flds.next_field
 |  |  |  \_
 |  |  \_
 |  | C1 buf{24}
 |  | (snprintf)[ buf | 24 | " = %d" | v ]
 |  | (s.append)[ name ]
 |  | (s.append)[ buf ]
 |  \_
 |
 | IF [ owner != 0 ]
 |  | (s.append)[ "  ; in " ]
 |  | (s.append)[ owner.as.type_def.ident.as.ident ]
 |  \_
 | RET
 \_

ABYSS ix_dump: [ @Index ix | @ASTNode root ]
 | ; a call names the declaration meta kept; jump to the body when there is one
 | Map defs
 | (map_init)[ @defs | 256 ]
 | @ASTNode ts = root.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | IF [ ts.as.tu_stmt.kind == TUST_FN_DEF ]
 |  |  | @ASTNode fd = ts.as.tu_stmt.tu_stmt.as.fn_def.decl
 |  |  | (map_put)[ @defs | fd.as.fn_decl.ident.as.ident | fd AS @ABYSS ]
 |  |  \_
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 |
 | ; a generic body is checked once per instance: say each place once
 | Map seen
 | (map_init)[ @seen | 4096 ]
 | @ABYSS unused = 0
 |
 | String hover
 | (hover.init)[ 128 ]
 | U64 i = 0
 | WHILE [ i < (ix.refs.size)[] ]
 |  | @IxRef r = (ix.refs.at)[ i ]
 |  | i += 1
 |  |
 |  | @ASTNode d = r.decl
 |  | @ABYSS def = 0
 |  | IF [ d.kind == NT_FN_DECL && (map_get)[ @defs | d.as.fn_decl.ident.as.ident | @def AS @@ABYSS ] == 1 ]
 |  |  | d = def AS @ASTNode
 |  |  \_
 |  | @ASTNode to = (ix_decl_ident)[ d ]
 |  | IF [ to == NULL || to.loc.file == NULL || r.use.loc.file == NULL ]
 |  |  | CONTINUE
 |  |  \_
 |  |
 |  | Location a = r.use.loc
 |  | Location b = to.loc
 |  | U64 kn = (strlen)[ a.file ] + 32
 |  | @C1 key = (malloc)[ kn ] AS @C1
 |  | (snprintf)[ key | kn | "%s:%d:%d" | a.file | a.line | a.col ]
 |  | IF [ (map_get)[ @seen | key | @unused ] == 1 ]
 |  |  | (free)[ key AS @ABYSS ]
 |  |  | CONTINUE
 |  |  \_
 |  | (map_put)[ @seen | key | NULL ]
 |  |
 |  | (hover.clear)[]
 |  | (ix_hover)[ @hover | d | r.owner ]
 |  | (printf)[ "R\t%s\t%d\t%d\t%s\t%d\t%d\t%s\n" | a.file | a.line | a.col | b.file | b.line | b.col | hover.data ]
 |  \_
 |
 | (hover.deinit)[]
 | (map_deinit)[ @seen ]
 | (map_deinit)[ @defs ]
 | RET
 \_
