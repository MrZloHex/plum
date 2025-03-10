#include "parser.h"

#include <iostream>

#include "token.h"

Parser::Parser(const std::vector<Token>& tokens) : tokens(tokens), current(0) {}

// Вспомогательные методы для навигации
Token Parser::peek() const {
  if (isAtEnd()) return Token(TokenType::EOF_TOKEN, "", 0, 0);
  return tokens[current];
}

Token Parser::previous() const { return tokens[current - 1]; }

bool Parser::isAtEnd() const {
  return current >= tokens.size() ||
         tokens[current].type == TokenType::EOF_TOKEN;
}

Token Parser::advance() {
  if (!isAtEnd()) current++;
  return previous();
}

bool Parser::check(TokenType type) const {
  if (isAtEnd()) return false;
  return peek().type == type;
}

bool Parser::match(TokenType type) {
  if (check(type)) {
    advance();
    return true;
  }
  return false;
}

Token Parser::consume(TokenType type, const std::string& message) {
  if (check(type)) return advance();
  throw error(peek(), message);
}

Parser::ParseError Parser::error(const Token& token,
                                 const std::string& message) {
  std::string errorMsg;
  if (token.type == TokenType::EOF_TOKEN) {
    errorMsg = "Ошибка в конце файла: " + message;
  } else {
    errorMsg = "Ошибка в строке " + std::to_string(token.line) + ", столбец " +
               std::to_string(token.column) + ": " + message + " (найдено '" +
               token.lexeme + "')";
  }
  return ParseError(errorMsg);
}

void Parser::synchronize() {
  advance();

  while (!isAtEnd()) {
    if (previous().type == TokenType::SEMICOLON) return;

    switch (peek().type) {
      case TokenType::CLASS:
      case TokenType::PUBLIC:
      case TokenType::IF:
      case TokenType::WHILE:
      case TokenType::RETURN:
        return;
      default:
        break;
    }

    advance();
  }
}

// Основной метод парсинга программы
std::unique_ptr<Program> Parser::parseProgram() {
  try {
    auto mainClass = parseMainClass();
    std::vector<std::unique_ptr<ClassDeclaration>> classes;

    while (!isAtEnd() && check(TokenType::CLASS)) {
      classes.push_back(parseClassDeclaration());
    }

    return std::make_unique<Program>(std::move(mainClass), std::move(classes));
  } catch (const ParseError& e) {
    std::cerr << e.what() << std::endl;
    synchronize();
    throw;
  }
}

// Парсинг главного класса
std::unique_ptr<MainClass> Parser::parseMainClass() {
  consume(TokenType::CLASS, "Ожидалось ключевое слово 'class'");
  Token className =
      consume(TokenType::IDENTIFIER, "Ожидался идентификатор имени класса");
  consume(TokenType::LBRACE, "Ожидалась '{'");
  consume(TokenType::PUBLIC, "Ожидалось ключевое слово 'public'");
  consume(TokenType::STATIC, "Ожидалось ключевое слово 'static'");
  consume(TokenType::VOID_TYPE, "Ожидалось ключевое слово 'void'");
  consume(TokenType::MAIN, "Ожидалось ключевое слово 'main'");
  consume(TokenType::LPAREN, "Ожидалась '('");
  consume(TokenType::RPAREN, "Ожидалась ')'");
  consume(TokenType::LBRACE, "Ожидалась '{'");

  std::vector<std::unique_ptr<Statement>> statements;
  while (!check(TokenType::RBRACE) && !isAtEnd()) {
    statements.push_back(parseStatement());
  }

  consume(TokenType::RBRACE, "Ожидалась '}' для закрытия блока main");
  consume(TokenType::RBRACE, "Ожидалась '}' для закрытия класса");

  return std::make_unique<MainClass>(className.lexeme, std::move(statements));
}

// Парсинг объявления класса
std::unique_ptr<ClassDeclaration> Parser::parseClassDeclaration() {
  consume(TokenType::CLASS, "Ожидалось ключевое слово 'class'");
  Token className =
      consume(TokenType::IDENTIFIER, "Ожидался идентификатор имени класса");

  std::string baseClassName = "";
  if (match(TokenType::EXTENDS)) {
    Token baseClass = consume(TokenType::IDENTIFIER,
                              "Ожидался идентификатор родительского класса");
    baseClassName = baseClass.lexeme;
  }

  consume(TokenType::LBRACE, "Ожидалась '{'");

  std::vector<std::unique_ptr<Declaration>> declarations;
  while (!check(TokenType::RBRACE) && !isAtEnd()) {
    declarations.push_back(parseDeclaration());
  }

  consume(TokenType::RBRACE, "Ожидалась '}'");

  return std::make_unique<ClassDeclaration>(className.lexeme, baseClassName,
                                            std::move(declarations));
}

// Парсинг объявления (переменной или метода)
std::unique_ptr<Declaration> Parser::parseDeclaration() {
  if (match(TokenType::PUBLIC)) {
    return parseMethodDeclaration();
  } else {
    // Объявление переменной
    auto varDecl = parseVariableDeclaration();
    return varDecl;
  }
}

// Парсинг объявления метода
std::unique_ptr<MethodDeclaration> Parser::parseMethodDeclaration() {
  auto returnType = parseType();
  Token methodName =
      consume(TokenType::IDENTIFIER, "Ожидался идентификатор метода");
  consume(TokenType::LPAREN, "Ожидалась '('");

  std::vector<std::unique_ptr<VariableDeclaration>> parameters;
  if (!check(TokenType::RPAREN)) {
    parameters = parseFormals();
  }

  consume(TokenType::RPAREN, "Ожидалась ')'");
  consume(TokenType::LBRACE, "Ожидалась '{'");

  std::vector<std::unique_ptr<Statement>> statements;
  while (!check(TokenType::RBRACE) && !isAtEnd()) {
    statements.push_back(parseStatement());
  }

  consume(TokenType::RBRACE, "Ожидалась '}'");

  return std::make_unique<MethodDeclaration>(
      std::move(returnType), methodName.lexeme, std::move(parameters),
      std::move(statements));
}

// Парсинг объявления переменной
std::unique_ptr<VariableDeclaration> Parser::parseVariableDeclaration() {
  auto type = parseType();
  Token varName =
      consume(TokenType::IDENTIFIER, "Ожидался идентификатор переменной");
  consume(TokenType::SEMICOLON, "Ожидалась ';'");

  return std::make_unique<VariableDeclaration>(std::move(type), varName.lexeme);
}

// Парсинг формальных параметров
std::vector<std::unique_ptr<VariableDeclaration>> Parser::parseFormals() {
  std::vector<std::unique_ptr<VariableDeclaration>> parameters;

  auto type = parseType();
  Token paramName =
      consume(TokenType::IDENTIFIER, "Ожидался идентификатор параметра");
  parameters.push_back(
      std::make_unique<VariableDeclaration>(std::move(type), paramName.lexeme));

  while (match(TokenType::COMMA)) {
    type = parseType();
    paramName =
        consume(TokenType::IDENTIFIER, "Ожидался идентификатор параметра");
    parameters.push_back(std::make_unique<VariableDeclaration>(
        std::move(type), paramName.lexeme));
  }

  return parameters;
}

// Парсинг типа
std::unique_ptr<Type> Parser::parseType() {
  auto baseType = parseSimpleType();

  if (match(TokenType::LBRACKET)) {
    consume(TokenType::RBRACKET, "Ожидалась ']'");
    return std::make_unique<ArrayType>(std::unique_ptr<SimpleType>(
        static_cast<SimpleType*>(baseType.release())));
  }

  return baseType;
}

// Парсинг простого типа
std::unique_ptr<Type> Parser::parseSimpleType() {
  if (match(TokenType::INT_TYPE)) {
    return std::make_unique<IntType>();
  } else if (match(TokenType::BOOLEAN_TYPE)) {
    return std::make_unique<BooleanType>();
  } else if (match(TokenType::VOID_TYPE)) {
    return std::make_unique<VoidType>();
  } else if (check(TokenType::IDENTIFIER)) {
    Token typeName =
        consume(TokenType::IDENTIFIER, "Ожидался идентификатор типа");
    return std::make_unique<IdentifierType>(typeName.lexeme);
  } else {
    throw error(peek(), "Ожидался тип");
  }
}

// Парсинг оператора
std::unique_ptr<Statement> Parser::parseStatement() {
  if (match(TokenType::ASSERT)) {
    return parseAssertStatement();
  } else if (check(TokenType::INT_TYPE) || check(TokenType::BOOLEAN_TYPE) ||
             check(TokenType::VOID_TYPE) || check(TokenType::IDENTIFIER)) {
    
    // Проверяем, не является ли это присваиванием переменной
    if (check(TokenType::IDENTIFIER)) {
      size_t savePoint = current;
      
      // Смотрим вперед: если идентификатор, за которым следует =, то это присваивание
      Token identToken = advance();  // Получаем токен идентификатора
      
      if (match(TokenType::ASSIGN)) {
        // Это оператор присваивания
        auto lvalue = std::make_unique<IdentifierLValue>(identToken.lexeme);
        auto value = parseExpression();
        consume(TokenType::SEMICOLON, "Ожидалась ';'");
        
        return std::make_unique<AssignStatement>(std::move(lvalue), std::move(value));
      } else {
        // Это не присваивание, возвращаемся назад
        current = savePoint;
        
        // Локальное объявление переменной
        return std::make_unique<LocalVarDeclStatement>(parseVariableDeclaration());
      }
    } else {
      // Локальное объявление переменной
      return std::make_unique<LocalVarDeclStatement>(parseVariableDeclaration());
    }
  } else if (match(TokenType::LBRACE)) {
    return parseBlockStatement();
  } else if (match(TokenType::IF)) {
    return parseIfStatement();
  } else if (match(TokenType::WHILE)) {
    return parseWhileStatement();
  } else if (match(TokenType::SYSTEM)) {
    return parsePrintStatement();
  } else if (match(TokenType::RETURN)) {
    return parseReturnStatement();
  } else {
    // Остальная логика parseStatement...
  }
}
// Парсинг оператора assert
std::unique_ptr<Statement> Parser::parseAssertStatement() {
  consume(TokenType::LPAREN, "Ожидалась '(' после 'assert'");
  auto condition = parseExpression();
  consume(TokenType::RPAREN, "Ожидалась ')'");
  consume(TokenType::SEMICOLON, "Ожидалась ';'");

  return std::make_unique<AssertStatement>(std::move(condition));
}

// Парсинг блока операторов
std::unique_ptr<Statement> Parser::parseBlockStatement() {
  std::vector<std::unique_ptr<Statement>> statements;

  while (!check(TokenType::RBRACE) && !isAtEnd()) {
    statements.push_back(parseStatement());
  }

  consume(TokenType::RBRACE, "Ожидалась '}'");

  return std::make_unique<BlockStatement>(std::move(statements));
}

// Парсинг оператора if
std::unique_ptr<Statement> Parser::parseIfStatement() {
  consume(TokenType::LPAREN, "Ожидалась '(' после 'if'");
  auto condition = parseExpression();
  consume(TokenType::RPAREN, "Ожидалась ')'");

  auto thenStatement = parseStatement();

  std::unique_ptr<Statement> elseStatement = nullptr;
  if (match(TokenType::ELSE)) {
    elseStatement = parseStatement();
  }

  return std::make_unique<IfStatement>(
      std::move(condition), std::move(thenStatement), std::move(elseStatement));
}

// Парсинг оператора while
std::unique_ptr<Statement> Parser::parseWhileStatement() {
  consume(TokenType::LPAREN, "Ожидалась '(' после 'while'");
  auto condition = parseExpression();
  consume(TokenType::RPAREN, "Ожидалась ')'");

  auto body = parseStatement();

  return std::make_unique<WhileStatement>(std::move(condition),
                                          std::move(body));
}

// Парсинг оператора вывода System.out.println
std::unique_ptr<Statement> Parser::parsePrintStatement() {
  consume(TokenType::DOT, "Ожидалась '.' после 'System'");
  consume(TokenType::OUT, "Ожидалось 'out' после 'System.'");
  consume(TokenType::DOT, "Ожидалась '.' после 'out'");
  consume(TokenType::PRINTLN, "Ожидалось 'println'");
  consume(TokenType::LPAREN, "Ожидалась '('");

  auto expression = parseExpression();

  consume(TokenType::RPAREN, "Ожидалась ')'");
  consume(TokenType::SEMICOLON, "Ожидалась ';'");

  return std::make_unique<PrintStatement>(std::move(expression));
}

// Парсинг оператора return
std::unique_ptr<Statement> Parser::parseReturnStatement() {
  auto expression = parseExpression();
  consume(TokenType::SEMICOLON, "Ожидалась ';' после return");

  return std::make_unique<ReturnStatement>(std::move(expression));
}

// Парсинг выражения
std::unique_ptr<Expression> Parser::parseExpression() {
  return parseLogicalOr();
}

// Парсинг логического "ИЛИ"
std::unique_ptr<Expression> Parser::parseLogicalOr() {
  auto expr = parseLogicalAnd();

  while (match(TokenType::OR)) {
    auto right = parseLogicalAnd();
    expr = std::make_unique<BinaryOperation>(
        std::move(expr), BinaryOperator::OR, std::move(right));
  }

  return expr;
}

// Парсинг логического "И"
std::unique_ptr<Expression> Parser::parseLogicalAnd() {
  auto expr = parseEquality();

  while (match(TokenType::AND)) {
    auto right = parseEquality();
    expr = std::make_unique<BinaryOperation>(
        std::move(expr), BinaryOperator::AND, std::move(right));
  }

  return expr;
}

// Парсинг операций равенства
std::unique_ptr<Expression> Parser::parseEquality() {
  auto expr = parseRelational();

  while (match(TokenType::EQUAL)) {
    auto right = parseRelational();
    expr = std::make_unique<BinaryOperation>(
        std::move(expr), BinaryOperator::EQUAL, std::move(right));
  }

  return expr;
}

// Парсинг операций отношения
std::unique_ptr<Expression> Parser::parseRelational() {
  auto expr = parseAdditive();

  while (true) {
    if (match(TokenType::LESS)) {
      auto right = parseAdditive();
      expr = std::make_unique<BinaryOperation>(
          std::move(expr), BinaryOperator::LESS, std::move(right));
    } else if (match(TokenType::GREATER)) {
      auto right = parseAdditive();
      expr = std::make_unique<BinaryOperation>(
          std::move(expr), BinaryOperator::GREATER, std::move(right));
    } else {
      break;
    }
  }

  return expr;
}

// Парсинг аддитивных операций
std::unique_ptr<Expression> Parser::parseAdditive() {
  auto expr = parseMultiplicative();

  while (true) {
    if (match(TokenType::PLUS)) {
      auto right = parseMultiplicative();
      expr = std::make_unique<BinaryOperation>(
          std::move(expr), BinaryOperator::PLUS, std::move(right));
    } else if (match(TokenType::MINUS)) {
      auto right = parseMultiplicative();
      expr = std::make_unique<BinaryOperation>(
          std::move(expr), BinaryOperator::MINUS, std::move(right));
    } else {
      break;
    }
  }

  return expr;
}

// Парсинг мультипликативных операций
std::unique_ptr<Expression> Parser::parseMultiplicative() {
  auto expr = parseUnary();

  while (true) {
    if (match(TokenType::MULTIPLY)) {
      auto right = parseUnary();
      expr = std::make_unique<BinaryOperation>(
          std::move(expr), BinaryOperator::MULTIPLY, std::move(right));
    } else if (match(TokenType::DIVIDE)) {
      auto right = parseUnary();
      expr = std::make_unique<BinaryOperation>(
          std::move(expr), BinaryOperator::DIVIDE, std::move(right));
    } else if (match(TokenType::MODULO)) {
      auto right = parseUnary();
      expr = std::make_unique<BinaryOperation>(
          std::move(expr), BinaryOperator::MODULO, std::move(right));
    } else {
      break;
    }
  }

  return expr;
}

// Парсинг унарных операций
std::unique_ptr<Expression> Parser::parseUnary() {
  if (match(TokenType::NOT)) {
    auto right = parseUnary();
    return std::make_unique<UnaryOperation>(UnaryOperator::NOT,
                                            std::move(right));
  }

  return parsePostfix();
}

// Парсинг постфиксных выражений (доступ к массивам, полям, вызовы методов)
std::unique_ptr<Expression> Parser::parsePostfix() {
  auto expr = parsePrimary();

  while (true) {
    if (match(TokenType::LBRACKET)) {
      // Индексация массива
      auto index = parseExpression();
      consume(TokenType::RBRACKET, "Ожидалась ']'");

      expr = std::make_unique<ArrayIndexing>(std::move(expr), std::move(index));
    } else if (match(TokenType::DOT)) {
      // Обращение к члену через точку
      if (match(TokenType::LENGTH)) {
        // Доступ к длине массива
        expr = std::make_unique<ArrayLength>(std::move(expr));
      } else {
        // Вызов метода или доступ к полю
        Token memberName =
            consume(TokenType::IDENTIFIER, "Ожидался идентификатор члена");

        if (match(TokenType::LPAREN)) {
          // Вызов метода
          std::vector<std::unique_ptr<Expression>> arguments;

          if (!check(TokenType::RPAREN)) {
            arguments.push_back(parseExpression());

            while (match(TokenType::COMMA)) {
              arguments.push_back(parseExpression());
            }
          }

          consume(TokenType::RPAREN, "Ожидалась ')'");

          expr = std::make_unique<MethodInvocation>(
              std::move(expr), memberName.lexeme, std::move(arguments));
        } else {
          // Доступ к полю
          expr =
              std::make_unique<FieldAccess>(std::move(expr), memberName.lexeme);
        }
      }
    } else {
      break;
    }
  }

  return expr;
}

// Парсинг первичных выражений
std::unique_ptr<Expression> Parser::parsePrimary() {
  if (match(TokenType::INTEGER_LITERAL)) {
    int value = std::stoi(previous().lexeme);
    return std::make_unique<IntegerLiteral>(value);
  }

  if (match(TokenType::TRUE)) {
    return std::make_unique<BooleanLiteral>(true);
  }

  if (match(TokenType::FALSE)) {
    return std::make_unique<BooleanLiteral>(false);
  }

  if (match(TokenType::THIS)) {
    return std::make_unique<ThisExpression>();
  }

  if (match(TokenType::IDENTIFIER)) {
    return std::make_unique<IdentifierExpression>(previous().lexeme);
  }

  if (match(TokenType::LPAREN)) {
    auto expr = parseExpression();
    consume(TokenType::RPAREN, "Ожидалась ')'");
    return expr;
  }

  if (match(TokenType::NEW)) {
    if (check(TokenType::INT_TYPE) || check(TokenType::BOOLEAN_TYPE) ||
        check(TokenType::IDENTIFIER)) {
      if (check(TokenType::IDENTIFIER)) {
        // Создание объекта класса
        Token className =
            consume(TokenType::IDENTIFIER, "Ожидался идентификатор класса");
        consume(TokenType::LPAREN, "Ожидалась '('");
        consume(TokenType::RPAREN, "Ожидалась ')'");
        return std::make_unique<NewObject>(className.lexeme);
      } else {
        // Создание массива
        auto type = parseSimpleType();
        
        // Проверяем, что тип действительно SimpleType
        SimpleType* simpleTypePtr = dynamic_cast<SimpleType*>(type.get());
        if (!simpleTypePtr) {
          throw error(peek(), "Ожидался простой тип для создания массива");
        }
        
        consume(TokenType::LBRACKET, "Ожидалась '['");
        auto size = parseExpression();
        consume(TokenType::RBRACKET, "Ожидалась ']'");
        
        // Безопасно преобразуем тип
        return std::make_unique<NewArray>(
            std::unique_ptr<SimpleType>(static_cast<SimpleType*>(type.release())),
            std::move(size)
        );
      }
    }
  }

  throw error(peek(), "Ожидалось выражение");
}

// Парсинг lvalue
std::unique_ptr<LValue> Parser::parseLValue() {
  if (match(TokenType::IDENTIFIER)) {
    std::string name = previous().lexeme;

    if (match(TokenType::LBRACKET)) {
      auto index = parseExpression();
      consume(TokenType::RBRACKET, "Ожидалась ']'");

      return std::make_unique<ArrayAccess>(name, std::move(index));
    }

    return std::make_unique<IdentifierLValue>(name);
  } else if (match(TokenType::THIS)) {
    return parseFieldInvocation();
  }

  throw error(peek(), "Ожидался идентификатор или 'this'");
}

// Парсинг обращения к полю
std::unique_ptr<FieldInvocation> Parser::parseFieldInvocation() {
  consume(TokenType::DOT, "Ожидалась '.' после 'this'");
  Token fieldName =
      consume(TokenType::IDENTIFIER, "Ожидался идентификатор поля");

  if (match(TokenType::LBRACKET)) {
    auto index = parseExpression();
    consume(TokenType::RBRACKET, "Ожидалась ']'");

    return std::make_unique<FieldArrayInvocation>(fieldName.lexeme,
                                                  std::move(index));
  }

  return std::make_unique<SimpleFieldInvocation>(fieldName.lexeme);
}