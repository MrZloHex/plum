#include <gtest/gtest.h>
#include "parser.h"
#include "lexer.h"

TEST(ParserTest, ParseSimpleProgram) {
    std::string sourceCode = R"(
        class Hello {
          public static void main() {
            System.out.println(123);
          }
        }
    )";

    Lexer lexer(sourceCode);
    std::vector<Token> tokens = lexer.tokenize();
    Parser parser(tokens);

    EXPECT_NO_THROW({
        auto program = parser.parseProgram();
        EXPECT_NE(program, nullptr);
    });
}

TEST(ParserTest, ParseFactorialProgram) {
    std::string sourceCode = R"(
        class Factorial {
          public static void main () {
            System.out.println (new Fac().ComputeFac(10));
          }
        }

        class Fac {
          public int ComputeFac(int num) {
            assert(num > -1);
            int num_aux;
            if (num == 0)
              num_aux = 1;
            else
              num_aux = num * this.ComputeFac(num - 1);
            return num_aux;
          }
        }
    )";

    Lexer lexer(sourceCode);
    std::vector<Token> tokens = lexer.tokenize();
    Parser parser(tokens);

    EXPECT_NO_THROW({
        auto program = parser.parseProgram();
        EXPECT_NE(program, nullptr);
    });
}