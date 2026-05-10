#!/bin/bash
set -e

DEVICE_PATH="${DEVICE_PATH:-/dev/timer_demo}"
TEST_BIN="./timer_test"

echo "========================================="
echo "Timer Demo Integration Test"
echo "Device: $DEVICE_PATH"
echo "========================================="

if [ ! -e "$DEVICE_PATH" ]; then
    echo "ERROR: Device $DEVICE_PATH not found"
    echo "Please load the timer_demo driver first"
    exit 1
fi

echo ""
echo "Test 1: Read initial state"
$TEST_BIN read

echo ""
echo "Test 2: Start timer (500ms)"
$TEST_BIN start 500

echo ""
echo "Test 3: Read after start"
$TEST_BIN read

sleep 2

echo ""
echo "Test 4: Stop timer"
$TEST_BIN stop

echo ""
echo "Test 5: Read after stop"
$TEST_BIN read

echo ""
echo "Test 6: Reset statistics"
$TEST_BIN reset

echo ""
echo "Test 7: Final read"
$TEST_BIN read

echo ""
echo "========================================="
echo "All integration tests passed!"
echo "========================================="
