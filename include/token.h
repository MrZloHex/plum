#pragma once
#include <string>

enum class TokenType {
    // Ключевые слова
    CLASS, PUBLIC, STATIC, VOID, MAIN, EXTENDS, RETURN,
    IF, ELSE, WHILE, NEW, THIS, ASSERT,
    
    // Типы данных
    INT_TYPE, BOOLEAN_TYPE, VOID_TYPE,
    
    // Булевы литералы
    TRUE, FALSE,
    
    // Специальные "литералы"
    SYSTEM, OUT, PRINTLN, LENGTH,
    
    // Литералы
    INTEGER_LITERAL,
    
    // Идентификаторы
    IDENTIFIER,
    
    // Операторы
    AND,        // &&
    OR,         // ||
    LESS,       // <
    GREATER,    // >
    EQUAL,      // ==
    PLUS,       // +
    MINUS,      // -
    MULTIPLY,   // *
    DIVIDE,     // /
    MODULO,     // %
    NOT,        // !
    ASSIGN,     // =
    NOT_EQUAL,  // !=
    LESS_EQUAL, // <=
    GREATER_EQUAL, // >=
    
    // Разделители
    LPAREN,     // (
    RPAREN,     // )
    LBRACE,     // {
    RBRACE,     // }
    LBRACKET,   // [
    RBRACKET,   // ]
    SEMICOLON,  // ;
    COMMA,      // ,
    DOT,        // .
    
    // Конец файла
    EOF_TOKEN,
    
    // Ошибка
    ERROR
};

struct Token {
    TokenType type;
    std::string lexeme;
    int line;
    int column;
    
    Token(TokenType t, const std::string& l, int lin, int col)
        : type(t), lexeme(l), line(lin), column(col) {}
};