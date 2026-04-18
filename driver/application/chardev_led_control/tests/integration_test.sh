#!/bin/bash
#
# Integration test script for LED control application
# Tests argument validation and basic functionality
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Run a test
run_test() {
    local test_name="$1"
    local test_cmd="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo "[$TESTS_RUN] Running: $test_name"

    if eval "$test_cmd"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_info "  PASSED"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "  FAILED"
    fi
    echo ""
}

# Find the led_control binary
find_led_control() {
    # Check various possible locations
    local locations=(
        "./led_control"
        "../build/bin/led_control"
        "../led_control"
        "./build/led_control"
    )

    for loc in "${locations[@]}"; do
        if [[ -f "$loc" && -x "$loc" ]]; then
            echo "$loc"
            return 0
        fi
    done

    return 1
}

# Create a mock device file
create_mock_device() {
    local mock_path="/tmp/mock_led_test_$$"
    echo "0" > "$mock_path"
    echo "$mock_path"
}

# Clean up mock device
cleanup_mock_device() {
    local mock_path="$1"
    [[ -f "$mock_path" ]] && rm -f "$mock_path"
}

# Main test execution
main() {
    echo "========================================"
    echo "LED Control Integration Tests"
    echo "========================================"
    echo ""

    # Find the binary
    LED_CONTROL=$(find_led_control)
    if [[ -z "$LED_CONTROL" ]]; then
        log_error "Could not find led_control binary"
        log_info "Build it first: mkdir -p build && cd build && cmake .. && cmake --build ."
        exit 1
    fi
    log_info "Using binary: $LED_CONTROL"
    echo ""

    # Test 1: Help message on wrong arguments (no args)
    run_test "Help message with no arguments" \
        "$LED_CONTROL 2>&1 | grep -q 'Usage:'"

    # Test 2: Help message with one argument
    run_test "Help message with one argument" \
        "$LED_CONTROL /dev/some_dev 2>&1 | grep -q 'Usage:'"

    # Test 3: Invalid value argument
    MOCK_DEV=$(create_mock_device)
    run_test "Invalid value argument rejected" \
        "$LED_CONTROL $MOCK_DEV invalid 2>&1 | grep -q 'Expected only 1 and 0'"
    cleanup_mock_device "$MOCK_DEV"

    # Test 4: Non-existent device file
    run_test "Non-existent device file handled" \
        "$LED_CONTROL /nonexistent/path/that/does/not/exist 1 2>&1 | grep -q 'Failed to open'"

    # Test 5: Valid value '0' opens file successfully
    MOCK_DEV=$(create_mock_device)
    run_test "Valid value '0' opens file" \
        "! $LED_CONTROL $MOCK_DEV 0 2>&1 | grep -q 'Failed to open'"
    cleanup_mock_device "$MOCK_DEV"

    # Test 6: Valid value '1' opens file successfully
    MOCK_DEV=$(create_mock_device)
    run_test "Valid value '1' opens file" \
        "! $LED_CONTROL $MOCK_DEV 1 2>&1 | grep -q 'Failed to open'"
    cleanup_mock_device "$MOCK_DEV"

    # Test 7: Various invalid values are rejected
    MOCK_DEV=$(create_mock_device)
    run_test "Invalid value '2' rejected" \
        "$LED_CONTROL $MOCK_DEV 2 >/dev/null 2>&1 && false || true"
    cleanup_mock_device "$MOCK_DEV"

    # Test 8: Help message contains usage information
    run_test "Help message shows correct usage" \
        "$LED_CONTROL 2>&1 | grep -q '<0/1>'"

    # Test 9: Real device (if available)
    if [[ -c "/dev/aes_led" ]]; then
        log_warn "Real LED device found at /dev/aes_led"
        echo "Would you like to run tests on real hardware? [y/N]"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            run_test "Real device - Turn LED on" \
                "$LED_CONTROL /dev/aes_led 1 | grep -q 'LED is on'"

            run_test "Real device - Turn LED off" \
                "$LED_CONTROL /dev/aes_led 0 | grep -q 'LED is off'"
        fi
    else
        log_info "Real LED device not found (/dev/aes_led) - skipping hardware tests"
    fi

    # Summary
    echo "========================================"
    echo "Integration Test Summary"
    echo "========================================"
    echo "  Total:  $TESTS_RUN"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo "========================================"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_info "All tests passed!"
        echo ""
        echo "For full integration testing on hardware:"
        echo "  1. Load the chardev LED driver: insmod chardev_led_v2_02_driver.ko"
        echo "  2. Turn LED on: $LED_CONTROL /dev/aes_led 1"
        echo "  3. Turn LED off: $LED_CONTROL /dev/aes_led 0"
        exit 0
    else
        log_error "Some tests failed!"
        exit 1
    fi
}

# Run main function
main "$@"
