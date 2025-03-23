%code requires {
    #include "ast.h"
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "ast.h"

void yyerror(const char *s);
int yylex(void);

extern Node *root;

%}

%union {
    size_t indent;
    char* str;
    size_t vbars;
    Node *node;
}

%token <str> TYPE IDENT
%token <str> NUM_LITERAL CHR_LITERAL STR_LITERAL
%token <vbars> VBAR
%token BLOCK_END BLOCK_CONTINUE
%token COLON LBRACKET RBRACKET PTR EQUAL
%token LPAREN RPAREN RET PLUS MINUS STAR SLASH MODULA
%token DOUBLE_EQUAL NOT_EQUAL
%token LESS LEQ GREAT GEQ
%token IF ELIF ELSE LOOP BREAK
%token B1_FALSE B1_TRUE

%token INDENT

%left EQUAL
%left PLUS MINUS
%left STAR SLASH MODULA
%left DOUBLE_EQUAL NOT_EQUAL
%left LESS LEQ GREAT GEQ


%type <node> program prg_stmt
%type <node> fn_decl fn_def param_list_opt param_list parametre
%type <node> block_with_end block_with_continue block_line_list block_line stmt
%type <node> var_decl ret_stmt expression type function_call arg_list_opt arg_list
%type <node> cond_stmt cond_if cond_if_else cond_else
%type <node> loop_stmt
%type <vbars> indent_seq

%debug
%define parse.error verbose

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
    fn_decl block_with_end
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

block_with_continue:
    block_line_list BLOCK_CONTINUE
    { $$ = $1; }
;

block_with_end:
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
    indent_seq stmt
    { $$ = node_make_block($2); }
;

indent_seq:
    VBAR
    { $$ = 1; }
    | VBAR indent_seq
    { $$ = 1 + $2; }
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
    | cond_stmt
    { $$ = node_make_stmt(ST_COND, $1); }
    | loop_stmt
    { $$ = node_make_stmt(ST_LOOP, $1); }
    | BREAK
    { $$ = node_make_stmt(ST_BREAK, NULL); }
;

loop_stmt:
    LOOP block_with_end
    { $$ = node_make_loop($2); }
;

cond_stmt:
    cond_if
    { $$ = node_make_cond($1, NULL); }
    | cond_if_else cond_else
    { $$ = node_make_cond($1, $2); }
;

cond_if:
    IF LBRACKET IDENT RBRACKET block_with_end
    {
        Node *id = node_make_ident($3);
        $$ = node_make_if(id, $5);
    }
;

cond_if_else:
    IF LBRACKET IDENT RBRACKET block_with_continue
    {
        Node *id = node_make_ident($3);
        $$ = node_make_if(id, $5);
    }
;

cond_else:
    indent_seq ELSE block_with_end
    { $$ = node_make_else($3); }
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
    {
        Node *e = node_make_bin_op(BOT_MINUS, $1, $3);
        $$ = node_make_expr(ET_BIN_OP, e);
    }
    | expression STAR expression
    {
        Node *e = node_make_bin_op(BOT_MULT, $1, $3);
        $$ = node_make_expr(ET_BIN_OP, e);
    }
    | expression SLASH expression
    {
        Node *e = node_make_bin_op(BOT_DIV, $1, $3);
        $$ = node_make_expr(ET_BIN_OP, e);
    }
    | expression MODULA expression
    {
        Node *e = node_make_bin_op(BOT_MOD, $1, $3);
        $$ = node_make_expr(ET_BIN_OP, e);
    }
    | expression DOUBLE_EQUAL expression
    {
        Node *e = node_make_bin_op(BOT_EQUAL, $1, $3);
        $$ = node_make_expr(ET_BIN_OP, e);
    }
    | expression NOT_EQUAL expression
    {
        Node *e = node_make_bin_op(BOT_NEQ, $1, $3);
        $$ = node_make_expr(ET_BIN_OP, e);
    }
    | expression LESS expression
    {
        Node *e = node_make_bin_op(BOT_LESS, $1, $3);
        $$ = node_make_expr(ET_BIN_OP, e);
    }
    | expression LEQ expression
    {
        Node *e = node_make_bin_op(BOT_LEQ, $1, $3);
        $$ = node_make_expr(ET_BIN_OP, e);
    }
    | expression GREAT expression
    {
        Node *e = node_make_bin_op(BOT_GREAT, $1, $3);
        $$ = node_make_expr(ET_BIN_OP, e);
    }
    | expression GEQ expression
    {
        Node *e = node_make_bin_op(BOT_GEQ, $1, $3);
        $$ = node_make_expr(ET_BIN_OP, e);
    }
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
    | B1_TRUE
    {
        Node *e = node_make_bool_lit(BL_TRUE);
        $$ = node_make_expr(ET_BOOL_LIT, e);
    }
    | B1_FALSE
    {
        Node *e = node_make_bool_lit(BL_FALSE);
        $$ = node_make_expr(ET_BOOL_LIT, e);
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

void yyerror(const char *s) {
    extern char *yytext;
    extern int yylineno;

    fprintf(stderr, "Error: %s\n", s);
    fprintf(stderr, " at line %d: '%s'\n", yylineno, yytext);
}


