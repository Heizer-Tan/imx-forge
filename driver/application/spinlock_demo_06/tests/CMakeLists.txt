# Test CMakeLists.txt for spinlock_demo_06
cmake_minimum_required(VERSION 3.16)

# Enable testing
enable_testing()

# Mock spinlock device library (for testing)
add_library(mock_spinlock_demo STATIC
    mock_spinlock_demo.c
    mock_spinlock_demo.h
)

target_include_directories(mock_spinlock_demo PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Spinlock test unit test executable
add_executable(test_spinlock_test
    test_spinlock_test.c
)

# Add compile definition for the binary path using generator expression
target_compile_definitions(test_spinlock_test PRIVATE
    SPINLOCK_TEST_BIN="$<TARGET_FILE:spinlock_test>"
)

# Add dependency on spinlock_test so tests build after main binary
add_dependencies(test_spinlock_test spinlock_test)

# Add the test to CTest
add_test(NAME unit_test_spinlock COMMAND test_spinlock_test)

# Set test properties
set_tests_properties(unit_test_spinlock PROPERTIES
    TIMEOUT 30
    LABELS "unit"
)

# Custom target to run all tests
add_custom_target(run_spinlock_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --verbose
    DEPENDS test_spinlock_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running spinlock demo tests..."
)

# Integration test script (for manual testing or on actual hardware)
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/integration_test.sh
    ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    COPYONLY
)

# Add a test that runs the shell script
add_test(NAME integration_test_spinlock
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

set_tests_properties(integration_test_spinlock PROPERTIES
    TIMEOUT 60
    LABELS "integration"
)
