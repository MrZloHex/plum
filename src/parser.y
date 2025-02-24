%code requires {
    #include "ast.h"
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"

void yyerror(const char *s);
int yylex(void);

/* Global AST root (for simplicity, we store the last parsed function) */
Node *root = NULL;
%}

%union {
    char* str;
    Node *node;
}

/* Tokens from types, symbols, and new operators */
%token <str> TYPE IDENT NUMBER
%token COLON LBRACKET RBRACKET VBAR PTR BLOCK_END EQUAL
%token LPAREN RPAREN RET PLUS MINUS STAR SLASH

/* Operator precedence for math expressions */
%left PLUS MINUS
%left STAR SLASH

/* Nonterminals carrying AST nodes */
%type <node> program fn_decl fn_def param_list_opt param_list parametre
%type <node> block block_line_list block_line stmt
%type <node> var_decl ret_stmt expression type function_call arg_list_opt arg_list

%%
program:
    fn_def
    { 
        $$ = $1;
        root = $$;
    }
;

fn_def:
    fn_decl
    {
        // TODO
        exit(42);
    }
    | fn_decl block
    { $$ = node_make_fndef($1, $2); }
;

fn_decl:
    type IDENT COLON LBRACKET param_list_opt RBRACKET
    {
        Node *id = node_make_ident($2);
        $$ = node_make_fndecl($1, id, $5);
    }
;

param_list_opt:
    /* empty */
    { $$ = NULL; }
    | param_list
    { $$ = $1; }
;

param_list:
    parametre
    { $$ = $1; }
    | param_list VBAR parametre
    {
        Node *list = $1;
        while(list->as.parametre.next)
        { list = list->as.parametre.next; }
        list->as.parametre.next = $3;
        $$ = $1;
    }
;

parametre:
    type IDENT
    {
        Node *id = node_make_ident($2);
        $$ = node_make_parametre($1, id);
    }
;

block:
    block_line_list BLOCK_END
    { $$ = $1; }
;

block_line_list:
    block_line
    { $$ = $1; }
    | block_line_list block_line
    {
        Node *list = $1;
        while(list->as.block.next)
        { list = list->as.block.next; }
        list->as.block.next = $2;
        $$ = $1;
    }
;

block_line:
    VBAR stmt
    { $$ = node_make_block($2); }
;

stmt:
    /* empty */
    { $$ = NULL; }
    | expression
    { $$ = node_make_stmt(ST_EXPR, $1); }
    | var_decl
    { $$ = node_make_stmt(ST_VAR_DECL, $1); }
    | ret_stmt
    { $$ = node_make_stmt(ST_RET, $1); }
;

var_decl:
    type IDENT
    {
        Node *id = node_make_ident($2);
        $$ = node_make_var_decl($1, id);
    }
;

ret_stmt:
    RET LBRACKET expression RBRACKET
    {
        $$ = node_make_ret($3);
    }
;

/* Expression grammar with arithmetic, function calls, and primary expressions */
expression:
    LPAREN expression RPAREN
    { $$ = $2; }
    | expression EQUAL expression
    {
        Node *e = node_make_bin_op(BOT_ASSIGN, $1, $3);
        $$ = node_make_expr(ET_BIN_OP, e);
    }
    | expression PLUS expression
    {
        Node *e = node_make_bin_op(BOT_PLUS, $1, $3);
        $$ = node_make_expr(ET_BIN_OP, e);
    }
    | expression MINUS expression
    {  }
    | expression STAR expression
    {  }
    | expression SLASH expression
    {  }
    | function_call
    { }
    | NUMBER
    {  }
    | IDENT
    {
        Node *e = node_make_ident($1);
        $$ = node_make_expr(ET_IDENT, e);
    }
;

/* Function call: (<FN_PTR>)[ <arg_list_opt> ] */
function_call:
    LPAREN expression RPAREN LBRACKET arg_list_opt RBRACKET
    { }
;

arg_list_opt:
    /* empty */
    { $$ = NULL; }
    | arg_list
    { $$ = $1; }
;

arg_list:
    expression
    { $$ = $1; }
    | arg_list VBAR expression
    {}
;

type:
    TYPE
    {
        $$ = node_make_type($1);
    }
    | PTR type
    {
        // char* newType = malloc(strlen($2->value) + 2);
        // sprintf(newType, "@%s", $2->value);
        // $$ = create_node(AST_PTR, NULL, $2, NULL);
        // free(newType);
    }
;
%%

void yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
}

int main() {
    // Parse input and generate AST
    yyparse();
    node_dump_fndef(root, 0);
    // Generate LLVM IR from the AST
    //generateLLVMIR(root);

    return 0;
}












