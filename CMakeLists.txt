cmake_minimum_required(VERSION 3.10)
project(MinijavaCompiler)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Установка путей для вывода бинарных файлов
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Пути к исходным файлам и заголовкам
set(SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)
set(INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include)

# Добавляем пути включения
include_directories(${INCLUDE_DIR})

# Сборка основного проекта
add_executable(minijava_compiler
    ${SRC_DIR}/main.cpp
    ${SRC_DIR}/lexer.cpp
    ${SRC_DIR}/parser.cpp
)

# Тесты
enable_testing()
find_package(GTest CONFIG QUIET)
if(NOT GTest_FOUND)
    # Если GTest не установлен через пакетный менеджер, 
    # скачиваем и собираем из исходников
    include(FetchContent)
    FetchContent_Declare(
        googletest
        URL https://github.com/google/googletest/archive/refs/tags/v1.13.0.zip
    )
    FetchContent_MakeAvailable(googletest)
endif()

# Создаем директорию tests, если она не существует
file(MAKE_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests)

# Создаем библиотеку компилятора для использования в тестах
add_library(minijava_lib STATIC
    ${SRC_DIR}/lexer.cpp
    ${SRC_DIR}/parser.cpp
)
target_include_directories(minijava_lib PUBLIC ${INCLUDE_DIR})

# Добавляем тесты
add_executable(lexer_test 
    tests/lexer_test.cpp
    tests/main_test.cpp
)
target_link_libraries(lexer_test GTest::gtest minijava_lib)

add_executable(parser_test
    tests/parser_test.cpp
    tests/main_test.cpp
)
target_link_libraries(parser_test GTest::gtest minijava_lib)

# Регистрируем тесты
add_test(NAME LexerTest COMMAND lexer_test)
add_test(NAME ParserTest COMMAND parser_test)