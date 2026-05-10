cmake_minimum_required(VERSION 3.16)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
project(nonblocking_io_demo_11
    VERSION 1.0.0
    LANGUAGES C)

option(BUILD_TESTING "Build test programs" ON)

add_executable(poll_test poll_test.c)

if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(tests)
endif()
