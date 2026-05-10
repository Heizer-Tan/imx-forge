#!/bin/bash
#
# integration_test.sh - Integration test for atomic_demo driver
#
# This script requires the actual atomic_demo driver to be loaded.

set -e

DEVICE_PATH="${DEVICE_PATH:-/dev/atomic_demo}"
TEST_BIN="./atomic_test"

echo "========================================="
echo "Atomic Demo Integration Test"
echo "Device: $DEVICE_PATH"
echo "========================================="

# Check if device exists
if [ ! -e "$DEVICE_PATH" ]; then
    echo "ERROR: Device $DEVICE_PATH not found"
    echo "Please load the atomic_demo driver first"
    exit 1
fi

# Test 1: Read initial state
echo ""
echo "Test 1: Read initial state"
$TEST_BIN read

# Test 2: Set value
echo ""
echo "Test 2: Set counter to 100"
$TEST_BIN set 100

# Test 3: Read after set
echo ""
echo "Test 3: Read after set"
$TEST_BIN read

# Test 4: Add value
echo ""
echo "Test 4: Add 50"
$TEST_BIN add 50

# Test 5: Read after add
echo ""
echo "Test 5: Read after add"
$TEST_BIN read

# Test 6: Subtract value
echo ""
echo "Test 6: Subtract 25"
$TEST_BIN sub 25

# Test 7: Read after subtract
echo ""
echo "Test 7: Read after subtract"
$TEST_BIN read

# Test 8: Increment
echo ""
echo "Test 8: Increment"
$TEST_BIN inc

# Test 9: Read after increment
echo ""
echo "Test 9: Read after increment"
$TEST_BIN read

# Test 10: Decrement
echo ""
echo "Test 10: Decrement"
$TEST_BIN dec

# Test 11: Read after decrement
echo ""
echo "Test 11: Read after decrement"
$TEST_BIN read

# Test 12: Set to zero
echo ""
echo "Test 12: Set to zero"
$TEST_BIN set 0

# Test 13: Final read
echo ""
echo "Test 13: Final read"
$TEST_BIN read

echo ""
echo "========================================="
echo "All integration tests passed!"
echo "========================================="
