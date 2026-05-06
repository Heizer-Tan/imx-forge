cmake_minimum_required(VERSION 3.16)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
project(beep
    VERSION 0.1.0
    LANGUAGES C)

option(BUILD_TESTING "Build beep control programs" ON)

add_executable(beep beep_control.c)

if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(tests)
endif()