%option noyywrap nounput noinput yylineno

%{
#include "parser.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

static int yycolumn = 1;
#define TAB_WIDTH 8


static inline
char *xstrdup(const char *s)
{
    char *p = strdup(s);
    if (!p) { perror("strdup"); exit(EXIT_FAILURE); }
    return p;
}

#define YY_USER_ACTION                                   \
    yylloc.first_line   = yylineno;                      \
    yylloc.first_column = yycolumn;                      \
    yylloc.last_line    = yylineno;                      \
    yylloc.last_column  = yycolumn + yyleng - 1;         \
    yycolumn           += yyleng;

%}

%%
\n                          { yycolumn = 1; }
\t+                         { yycolumn += (TAB_WIDTH-1) * yyleng; }

"ABYSS"                     { yylval.str = xstrdup(yytext); return TYPE; }
F(32|64)                    { yylval.str = xstrdup(yytext); return TYPE; }
"B1"                        { yylval.str = xstrdup(yytext); return TYPE; }
C(1|2|4)                    { yylval.str = xstrdup(yytext); return TYPE; }
[IU](8|16|32|64|SIZE)       { yylval.str = xstrdup(yytext); return TYPE; }

"TRUE"                      { return B1_TRUE; }
"FALSE"                     { return B1_FALSE; }

"IF"                        { return IF; }
"ELIF"                      { return ELIF; }
"ELSE"                      { return ELSE; }
"LOOP"                      { return LOOP; }
"BREAK"                     { return BREAK; }
"RET"                       { return RET; }
"TYPE"                      { return TYPEDEF; }

"|"                         { yylval.vbars = 1; return VBAR; }

"..."                       { return ELLIPSIS; }
"\."                        { return DOT; }

[ \t]*\|([ \t]*\|)*[ \t]*\\_ { return BLOCK_END; }
"\\_"                       { return BLOCK_END; }
[ \t]*\|([ \t]*\|)*[ \t]*\\ { return BLOCK_CONTINUE; }
"\\"                        { return BLOCK_CONTINUE; }

"@"                         { return PTR; }
"("                         { return LPAREN; }
")"                         { return RPAREN; }
"["                         { return LBRACKET; }
"]"                         { return RBRACKET; }
":"                         { return COLON; }
"="                         { return EQUAL; }
"=="                        { return DOUBLE_EQUAL; }
"!="                        { return NOT_EQUAL; }
"<"                         { return LESS; }
">"                         { return GREAT; }
"<="                        { return LEQ; }
">="                        { return GEQ; }
"+"                         { return PLUS; }
"-"                         { return MINUS; }
"*"                         { return STAR; }
"/"                         { return SLASH; }
"%"                         { return MODULA; }

\'([^\\\']|\\.)\'           { yylval.str = xstrdup(yytext); return CHR_LITERAL; }
\"([^\"\\]|\\.)*\"          { yylval.str = xstrdup(yytext); return STR_LITERAL; }
[0-9]+                      { yylval.str = xstrdup(yytext); return NUM_LITERAL; }
[a-zA-Z_][a-zA-Z0-9_]*      { yylval.str = xstrdup(yytext); return IDENT; }

";"[^\n\r]*                 { /* skip comment lines */ }
[ ]+                        { /* skip whitespace */ }
.                           {
                                fprintf(stderr,
                                        "lexical error: unexpected '%c' at %d:%d\n",
                                        yytext[0], yylineno, yycolumn - yyleng);
                                YY_FATAL_ERROR("HUY");
                            }
%%
