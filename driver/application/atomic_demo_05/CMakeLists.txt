cmake_minimum_required(VERSION 3.16)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
project(atomic_demo_05
    VERSION 1.0.0
    LANGUAGES C)

# Build option for testing
option(BUILD_TESTING "Build test programs" ON)

# Main executable
add_executable(atomic_test atomic_test.c)

# Add tests subdirectory if testing is enabled
if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(tests)
endif()
