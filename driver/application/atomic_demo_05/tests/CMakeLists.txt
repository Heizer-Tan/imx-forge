# Test CMakeLists.txt for atomic_demo_05
cmake_minimum_required(VERSION 3.16)

# Enable testing
enable_testing()

# Mock atomic device library (for testing)
add_library(mock_atomic_demo STATIC
    mock_atomic_demo.c
    mock_atomic_demo.h
)

target_include_directories(mock_atomic_demo PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Atomic test unit test executable
add_executable(test_atomic_test
    test_atomic_test.c
)

# Add compile definition for the binary path using generator expression
target_compile_definitions(test_atomic_test PRIVATE
    ATOMIC_TEST_BIN="$<TARGET_FILE:atomic_test>"
)

# Add dependency on atomic_test so tests build after main binary
add_dependencies(test_atomic_test atomic_test)

# Add the test to CTest
add_test(NAME unit_test_atomic COMMAND test_atomic_test)

# Set test properties
set_tests_properties(unit_test_atomic PROPERTIES
    TIMEOUT 30
    LABELS "unit"
)

# Custom target to run all tests
add_custom_target(run_atomic_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --verbose
    DEPENDS test_atomic_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running atomic demo tests..."
)

# Integration test script (for manual testing or on actual hardware)
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/integration_test.sh
    ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    COPYONLY
)

# Add a test that runs the shell script
add_test(NAME integration_test_atomic
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

set_tests_properties(integration_test_atomic PROPERTIES
    TIMEOUT 60
    LABELS "integration"
)
