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

extern Node *root;

%}

%union {
    char* str;
    Node *node;
}

%token <str> TYPE IDENT KWORD
%token <str> NUM_LITERAL CHR_LITERAL STR_LITERAL
%token COLON LBRACKET RBRACKET VBAR PTR BLOCK_END EQUAL
%token LPAREN RPAREN RET PLUS MINUS STAR SLASH

%left EQUAL
%left PLUS MINUS
%left STAR SLASH


%type <node> program prg_stmt
%type <node> fn_decl fn_def param_list_opt param_list parametre
%type <node> block block_line_list block_line stmt
%type <node> var_decl ret_stmt expression type function_call arg_list_opt arg_list

%%
program:
    prg_stmt 
    { 
        $$ = node_make_programme($1);
        root = $$;
    }
    | program prg_stmt 
    {
        Node *pr = $1;
        while(pr->as.programme.next)
        { pr = pr->as.programme.next; }
        pr->as.programme.next = node_make_programme($2);
        $$ = $1;
    }
;

prg_stmt:
    fn_def
    { $$ = node_make_prg_stmt(PST_FN_DEF, $1); }
    | fn_decl
    { $$ = node_make_prg_stmt(PST_FN_DECL, $1); }

fn_def:
    fn_decl block
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
    %empty
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
    %empty
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
    | RET LBRACKET RBRACKET
    { $$ = node_make_ret(NULL); }
;

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
    { $$ = node_make_expr(ET_FN_CALL, $1); }
    | STR_LITERAL
    {
        Node *e = node_make_str_lit($1);
        $$ = node_make_expr(ET_STR_LIT, e);
    }
    | CHR_LITERAL
    {
        Node *e = node_make_chr_lit($1);
        $$ = node_make_expr(ET_CHR_LIT, e);
    }
    | NUM_LITERAL
    {
        Node *e = node_make_num_lit($1);
        $$ = node_make_expr(ET_NUM_LIT, e);
    }
    | IDENT
    {
        Node *e = node_make_ident($1);
        $$ = node_make_expr(ET_IDENT, e);
    }
;

function_call:
    LPAREN IDENT RPAREN LBRACKET arg_list_opt RBRACKET
    {
        Node *ident = node_make_ident($2);
        $$ = node_make_fncall(ident, $5);
    }
;

arg_list_opt:
    %empty
    { $$ = NULL; }
    | arg_list
    { $$ = $1; }
;

arg_list:
    expression
    { $$ = node_make_argument($1); }
    | arg_list VBAR expression
    {
        Node *list = $1;
        while(list->as.arguments.next)
        { list = list->as.arguments.next; }
        list->as.arguments.next = node_make_argument($3);
        $$ = $1;
    }
;


type:
    TYPE
    { $$ = node_make_type($1); }
    | PTR type
    { $$ = node_make_type_ptr($2); }
;
%%

void
yyerror(const char *s)
{
    fprintf(stderr, "Error: %s\n", s);
}


