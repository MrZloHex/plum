#pragma once

#include <string>
#include <vector>
#include <memory>

// Базовые классы для нетерминалов грамматики

// Базовый класс для всех узлов AST
class ASTNode {
public:
    virtual ~ASTNode() = default;
    virtual void accept(class Visitor& visitor) = 0;
};

// Базовый класс для выражений
class Expression : public ASTNode {
public:
    virtual ~Expression() = default;
};

// Базовый класс для операторов
class Statement : public ASTNode {
public:
    virtual ~Statement() = default;
};

// Базовый класс для типов
class Type : public ASTNode {
public:
    virtual ~Type() = default;
    virtual bool isArray() const = 0;
};

// Базовый класс для объявлений (методов и переменных)
class Declaration : public ASTNode {
public:
    virtual ~Declaration() = default;
    std::string name;

    Declaration(const std::string& name) : name(name) {}
};

// Базовый класс для lvalue (левая часть присваивания)
class LValue : public Expression {
public:
    virtual ~LValue() = default;
};

// Базовый класс для простых типов
class SimpleType : public Type {
public:
    virtual ~SimpleType() = default;
    bool isArray() const override { return false; }
};

// Классы для программы и основных структур

// Программа состоит из главного класса и других классов
class Program : public ASTNode {
public:
    std::unique_ptr<class MainClass> mainClass;
    std::vector<std::unique_ptr<class ClassDeclaration>> classes;

    Program(std::unique_ptr<MainClass> mainClass, 
            std::vector<std::unique_ptr<ClassDeclaration>> classes)
        : mainClass(std::move(mainClass)), classes(std::move(classes)) {}

    void accept(Visitor& visitor) override;
};

// Главный класс программы
class MainClass : public ASTNode {
public:
    std::string className;
    std::vector<std::unique_ptr<Statement>> statements;

    MainClass(const std::string& className, std::vector<std::unique_ptr<Statement>> statements)
        : className(className), statements(std::move(statements)) {}

    void accept(Visitor& visitor) override;
};

// Объявление класса
class ClassDeclaration : public ASTNode {
public:
    std::string className;
    std::string baseClassName; // Может быть пустой, если нет наследования
    std::vector<std::unique_ptr<Declaration>> declarations;

    ClassDeclaration(const std::string& className, const std::string& baseClassName,
                    std::vector<std::unique_ptr<Declaration>> declarations)
        : className(className), baseClassName(baseClassName), declarations(std::move(declarations)) {}

    void accept(Visitor& visitor) override;
};

// Классы для типов

// Тип "int"
class IntType : public SimpleType {
public:
    void accept(Visitor& visitor) override;
};

// Тип "boolean"
class BooleanType : public SimpleType {
public:
    void accept(Visitor& visitor) override;
};

// Тип "void"
class VoidType : public SimpleType {
public:
    void accept(Visitor& visitor) override;
};

// Тип по идентификатору (пользовательский класс)
class IdentifierType : public SimpleType {
public:
    std::string typeName;

    IdentifierType(const std::string& typeName) : typeName(typeName) {}

    void accept(Visitor& visitor) override;
};

// Тип массива
class ArrayType : public Type {
public:
    std::unique_ptr<SimpleType> elementType;

    ArrayType(std::unique_ptr<SimpleType> elementType) : elementType(std::move(elementType)) {}

    bool isArray() const override { return true; }
    void accept(Visitor& visitor) override;
};

// Классы для объявлений

// Объявление переменной
class VariableDeclaration : public Declaration {
public:
    std::unique_ptr<Type> type;

    VariableDeclaration(std::unique_ptr<Type> type, const std::string& name)
        : Declaration(name), type(std::move(type)) {}

    void accept(Visitor& visitor) override;
};

// Объявление метода
class MethodDeclaration : public Declaration {
public:
    std::unique_ptr<Type> returnType;
    std::vector<std::unique_ptr<VariableDeclaration>> parameters;
    std::vector<std::unique_ptr<Statement>> statements;

    MethodDeclaration(std::unique_ptr<Type> returnType, const std::string& name,
                     std::vector<std::unique_ptr<VariableDeclaration>> parameters,
                     std::vector<std::unique_ptr<Statement>> statements)
        : Declaration(name), returnType(std::move(returnType)), 
          parameters(std::move(parameters)), statements(std::move(statements)) {}

    void accept(Visitor& visitor) override;
};

// Классы для операторов

// Оператор assert
class AssertStatement : public Statement {
public:
    std::unique_ptr<Expression> condition;

    AssertStatement(std::unique_ptr<Expression> condition)
        : condition(std::move(condition)) {}

    void accept(Visitor& visitor) override;
};

// Локальное объявление переменной
class LocalVarDeclStatement : public Statement {
public:
    std::unique_ptr<VariableDeclaration> declaration;

    LocalVarDeclStatement(std::unique_ptr<VariableDeclaration> declaration)
        : declaration(std::move(declaration)) {}

    void accept(Visitor& visitor) override;
};

// Блок операторов
class BlockStatement : public Statement {
public:
    std::vector<std::unique_ptr<Statement>> statements;

    BlockStatement(std::vector<std::unique_ptr<Statement>> statements)
        : statements(std::move(statements)) {}

    void accept(Visitor& visitor) override;
};

// Условный оператор if
class IfStatement : public Statement {
public:
    std::unique_ptr<Expression> condition;
    std::unique_ptr<Statement> thenStatement;
    std::unique_ptr<Statement> elseStatement; // Может быть nullptr

    IfStatement(std::unique_ptr<Expression> condition,
               std::unique_ptr<Statement> thenStatement,
               std::unique_ptr<Statement> elseStatement = nullptr)
        : condition(std::move(condition)), 
          thenStatement(std::move(thenStatement)), 
          elseStatement(std::move(elseStatement)) {}

    void accept(Visitor& visitor) override;
};

// Цикл while
class WhileStatement : public Statement {
public:
    std::unique_ptr<Expression> condition;
    std::unique_ptr<Statement> body;

    WhileStatement(std::unique_ptr<Expression> condition, std::unique_ptr<Statement> body)
        : condition(std::move(condition)), body(std::move(body)) {}

    void accept(Visitor& visitor) override;
};

// Оператор вывода
class PrintStatement : public Statement {
public:
    std::unique_ptr<Expression> expression;

    PrintStatement(std::unique_ptr<Expression> expression)
        : expression(std::move(expression)) {}

    void accept(Visitor& visitor) override;
};

// Оператор присваивания
class AssignStatement : public Statement {
public:
    std::unique_ptr<LValue> lvalue;
    std::unique_ptr<Expression> expression;

    AssignStatement(std::unique_ptr<LValue> lvalue, std::unique_ptr<Expression> expression)
        : lvalue(std::move(lvalue)), expression(std::move(expression)) {}

    void accept(Visitor& visitor) override;
};

// Оператор return
class ReturnStatement : public Statement {
public:
    std::unique_ptr<Expression> expression;

    ReturnStatement(std::unique_ptr<Expression> expression)
        : expression(std::move(expression)) {}

    void accept(Visitor& visitor) override;
};

// Вызов метода как оператор (не выражение)
class MethodInvocationStatement : public Statement {
public:
    std::unique_ptr<class MethodInvocation> invocation;

    MethodInvocationStatement(std::unique_ptr<class MethodInvocation> invocation)
        : invocation(std::move(invocation)) {}

    void accept(Visitor& visitor) override;
};

// Классы для выражений

// Бинарные операторы
enum class BinaryOperator {
    AND, OR, LESS, GREATER, EQUAL, PLUS, MINUS, MULTIPLY, DIVIDE, MODULO
};

// Бинарная операция
class BinaryOperation : public Expression {
public:
    std::unique_ptr<Expression> left;
    BinaryOperator op;
    std::unique_ptr<Expression> right;

    BinaryOperation(std::unique_ptr<Expression> left, BinaryOperator op, std::unique_ptr<Expression> right)
        : left(std::move(left)), op(op), right(std::move(right)) {}

    void accept(Visitor& visitor) override;
};

// Унарные операторы
enum class UnaryOperator {
    NOT
};

// Унарная операция
class UnaryOperation : public Expression {
public:
    UnaryOperator op;
    std::unique_ptr<Expression> expression;

    UnaryOperation(UnaryOperator op, std::unique_ptr<Expression> expression)
        : op(op), expression(std::move(expression)) {}

    void accept(Visitor& visitor) override;
};

// Индексация массива
class ArrayIndexing : public Expression {
public:
    std::unique_ptr<Expression> array;
    std::unique_ptr<Expression> index;

    ArrayIndexing(std::unique_ptr<Expression> array, std::unique_ptr<Expression> index)
        : array(std::move(array)), index(std::move(index)) {}

    ArrayIndexing(std::unique_ptr<Expression> array) // Для доступа к length
        : array(std::move(array)), index(nullptr) {}

    void accept(Visitor& visitor) override;
};

// Получение длины массива
class ArrayLength : public Expression {
public:
    std::unique_ptr<Expression> array;

    ArrayLength(std::unique_ptr<Expression> array)
        : array(std::move(array)) {}

    void accept(Visitor& visitor) override;
};

// Вызов метода
class MethodInvocation : public Expression {
public:
    std::unique_ptr<Expression> object;
    std::string methodName;
    std::vector<std::unique_ptr<Expression>> arguments;

    MethodInvocation(std::unique_ptr<Expression> object, const std::string& methodName,
                    std::vector<std::unique_ptr<Expression>> arguments)
        : object(std::move(object)), methodName(methodName), arguments(std::move(arguments)) {}

    void accept(Visitor& visitor) override;
};

// Доступ к полю
class FieldAccess : public Expression {
public:
    std::unique_ptr<Expression> object;
    std::string fieldName;

    FieldAccess(std::unique_ptr<Expression> object, const std::string& fieldName)
        : object(std::move(object)), fieldName(fieldName) {}

    void accept(Visitor& visitor) override;
};

// Создание нового массива
class NewArray : public Expression {
public:
    std::unique_ptr<SimpleType> elementType;
    std::unique_ptr<Expression> size;

    NewArray(std::unique_ptr<SimpleType> elementType, std::unique_ptr<Expression> size)
        : elementType(std::move(elementType)), size(std::move(size)) {}

    void accept(Visitor& visitor) override;
};

// Создание нового объекта
class NewObject : public Expression {
public:
    std::string className;

    NewObject(const std::string& className) : className(className) {}

    void accept(Visitor& visitor) override;
};

// Литерал целого числа
class IntegerLiteral : public Expression {
public:
    int value;

    IntegerLiteral(int value) : value(value) {}

    void accept(Visitor& visitor) override;
};

// Логический литерал (true/false)
class BooleanLiteral : public Expression {
public:
    bool value;

    BooleanLiteral(bool value) : value(value) {}

    void accept(Visitor& visitor) override;
};

// Выражение this
class ThisExpression : public Expression {
public:
    void accept(Visitor& visitor) override;
};

// Идентификатор как выражение
class IdentifierExpression : public Expression {
public:
    std::string name;

    IdentifierExpression(const std::string& name) : name(name) {}

    void accept(Visitor& visitor) override;
};

// Классы для lvalue

// Простой идентификатор как lvalue
class IdentifierLValue : public LValue {
public:
    std::string name;

    IdentifierLValue(const std::string& name) : name(name) {}

    void accept(Visitor& visitor) override;
};

// Доступ к элементу массива как lvalue
class ArrayAccess : public LValue {
public:
    std::string arrayName;
    std::unique_ptr<Expression> index;

    ArrayAccess(const std::string& arrayName, std::unique_ptr<Expression> index)
        : arrayName(arrayName), index(std::move(index)) {}

    void accept(Visitor& visitor) override;
};

// Базовый класс для обращения к полю
class FieldInvocation : public LValue {
public:
    virtual ~FieldInvocation() = default;
};

// Простое обращение к полю (this.field)
class SimpleFieldInvocation : public FieldInvocation {
public:
    std::string fieldName;

    SimpleFieldInvocation(const std::string& fieldName) : fieldName(fieldName) {}

    void accept(Visitor& visitor) override;
};

// Обращение к элементу массива-поля (this.field[index])
class FieldArrayInvocation : public FieldInvocation {
public:
    std::string fieldName;
    std::unique_ptr<Expression> index;

    FieldArrayInvocation(const std::string& fieldName, std::unique_ptr<Expression> index)
        : fieldName(fieldName), index(std::move(index)) {}

    void accept(Visitor& visitor) override;
};

// Абстрактный класс для реализации паттерна посетитель
class Visitor {
public:
    virtual ~Visitor() = default;

    virtual void visit(Program& node) = 0;
    virtual void visit(MainClass& node) = 0;
    virtual void visit(ClassDeclaration& node) = 0;

    virtual void visit(IntType& node) = 0;
    virtual void visit(BooleanType& node) = 0;
    virtual void visit(VoidType& node) = 0;
    virtual void visit(IdentifierType& node) = 0;
    virtual void visit(ArrayType& node) = 0;

    virtual void visit(VariableDeclaration& node) = 0;
    virtual void visit(MethodDeclaration& node) = 0;

    virtual void visit(AssertStatement& node) = 0;
    virtual void visit(LocalVarDeclStatement& node) = 0;
    virtual void visit(BlockStatement& node) = 0;
    virtual void visit(IfStatement& node) = 0;
    virtual void visit(WhileStatement& node) = 0;
    virtual void visit(PrintStatement& node) = 0;
    virtual void visit(AssignStatement& node) = 0;
    virtual void visit(ReturnStatement& node) = 0;
    virtual void visit(MethodInvocationStatement& node) = 0;

    virtual void visit(BinaryOperation& node) = 0;
    virtual void visit(UnaryOperation& node) = 0;
    virtual void visit(ArrayIndexing& node) = 0;
    virtual void visit(ArrayLength& node) = 0;
    virtual void visit(MethodInvocation& node) = 0;
    virtual void visit(FieldAccess& node) = 0;
    virtual void visit(NewArray& node) = 0;
    virtual void visit(NewObject& node) = 0;
    virtual void visit(IntegerLiteral& node) = 0;
    virtual void visit(BooleanLiteral& node) = 0;
    virtual void visit(ThisExpression& node) = 0;
    virtual void visit(IdentifierExpression& node) = 0;

    virtual void visit(IdentifierLValue& node) = 0;
    virtual void visit(ArrayAccess& node) = 0;
    virtual void visit(SimpleFieldInvocation& node) = 0;
    virtual void visit(FieldArrayInvocation& node) = 0;
};

// Реализации методов accept для всех классов
inline void Program::accept(Visitor& visitor) { visitor.visit(*this); }
inline void MainClass::accept(Visitor& visitor) { visitor.visit(*this); }
inline void ClassDeclaration::accept(Visitor& visitor) { visitor.visit(*this); }
inline void IntType::accept(Visitor& visitor) { visitor.visit(*this); }
inline void BooleanType::accept(Visitor& visitor) { visitor.visit(*this); }
inline void VoidType::accept(Visitor& visitor) { visitor.visit(*this); }
inline void IdentifierType::accept(Visitor& visitor) { visitor.visit(*this); }
inline void ArrayType::accept(Visitor& visitor) { visitor.visit(*this); }
inline void VariableDeclaration::accept(Visitor& visitor) { visitor.visit(*this); }
inline void MethodDeclaration::accept(Visitor& visitor) { visitor.visit(*this); }
inline void AssertStatement::accept(Visitor& visitor) { visitor.visit(*this); }
inline void LocalVarDeclStatement::accept(Visitor& visitor) { visitor.visit(*this); }
inline void BlockStatement::accept(Visitor& visitor) { visitor.visit(*this); }
inline void IfStatement::accept(Visitor& visitor) { visitor.visit(*this); }
inline void WhileStatement::accept(Visitor& visitor) { visitor.visit(*this); }
inline void PrintStatement::accept(Visitor& visitor) { visitor.visit(*this); }
inline void AssignStatement::accept(Visitor& visitor) { visitor.visit(*this); }
inline void ReturnStatement::accept(Visitor& visitor) { visitor.visit(*this); }
inline void MethodInvocationStatement::accept(Visitor& visitor) { visitor.visit(*this); }
inline void BinaryOperation::accept(Visitor& visitor) { visitor.visit(*this); }
inline void UnaryOperation::accept(Visitor& visitor) { visitor.visit(*this); }
inline void ArrayIndexing::accept(Visitor& visitor) { visitor.visit(*this); }
inline void ArrayLength::accept(Visitor& visitor) { visitor.visit(*this); }
inline void MethodInvocation::accept(Visitor& visitor) { visitor.visit(*this); }
inline void FieldAccess::accept(Visitor& visitor) { visitor.visit(*this); }
inline void NewArray::accept(Visitor& visitor) { visitor.visit(*this); }
inline void NewObject::accept(Visitor& visitor) { visitor.visit(*this); }
inline void IntegerLiteral::accept(Visitor& visitor) { visitor.visit(*this); }
inline void BooleanLiteral::accept(Visitor& visitor) { visitor.visit(*this); }
inline void ThisExpression::accept(Visitor& visitor) { visitor.visit(*this); }
inline void IdentifierExpression::accept(Visitor& visitor) { visitor.visit(*this); }
inline void IdentifierLValue::accept(Visitor& visitor) { visitor.visit(*this); }
inline void ArrayAccess::accept(Visitor& visitor) { visitor.visit(*this); }
inline void SimpleFieldInvocation::accept(Visitor& visitor) { visitor.visit(*this); }
inline void FieldArrayInvocation::accept(Visitor& visitor) { visitor.visit(*this); }