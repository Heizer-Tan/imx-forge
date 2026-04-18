# Test CMakeLists.txt for chardev_led_control
cmake_minimum_required(VERSION 3.16)

# Enable testing
enable_testing()

# Mock character device library (for testing)
add_library(mock_chardev STATIC
    mock_chardev.c
    mock_chardev.h
)

target_include_directories(mock_chardev PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# LED Control unit test executable
add_executable(test_led_control
    test_led_control.c
)

# Add compile definition for the binary path using generator expression
target_compile_definitions(test_led_control PRIVATE
    LED_CONTROL_BIN="$<TARGET_FILE:led_control>"
)

# Add dependency on led_control so tests build after main binary
add_dependencies(test_led_control led_control)

# Add the test to CTest
add_test(NAME unit_test_led_control COMMAND test_led_control)

# Set test properties
set_tests_properties(unit_test_led_control PROPERTIES
    TIMEOUT 30
    LABELS "unit"
)

# Custom target to run all tests
add_custom_target(run_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --verbose
    DEPENDS test_led_control
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running LED control tests..."
)

# Integration test script (for manual testing or on actual hardware)
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/integration_test.sh
    ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    COPYONLY
)

# Add a test that runs the shell script
add_test(NAME integration_test_led_control
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

set_tests_properties(integration_test_led_control PROPERTIES
    TIMEOUT 60
    LABELS "integration"
)
