#pragma once

#include <vector>
#include <memory>
#include <stdexcept>
#include <string>
#include "ast.h"

// Предполагается, что класс Token определен ранее
class Token;
enum class TokenType;

// Класс для парсинга токенов и построения AST
class Parser {
public:
    // Исключение для ошибок парсинга
    class ParseError : public std::runtime_error {
    public:
        ParseError(const std::string& message) : std::runtime_error(message) {}
    };

    // Конструктор принимает последовательность токенов
    Parser(const std::vector<Token>& tokens);

    // Основной метод парсинга, возвращает корень AST
    std::unique_ptr<Program> parseProgram();

private:
    // Поля для отслеживания токенов и текущей позиции
    const std::vector<Token>& tokens;
    size_t current;

    // Вспомогательные методы для навигации по токенам
    Token peek() const;
    Token previous() const;
    bool isAtEnd() const;
    Token advance();
    bool check(TokenType type) const;
    bool match(TokenType type);
    Token consume(TokenType type, const std::string& message);
    ParseError error(const Token& token, const std::string& message);
    void synchronize();

    // Методы для парсинга различных нетерминалов грамматики
    std::unique_ptr<MainClass> parseMainClass();
    std::unique_ptr<ClassDeclaration> parseClassDeclaration();
    std::unique_ptr<Declaration> parseDeclaration();
    std::unique_ptr<MethodDeclaration> parseMethodDeclaration();
    std::unique_ptr<VariableDeclaration> parseVariableDeclaration();
    std::vector<std::unique_ptr<VariableDeclaration>> parseFormals();
    std::unique_ptr<Type> parseType();
    std::unique_ptr<Type> parseSimpleType();
    std::unique_ptr<Statement> parseStatement();
    std::unique_ptr<Statement> parseAssertStatement();
    std::unique_ptr<Statement> parseBlockStatement();
    std::unique_ptr<Statement> parseIfStatement();
    std::unique_ptr<Statement> parseWhileStatement();
    std::unique_ptr<Statement> parsePrintStatement();
    std::unique_ptr<Statement> parseReturnStatement();

    // Методы для парсинга выражений
    std::unique_ptr<Expression> parseExpression();
    std::unique_ptr<Expression> parseLogicalOr();
    std::unique_ptr<Expression> parseLogicalAnd();
    std::unique_ptr<Expression> parseEquality();
    std::unique_ptr<Expression> parseRelational();
    std::unique_ptr<Expression> parseAdditive();
    std::unique_ptr<Expression> parseMultiplicative();
    std::unique_ptr<Expression> parseUnary();
    std::unique_ptr<Expression> parsePostfix();
    std::unique_ptr<Expression> parsePrimary();

    // Методы для парсинга LValue и связанных конструкций
    std::unique_ptr<LValue> parseLValue();
    std::unique_ptr<MethodInvocation> parseMethodInvocation();
    std::unique_ptr<FieldInvocation> parseFieldInvocation();
};