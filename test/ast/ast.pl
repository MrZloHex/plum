; Exercises plum/ast.pl -- arena allocation, the tagged union, and the
; self-referential child pointers the whole compiler is built on.

!USES <../../src/ast.pl>

I32 main: []
 | AST ast
 | (ast_init)[ @ast ]
 | (printf)[ "root kind=%d (expect %d)\n" | ast.root.kind | NT_TRANSLATION_UNIT ]
 | (printf)[ "sizeof ASTNode=%d\n" | SIZE [ ASTNode ] ]
 |
 | ; build:  I32 answer = 6 * 7
 | @ASTNode lhs = (ast_node_new)[ @ast ]
 | lhs.kind = NT_LITERAL
 | lhs.as.literal.kind = LT_INTEGER
 | lhs.as.literal.as.int_lit = 6
 |
 | @ASTNode rhs = (ast_node_new)[ @ast ]
 | rhs.kind = NT_LITERAL
 | rhs.as.literal.kind = LT_INTEGER
 | rhs.as.literal.as.int_lit = 7
 |
 | @ASTNode bin = (ast_node_new)[ @ast ]
 | bin.kind = NT_BIN_OP
 | bin.as.bin_op.kind  = BOT_MULT
 | bin.as.bin_op.left  = lhs
 | bin.as.bin_op.right = rhs
 | bin.loc.line = 3
 | bin.loc.col  = 14
 |
 | (printf)[ "binop kind=%d at %d:%d left=%d right=%d\n" | bin.as.bin_op.kind | bin.loc.line | bin.loc.col | bin.as.bin_op.left.as.literal.as.int_lit | bin.as.bin_op.right.as.literal.as.int_lit ]
 |
 | ; the union really overlaps: write through one member, read the other
 | @ASTNode s = (ast_node_new)[ @ast ]
 | s.kind = NT_IDENT
 | s.as.ident = "hello"
 | (printf)[ "ident=%s\n" | s.as.ident ]
 |
 | ; a statement list, threaded through next_stmt
 | @ASTNode head = 0
 | I32 i = 0
 | WHILE [ i < 5 ]
 |  | @ASTNode st = (ast_node_new)[ @ast ]
 |  | st.kind = NT_STMT
 |  | st.as.stmt.kind = ST_EXPR
 |  | st.loc.line = i
 |  | st.as.stmt.next_stmt = head
 |  | head = st
 |  | i += 1
 |  \_
 |
 | I32 count = 0
 | @ASTNode cur = head
 | WHILE [ cur != 0 ]
 |  | count += 1
 |  | cur = cur.as.stmt.next_stmt
 |  \_
 | (printf)[ "list length=%d first line=%d\n" | count | head.loc.line ]
 |
 | ; many nodes, to push the arena across blocks
 | I32 k = 0
 | WHILE [ k < 5000 ]
 |  | @ASTNode n = (ast_node_new)[ @ast ]
 |  | n.kind = NT_EXPR
 |  | k += 1
 |  \_
 | (puts)[ "5000 nodes allocated" ]
 |
 | (ast_deinit)[ @ast ]
 | RET [ 0 ]
 \_
