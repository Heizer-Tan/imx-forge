cmake_minimum_required(VERSION 3.16)
enable_testing()

add_library(mock_nonblocking_io_demo STATIC
    mock_nonblocking_io_demo.c
    mock_nonblocking_io_demo.h
)

target_include_directories(mock_nonblocking_io_demo PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

add_executable(test_poll_test
    test_poll_test.c
)

target_compile_definitions(test_poll_test PRIVATE
    POLL_TEST_BIN="$<TARGET_FILE:poll_test>"
)

add_dependencies(test_poll_test poll_test)

add_test(NAME unit_test_nonblocking_io COMMAND test_poll_test)
set_tests_properties(unit_test_nonblocking_io PROPERTIES
    TIMEOUT 30
    LABELS "unit"
)

add_custom_target(run_nonblocking_io_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --verbose
    DEPENDS test_poll_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running nonblocking I/O demo tests..."
)

configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/integration_test.sh
    ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    COPYONLY
)

add_test(NAME integration_test_nonblocking_io
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

set_tests_properties(integration_test_nonblocking_io PROPERTIES
    TIMEOUT 60
    LABELS "integration"
)
