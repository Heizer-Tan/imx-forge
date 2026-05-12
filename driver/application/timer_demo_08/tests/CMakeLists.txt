cmake_minimum_required(VERSION 3.16)
enable_testing()

add_library(mock_timer_demo STATIC
    mock_timer_demo.c
    mock_timer_demo.h
)

target_include_directories(mock_timer_demo PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

add_executable(test_timer_test
    test_timer_test.c
)

target_compile_definitions(test_timer_test PRIVATE
    TIMER_TEST_BIN="$<TARGET_FILE:timer_test>"
)

add_dependencies(test_timer_test timer_test)

add_test(NAME unit_test_timer COMMAND test_timer_test)
set_tests_properties(unit_test_timer PROPERTIES
    TIMEOUT 30
    LABELS "unit"
)

add_custom_target(run_timer_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --verbose
    DEPENDS test_timer_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running timer demo tests..."
)

configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/integration_test.sh
    ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    COPYONLY
)

add_test(NAME integration_test_timer
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/integration_test.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

set_tests_properties(integration_test_timer PROPERTIES
    TIMEOUT 60
    LABELS "integration"
)
