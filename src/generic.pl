; generic.pl -- generics, interfaces and classes, by instantiation
;
; Runs between the parser and meta. It takes every template out of the
; unit and appends one concrete copy per distinct use, so every later pass
; sees only ordinary TYPEs and functions:
;
;   TYPE Box<T>: ...            Box<I32> becomes a TYPE named "Box<I32>"
;   IFACE Face<T>: [ @D<T> me ] methods written against @D<T>
;   CLASS Cls<T>: D<T> IMPL [ Face<T> ]
;                               a STRUCT "Cls<X>" laid out like D<X>, plus a
;                               function "Cls<X>.method" for every method of
;                               every IFACE, taking `@Cls<X> me` first
;
; A method call (obj.method)[ ... ] is left for check and codegen: they
; know obj's type, and look up "<that type>.method" among the functions.

!USES <ast.pl>
!USES <diag.pl>
!USES <../lib/vector.pl>
!USES <../lib/map.pl>
!USES <../lib/string.pl>
!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>

TYPE Generics: STRUCT
 | @AST       ast
 | Map        type_tmpls   ; name -> NT_TYPE_DEF with gparams
 | Map        iface_tmpls  ; name -> NT_IFACE
 | Map        class_tmpls  ; name -> NT_CLASS with gparams
 | Map        types        ; concrete name -> NT_TYPE_DEF, instances too
 | Map        done         ; instances and methods already made
 | Map        impls        ; class name -> NT_LIST of the interfaces it takes
 | Map        bases        ; class name -> the name of the struct it holds
 | Vector<@ASTNode> work   ; instances still to be scanned
 | @ASTNode   out_head     ; the instances, as NT_TU_STMTs
 | @@ASTNode  out_tail
 | I32        count
 \_

; Template parameters and the concrete types standing in for them.
TYPE Subst: STRUCT
 | @ASTNode params         ; NT_LIST of NT_IDENT
 | @ASTNode args           ; NT_LIST of NT_TYPE
 \_

ABYSS gn_error: [ @ASTNode at | @C1 fmt | @C1 a | @C1 b ]
 | Location none
 | none.file = NULL
 | none.line = 0
 | none.col = 0
 | IF [ at != NULL ]
 |  | none = at.loc
 |  \_
 | (diag_fatal)[ none | fmt | a | b ]
 \_

@ASTNode gn_ident: [ @Generics g | @C1 name | @ASTNode at ]
 | @ASTNode id = (ast_node_new)[ g.ast ]
 | id.kind = NT_IDENT
 | id.as.ident = name
 | IF [ at != 0 ]
 |  | id.loc = at.loc
 |  \_
 | RET [ id ]
 \_

B1 gn_has: [ @Map m | @C1 name ]
 | @ABYSS d = 0
 | RET [ (map_get)[ m | name | @d AS @@ABYSS ] == 1 ]
 \_

@ASTNode gn_find: [ @Map m | @C1 name ]
 | @ABYSS d = 0
 | IF [ (map_get)[ m | name | @d AS @@ABYSS ] == 1 ]
 |  | RET [ d AS @ASTNode ]
 |  \_
 | RET [ 0 ]
 \_

I32 list_len: [ @ASTNode l ]
 | I32 n = 0
 | WHILE [ l != 0 ]
 |  | n += 1
 |  | l = l.as.list.next
 |  \_
 | RET [ n ]
 \_

; --- names ----------------------------------------------------------------

@C1 base_type_name: [ I32 bt ]
 | IF [ bt == BT_ABYSS ]
 |  | RET [ "ABYSS" ]
 | ELIF [ bt == BT_B1 ]
 |  | RET [ "B1" ]
 | ELIF [ bt == BT_C1 ]
 |  | RET [ "C1" ]
 | ELIF [ bt == BT_U8 ]
 |  | RET [ "U8" ]
 | ELIF [ bt == BT_U16 ]
 |  | RET [ "U16" ]
 | ELIF [ bt == BT_U32 ]
 |  | RET [ "U32" ]
 | ELIF [ bt == BT_U64 ]
 |  | RET [ "U64" ]
 | ELIF [ bt == BT_I8 ]
 |  | RET [ "I8" ]
 | ELIF [ bt == BT_I16 ]
 |  | RET [ "I16" ]
 | ELIF [ bt == BT_I32 ]
 |  | RET [ "I32" ]
 | ELIF [ bt == BT_I64 ]
 |  | RET [ "I64" ]
 | ELIF [ bt == BT_USIZE ]
 |  | RET [ "USIZE" ]
 | ELIF [ bt == BT_ISIZE ]
 |  | RET [ "ISIZE" ]
 | ELIF [ bt == BT_F32 ]
 |  | RET [ "F32" ]
 |  \_
 | RET [ "F64" ]
 \_

; A concrete type's spelling: "@C1", "Vec<I32>". Arguments are resolved
; first, so a nested instance already carries its full name.
; `CONST ` and `VOLATILE ` of one level, as written before it.
ABYSS append_quals: [ @String s | U32 q ]
 | IF [ (q & QUAL_CONST) != 0 ]
 |  | (s.append)[ "CONST " ]
 |  \_
 | IF [ (q & QUAL_VOLATILE) != 0 ]
 |  | (s.append)[ "VOLATILE " ]
 |  \_
 \_

ABYSS append_type_name: [ @String s | @ASTNode tn ]
 | (append_quals)[ s | (quals_at)[ tn.as.type.quals | 0 ] ]
 | U32 i = 0
 | WHILE [ i < tn.as.type.ptrs ]
 |  | (s.push)[ '@' ]
 |  | i = i + 1
 |  | (append_quals)[ s | (quals_at)[ tn.as.type.quals | i ] ]
 |  \_
 | IF [ tn.as.type.kind == TT_BASE_TYPE ]
 |  | (s.append)[ (base_type_name)[ tn.as.type.type.as.base_type ] ]
 | ELIF [ tn.as.type.kind == TT_FN_TYPE ]
 |  | (s.append)[ "FN " ]
 |  | (append_type_name)[ s | tn.as.type.type ]
 |  | (s.append)[ " [" ]
 |  | @ASTNode p = tn.as.type.args
 |  | WHILE [ p != 0 ]
 |  |  | (s.push)[ ' ' ]
 |  |  | IF [ p.as.list.item == 0 ]
 |  |  |  | (s.append)[ "..." ]
 |  |  | ELSE
 |  |  |  | (append_type_name)[ s | p.as.list.item ]
 |  |  |  \_
 |  |  | IF [ p.as.list.next != 0 ]
 |  |  |  | (s.append)[ " |" ]
 |  |  |  \_
 |  |  | p = p.as.list.next
 |  |  \_
 |  | (s.append)[ " ]" ]
 | ELSE
 |  | (s.append)[ tn.as.type.type.as.ident ]
 |  \_
 | RET
 \_

@C1 instance_name: [ @C1 tmpl | @ASTNode args ]
 | String s
 | (s.init_cstr)[ tmpl ]
 | (s.push)[ '<' ]
 | @ASTNode a = args
 | WHILE [ a != 0 ]
 |  | (append_type_name)[ @s | a.as.list.item ]
 |  | IF [ a.as.list.next != 0 ]
 |  |  | (s.append)[ ", " ]
 |  |  \_
 |  | a = a.as.list.next
 |  \_
 | (s.push)[ '>' ]
 | RET [ s.data ]
 \_

; --- copying a template ---------------------------------------------------

@ASTNode subst_lookup: [ @Subst s | @C1 name ]
 | IF [ s == 0 ]
 |  | RET [ 0 ]
 |  \_
 | @ASTNode p = s.params
 | @ASTNode a = s.args
 | WHILE [ p != 0 && a != 0 ]
 |  | IF [ (strcmp)[ p.as.list.item.as.ident | name ] == 0 ]
 |  |  | RET [ a.as.list.item ]
 |  |  \_
 |  | p = p.as.list.next
 |  | a = a.as.list.next
 |  \_
 | RET [ 0 ]
 \_

; A deep copy of a subtree, with every use of a template parameter
; replaced by its argument. Names are shared; nodes never are.
@ASTNode clone: [ @Generics g | @ASTNode n | @Subst s ]
 | IF [ n == 0 ]
 |  | RET [ 0 ]
 |  \_
 |
 | @ASTNode c = (ast_node_new)[ g.ast ]
 | (memcpy)[ c AS @ABYSS | n AS @ABYSS | SIZE [ ASTNode ] ]
 | I32 k = n.kind
 |
 | IF [ k == NT_TYPE ]
 |  | c.as.type.type = (clone)[ g | n.as.type.type | s ]
 |  | c.as.type.args = (clone)[ g | n.as.type.args | s ]
 |  | IF [ n.as.type.kind == TT_USER_TYPE && n.as.type.args == 0 ]
 |  |  | @ASTNode a = (subst_lookup)[ s | n.as.type.type.as.ident ]
 |  |  | IF [ a != 0 ]
 |  |  |  | ; T with ptrs levels over it: @T where T = @C1 is @@C1
 |  |  |  | c.as.type.kind = a.as.type.kind
 |  |  |  | c.as.type.ptrs = n.as.type.ptrs + a.as.type.ptrs
 |  |  |  | c.as.type.quals = (quals_compose)[ n.as.type.quals | n.as.type.ptrs | a.as.type.quals ]
 |  |  |  | c.as.type.type = (clone)[ g | a.as.type.type | 0 ]
 |  |  |  | c.as.type.args = (clone)[ g | a.as.type.args | 0 ]
 |  |  |  \_
 |  |  \_
 |  | RET [ c ]
 |  \_
 |
 | IF [ k == NT_FN_DECL ]
 |  | c.as.fn_decl.ident = (clone)[ g | n.as.fn_decl.ident | s ]
 |  | c.as.fn_decl.type = (clone)[ g | n.as.fn_decl.type | s ]
 |  | c.as.fn_decl.params = (clone)[ g | n.as.fn_decl.params | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_FN_DEF ]
 |  | c.as.fn_def.decl = (clone)[ g | n.as.fn_def.decl | s ]
 |  | c.as.fn_def.block = (clone)[ g | n.as.fn_def.block | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_TYPE_DEF ]
 |  | c.as.type_def.ident = (clone)[ g | n.as.type_def.ident | s ]
 |  | c.as.type_def.tdef = (clone)[ g | n.as.type_def.tdef | s ]
 |  | c.as.type_def.gparams = 0
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_PARAMETRE ]
 |  | c.as.parametre.ident = (clone)[ g | n.as.parametre.ident | s ]
 |  | c.as.parametre.type = (clone)[ g | n.as.parametre.type | s ]
 |  | c.as.parametre.next_param = (clone)[ g | n.as.parametre.next_param | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_ENUM ]
 |  | c.as.enumeration.fields = (clone)[ g | n.as.enumeration.fields | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_ENUM_FIELDS ]
 |  | c.as.enum_flds.ident = (clone)[ g | n.as.enum_flds.ident | s ]
 |  | c.as.enum_flds.next_field = (clone)[ g | n.as.enum_flds.next_field | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_RECORD ]
 |  | c.as.record.fields = (clone)[ g | n.as.record.fields | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_FIELD ]
 |  | c.as.rcrd_flds.type = (clone)[ g | n.as.rcrd_flds.type | s ]
 |  | c.as.rcrd_flds.ident = (clone)[ g | n.as.rcrd_flds.ident | s ]
 |  | c.as.rcrd_flds.next_field = (clone)[ g | n.as.rcrd_flds.next_field | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_BLOCK ]
 |  | c.as.block.stmts = (clone)[ g | n.as.block.stmts | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_STMT ]
 |  | c.as.stmt.stmt = (clone)[ g | n.as.stmt.stmt | s ]
 |  | c.as.stmt.next_stmt = (clone)[ g | n.as.stmt.next_stmt | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_RET ]
 |  | c.as.ret.expr = (clone)[ g | n.as.ret.expr | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_COND ]
 |  | c.as.cond.if_part = (clone)[ g | n.as.cond.if_part | s ]
 |  | c.as.cond.elif_part = (clone)[ g | n.as.cond.elif_part | s ]
 |  | c.as.cond.else_part = (clone)[ g | n.as.cond.else_part | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_IF ]
 |  | c.as.if_cond.expr = (clone)[ g | n.as.if_cond.expr | s ]
 |  | c.as.if_cond.block = (clone)[ g | n.as.if_cond.block | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_ELIF ]
 |  | c.as.elif_cond.expr = (clone)[ g | n.as.elif_cond.expr | s ]
 |  | c.as.elif_cond.block = (clone)[ g | n.as.elif_cond.block | s ]
 |  | c.as.elif_cond.next_elif = (clone)[ g | n.as.elif_cond.next_elif | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_ELSE ]
 |  | c.as.else_cond.block = (clone)[ g | n.as.else_cond.block | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_LOOP ]
 |  | c.as.loop.expr = (clone)[ g | n.as.loop.expr | s ]
 |  | c.as.loop.block = (clone)[ g | n.as.loop.block | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_VAR_DECL ]
 |  | c.as.var_decl.ident = (clone)[ g | n.as.var_decl.ident | s ]
 |  | c.as.var_decl.type = (clone)[ g | n.as.var_decl.type | s ]
 |  | c.as.var_decl.init = (clone)[ g | n.as.var_decl.init | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_EXPR ]
 |  | c.as.expr.expr = (clone)[ g | n.as.expr.expr | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_BIN_OP ]
 |  | c.as.bin_op.left = (clone)[ g | n.as.bin_op.left | s ]
 |  | c.as.bin_op.right = (clone)[ g | n.as.bin_op.right | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_UNY_OP ]
 |  | c.as.uny_op.operand = (clone)[ g | n.as.uny_op.operand | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_FN_CALL ]
 |  | c.as.fn_call.ident = (clone)[ g | n.as.fn_call.ident | s ]
 |  | c.as.fn_call.args = (clone)[ g | n.as.fn_call.args | s ]
 |  | c.as.fn_call.recv = (clone)[ g | n.as.fn_call.recv | s ]
 |  | c.as.fn_call.target = (clone)[ g | n.as.fn_call.target | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_ARGUMENT ]
 |  | c.as.argument.argument = (clone)[ g | n.as.argument.argument | s ]
 |  | c.as.argument.next_arg = (clone)[ g | n.as.argument.next_arg | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_BUILTIN ]
 |  | c.as.builtin.size = (clone)[ g | n.as.builtin.size | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_CAST ]
 |  | c.as.cast.type = (clone)[ g | n.as.cast.type | s ]
 |  | c.as.cast.expr = (clone)[ g | n.as.cast.expr | s ]
 |  | RET [ c ]
 |  \_
 | IF [ k == NT_LIST ]
 |  | c.as.list.item = (clone)[ g | n.as.list.item | s ]
 |  | c.as.list.next = (clone)[ g | n.as.list.next | s ]
 |  | RET [ c ]
 |  \_
 |
 | ; NT_IDENT, NT_BASE_TYPE, NT_LITERAL: nothing below them
 | RET [ c ]
 \_

; --- instantiating --------------------------------------------------------

ABYSS resolve_type: [ @Generics g | @ASTNode tn ]

ABYSS emit: [ @Generics g | I32 kind | @ASTNode node ]
 | @ASTNode ts = (ast_node_new)[ g.ast ]
 | ts.kind = NT_TU_STMT
 | ts.loc = node.loc
 | ts.as.tu_stmt.kind = kind
 | ts.as.tu_stmt.tu_stmt = node
 | ?(g.out_tail) = ts
 | g.out_tail = @(ts.as.tu_stmt.next_tu_stmt)
 | (g.work.push)[ node ]
 | RET
 \_

ABYSS check_arity: [ @ASTNode at | @C1 what | @ASTNode params | @ASTNode args ]
 | I32 want = (list_len)[ params ]
 | I32 got = (list_len)[ args ]
 | IF [ want != got ]
 |  | @C1 buf = (malloc)[ 64 ] AS @C1
 |  | @C1 plural = "s"
 |  | IF [ want == 1 ]
 |  |  | plural = ""
 |  |  \_
 |  | (snprintf)[ buf | 64 | "%d type argument%s, got %d" | want | plural | got ]
 |  | (gn_error)[ at | "`%s` takes %s" | what | buf ]
 |  \_
 | RET
 \_

; The STRUCT a CLASS stores its data in, through any aliases.
@ASTNode class_base: [ @Generics g | @ASTNode at | @ASTNode base ]
 | @ASTNode tn = base
 | I32 hops = 0
 | LOOP
 |  | IF [ tn.as.type.kind != TT_USER_TYPE || tn.as.type.ptrs != 0 ]
 |  |  | (gn_error)[ at | "a CLASS is built on a STRUCT, not on a pointer or a base type%s%s" | "" | "" ]
 |  |  \_
 |  | @C1 nm = tn.as.type.type.as.ident
 |  | @ASTNode td = (gn_find)[ @(g.types) | nm ]
 |  | IF [ td == 0 ]
 |  |  | (gn_error)[ at | "unknown type `%s`%s" | nm | "" ]
 |  |  \_
 |  | IF [ td.as.type_def.kind == TD_RECORD ]
 |  |  | IF [ td.as.type_def.tdef.as.record.kind != TDRT_STRUCTURE ]
 |  |  |  | (gn_error)[ at | "a CLASS is built on a STRUCT, and `%s` is a UNION%s" | nm | "" ]
 |  |  |  \_
 |  |  | RET [ td ]
 |  |  \_
 |  | IF [ td.as.type_def.kind != TD_ALIAS || hops > 16 ]
 |  |  | (gn_error)[ at | "a CLASS is built on a STRUCT, and `%s` is not one%s" | nm | "" ]
 |  |  \_
 |  | tn = td.as.type_def.tdef
 |  | (resolve_type)[ g | tn ]
 |  | hops += 1
 |  \_
 | RET [ 0 ]
 \_

ABYSS inst_type: [ @Generics g | @ASTNode at | @ASTNode tmpl | @C1 name | @ASTNode args ]
 | (check_arity)[ at | tmpl.as.type_def.ident.as.ident | tmpl.as.type_def.gparams | args ]
 | Subst s
 | s.params = tmpl.as.type_def.gparams
 | s.args = args
 |
 | @ASTNode td = (clone)[ g | tmpl | @s ]
 | td.as.type_def.ident = (gn_ident)[ g | name | tmpl.as.type_def.ident ]
 | (map_put)[ @(g.types) | name | td AS @ABYSS ]
 | (emit)[ g | TUST_TYPE_DEF | td ]
 | RET
 \_

; One IFACE's methods, attached to the class `cls`.
; An interface as the class names it, spelled for messages: Named<CoinData>.
; Resolves its arguments on the way.
@C1 iface_spelling: [ @Generics g | @ASTNode ref ]
 | @ASTNode a = ref.as.type.args
 | WHILE [ a != 0 ]
 |  | (resolve_type)[ g | a.as.list.item ]
 |  | a = a.as.list.next
 |  \_
 | IF [ ref.as.type.args == 0 ]
 |  | RET [ ref.as.type.type.as.ident ]
 |  \_
 | ; as PLUM writes it, with `|` between the arguments
 | String sp
 | (sp.init_cstr)[ ref.as.type.type.as.ident ]
 | (sp.push)[ '<' ]
 | a = ref.as.type.args
 | WHILE [ a != 0 ]
 |  | (append_type_name)[ @sp | a.as.list.item ]
 |  | IF [ a.as.list.next != 0 ]
 |  |  | (sp.append)[ " | " ]
 |  |  \_
 |  | a = a.as.list.next
 |  \_
 | (sp.push)[ '>' ]
 | RET [ sp.data ]
 \_

; A type, resolved, spelled for messages and for comparing: @Vector<I32>.
@C1 type_spelling: [ @Generics g | @ASTNode tn ]
 | (resolve_type)[ g | tn ]
 | String s
 | (s.init_cstr)[ "" ]
 | (append_type_name)[ @s | tn ]
 | RET [ s.data ]
 \_

; Two spelled types name one implementation subject: the same type, or a
; class and the struct it holds. Only REQ and required methods ask this;
; everywhere else Foo<FakeBus> and Foo<FakeBusData> stay two types.
B1 same_subject: [ @Generics g | @C1 sa | @C1 sb ]
 | IF [ (strcmp)[ sa | sb ] == 0 ]
 |  | RET [ TRUE ]
 |  \_
 | @ABYSS base = 0
 | IF [ (map_get)[ @(g.bases) | sa | @base ] == 1 && (strcmp)[ base AS @C1 | sb ] == 0 ]
 |  | RET [ TRUE ]
 |  \_
 | RET [ (map_get)[ @(g.bases) | sb | @base ] == 1 && (strcmp)[ base AS @C1 | sa ] == 0 ]
 \_

; Two interface references are the same interface with the same
; arguments, each argument up to its implementation subject:
; SPIBus<STM32SPI> is met by a class that takes SPIBus<STM32SPIData>.
B1 same_iface: [ @Generics g | @ASTNode have | @ASTNode want ]
 | IF [ (strcmp)[ have.as.type.type.as.ident | want.as.type.type.as.ident ] != 0 ]
 |  | RET [ FALSE ]
 |  \_
 | @ASTNode a = have.as.type.args
 | @ASTNode b = want.as.type.args
 | WHILE [ a != 0 && b != 0 ]
 |  | IF [ !(same_subject)[ g | (type_spelling)[ g | a.as.list.item ] | (type_spelling)[ g | b.as.list.item ] ] ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | a = a.as.list.next
 |  | b = b.as.list.next
 |  \_
 | RET [ a == 0 && b == 0 ]
 \_

; --- required methods -------------------------------------------------------
;
; A method with no body in an interface is required: the interface needs
; it, and another interface of the same class must give it, with exactly
; its signature. Bodies still may not meet: two are an error.

TYPE ReqMethod: STRUCT
 | @ASTNode decl      ; as declared, the class's arguments in place
 | @ASTNode fref      ; the interface needing it, as the class names it
 | @ASTNode where     ; where to report it missing
 | B1       anon
 \_

; `U8 transfer: [ U8 ]`: a method's signature past its `me`, for messages.
@C1 sig_spelling: [ @Generics g | @C1 name | @ASTNode decl | B1 skip_me ]
 | String s
 | (s.init_cstr)[ (type_spelling)[ g | decl.as.fn_decl.type ] ]
 | (s.push)[ ' ' ]
 | (s.append)[ name ]
 | (s.append)[ ": [" ]
 | @ASTNode p = decl.as.fn_decl.params
 | IF [ skip_me && p != 0 ]
 |  | p = p.as.parametre.next_param
 |  \_
 | WHILE [ p != 0 ]
 |  | (s.push)[ ' ' ]
 |  | IF [ p.as.parametre.vaarg ]
 |  |  | (s.append)[ "..." ]
 |  | ELSE
 |  |  | (s.append)[ (type_spelling)[ g | p.as.parametre.type ] ]
 |  |  \_
 |  | p = p.as.parametre.next_param
 |  | IF [ p != 0 ]
 |  |  | (s.append)[ " |" ]
 |  |  \_
 |  \_
 | (s.append)[ " ]" ]
 | RET [ s.data ]
 \_

; The given method has the needed one's signature exactly: return type,
; every parameter, `...` -- each type up to its implementation subject.
B1 sig_matches: [ @Generics g | @ASTNode want | @ASTNode have | B1 skip_me ]
 | IF [ !(same_subject)[ g | (type_spelling)[ g | want.as.fn_decl.type ] | (type_spelling)[ g | have.as.fn_decl.type ] ] ]
 |  | RET [ FALSE ]
 |  \_
 | @ASTNode p = want.as.fn_decl.params
 | @ASTNode q = have.as.fn_decl.params
 | IF [ skip_me && q != 0 ]
 |  | q = q.as.parametre.next_param
 |  \_
 | WHILE [ p != 0 && q != 0 ]
 |  | IF [ p.as.parametre.vaarg != q.as.parametre.vaarg ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | IF [ !(p.as.parametre.vaarg) && !(same_subject)[ g | (type_spelling)[ g | p.as.parametre.type ] | (type_spelling)[ g | q.as.parametre.type ] ] ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | p = p.as.parametre.next_param
 |  | q = q.as.parametre.next_param
 |  \_
 | RET [ p == 0 && q == 0 ]
 \_

; Every method the class's interfaces need, given by one of them.
ABYSS check_required: [ @Generics g | @C1 cls | @Vector<ReqMethod> needs ]
 | C1 msg{768}
 | U64 i = 0
 | WHILE [ i < (needs.size)[] ]
 |  | @ReqMethod r = (needs.at)[ i ]
 |  | i += 1
 |  | @C1 short = r.decl.as.fn_decl.ident.as.ident
 |  | @C1 fname = (iface_spelling)[ g | r.fref ]
 |  | @C1 want = (sig_spelling)[ g | short | r.decl | FALSE ]
 |  | @ABYSS d = 0
 |  | IF [ (map_get)[ @(g.done) | (method_name)[ cls | short ] | @d ] != 1 ]
 |  |  | (snprintf)[ msg | 768 | "`%s` cannot IMPL %s: it needs `%s`, and no interface of `%s` gives it" | cls | fname | want | cls ]
 |  |  | (gn_error)[ r.where | "%s%s" | msg | "" ]
 |  |  \_
 |  | @ASTNode have = (d AS @ASTNode).as.fn_def.decl
 |  | B1 skip = !(have.as.fn_decl.is_anon)
 |  | IF [ have.as.fn_decl.is_anon != r.anon || !(sig_matches)[ g | r.decl | have | skip ] ]
 |  |  | @C1 got = (sig_spelling)[ g | short | have | skip ]
 |  |  | IF [ have.as.fn_decl.is_anon != r.anon ]
 |  |  |  | got = "an ANONYMOUS method where an ordinary one is needed, or the other way round"
 |  |  |  \_
 |  |  | (snprintf)[ msg | 768 | "`%s` cannot IMPL %s: it needs `%s`, and `%s` gives `%s`" | cls | fname | want | cls | got ]
 |  |  | (gn_error)[ r.where | "%s%s" | msg | "" ]
 |  |  \_
 |  \_
 \_

; What the interface's REQ asks of the class taking it: each field, with
; exactly its type, in the struct the class holds, and each interface in
; the class's own IMPL list. Checked before any method is, so a class
; that does not fit is told so at its IMPL, not deep in a method body.
; Errors point at `where`: the class's IMPL entry, or for an instance of a
; generic class, the use that made it -- that is where the type came from.
ABYSS check_reqs: [ @Generics g | @C1 cls | @ASTNode base_td | @ASTNode fref | @ASTNode ifc | @Subst s | @ASTNode impls | @ASTNode where ]
 | @C1 fname = (iface_spelling)[ g | fref ]
 | C1 msg{512}
 | @ASTNode r = ifc.as.iface.reqs
 | WHILE [ r != 0 ]
 |  | @ASTNode it = r.as.list.item
 |  | IF [ it.kind == NT_FIELD ]
 |  |  | @C1 fld = it.as.rcrd_flds.ident.as.ident
 |  |  | @ASTNode wt = (clone)[ g | it.as.rcrd_flds.type | s ]
 |  |  | @C1 want = (type_spelling)[ g | wt ]
 |  |  | @ASTNode f = base_td.as.type_def.tdef.as.record.fields
 |  |  | WHILE [ f != 0 && (strcmp)[ f.as.rcrd_flds.ident.as.ident | fld ] != 0 ]
 |  |  |  | f = f.as.rcrd_flds.next_field
 |  |  |  \_
 |  |  | IF [ f == 0 ]
 |  |  |  | (snprintf)[ msg | 512 | "`%s` cannot IMPL %s: it has no field `%s` (%s)" | cls | fname | fld | want ]
 |  |  |  | (gn_error)[ where | "%s%s" | msg | "" ]
 |  |  |  \_
 |  |  | @ASTNode ht = (clone)[ g | f.as.rcrd_flds.type | 0 ]
 |  |  | @C1 have = (type_spelling)[ g | ht ]
 |  |  | IF [ (strcmp)[ have | want ] != 0 || ht.as.type.arr != wt.as.type.arr ]
 |  |  |  | (snprintf)[ msg | 512 | "`%s` cannot IMPL %s: its field `%s` is %s, and REQ wants %s" | cls | fname | fld | have | want ]
 |  |  |  | (gn_error)[ where | "%s%s" | msg | "" ]
 |  |  |  \_
 |  | ELIF [ it.kind == NT_REQ_IMPL ]
 |  |  | ; BUS IMPL SPIBus<BUS>: the type put for BUS, not this class
 |  |  | @ASTNode subj = (clone)[ g | it.as.req_impl.subject | s ]
 |  |  | @ASTNode need = (clone)[ g | it.as.req_impl.iface | s ]
 |  |  | B1 need_iface = need.as.type.kind == TT_USER_TYPE && need.as.type.ptrs == 0
 |  |  | IF [ !need_iface || !(gn_has)[ @(g.iface_tmpls) | need.as.type.type.as.ident ] ]
 |  |  |  | (gn_error)[ it.as.req_impl.iface | "REQ: what follows IMPL must be an interface%s%s" | "" | "" ]
 |  |  |  \_
 |  |  | @C1 sn = (type_spelling)[ g | subj ]
 |  |  | @C1 nn = (iface_spelling)[ g | need ]
 |  |  |
 |  |  | ; the class it names -- this one, when it names this one's struct
 |  |  | @ASTNode list = 0
 |  |  | @ABYSS found_list = 0
 |  |  | B1 is_class = FALSE
 |  |  | IF [ subj.as.type.kind == TT_USER_TYPE && subj.as.type.ptrs == 0 ]
 |  |  |  | @C1 subn = subj.as.type.type.as.ident
 |  |  |  | IF [ (strcmp)[ subn | cls ] == 0 || (strcmp)[ subn | base_td.as.type_def.ident.as.ident ] == 0 ]
 |  |  |  |  | list = impls
 |  |  |  |  | is_class = TRUE
 |  |  |  | ELIF [ (map_get)[ @(g.impls) | subn | @found_list ] == 1 ]
 |  |  |  |  | list = found_list AS @ASTNode
 |  |  |  |  | is_class = TRUE
 |  |  |  |  \_
 |  |  |  \_
 |  |  | IF [ !is_class ]
 |  |  |  | (snprintf)[ msg | 512 | "`%s` cannot IMPL %s: it needs %s to IMPL %s, and %s is not a CLASS" | cls | fname | sn | nn | sn ]
 |  |  |  | (gn_error)[ where | "%s%s" | msg | "" ]
 |  |  |  \_
 |  |  | B1 has = FALSE
 |  |  | WHILE [ list != 0 && !has ]
 |  |  |  | has = (same_iface)[ g | list.as.list.item | need ]
 |  |  |  | list = list.as.list.next
 |  |  |  \_
 |  |  | IF [ !has ]
 |  |  |  | (snprintf)[ msg | 512 | "`%s` cannot IMPL %s: it needs %s to IMPL %s, and it does not" | cls | fname | sn | nn ]
 |  |  |  | (gn_error)[ where | "%s%s" | msg | "" ]
 |  |  |  \_
 |  | ELSE
 |  |  | @ASTNode need = (clone)[ g | it | s ]
 |  |  | B1 is_iface = need.as.type.kind == TT_USER_TYPE && need.as.type.ptrs == 0
 |  |  | IF [ !is_iface || !(gn_has)[ @(g.iface_tmpls) | need.as.type.type.as.ident ] ]
 |  |  |  | (gn_error)[ it | "REQ lists fields, as `I32 hp`, and interfaces; this is neither%s%s" | "" | "" ]
 |  |  |  \_
 |  |  | @C1 nn = (iface_spelling)[ g | need ]
 |  |  | B1 found = FALSE
 |  |  | @ASTNode c = impls
 |  |  | WHILE [ c != 0 && !found ]
 |  |  |  | found = (same_iface)[ g | c.as.list.item | need ]
 |  |  |  | c = c.as.list.next
 |  |  |  \_
 |  |  | IF [ !found ]
 |  |  |  | (snprintf)[ msg | 512 | "`%s` cannot IMPL %s: it must also IMPL %s" | cls | fname | nn ]
 |  |  |  | (gn_error)[ where | "%s%s" | msg | "" ]
 |  |  |  \_
 |  |  \_
 |  | r = r.as.list.next
 |  \_
 \_

; `impls` is every interface the class names, for check_reqs.
ABYSS inst_iface: [ @Generics g | @C1 cls | @ASTNode base_td | @ASTNode fref | @ASTNode impls | @ASTNode where | @Vector<ReqMethod> needs ]
 | IF [ fref.as.type.kind != TT_USER_TYPE || fref.as.type.ptrs != 0 ]
 |  | (gn_error)[ fref | "IMPL lists interfaces, and this is a type%s%s" | "" | "" ]
 |  \_
 | @C1 fname = fref.as.type.type.as.ident
 | @ASTNode ifc = (gn_find)[ @(g.iface_tmpls) | fname ]
 | IF [ ifc == 0 ]
 |  | (gn_error)[ fref | "unknown interface `%s`%s" | fname | "" ]
 |  \_
 |
 | @ASTNode a = fref.as.type.args
 | WHILE [ a != 0 ]
 |  | (resolve_type)[ g | a.as.list.item ]
 |  | a = a.as.list.next
 |  \_
 | (check_arity)[ fref | fname | ifc.as.iface.gparams | fref.as.type.args ]
 |
 | Subst s
 | s.params = ifc.as.iface.gparams
 | s.args = fref.as.type.args
 |
 | ; the receiver the interface was written for must be what the class holds
 | @ASTNode recv = ifc.as.iface.recv
 | @ASTNode rt = (clone)[ g | recv.as.parametre.type | @s ]
 | (resolve_type)[ g | rt ]
 | @C1 base = base_td.as.type_def.ident.as.ident
 | B1 fits = rt.as.type.kind == TT_USER_TYPE && rt.as.type.ptrs == 1
 | IF [ fits ]
 |  | @C1 rn = rt.as.type.type.as.ident
 |  | fits = (strcmp)[ rn | base ] == 0 || (strcmp)[ rn | cls ] == 0
 |  \_
 | IF [ !fits ]
 |  | String want
 |  | (want.init_cstr)[ "" ]
 |  | (append_type_name)[ @want | rt ]
 |  | (gn_error)[ fref | "`%s` works on `%s`, which this CLASS does not hold" | fname | want.data ]
 |  \_
 | (check_reqs)[ g | cls | base_td | fref | ifc | @s | impls | where ]
 |
 | @C1 me = recv.as.parametre.ident.as.ident
 | @ASTNode m = ifc.as.iface.methods
 | WHILE [ m != 0 ]
 |  | ; a required method gives nothing: noted, to be met once every
 |  | ; interface of the class is in
 |  | IF [ m.as.method.is_req ]
 |  |  | ReqMethod rq
 |  |  | rq.decl = (clone)[ g | m.as.method.def.as.fn_def.decl | @s ]
 |  |  | rq.fref = fref
 |  |  | rq.where = where
 |  |  | rq.anon = m.as.method.is_anon
 |  |  | (needs.push)[ rq ]
 |  |  | m = m.as.method.next
 |  |  | CONTINUE
 |  |  \_
 |  | @ASTNode def = (clone)[ g | m.as.method.def | @s ]
 |  | @ASTNode decl = def.as.fn_def.decl
 |  | @C1 mname = (method_name)[ cls | decl.as.fn_decl.ident.as.ident ]
 |  | IF [ (gn_has)[ @(g.done) | mname ] ]
 |  |  | (gn_error)[ decl | "`%s` is defined by two interfaces of `%s`" | decl.as.fn_decl.ident.as.ident | cls ]
 |  |  \_
 |  | (map_put)[ @(g.done) | mname | def AS @ABYSS ]
 |  |
 |  | decl.as.fn_decl.ident = (gn_ident)[ g | mname | decl.as.fn_decl.ident ]
 |  | decl.as.fn_decl.owner = cls
 |  | decl.as.fn_decl.is_private = m.as.method.is_private
 |  | decl.as.fn_decl.is_anon = m.as.method.is_anon
 |  |
 |  | ; an ANONYMOUS method is a plain function in the class's name
 |  | IF [ m.as.method.is_anon ]
 |  |  | (emit)[ g | TUST_FN_DEF | def ]
 |  |  | m = m.as.method.next
 |  |  | CONTINUE
 |  |  \_
 |  |
 |  | ; every other method takes `@Cls me` ahead of its declared parameters
 |  | @ASTNode ty = (ast_node_new)[ g.ast ]
 |  | ty.kind = NT_TYPE
 |  | ty.loc = recv.loc
 |  | ty.as.type.kind = TT_USER_TYPE
 |  | ty.as.type.ptrs = 1
 |  | ; as the interface wrote it: [ @CONST PinData me ] gives `@CONST Pin me`
 |  | ty.as.type.quals = rt.as.type.quals
 |  | ty.as.type.type = (gn_ident)[ g | cls | recv ]
 |  |
 |  | @ASTNode self = (ast_node_new)[ g.ast ]
 |  | self.kind = NT_PARAMETRE
 |  | self.loc = recv.loc
 |  | self.as.parametre.ident = (gn_ident)[ g | me | recv ]
 |  | self.as.parametre.type = ty
 |  | self.as.parametre.next_param = decl.as.fn_decl.params
 |  | decl.as.fn_decl.params = self
 |  |
 |  | (emit)[ g | TUST_FN_DEF | def ]
 |  | m = m.as.method.next
 |  \_
 | RET
 \_

ABYSS inst_class: [ @Generics g | @ASTNode at | @ASTNode cls | @C1 name | @ASTNode args ]
 | (check_arity)[ at | cls.as.klass.ident.as.ident | cls.as.klass.gparams | args ]
 | Subst s
 | s.params = cls.as.klass.gparams
 | s.args = args
 |
 | @ASTNode base = (clone)[ g | cls.as.klass.base | @s ]
 | (resolve_type)[ g | base ]
 | @ASTNode base_td = (class_base)[ g | cls | base ]
 |
 | ; a STRUCT of its own, with the base's fields
 | @ASTNode td = (ast_node_new)[ g.ast ]
 | td.kind = NT_TYPE_DEF
 | td.loc = cls.loc
 | td.as.type_def.kind = TD_RECORD
 | td.as.type_def.ident = (gn_ident)[ g | name | cls.as.klass.ident ]
 | td.as.type_def.tdef = (clone)[ g | base_td.as.type_def.tdef | 0 ]
 | (map_put)[ @(g.types) | name | td AS @ABYSS ]
 | (emit)[ g | TUST_TYPE_DEF | td ]
 |
 | ; every interface as this class names it, first: a REQ is checked
 | ; against all of them
 | @ASTNode impls = 0
 | @@ASTNode itail = @impls
 | @ASTNode it = cls.as.klass.ifaces
 | WHILE [ it != 0 ]
 |  | @ASTNode li = (ast_node_new)[ g.ast ]
 |  | li.kind = NT_LIST
 |  | li.as.list.item = (clone)[ g | it.as.list.item | @s ]
 |  | ?(itail) = li
 |  | itail = @(li.as.list.next)
 |  | it = it.as.list.next
 |  \_
 | Vector<ReqMethod> needs
 | (needs.init)[ 4 ]
 |
 | ; before the interfaces are made: one of theirs may ask about this class
 | (map_put)[ @(g.impls) | name | impls AS @ABYSS ]
 | (map_put)[ @(g.bases) | name | base_td.as.type_def.ident.as.ident AS @ABYSS ]
 | @ASTNode l = impls
 | WHILE [ l != 0 ]
 |  | @ASTNode where = l.as.list.item
 |  | IF [ cls.as.klass.gparams != 0 ]
 |  |  | where = at
 |  |  \_
 |  | (inst_iface)[ g | name | base_td | l.as.list.item | impls | where | @needs ]
 |  | l = l.as.list.next
 |  \_
 | (check_required)[ g | name | @needs ]
 | (needs.deinit)[]
 | RET
 \_

ABYSS instantiate: [ @Generics g | @ASTNode at | @C1 tmpl | @C1 name | @ASTNode args ]
 | ; a template that instantiates itself with a bigger argument never
 | ; ends; its names grow with every round, which gives it away long
 | ; before the count does -- and the work is quadratic in that length
 | g.count += 1
 | IF [ g.count > 10000 || (strlen)[ name ] > 1000 ]
 |  | (gn_error)[ at | "too many instances of `%s`; is it generic in itself, as in X<@T> inside X<T>?%s" | tmpl | "" ]
 |  \_
 | (map_put)[ @(g.done) | name | at AS @ABYSS ]
 |
 | @ASTNode d = (gn_find)[ @(g.type_tmpls) | tmpl ]
 | IF [ d != 0 ]
 |  | (inst_type)[ g | at | d | name | args ]
 |  | RET
 |  \_
 | d = (gn_find)[ @(g.class_tmpls) | tmpl ]
 | IF [ d != 0 ]
 |  | (inst_class)[ g | at | d | name | args ]
 |  | RET
 |  \_
 | IF [ (gn_has)[ @(g.iface_tmpls) | tmpl ] ]
 |  | (gn_error)[ at | "`%s` is an interface, not a type%s" | tmpl | "" ]
 |  \_
 | (gn_error)[ at | "`%s` is not a generic type%s" | tmpl | "" ]
 | RET
 \_

; Make a type reference concrete: Vec<I32> becomes a plain reference to
; the TYPE named "Vec<I32>", instantiated on first sight.
ABYSS resolve_type: [ @Generics g | @ASTNode tn ]
 | IF [ tn.as.type.kind == TT_FN_TYPE ]
 |  | (resolve_type)[ g | tn.as.type.type ]
 |  | @ASTNode p = tn.as.type.args
 |  | WHILE [ p != 0 ]
 |  |  | IF [ p.as.list.item != 0 ]
 |  |  |  | (resolve_type)[ g | p.as.list.item ]
 |  |  |  \_
 |  |  | p = p.as.list.next
 |  |  \_
 |  | RET
 |  \_
 | IF [ tn.as.type.kind != TT_USER_TYPE ]
 |  | RET
 |  \_
 | @C1 tmpl = tn.as.type.type.as.ident
 |
 | IF [ tn.as.type.args == 0 ]
 |  | IF [ (gn_has)[ @(g.type_tmpls) | tmpl ] || (gn_has)[ @(g.class_tmpls) | tmpl ] ]
 |  |  | (gn_error)[ tn | "`%s` is generic and needs type arguments, as in %s<I32>" | tmpl | tmpl ]
 |  |  \_
 |  | RET
 |  \_
 |
 | ; innermost first, so the name is spelled from concrete arguments
 | @ASTNode a = tn.as.type.args
 | WHILE [ a != 0 ]
 |  | (resolve_type)[ g | a.as.list.item ]
 |  | a = a.as.list.next
 |  \_
 |
 | @C1 name = (instance_name)[ tmpl | tn.as.type.args ]
 | IF [ !(gn_has)[ @(g.done) | name ] ]
 |  | (instantiate)[ g | tn | tmpl | name | tn.as.type.args ]
 |  \_
 |
 | tn.as.type.type = (gn_ident)[ g | name | tn.as.type.type ]
 | tn.as.type.written = tn.as.type.args
 | tn.as.type.args = 0
 | RET
 \_

; Every type reference anywhere below n.
ABYSS resolve: [ @Generics g | @ASTNode n ]
 | IF [ n == 0 ]
 |  | RET
 |  \_
 | I32 k = n.kind
 |
 | IF [ k == NT_TYPE ]
 |  | (resolve_type)[ g | n ]
 |  | RET
 |  \_
 | IF [ k == NT_FN_DECL ]
 |  | (resolve)[ g | n.as.fn_decl.type ]
 |  | (resolve)[ g | n.as.fn_decl.params ]
 |  | RET
 |  \_
 | IF [ k == NT_FN_DEF ]
 |  | (resolve)[ g | n.as.fn_def.decl ]
 |  | (resolve)[ g | n.as.fn_def.block ]
 |  | RET
 |  \_
 | IF [ k == NT_TYPE_DEF ]
 |  | (resolve)[ g | n.as.type_def.tdef ]
 |  | RET
 |  \_
 | IF [ k == NT_PARAMETRE ]
 |  | @ASTNode p = n
 |  | WHILE [ p != 0 ]
 |  |  | (resolve)[ g | p.as.parametre.type ]
 |  |  | p = p.as.parametre.next_param
 |  |  \_
 |  | RET
 |  \_
 | IF [ k == NT_RECORD ]
 |  | @ASTNode f = n.as.record.fields
 |  | WHILE [ f != 0 ]
 |  |  | (resolve)[ g | f.as.rcrd_flds.type ]
 |  |  | f = f.as.rcrd_flds.next_field
 |  |  \_
 |  | RET
 |  \_
 | IF [ k == NT_BLOCK ]
 |  | @ASTNode st = n.as.block.stmts
 |  | WHILE [ st != 0 ]
 |  |  | (resolve)[ g | st.as.stmt.stmt ]
 |  |  | st = st.as.stmt.next_stmt
 |  |  \_
 |  | RET
 |  \_
 | IF [ k == NT_RET ]
 |  | (resolve)[ g | n.as.ret.expr ]
 |  | RET
 |  \_
 | IF [ k == NT_COND ]
 |  | (resolve)[ g | n.as.cond.if_part ]
 |  | (resolve)[ g | n.as.cond.elif_part ]
 |  | (resolve)[ g | n.as.cond.else_part ]
 |  | RET
 |  \_
 | IF [ k == NT_IF ]
 |  | (resolve)[ g | n.as.if_cond.expr ]
 |  | (resolve)[ g | n.as.if_cond.block ]
 |  | RET
 |  \_
 | IF [ k == NT_ELIF ]
 |  | (resolve)[ g | n.as.elif_cond.expr ]
 |  | (resolve)[ g | n.as.elif_cond.block ]
 |  | (resolve)[ g | n.as.elif_cond.next_elif ]
 |  | RET
 |  \_
 | IF [ k == NT_ELSE ]
 |  | (resolve)[ g | n.as.else_cond.block ]
 |  | RET
 |  \_
 | IF [ k == NT_LOOP ]
 |  | (resolve)[ g | n.as.loop.expr ]
 |  | (resolve)[ g | n.as.loop.block ]
 |  | RET
 |  \_
 | IF [ k == NT_VAR_DECL ]
 |  | (resolve)[ g | n.as.var_decl.type ]
 |  | (resolve)[ g | n.as.var_decl.init ]
 |  | RET
 |  \_
 | IF [ k == NT_EXPR ]
 |  | (resolve)[ g | n.as.expr.expr ]
 |  | RET
 |  \_
 | IF [ k == NT_BIN_OP ]
 |  | (resolve)[ g | n.as.bin_op.left ]
 |  | (resolve)[ g | n.as.bin_op.right ]
 |  | RET
 |  \_
 | IF [ k == NT_UNY_OP ]
 |  | (resolve)[ g | n.as.uny_op.operand ]
 |  | RET
 |  \_
 | IF [ k == NT_FN_CALL ]
 |  | (resolve)[ g | n.as.fn_call.recv ]
 |  | (resolve)[ g | n.as.fn_call.target ]
 |  | @ASTNode a = n.as.fn_call.args
 |  | WHILE [ a != 0 ]
 |  |  | (resolve)[ g | a.as.argument.argument ]
 |  |  | a = a.as.argument.next_arg
 |  |  \_
 |  | RET
 |  \_
 | IF [ k == NT_BUILTIN ]
 |  | (resolve)[ g | n.as.builtin.size ]
 |  | RET
 |  \_
 | IF [ k == NT_STATIC_ASSERT ]
 |  | (resolve)[ g | n.as.assert.cond ]
 |  | RET
 |  \_
 | IF [ k == NT_CAST ]
 |  | (resolve)[ g | n.as.cast.type ]
 |  | (resolve)[ g | n.as.cast.expr ]
 |  | RET
 |  \_
 | RET
 \_

; --- entry point ----------------------------------------------------------

; USES is textual and not include-once, so the same definition routinely
; arrives several times. The first one wins, as it does in codegen.
B1 gn_template: [ @Map m | @C1 name | @ASTNode node | @Generics g ]
 | IF [ (gn_has)[ @(g.types) | name ] || (gn_has)[ @(g.type_tmpls) | name ] ]
 |  | RET [ FALSE ]
 |  \_
 | IF [ (gn_has)[ @(g.class_tmpls) | name ] || (gn_has)[ @(g.iface_tmpls) | name ] ]
 |  | RET [ FALSE ]
 |  \_
 | (map_put)[ m | name | node AS @ABYSS ]
 | RET [ TRUE ]
 \_

ABYSS generics_pass: [ @AST ast ]
 | Generics g
 | g.ast = ast
 | (map_init)[ @(g.type_tmpls) | 64 ]
 | (map_init)[ @(g.iface_tmpls) | 64 ]
 | (map_init)[ @(g.class_tmpls) | 64 ]
 | (map_init)[ @(g.types) | 256 ]
 | (map_init)[ @(g.done) | 256 ]
 | (map_init)[ @(g.impls) | 64 ]
 | (map_init)[ @(g.bases) | 64 ]
 | (g.work.init)[ 64 ]
 | g.out_head = 0
 | g.out_tail = @(g.out_head)
 | g.count = 0
 |
 | ; take the templates out of the unit; classes without parameters wait
 | ; until every interface has been seen
 | @ASTNode plain = 0
 | @@ASTNode plain_tail = @plain
 | @@ASTNode link = @(ast.root.as.tu.tu_stmt)
 | WHILE [ ?(link) != 0 ]
 |  | @ASTNode ts = ?(link)
 |  | I32 k = ts.as.tu_stmt.kind
 |  | @ASTNode node = ts.as.tu_stmt.tu_stmt
 |  | B1 drop = TRUE
 |  |
 |  | IF [ k == TUST_TYPE_DEF && node.as.type_def.gparams != 0 ]
 |  |  | IF [ node.as.type_def.kind == TD_ENUM ]
 |  |  |  | (gn_error)[ node | "ENUM `%s` cannot be generic: its constants do not depend on the parameters%s" | node.as.type_def.ident.as.ident | "" ]
 |  |  |  \_
 |  |  | (gn_template)[ @(g.type_tmpls) | node.as.type_def.ident.as.ident | node | @g ]
 |  | ELIF [ k == TUST_TYPE_DEF ]
 |  |  | (gn_template)[ @(g.types) | node.as.type_def.ident.as.ident | node | @g ]
 |  |  | drop = FALSE
 |  | ELIF [ k == TUST_IFACE ]
 |  |  | (gn_template)[ @(g.iface_tmpls) | node.as.iface.ident.as.ident | node | @g ]
 |  | ELIF [ k == TUST_CLASS && node.as.klass.gparams != 0 ]
 |  |  | (gn_template)[ @(g.class_tmpls) | node.as.klass.ident.as.ident | node | @g ]
 |  | ELIF [ k == TUST_CLASS ]
 |  |  | @ASTNode item = (ast_node_new)[ ast ]
 |  |  | item.kind = NT_LIST
 |  |  | item.as.list.item = node
 |  |  | ?(plain_tail) = item
 |  |  | plain_tail = @(item.as.list.next)
 |  | ELSE
 |  |  | drop = FALSE
 |  |  \_
 |  |
 |  | IF [ drop ]
 |  |  | ?(link) = ts.as.tu_stmt.next_tu_stmt
 |  | ELSE
 |  |  | link = @(ts.as.tu_stmt.next_tu_stmt)
 |  |  \_
 |  \_
 |
 | ; what every plain class takes, before any is made: a REQ may ask about
 | ; a class further down the file
 | @ASTNode pr = plain
 | WHILE [ pr != 0 ]
 |  | @ASTNode pk = pr.as.list.item
 |  | (map_put)[ @(g.impls) | pk.as.klass.ident.as.ident | pk.as.klass.ifaces AS @ABYSS ]
 |  | IF [ pk.as.klass.base != 0 && pk.as.klass.base.as.type.kind == TT_USER_TYPE ]
 |  |  | (map_put)[ @(g.bases) | pk.as.klass.ident.as.ident | pk.as.klass.base.as.type.type.as.ident AS @ABYSS ]
 |  |  \_
 |  | pr = pr.as.list.next
 |  \_
 |
 | @ASTNode pc = plain
 | WHILE [ pc != 0 ]
 |  | @ASTNode cls = pc.as.list.item
 |  | @C1 nm = cls.as.klass.ident.as.ident
 |  | IF [ (gn_has)[ @(g.types) | nm ] && !(gn_has)[ @(g.done) | nm ] ]
 |  |  | (gn_error)[ cls | "CLASS `%s` has the name of an existing TYPE%s" | nm | "" ]
 |  |  \_
 |  | IF [ (gn_template)[ @(g.done) | nm | cls | @g ] ]
 |  |  | (inst_class)[ @g | cls | cls | nm | 0 ]
 |  |  \_
 |  | pc = pc.as.list.next
 |  \_
 |
 | ; whatever is left is concrete; its uses pull in the instances, whose
 | ; own uses pull in more
 | @ASTNode ts = ast.root.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | (resolve)[ @g | ts.as.tu_stmt.tu_stmt ]
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 |
 | U64 i = 0
 | WHILE [ i < (g.work.size)[] ]
 |  | @ASTNode n = ?((g.work.at)[ i ])
 |  | (resolve)[ @g | n ]
 |  | i = i + 1
 |  \_
 |
 | ?(link) = g.out_head
 |
 | (g.work.deinit)[]
 | (map_deinit)[ @(g.type_tmpls) ]
 | (map_deinit)[ @(g.iface_tmpls) ]
 | (map_deinit)[ @(g.class_tmpls) ]
 | (map_deinit)[ @(g.types) ]
 | (map_deinit)[ @(g.done) ]
 | (map_deinit)[ @(g.impls) ]
 | (map_deinit)[ @(g.bases) ]
 | RET
 \_
