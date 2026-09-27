; meta.pl -- the PLUM counterpart of src/meta.c
;
; Walks the AST collecting a scoped symbol table plus name->node maps for
; string literals, function declarations and type definitions. No type
; checking, as in the C version.
;
; Deviations from src/meta.c, all bug fixes rather than translation:
;   * NT_COND and NT_RET have cases here. In C they are missing, so whole
;     conditionals and every return expression are silently never walked.
;   * NT_IF reads its own payload; the C version reads as.cond.* off an
;     NT_IF node, which is union confusion over uninitialised memory.
;   * NT_CAST is walked through.

!USES <ast.pl>
!USES <../lib/vector.pl>
!USES <../lib/map.pl>
!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>

TYPE SymKind: ENUM
 | SYM_VAR
 | SYM_FN
 | SYM_TYPE
 \_

TYPE Symbol: STRUCT
 | I32      kind
 | @ASTNode type
 | @ASTNode decl
 | @C1      name
 \_

TYPE Scope: STRUCT
 | Vector<Symbol> syms
 \_

TYPE SymTab: STRUCT
 | Vector<Scope> scopes
 | U64           curr
 \_

TYPE Meta: STRUCT
 | SymTab symtab
 | Map    str_lits
 | Map    func_decls
 | Map    types
 \_

ABYSS symtab_push_scope: [ @SymTab st ]
 | Scope sc
 | (sc.syms.init)[ 8 ]
 | (st.scopes.push)[ sc ]
 | st.curr = (st.scopes.size)[] - 1
 | RET
 \_

ABYSS symtab_pop_scope: [ @SymTab st ]
 | IF [ (st.scopes.empty)[] ]
 |  | RET
 |  \_
 | ((st.scopes.last)[].syms.deinit)[]
 | (st.scopes.pop)[]
 |
 | IF [ (st.scopes.empty)[] ]
 |  | st.curr = 0
 | ELSE
 |  | st.curr = (st.scopes.size)[] - 1
 |  \_
 | RET
 \_

B1 symtab_insert: [ @SymTab st | @C1 name | I32 kind | @ASTNode type | @ASTNode decl ]
 | @Scope sc = (st.scopes.at)[ st.curr ]
 |
 | U64 i = 0
 | WHILE [ i < (sc.syms.size)[] ]
 |  | @Symbol tmp = (sc.syms.at)[ i ]
 |  | IF [ (strcmp)[ tmp.name | name ] == 0 ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | i = i + 1
 |  \_
 |
 | Symbol s
 | s.kind = kind
 | s.type = type
 | s.decl = decl
 | s.name = (strdup)[ name ]
 | (sc.syms.push)[ s ]
 | RET [ TRUE ]
 \_

ABYSS collect_node: [ @ASTNode node | @Meta m ]

ABYSS collect_block_stmts: [ @ASTNode block | @Meta m ]
 | @ASTNode s = block.as.block.stmts
 | WHILE [ s != 0 ]
 |  | (collect_node)[ s.as.stmt.stmt | m ]
 |  | s = s.as.stmt.next_stmt
 |  \_
 | RET
 \_

ABYSS collect_node: [ @ASTNode node | @Meta m ]
 | IF [ node == 0 ]
 |  | RET
 |  \_
 |
 | I32 k = node.kind
 |
 | IF [ k == NT_TRANSLATION_UNIT ]
 |  | @ASTNode ts = node.as.tu.tu_stmt
 |  | WHILE [ ts != 0 ]
 |  |  | (collect_node)[ ts.as.tu_stmt.tu_stmt | m ]
 |  |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  |  \_
 |  | RET
 |  \_
 |
 | IF [ k == NT_FN_DECL ]
 |  | @C1 fname = node.as.fn_decl.ident.as.ident
 |  | (map_put)[ @(m.func_decls) | fname | node AS @ABYSS ]
 |  | (symtab_insert)[ @(m.symtab) | fname | SYM_FN | node.as.fn_decl.type | node ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_FN_DEF ]
 |  | (collect_node)[ node.as.fn_def.decl | m ]
 |  | (symtab_push_scope)[ @(m.symtab) ]
 |  |
 |  | @ASTNode p = node.as.fn_def.decl.as.fn_decl.params
 |  | WHILE [ p != 0 ]
 |  |  | IF [ !(p.as.parametre.vaarg) ]
 |  |  |  | @C1 pn = p.as.parametre.ident.as.ident
 |  |  |  | (symtab_insert)[ @(m.symtab) | pn | SYM_VAR | p.as.parametre.type | p ]
 |  |  |  \_
 |  |  | p = p.as.parametre.next_param
 |  |  \_
 |  |
 |  | (collect_node)[ node.as.fn_def.block | m ]
 |  | (symtab_pop_scope)[ @(m.symtab) ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_TYPE_DEF ]
 |  | @C1 tname = node.as.type_def.ident.as.ident
 |  | (map_put)[ @(m.types) | tname | node AS @ABYSS ]
 |  | (symtab_insert)[ @(m.symtab) | tname | SYM_TYPE | 0 | node ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_VAR_DECL ]
 |  | @C1 vname = node.as.var_decl.ident.as.ident
 |  | (symtab_insert)[ @(m.symtab) | vname | SYM_VAR | node.as.var_decl.type | node ]
 |  | (collect_node)[ node.as.var_decl.init | m ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_LITERAL ]
 |  | IF [ node.as.literal.kind == LT_STRING ]
 |  |  | (map_put)[ @(m.str_lits) | node.as.literal.as.str_lit | node AS @ABYSS ]
 |  |  \_
 |  | RET
 |  \_
 |
 | IF [ k == NT_BLOCK ]
 |  | (symtab_push_scope)[ @(m.symtab) ]
 |  | (collect_block_stmts)[ node | m ]
 |  | (symtab_pop_scope)[ @(m.symtab) ]
 |  | RET
 |  \_
 |
 | ; src/meta.c has no NT_COND case at all, so conditionals are never
 | ; walked there. Fixed here.
 | IF [ k == NT_COND ]
 |  | (collect_node)[ node.as.cond.if_part | m ]
 |  | (collect_node)[ node.as.cond.elif_part | m ]
 |  | (collect_node)[ node.as.cond.else_part | m ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_IF ]
 |  | (collect_node)[ node.as.if_cond.expr | m ]
 |  | (collect_node)[ node.as.if_cond.block | m ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_ELIF ]
 |  | (collect_node)[ node.as.elif_cond.expr | m ]
 |  | (collect_node)[ node.as.elif_cond.block | m ]
 |  | (collect_node)[ node.as.elif_cond.next_elif | m ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_ELSE ]
 |  | (collect_node)[ node.as.else_cond.block | m ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_LOOP ]
 |  | (collect_node)[ node.as.loop.expr | m ]
 |  | (collect_node)[ node.as.loop.block | m ]
 |  | RET
 |  \_
 |
 | ; likewise absent from src/meta.c
 | IF [ k == NT_RET ]
 |  | (collect_node)[ node.as.ret.expr | m ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_STMT ]
 |  | (collect_node)[ node.as.stmt.stmt | m ]
 |  | (collect_node)[ node.as.stmt.next_stmt | m ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_EXPR ]
 |  | (collect_node)[ node.as.expr.expr | m ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_CAST ]
 |  | (collect_node)[ node.as.cast.expr | m ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_BIN_OP ]
 |  | (collect_node)[ node.as.bin_op.left | m ]
 |  | (collect_node)[ node.as.bin_op.right | m ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_UNY_OP ]
 |  | (collect_node)[ node.as.uny_op.operand | m ]
 |  | RET
 |  \_
 |
 | IF [ k == NT_FN_CALL ]
 |  | @ASTNode a = node.as.fn_call.args
 |  | WHILE [ a != 0 ]
 |  |  | (collect_node)[ a.as.argument.argument | m ]
 |  |  | a = a.as.argument.next_arg
 |  |  \_
 |  | RET
 |  \_
 |
 | RET
 \_

ABYSS meta_init: [ @Meta m ]
 | (m.symtab.scopes.init)[ 8 ]
 | m.symtab.curr = 0
 | (map_init)[ @(m.str_lits) | 64 ]
 | (map_init)[ @(m.func_decls) | 64 ]
 | (map_init)[ @(m.types) | 64 ]
 | (symtab_push_scope)[ @(m.symtab) ]
 | RET
 \_

ABYSS meta_pass: [ @Meta m | @AST ast ]
 | (collect_node)[ ast.root | m ]
 | RET
 \_

ABYSS meta_deinit: [ @Meta m ]
 | WHILE [ !(m.symtab.scopes.empty)[] ]
 |  | (symtab_pop_scope)[ @(m.symtab) ]
 |  \_
 | (m.symtab.scopes.deinit)[]
 | (map_deinit)[ @(m.str_lits) ]
 | (map_deinit)[ @(m.func_decls) ]
 | (map_deinit)[ @(m.types) ]
 | RET
 \_
