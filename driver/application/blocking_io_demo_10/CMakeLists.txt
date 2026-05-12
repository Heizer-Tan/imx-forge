cmake_minimum_required(VERSION 3.16)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
project(blocking_io_demo_10
    VERSION 1.0.0
    LANGUAGES C)

option(BUILD_TESTING "Build test programs" ON)

add_executable(buffer_test buffer_test.c)

if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(tests)
endif()
