# Test CMakeLists.txt for beep
cmake_minimum_required(VERSION 3.16)

# Enable testing
enable_testing()

# Mock beep device library (for testing)
add_library(mock_beep STATIC
    mock_beep.c
    mock_beep.h
)

target_include_directories(mock_beep PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Beep unit test executable
add_executable(test_beep
    test_beep.c
)

target_compile_definitions(test_beep PRIVATE
    BEEP_BIN="$<TARGET_FILE:beep>"
)

add_dependencies(test_beep beep)

add_test(NAME unit_test_beep COMMAND test_beep)

set_tests_properties(unit_test_beep PROPERTIES
    TIMEOUT 30
    LABELS "unit"
)

add_custom_target(run_beep_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --verbose
    DEPENDS test_beep
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running beep tests..."
)

configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/integration_test.sh
    ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    COPYONLY
)

add_test(NAME integration_test_beep
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

set_tests_properties(integration_test_beep PROPERTIES
    TIMEOUT 60
    LABELS "integration"
)