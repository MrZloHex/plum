#pragma once
#include "token.h"
#include <string>
#include <vector>
#include <unordered_map>

class Lexer {
public:
    Lexer(const std::string& source);
    Token getNextToken();
    std::vector<Token> tokenize();

private:
    std::string source;
    size_t position = 0;
    size_t currentLine = 1;
    size_t currentColumn = 1;
    
    std::unordered_map<std::string, TokenType> keywords;
    
    char peek() const;
    char advance();
    bool isAtEnd() const;
    
    Token makeToken(TokenType type, const std::string& lexeme);
    Token errorToken(const std::string& message);
    
    void skipWhitespace();
    bool match(char expected);
    
    Token identifier();
    Token number();
    
    bool skipLineComment();
    bool skipBlockComment();
    
    void initKeywords();
};