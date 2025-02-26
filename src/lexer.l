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
"IF"                        { yylval.str = strdup(yytext); return KWORD; }
"ELSE"                      { yylval.str = strdup(yytext); return KWORD; }
"LOOP"                      { yylval.str = strdup(yytext); return KWORD; }
"BREAK"                     { yylval.str = strdup(yytext); return KWORD; }


"@"                         { return PTR; }

"RET"                       { return RET; }
"("                         { return LPAREN; }
")"                         { return RPAREN; }
"["                         { return LBRACKET; }
"]"                         { return RBRACKET; }
"\\_"                       { return BLOCK_END; }
":"                         { return COLON; }
"="                         { return EQUAL; }
"|"                         { return VBAR; }
"+"                         { return PLUS; }
"-"                         { return MINUS; }
"*"                         { return STAR; }
"/"                         { return SLASH; }

\'([^\\\']|\\.)\'           { yylval.str = strdup(yytext); return CHR_LITERAL; }
\"([^\"\\]|\\.)*\"          { yylval.str = strdup(yytext); return STR_LITERAL; }
[0-9]+                      { yylval.str = strdup(yytext); return NUM_LITERAL; }
[a-zA-Z_][a-zA-Z0-9_]*      { yylval.str = strdup(yytext); return IDENT; }

";".*                       { /* skip comment lines */ }
[ \t\n]+                    { /* skip whitespace */ }
.                           { /* ignore any other character */ }
%%
