#!/bin/bash
#
# integration_test.sh - Integration test for mutex_demo driver
#
# This script requires the actual mutex_demo driver to be loaded.

set -e

DEVICE_PATH="${DEVICE_PATH:-/dev/mutex_demo}"
TEST_BIN="./mutex_test"

echo "========================================="
echo "Mutex Demo Integration Test"
echo "Device: $DEVICE_PATH"
echo "========================================="

# Check if device exists
if [ ! -e "$DEVICE_PATH" ]; then
    echo "ERROR: Device $DEVICE_PATH not found"
    echo "Please load the mutex_demo driver first"
    exit 1
fi

# Test 1: Read initial state
echo ""
echo "Test 1: Read initial state"
$TEST_BIN read

# Test 2: Write value
echo ""
echo "Test 2: Write value 42"
$TEST_BIN write 42

# Test 3: Read after write
echo ""
echo "Test 3: Read after write"
$TEST_BIN read

# Test 4: Slow write
echo ""
echo "Test 4: Slow write value 100"
$TEST_BIN slow_write 100

# Test 5: Read after slow write
echo ""
echo "Test 5: Read after slow write"
$TEST_BIN read

echo ""
echo "========================================="
echo "All integration tests passed!"
echo "========================================="
