#include <iostream>
#include <fstream>
#include <sstream>
#include "lexer.h"
#include "parser.h"
#include "ast_printer.h"

// Функция для чтения файла
std::string readFile(const std::string& path) {
    std::ifstream file(path);
    std::stringstream buffer;
    
    if (file.is_open()) {
        buffer << file.rdbuf();
        file.close();
    } else {
        std::cerr << "Не удалось открыть файл: " << path << std::endl;
    }
    
    return buffer.str();
}

int main(int argc, char* argv[]) {
    std::string source;
    
    // Проверка аргументов командной строки
    if (argc < 2) {
        std::cerr << "Использование: " << argv[0] << " <файл с исходным кодом>" << std::endl;
        return 1;
    }
    
    // Чтение исходного файла
    source = readFile(argv[1]);
    if (source.empty()) {
        std::cerr << "Файл пуст или не может быть прочитан." << std::endl;
        return 1;
    }
    
    try {
        // Лексический анализ
        Lexer lexer(source);
        std::vector<Token> tokens = lexer.tokenize();
        
        std::cout << "Лексический анализ завершен. Найдено токенов: " << tokens.size() << std::endl;
        
        // Синтаксический анализ
        Parser parser(tokens);
        auto program = parser.parseProgram();
        
        std::cout << "Синтаксический анализ завершен. AST дерево:" << std::endl;
        
        // Вывод AST
        ASTPrinter printer;
        program->accept(printer);
        
    } catch (const std::exception& e) {
        std::cerr << "Ошибка: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
}