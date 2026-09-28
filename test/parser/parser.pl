; Exercises plum/parser.pl on real PLUM source.

!USES <../../src/parser.pl>

@C1 nodename: [ I32 k ]
 | IF [ k == NT_TU_STMT ]
 |  | RET [ "TUStmt" ]
 |  \_
 | IF [ k == NT_FN_DECL ]
 |  | RET [ "FnDecl" ]
 |  \_
 | IF [ k == NT_FN_DEF ]
 |  | RET [ "FnDef" ]
 |  \_
 | IF [ k == NT_TYPE_DEF ]
 |  | RET [ "TypeDef" ]
 |  \_
 | IF [ k == NT_VAR_DECL ]
 |  | RET [ "VarDecl" ]
 |  \_
 | RET [ "?" ]
 \_

I32 count_stmts: [ @ASTNode block ]
 | I32 n = 0
 | @ASTNode s = block.as.block.stmts
 | WHILE [ s != 0 ]
 |  | n += 1
 |  | s = s.as.stmt.next_stmt
 |  \_
 | RET [ n ]
 \_

I32 count_params: [ @ASTNode decl ]
 | I32 n = 0
 | @ASTNode p = decl.as.fn_decl.params
 | WHILE [ p != 0 ]
 |  | n += 1
 |  | p = p.as.parametre.next_param
 |  \_
 | RET [ n ]
 \_

I32 main: []
 | String src
 | @ABYSS f = (fopen)[ "sample.txt" | "r" ]
 | IF [ f == 0 ]
 |  | (puts)[ "cannot open sample.txt" ]
 |  | RET [ 1 ]
 |  \_
 | (src.init_file)[ f ]
 | (fclose)[ f ]
 |
 | AST ast
 | (ast_init)[ @ast ]
 | (parse_unit)[ @ast | @src ]
 |
 | @ASTNode ts = ast.root.as.tu.tu_stmt
 | I32 n = 0
 | WHILE [ ts != 0 ]
 |  | @ASTNode node = ts.as.tu_stmt.tu_stmt
 |  | I32 kind = ts.as.tu_stmt.kind
 |  |
 |  | IF [ kind == TUST_TYPE_DEF ]
 |  |  | (printf)[ "%-8s %s\n" | "TYPEDEF" | node.as.type_def.ident.as.ident ]
 |  | ELIF [ kind == TUST_FN_DECL ]
 |  |  | (printf)[ "%-8s %s params=%d\n" | "FNDECL" | node.as.fn_decl.ident.as.ident | (count_params)[ node ] ]
 |  | ELIF [ kind == TUST_FN_DEF ]
 |  |  | @ASTNode d = node.as.fn_def.decl
 |  |  | (printf)[ "%-8s %s params=%d stmts=%d\n" | "FNDEF" | d.as.fn_decl.ident.as.ident | (count_params)[ d ] | (count_stmts)[ node.as.fn_def.block ] ]
 |  | ELSE
 |  |  | (printf)[ "%-8s %s\n" | "OTHER" | (nodename)[ node.kind ] ]
 |  |  \_
 |  |
 |  | n += 1
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 |
 | (printf)[ "-- %d top-level statements --\n" | n ]
 | (ast_deinit)[ @ast ]
 | RET [ 0 ]
 \_
