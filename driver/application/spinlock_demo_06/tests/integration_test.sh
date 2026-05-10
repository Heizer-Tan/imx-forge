#!/bin/bash
#
# integration_test.sh - Integration test for spinlock_demo driver
#
# This script requires the actual spinlock_demo driver to be loaded.

set -e

DEVICE_PATH="${DEVICE_PATH:-/dev/spinlock_demo}"
TEST_BIN="./spinlock_test"

echo "========================================="
echo "Spinlock Demo Integration Test"
echo "Device: $DEVICE_PATH"
echo "========================================="

# Check if device exists
if [ ! -e "$DEVICE_PATH" ]; then
    echo "ERROR: Device $DEVICE_PATH not found"
    echo "Please load the spinlock_demo driver first"
    exit 1
fi

# Test 1: Read initial state
echo ""
echo "Test 1: Read initial state"
$TEST_BIN read

# Test 2: Protected increments
echo ""
echo "Test 2: Do 100 protected increments"
$TEST_BIN protected 100

# Test 3: Read after protected
echo ""
echo "Test 3: Read after protected increments"
$TEST_BIN read

# Test 4: Unprotected increments
echo ""
echo "Test 4: Do 100 unprotected increments"
$TEST_BIN unprotected 100

# Test 5: Read after unprotected
echo ""
echo "Test 5: Read after unprotected increments"
$TEST_BIN read

# Test 6: Reset counters
echo ""
echo "Test 6: Reset counters"
$TEST_BIN reset

# Test 7: Read after reset
echo ""
echo "Test 7: Read after reset"
$TEST_BIN read

# Test 8: Stress test
echo ""
echo "Test 8: Stress test with 1000 iterations"
$TEST_BIN stress 1000

# Test 9: Final read
echo ""
echo "Test 9: Final read"
$TEST_BIN read

echo ""
echo "========================================="
echo "All integration tests passed!"
echo "========================================="
