#include <gtest/gtest.h>
#include "lexer.h"

TEST(LexerTest, SimpleClassTokenize) {
    std::string sourceCode = R"(
        class TestClass {
            public static void main() {
                int x = 42;
            }
        }
    )";

    Lexer lexer(sourceCode);
    std::vector<Token> tokens = lexer.tokenize();

    // Проверим, что мы не получили пустой список
    ASSERT_FALSE(tokens.empty()) << "Список токенов не должен быть пустым";

    // Найдём токен 'class'
    EXPECT_EQ(tokens[0].type, TokenType::CLASS);
    EXPECT_EQ(tokens[0].lexeme, "class");

    // Найдём имя класса TestClass
    EXPECT_EQ(tokens[1].type, TokenType::IDENTIFIER);
    EXPECT_EQ(tokens[1].lexeme, "TestClass");
}

TEST(LexerTest, NegativeNumberTokenize) {
    std::string sourceCode = "int x = -123;";

    Lexer lexer(sourceCode);
    std::vector<Token> tokens = lexer.tokenize();

    // Ищем токен INTEGER_LITERAL со значением -123
    bool foundNegative = false;
    for (auto &tok : tokens) {
        if (tok.type == TokenType::INTEGER_LITERAL && tok.lexeme == "-123") {
            foundNegative = true;
            break;
        }
    }
    EXPECT_TRUE(foundNegative) << "Ожидался токен с лексемой -123";
}