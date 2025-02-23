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
ASTNode* root = NULL;
%}

%union {
    char* str;
    ASTNode* ast;
}

/* Tokens from types, symbols, and new operators */
%token <str> TYPE IDENT NUMBER
%token COLON LBRACKET RBRACKET VBAR PTR BLOCK_END EQUAL
%token LPAREN RPAREN RET PLUS MINUS STAR SLASH

/* Operator precedence for math expressions */
%left PLUS MINUS
%left STAR SLASH

/* Nonterminals carrying AST nodes */
%type <ast> program function_decl param_list_opt param_list parameter
%type <ast> block_opt block block_line_list block_line opt_stmt stmt
%type <ast> var_decl ret_stmt expression type function_call arg_list_opt arg_list

%%
program:
      function_decl { 
          $$ = create_node(AST_LIST, "functions", $1, NULL); 
          root = $$;
      }
    | program function_decl {
          ASTNode* list = $1;
          ASTNode* newFunc = $2;
          /* Append the new function to the end of the list */
          ASTNode* p = list;
          while(p->right)
              p = p->right;
          p->right = create_node(AST_LIST, "functions", newFunc, NULL);
          $$ = list;
          root = $$;
      }
    ;




function_decl:
      type IDENT COLON LBRACKET param_list_opt RBRACKET block_opt
        {
            /* Build header: combine return type and a list node with the function name and parameter list */
            ASTNode *header = create_node(AST_LIST, NULL, $1, create_node(AST_LIST, $2, $5, NULL));
            $$ = create_node(AST_FUNCTION_DECL, NULL, header, $7);
        }
    ;

param_list_opt:
      /* empty */ { $$ = NULL; }
    | param_list { $$ = $1; }
    ;

param_list:
      parameter { $$ = $1; }
    | param_list VBAR parameter
        {
            ASTNode* p = $1;
            while(p->right)
                p = p->right;
            p->right = $3;
            $$ = $1;
        }
    ;

parameter:
      type IDENT
        {
            $$ = create_node(AST_PARAMETER, $2, $1, NULL);
        }
    ;

block_opt:
      /* empty */ { $$ = NULL; }
    | block { $$ = $1; }
    ;

block:
      block_line_list BLOCK_END { $$ = $1; }
    ;

block_line_list:
      block_line { $$ = $1; }
    | block_line_list block_line
        {
            ASTNode* p = $1;
            while(p->right)
                p = p->right;
            p->right = $2;
            $$ = $1;
        }
    ;

block_line:
      VBAR opt_stmt
        {
            if ($2 == NULL)
                $$ = create_node(AST_EMPTY, "", NULL, NULL);
            else
                $$ = $2;
        }
    ;

opt_stmt:
      /* empty */ { $$ = NULL; }
    | stmt { $$ = $1; }
    ;

stmt:
      var_decl { $$ = $1; }
    | ret_stmt { $$ = $1; }
    ;

var_decl:
      type IDENT
        {
            $$ = create_node(AST_VAR_DECL, $2, $1, NULL);
        }
    | type IDENT EQUAL expression
        {
            $$ = create_node(AST_VAR_DECL, $2, $1, $4);
        }
    ;

ret_stmt:
      RET LBRACKET expression RBRACKET
        {
            $$ = create_node(AST_RETURN, NULL, $3, NULL);
        }
    ;

/* Expression grammar with arithmetic, function calls, and primary expressions */
expression:
      expression PLUS expression
        { $$ = create_node(AST_EXPRESSION, "+", $1, $3); }
    | expression MINUS expression
        { $$ = create_node(AST_EXPRESSION, "-", $1, $3); }
    | expression STAR expression
        { $$ = create_node(AST_EXPRESSION, "*", $1, $3); }
    | expression SLASH expression
        { $$ = create_node(AST_EXPRESSION, "/", $1, $3); }
    | function_call
        { $$ = $1; }
    | LPAREN expression RPAREN
        { $$ = $2; }
    | NUMBER
        { $$ = create_node(AST_EXPRESSION, $1, NULL, NULL); }
    | IDENT
        { $$ = create_node(AST_EXPRESSION, $1, NULL, NULL); }
    ;

/* Function call: (<FN_PTR>)[ <arg_list_opt> ] */
function_call:
      LPAREN expression RPAREN LBRACKET arg_list_opt RBRACKET
        { $$ = create_node(AST_FUNC_CALL, NULL, $2, $5); }
    ;

arg_list_opt:
      /* empty */ { $$ = NULL; }
    | arg_list { $$ = $1; }
    ;

arg_list:
      expression { $$ = $1; }
    | arg_list VBAR expression
        {
            ASTNode* p = $1;
            while(p->right)
                p = p->right;
            p->right = $3;
            $$ = $1;
        }
    ;

type:
      TYPE { $$ = create_node(AST_TYPE, $1, NULL, NULL); }
    | PTR type
        {
            char* newType = malloc(strlen($2->value) + 2);
            sprintf(newType, "@%s", $2->value);
            $$ = create_node(AST_TYPE, newType, NULL, NULL);
            free(newType);
        }
    ;
%%

void yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
}

int main(void) {
    if (yyparse() == 0) {
        printf("Parsing completed successfully!\n");
        if (root) {
            printf("\n--- AST ---\n");
            print_ast(root, 0);
        }
    }
    // Optionally, free the AST: free_ast(root);
    return 0;
}
