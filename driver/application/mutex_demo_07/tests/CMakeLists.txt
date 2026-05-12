# Test CMakeLists.txt for mutex_demo_07
cmake_minimum_required(VERSION 3.16)

# Enable testing
enable_testing()

# Mock mutex device library (for testing)
add_library(mock_mutex_demo STATIC
    mock_mutex_demo.c
    mock_mutex_demo.h
)

target_include_directories(mock_mutex_demo PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Mutex test unit test executable
add_executable(test_mutex_test
    test_mutex_test.c
)

# Add compile definition for the binary path using generator expression
target_compile_definitions(test_mutex_test PRIVATE
    MUTEX_TEST_BIN="$<TARGET_FILE:mutex_test>"
)

# Add dependency on mutex_test so tests build after main binary
add_dependencies(test_mutex_test mutex_test)

# Add the test to CTest
add_test(NAME unit_test_mutex COMMAND test_mutex_test)

# Set test properties
set_tests_properties(unit_test_mutex PROPERTIES
    TIMEOUT 30
    LABELS "unit"
)

# Custom target to run all tests
add_custom_target(run_mutex_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --verbose
    DEPENDS test_mutex_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running mutex demo tests..."
)

# Integration test script (for manual testing or on actual hardware)
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/integration_test.sh
    ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    COPYONLY
)

# Add a test that runs the shell script
add_test(NAME integration_test_mutex
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

set_tests_properties(integration_test_mutex PROPERTIES
    TIMEOUT 60
    LABELS "integration"
)
