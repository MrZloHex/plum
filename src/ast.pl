; ast.pl -- the PLUM counterpart of inc/ast.h and src/ast.c
;
; One ASTNode per node: a kind tag, a source location, and a union of the
; per-kind payloads. Nodes are arena-allocated and never individually
; freed -- ast_deinit drops the whole arena, as in the C version.

!USES <../lib/arena.pl>
!USES <token.pl>
!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>

TYPE ASTNodeType: ENUM
 | NT_TRANSLATION_UNIT
 | NT_TU_STMT
 | NT_FN_DECL
 | NT_FN_DEF
 | NT_TYPE_DEF
 | NT_PARAMETRE
 | NT_ENUM
 | NT_ENUM_FIELDS
 | NT_RECORD
 | NT_FIELD
 | NT_TYPE
 | NT_BASE_TYPE
 | NT_IDENT
 | NT_BLOCK
 | NT_STMT
 | NT_RET
 | NT_COND
 | NT_LOOP
 | NT_VAR_DECL
 | NT_EXPR
 | NT_IF
 | NT_ELIF
 | NT_ELSE
 | NT_BIN_OP
 | NT_UNY_OP
 | NT_FN_CALL
 | NT_ARGUMENT
 | NT_LITERAL
 | NT_BUILTIN
 | NT_CAST
 | NT_LIST
 | NT_IFACE
 | NT_CLASS
 | NT_METHOD
 \_

TYPE TUStmtKind: ENUM
 | TUST_FN_DEF
 | TUST_FN_DECL
 | TUST_TYPE_DEF
 | TUST_VAR_DECL
 | TUST_IFACE
 | TUST_CLASS
 \_

TYPE TypeDefKind: ENUM
 | TD_ALIAS
 | TD_RECORD
 | TD_ENUM
 \_

TYPE RecordKind: ENUM
 | TDRT_STRUCTURE
 | TDRT_UNION
 \_

TYPE TypeKind: ENUM
 | TT_BASE_TYPE
 | TT_USER_TYPE
 | TT_FN_TYPE          ; FN R [ P | Q ]: type is R, args lists P and Q
 \_

TYPE BaseType: ENUM
 | BT_ABYSS
 | BT_B1
 | BT_C1
 | BT_U8
 | BT_U16
 | BT_U32
 | BT_U64
 | BT_I8
 | BT_I16
 | BT_I32
 | BT_I64
 | BT_USIZE
 | BT_ISIZE
 | BT_F32
 | BT_F64
 | BT_QUANTITY
 \_

TYPE StmtKind: ENUM
 | ST_RET
 | ST_BREAK
 | ST_CONTINUE
 | ST_COND
 | ST_LOOP
 | ST_VAR_DECL
 | ST_EXPR
 \_

TYPE ExprKind: ENUM
 | ET_IDENT
 | ET_BIN_OP
 | ET_UNY_OP
 | ET_FN_CALL
 | ET_LITERAL
 | ET_EXPR
 | ET_BUILTIN
 | ET_CAST
 \_

TYPE BinOpKind: ENUM
 | BOT_ASSIGN
 | BOT_PLUS
 | BOT_MINUS
 | BOT_MULT
 | BOT_DIV
 | BOT_MOD
 | BOT_EQUAL
 | BOT_NEQ
 | BOT_LESS
 | BOT_LEQ
 | BOT_GREAT
 | BOT_GEQ
 | BOT_AND
 | BOT_OR
 | BOT_BAND
 | BOT_BOR
 | BOT_BXOR
 | BOT_SHL
 | BOT_SHR
 | BOT_MEMBER
 | BOT_INDEX
 \_

TYPE UnyOpKind: ENUM
 | UOT_DEREF
 | UOT_REF
 | UOT_NEG
 | UOT_NOT
 | UOT_BNOT
 \_

TYPE LiteralKind: ENUM
 | LT_INTEGER
 | LT_FLOAT
 | LT_CHARACTER
 | LT_STRING
 | LT_BOOLEAN
 \_

TYPE BuiltInKind: ENUM
 | BI_SIZE
 \_

; --- payloads -------------------------------------------------------------

TYPE N_TransUnit: STRUCT
 | @ASTNode next_unit
 | @ASTNode tu_stmt
 \_

TYPE N_TUStmt: STRUCT
 | I32      kind
 | @ASTNode tu_stmt
 | @ASTNode next_tu_stmt
 \_

TYPE N_FnDecl: STRUCT
 | @ASTNode ident
 | @ASTNode type
 | @ASTNode params
 | @C1      owner       ; the class a method belongs to, 0 for a function
 | B1       is_private
 \_

TYPE N_Parametre: STRUCT
 | B1       vaarg
 | @ASTNode ident
 | @ASTNode type
 | @ASTNode next_param
 \_

TYPE N_FnDef: STRUCT
 | @ASTNode decl
 | @ASTNode block
 \_

TYPE N_TypeDef: STRUCT
 | I32      kind
 | @ASTNode ident
 | @ASTNode tdef
 | @ASTNode gparams     ; NT_LIST of NT_IDENT, 0 unless generic
 \_

TYPE N_Enum: STRUCT
 | @ASTNode fields
 \_

TYPE N_EnumField: STRUCT
 | @ASTNode ident
 | @ASTNode next_field
 \_

TYPE N_Record: STRUCT
 | I32      kind
 | @ASTNode fields
 \_

TYPE N_Field: STRUCT
 | @ASTNode type
 | @ASTNode ident
 | @ASTNode next_field
 \_

; arr sits beside kind so that `written` costs no space: ASTNode stays 64
TYPE N_Type: STRUCT
 | I32      kind
 | U32      arr         ; element count of `T name{N}`, 0 unless an array
 | U64      ptrs
 | @ASTNode type
 | @ASTNode args        ; NT_LIST of NT_TYPE, 0 unless generic
 | @ASTNode written     ; the args as written, kept once generics resolves them
 \_

TYPE N_Block: STRUCT
 | @ASTNode stmts
 \_

TYPE N_Stmt: STRUCT
 | I32      kind
 | @ASTNode stmt
 | @ASTNode next_stmt
 \_

TYPE N_Ret: STRUCT
 | @ASTNode expr
 \_

TYPE N_Cond: STRUCT
 | @ASTNode if_part
 | @ASTNode elif_part
 | @ASTNode else_part
 \_

TYPE N_If: STRUCT
 | @ASTNode expr
 | @ASTNode block
 \_

TYPE N_Elif: STRUCT
 | @ASTNode expr
 | @ASTNode block
 | @ASTNode next_elif
 \_

TYPE N_Else: STRUCT
 | @ASTNode block
 \_

TYPE N_Loop: STRUCT
 | @ASTNode expr
 | @ASTNode block
 \_

TYPE N_VarDecl: STRUCT
 | @ASTNode ident
 | @ASTNode type
 | @ASTNode init
 \_

TYPE N_Expr: STRUCT
 | I32      kind
 | @ASTNode expr
 \_

TYPE N_BinOp: STRUCT
 | I32      kind
 | @ASTNode left
 | @ASTNode right
 \_

TYPE N_UnyOp: STRUCT
 | I32      kind
 | @ASTNode operand
 \_

; With no ident, `target` is any expression yielding a function pointer.
TYPE N_FnCall: STRUCT
 | @ASTNode ident
 | @ASTNode args
 | @ASTNode recv        ; the object of a method call, 0 for a function
 | @ASTNode target      ; what is called, as an expression: recv.ident, or any
 \_

TYPE N_Argument: STRUCT
 | @ASTNode argument
 | @ASTNode next_arg
 \_

TYPE LiteralValue: UNION
 | I64 int_lit
 | F64 float_lit
 | C1  char_lit
 | @C1 str_lit
 | B1  bool_lit
 \_

TYPE N_Literal: STRUCT
 | I32          kind
 | LiteralValue as
 \_

TYPE N_BuiltIn: STRUCT
 | I32      kind
 | @ASTNode size
 \_

TYPE N_Cast: STRUCT
 | @ASTNode type
 | @ASTNode expr
 \_

; A plain singly linked list: generic parameters, type arguments, IMPL.
TYPE N_List: STRUCT
 | @ASTNode item
 | @ASTNode next
 \_

TYPE N_Iface: STRUCT
 | @ASTNode ident
 | @ASTNode gparams
 | @ASTNode recv        ; NT_PARAMETRE: the `me` every method receives
 | @ASTNode methods     ; NT_METHOD chain
 \_

TYPE N_Class: STRUCT
 | @ASTNode ident
 | @ASTNode gparams
 | @ASTNode base        ; NT_TYPE: the struct that holds the data
 | @ASTNode ifaces      ; NT_LIST of NT_TYPE
 \_

TYPE N_Method: STRUCT
 | B1       is_private
 | @ASTNode def         ; NT_FN_DEF
 | @ASTNode next
 \_

; The union of every payload. N_Ident is a bare @C1 and N_BaseType a bare
; tag, so they appear here directly rather than as wrapper structs.
TYPE NodeAs: UNION
 | N_TransUnit tu
 | N_TUStmt    tu_stmt
 | N_FnDecl    fn_decl
 | N_FnDef     fn_def
 | N_TypeDef   type_def
 | N_Enum      enumeration
 | N_EnumField enum_flds
 | N_Record    record
 | N_Field     rcrd_flds
 | N_Parametre parametre
 | N_Type      type
 | I32         base_type
 | @C1         ident
 | N_Block     block
 | N_Stmt      stmt
 | N_Ret       ret
 | N_Cond      cond
 | N_Loop      loop
 | N_VarDecl   var_decl
 | N_Expr      expr
 | N_If        if_cond
 | N_Elif      elif_cond
 | N_Else      else_cond
 | N_BinOp     bin_op
 | N_UnyOp     uny_op
 | N_FnCall    fn_call
 | N_Argument  argument
 | N_Literal   literal
 | N_BuiltIn   builtin
 | N_Cast      cast
 | N_List      list
 | N_Iface     iface
 | N_Class     klass
 | N_Method    method
 \_

TYPE ASTNode: STRUCT
 | I32      kind
 | Location loc
 | NodeAs   as
 \_

TYPE AST: STRUCT
 | Arena    arena
 | @ASTNode root
 \_

@ASTNode ast_node_new: [ @AST ast ]
 | @ASTNode n = (arena_alloc)[ @(ast.arena) | SIZE [ ASTNode ] ] AS @ASTNode
 | IF [ n == 0 ]
 |  | (puts)[ "ast: out of memory" ]
 |  | (exit)[ 1 ]
 |  \_
 | ; arena memory is not zeroed, and every consumer assumes NULL children
 | (memset)[ n AS @ABYSS | 0 | SIZE [ ASTNode ] ]
 | RET [ n ]
 \_

; --- signatures -----------------------------------------------------------
;
; What a call is checked and emitted against: an NT_FN_DECL for a named
; function, or an FN type for a pointer. Their parameters differ in shape
; (NT_PARAMETRE with a vaarg flag, or NT_LIST where a 0 item is `...`), so
; these read either.

@ASTNode sig_ret: [ @ASTNode s ]
 | IF [ s.kind == NT_FN_DECL ]
 |  | RET [ s.as.fn_decl.type ]
 |  \_
 | RET [ s.as.type.type ]
 \_

@ASTNode sig_params: [ @ASTNode s ]
 | IF [ s.kind == NT_FN_DECL ]
 |  | RET [ s.as.fn_decl.params ]
 |  \_
 | RET [ s.as.type.args ]
 \_

B1 sig_is_va: [ @ASTNode p ]
 | IF [ p.kind == NT_PARAMETRE ]
 |  | RET [ p.as.parametre.vaarg ]
 |  \_
 | RET [ p.as.list.item == 0 ]
 \_

@ASTNode sig_ptype: [ @ASTNode p ]
 | IF [ p.kind == NT_PARAMETRE ]
 |  | RET [ p.as.parametre.type ]
 |  \_
 | RET [ p.as.list.item ]
 \_

@ASTNode sig_next: [ @ASTNode p ]
 | IF [ p.kind == NT_PARAMETRE ]
 |  | RET [ p.as.parametre.next_param ]
 |  \_
 | RET [ p.as.list.next ]
 \_

; "Cls<X>" and "push" -> "Cls<X>.push", the function a method becomes.
@C1 method_name: [ @C1 cls | @C1 method ]
 | U64 n = (strlen)[ cls ] + (strlen)[ method ] + 2
 | @C1 buf = (malloc)[ n ] AS @C1
 | (snprintf)[ buf | n | "%s.%s" | cls | method ]
 | RET [ buf ]
 \_

ABYSS ast_init: [ @AST ast ]
 | (arena_init)[ @(ast.arena) | SIZE [ ASTNode ] * 1024 ]
 | ast.root = (ast_node_new)[ ast ]
 | ast.root.kind = NT_TRANSLATION_UNIT
 | RET
 \_

ABYSS ast_deinit: [ @AST ast ]
 | (arena_destroy)[ @(ast.arena) ]
 | ast.root = 0
 | RET
 \_
