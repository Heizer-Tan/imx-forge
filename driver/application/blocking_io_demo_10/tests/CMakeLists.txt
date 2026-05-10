cmake_minimum_required(VERSION 3.16)
enable_testing()

add_library(mock_blocking_io_demo STATIC
    mock_blocking_io_demo.c
    mock_blocking_io_demo.h
)

target_include_directories(mock_blocking_io_demo PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

add_executable(test_buffer_test
    test_buffer_test.c
)

target_compile_definitions(test_buffer_test PRIVATE
    BUFFER_TEST_BIN="$<TARGET_FILE:buffer_test>"
)

add_dependencies(test_buffer_test buffer_test)

add_test(NAME unit_test_blocking_io COMMAND test_buffer_test)
set_tests_properties(unit_test_blocking_io PROPERTIES
    TIMEOUT 30
    LABELS "unit"
)

add_custom_target(run_blocking_io_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --verbose
    DEPENDS test_buffer_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running blocking I/O demo tests..."
)

configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/integration_test.sh
    ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    COPYONLY
)

add_test(NAME integration_test_blocking_io
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

set_tests_properties(integration_test_blocking_io PROPERTIES
    TIMEOUT 60
    LABELS "integration"
)
