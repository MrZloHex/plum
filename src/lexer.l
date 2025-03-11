%{
#include "parser.h"
#include <string.h>
#include <stdlib.h>
%}

%option noyywrap

%%
"ABYSS"                     { yylval.str = strdup(yytext); return TYPE; }
F(32|64)                    { yylval.str = strdup(yytext); return TYPE; }
"B1"                        { yylval.str = strdup(yytext); return TYPE; }
C(1|2|4)                    { yylval.str = strdup(yytext); return TYPE; }
[IU](8|16|32|64|SIZE)       { yylval.str = strdup(yytext); return TYPE; }

"TRUE"                      { return B1_TRUE; }
"FALSE"                     { return B1_FALSE; }

"IF"                        { return IF; }
"ELIF"                      { return ELIF; }
"ELSE"                      { return ELSE; }
"LOOP"                      { return LOOP; }
"BREAK"                     { return BREAK; }
"RET"                       { return RET; }

"|"                         { yylval.vbars = 1; return VBAR; }

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

\'([^\\\']|\\.)\'           { yylval.str = strdup(yytext); return CHR_LITERAL; }
\"([^\"\\]|\\.)*\"          { yylval.str = strdup(yytext); return STR_LITERAL; }
[0-9]+                      { yylval.str = strdup(yytext); return NUM_LITERAL; }
[a-zA-Z_][a-zA-Z0-9_]*      { yylval.str = strdup(yytext); return IDENT; }

";".*                       { /* skip comment lines */ }
[ \t\n]+                      { /* skip whitespace */ }
.                           { /* ignore any other character */ }
%%
