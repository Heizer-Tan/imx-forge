cmake_minimum_required(VERSION 3.16)
enable_testing()

add_library(mock_interrupt_demo STATIC
    mock_interrupt_demo.c
    mock_interrupt_demo.h
)

target_include_directories(mock_interrupt_demo PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

add_executable(test_button_test
    test_button_test.c
)

target_compile_definitions(test_button_test PRIVATE
    BUTTON_TEST_BIN="$<TARGET_FILE:button_test>"
)

add_dependencies(test_button_test button_test)

add_test(NAME unit_test_interrupt COMMAND test_button_test)
set_tests_properties(unit_test_interrupt PROPERTIES
    TIMEOUT 30
    LABELS "unit"
)

add_custom_target(run_interrupt_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --verbose
    DEPENDS test_button_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running interrupt demo tests..."
)

configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/integration_test.sh
    ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    COPYONLY
)

add_test(NAME integration_test_interrupt
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

set_tests_properties(integration_test_interrupt PROPERTIES
    TIMEOUT 60
    LABELS "integration"
)
