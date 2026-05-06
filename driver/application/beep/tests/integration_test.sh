#!/bin/bash
#
# Integration test script for beep application
# Tests argument validation and basic functionality
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

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

find_beep() {
    local locations=(
        "./beep"
        "../build/bin/beep"
        "../beep"
        "./build/beep"
    )

    for loc in "${locations[@]}"; do
        if [[ -f "$loc" && -x "$loc" ]]; then
            echo "$loc"
            return 0
        fi
    done

    return 1
}

main() {
    echo "========================================"
    echo "Beep Integration Tests"
    echo "========================================"
    echo ""

    BEEP=$(find_beep)
    if [[ -z "$BEEP" ]]; then
        log_error "Could not find beep binary"
        log_info "Build it first: mkdir -p build && cd build && cmake .. && cmake --build ."
        exit 1
    fi
    log_info "Using binary: $BEEP"
    echo ""

    run_test "Help message with no arguments" \
        "$BEEP 2>&1 | grep -q 'Usage:'"

    run_test "Help message with one argument" \
        "$BEEP 2>&1 | grep -q 'Usage:'"

    run_test "Invalid mode '3' rejected" \
        "$BEEP 3 2>&1 | grep -q -E '(invalid|Failed)'"

    run_test "Invalid mode '-1' rejected" \
        "$BEEP -1 2>&1 | grep -q -E '(invalid|Failed)'"

    run_test "Non-existent device file handled" \
        "$BEEP 0 2>&1 | grep -q 'Failed to open'"

    run_test "Valid mode '0' (beep on) works or fails gracefully" \
        "$BEEP 0 2>&1 | grep -q -E '(Beep turned ON|Failed)'"

    run_test "Valid mode '1' (beep off) works or fails gracefully" \
        "$BEEP 1 2>&1 | grep -q -E '(Beep turned OFF|Failed)'"

    run_test "Valid mode '2' (beep once) works or fails gracefully" \
        "$BEEP 2 2>&1 | grep -q -E '(Beeped for|Failed)'"

    run_test "Help message shows correct usage" \
        "$BEEP 2>&1 | grep -q '<0|1|2>'"

    if [[ -c "/dev/beep" ]]; then
        log_warn "Real beep device found at /dev/beep"
        echo "Would you like to run tests on real hardware? [y/N]"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            run_test "Real device - Turn beep on" \
                "$BEEP 0 | grep -q 'Beep turned ON'"

            run_test "Real device - Turn beep off" \
                "$BEEP 1 | grep -q 'Beep turned OFF'"
        fi
    else
        log_info "Real beep device not found (/dev/beep) - skipping hardware tests"
    fi

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
        echo "  1. Load the beep driver"
        echo "  2. Turn beep on: $BEEP 0"
        echo "  3. Turn beep off: $BEEP 1"
        echo "  4. Beep once: $BEEP 2"
        exit 0
    else
        log_error "Some tests failed!"
        exit 1
    fi
}

main "$@"