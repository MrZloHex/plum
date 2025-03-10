#pragma once
#include "ast.h"
#include <iostream>
#include <string>

class ASTPrinter : public Visitor {
private:
    int indent = 0;
    std::string getIndent() const {
        return std::string(indent * 2, ' ');
    }
    
    void increaseIndent() { indent++; }
    void decreaseIndent() { indent--; }
    
public:
    void visit(Program& node) override {
        std::cout << "Program" << std::endl;
        increaseIndent();
        
        std::cout << getIndent() << "MainClass:" << std::endl;
        increaseIndent();
        node.mainClass->accept(*this);
        decreaseIndent();
        
        if (!node.classes.empty()) {
            std::cout << getIndent() << "Classes:" << std::endl;
            increaseIndent();
            for (auto& cls : node.classes) {
                cls->accept(*this);
            }
            decreaseIndent();
        }
        
        decreaseIndent();
    }
    
    void visit(MainClass& node) override {
        std::cout << getIndent() << "Class: " << node.className << std::endl;
        
        increaseIndent();
        std::cout << getIndent() << "main() statements:" << std::endl;
        increaseIndent();
        for (auto& stmt : node.statements) {
            stmt->accept(*this);
        }
        decreaseIndent();
        decreaseIndent();
    }
    
    void visit(ClassDeclaration& node) override {
        std::cout << getIndent() << "Class: " << node.className;
        if (!node.baseClassName.empty()) {
            std::cout << " extends " << node.baseClassName;
        }
        std::cout << std::endl;
        
        increaseIndent();
        for (auto& decl : node.declarations) {
            decl->accept(*this);
        }
        decreaseIndent();
    }
    
    // Типы
    void visit(IntType& node) override {
        std::cout << "int";
    }
    
    void visit(BooleanType& node) override {
        std::cout << "boolean";
    }
    
    void visit(VoidType& node) override {
        std::cout << "void";
    }
    
    void visit(IdentifierType& node) override {
        std::cout << node.typeName;
    }
    
    void visit(ArrayType& node) override {
        node.elementType->accept(*this);
        std::cout << "[]";
    }
    
    // Объявления
    void visit(VariableDeclaration& node) override {
        std::cout << getIndent() << "Variable: ";
        node.type->accept(*this);
        std::cout << " " << node.name << std::endl;
    }
    
    void visit(MethodDeclaration& node) override {
        std::cout << getIndent() << "Method: ";
        node.returnType->accept(*this);
        std::cout << " " << node.name << "(";
        
        // Параметры
        for (size_t i = 0; i < node.parameters.size(); i++) {
            if (i > 0) std::cout << ", ";
            node.parameters[i]->type->accept(*this);
            std::cout << " " << node.parameters[i]->name;
        }
        std::cout << ")" << std::endl;
        
        increaseIndent();
        for (auto& stmt : node.statements) {
            stmt->accept(*this);
        }
        decreaseIndent();
    }
    
    // Операторы
    void visit(AssertStatement& node) override {
        std::cout << getIndent() << "Assert(" << std::endl;
        increaseIndent();
        node.condition->accept(*this);
        decreaseIndent();
        std::cout << getIndent() << ")" << std::endl;
    }
    
    void visit(LocalVarDeclStatement& node) override {
        node.declaration->accept(*this);
    }
    
    void visit(BlockStatement& node) override {
        std::cout << getIndent() << "Block {" << std::endl;
        increaseIndent();
        for (auto& stmt : node.statements) {
            stmt->accept(*this);
        }
        decreaseIndent();
        std::cout << getIndent() << "}" << std::endl;
    }
    
    void visit(IfStatement& node) override {
        std::cout << getIndent() << "If (" << std::endl;
        increaseIndent();
        node.condition->accept(*this);
        decreaseIndent();
        std::cout << getIndent() << ") Then" << std::endl;
        
        increaseIndent();
        node.thenStatement->accept(*this);
        decreaseIndent();
        
        if (node.elseStatement) {
            std::cout << getIndent() << "Else" << std::endl;
            increaseIndent();
            node.elseStatement->accept(*this);
            decreaseIndent();
        }
    }
    
    void visit(WhileStatement& node) override {
        std::cout << getIndent() << "While (" << std::endl;
        increaseIndent();
        node.condition->accept(*this);
        decreaseIndent();
        std::cout << getIndent() << ")" << std::endl;
        
        increaseIndent();
        node.body->accept(*this);
        decreaseIndent();
    }
    
    void visit(PrintStatement& node) override {
        std::cout << getIndent() << "System.out.println(" << std::endl;
        increaseIndent();
        node.expression->accept(*this);
        decreaseIndent();
        std::cout << getIndent() << ")" << std::endl;
    }
    
    void visit(AssignStatement& node) override {
        std::cout << getIndent() << "Assign:" << std::endl;
        increaseIndent();
        std::cout << getIndent() << "LValue: " << std::endl;
        increaseIndent();
        node.lvalue->accept(*this);
        decreaseIndent();
        
        std::cout << getIndent() << "= " << std::endl;
        increaseIndent();
        node.expression->accept(*this);
        decreaseIndent();
        decreaseIndent();
    }
    
    void visit(ReturnStatement& node) override {
        std::cout << getIndent() << "Return:" << std::endl;
        increaseIndent();
        node.expression->accept(*this);
        decreaseIndent();
    }
    
    void visit(MethodInvocationStatement& node) override {
        std::cout << getIndent() << "Method Call:" << std::endl;
        increaseIndent();
        node.invocation->accept(*this);
        decreaseIndent();
    }
    
    // Выражения
    void visit(BinaryOperation& node) override {
        std::cout << getIndent() << "BinaryOp ";
        switch (node.op) {
            case BinaryOperator::AND: std::cout << "&&"; break;
            case BinaryOperator::OR: std::cout << "||"; break;
            case BinaryOperator::LESS: std::cout << "<"; break;
            case BinaryOperator::GREATER: std::cout << ">"; break;
            case BinaryOperator::EQUAL: std::cout << "=="; break;
            case BinaryOperator::PLUS: std::cout << "+"; break;
            case BinaryOperator::MINUS: std::cout << "-"; break;
            case BinaryOperator::MULTIPLY: std::cout << "*"; break;
            case BinaryOperator::DIVIDE: std::cout << "/"; break;
            case BinaryOperator::MODULO: std::cout << "%"; break;
        }
        std::cout << std::endl;
        
        increaseIndent();
        std::cout << getIndent() << "Left: " << std::endl;
        increaseIndent();
        node.left->accept(*this);
        decreaseIndent();
        
        std::cout << getIndent() << "Right: " << std::endl;
        increaseIndent();
        node.right->accept(*this);
        decreaseIndent();
        decreaseIndent();
    }
    
    void visit(UnaryOperation& node) override {
        std::cout << getIndent() << "UnaryOp ";
        switch (node.op) {
            case UnaryOperator::NOT: std::cout << "!"; break;
        }
        std::cout << std::endl;
        
        increaseIndent();
        node.expression->accept(*this);
        decreaseIndent();
    }
    
    void visit(ArrayIndexing& node) override {
        std::cout << getIndent() << "ArrayIndex:" << std::endl;
        increaseIndent();
        std::cout << getIndent() << "Array:" << std::endl;
        increaseIndent();
        node.array->accept(*this);
        decreaseIndent();
        
        std::cout << getIndent() << "Index:" << std::endl;
        increaseIndent();
        node.index->accept(*this);
        decreaseIndent();
        decreaseIndent();
    }
    
    void visit(ArrayLength& node) override {
        std::cout << getIndent() << "ArrayLength:" << std::endl;
        increaseIndent();
        node.array->accept(*this);
        decreaseIndent();
    }
    
    void visit(MethodInvocation& node) override {
        std::cout << getIndent() << "MethodInvocation: " << node.methodName << "()" << std::endl;
        increaseIndent();
        std::cout << getIndent() << "Object:" << std::endl;
        increaseIndent();
        node.object->accept(*this);
        decreaseIndent();
        
        if (!node.arguments.empty()) {
            std::cout << getIndent() << "Arguments:" << std::endl;
            increaseIndent();
            for (auto& arg : node.arguments) {
                arg->accept(*this);
            }
            decreaseIndent();
        }
        decreaseIndent();
    }
    
    void visit(FieldAccess& node) override {
        std::cout << getIndent() << "FieldAccess: " << node.fieldName << std::endl;
        increaseIndent();
        node.object->accept(*this);
        decreaseIndent();
    }
    
    void visit(NewArray& node) override {
        std::cout << getIndent() << "NewArray: ";
        node.elementType->accept(*this);
        std::cout << "[" << std::endl;
        increaseIndent();
        node.size->accept(*this);
        decreaseIndent();
        std::cout << getIndent() << "]" << std::endl;
    }
    
    void visit(NewObject& node) override {
        std::cout << getIndent() << "NewObject: " << node.className << "()" << std::endl;
    }
    
    void visit(IntegerLiteral& node) override {
        std::cout << getIndent() << "IntegerLiteral: " << node.value << std::endl;
    }
    
    void visit(BooleanLiteral& node) override {
        std::cout << getIndent() << "BooleanLiteral: " << (node.value ? "true" : "false") << std::endl;
    }
    
    void visit(ThisExpression& node) override {
        std::cout << getIndent() << "This" << std::endl;
    }
    
    void visit(IdentifierExpression& node) override {
        std::cout << getIndent() << "Identifier: " << node.name << std::endl;
    }
    
    void visit(IdentifierLValue& node) override {
        std::cout << getIndent() << "Identifier: " << node.name << std::endl;
    }
    
    void visit(ArrayAccess& node) override {
        std::cout << getIndent() << "ArrayAccess: " << node.arrayName << "[" << std::endl;
        increaseIndent();
        node.index->accept(*this);
        decreaseIndent();
        std::cout << getIndent() << "]" << std::endl;
    }
    
    void visit(SimpleFieldInvocation& node) override {
        std::cout << getIndent() << "this." << node.fieldName << std::endl;
    }
    
    void visit(FieldArrayInvocation& node) override {
        std::cout << getIndent() << "this." << node.fieldName << "[" << std::endl;
        increaseIndent();
        node.index->accept(*this);
        decreaseIndent();
        std::cout << getIndent() << "]" << std::endl;
    }
};