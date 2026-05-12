cmake_minimum_required(VERSION 3.16)
enable_testing()

add_library(mock_async_notify_demo STATIC
    mock_async_notify_demo.c
    mock_async_notify_demo.h
)

target_include_directories(mock_async_notify_demo PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

add_executable(test_async_test
    test_async_test.c
)

target_compile_definitions(test_async_test PRIVATE
    ASYNC_TEST_BIN="$<TARGET_FILE:async_test>"
)

add_dependencies(test_async_test async_test)

add_test(NAME unit_test_async_notify COMMAND test_async_test)
set_tests_properties(unit_test_async_notify PROPERTIES
    TIMEOUT 30
    LABELS "unit"
)

add_custom_target(run_async_notify_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --verbose
    DEPENDS test_async_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running async notify demo tests..."
)

configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/integration_test.sh
    ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    COPYONLY
)

add_test(NAME integration_test_async_notify
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

set_tests_properties(integration_test_async_notify PROPERTIES
    TIMEOUT 60
    LABELS "integration"
)
