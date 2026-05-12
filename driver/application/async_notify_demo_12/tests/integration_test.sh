#!/bin/bash
set -e

DEVICE_PATH="${DEVICE_PATH:-/dev/async_notify_demo}"
TEST_BIN="./async_test"

echo "========================================="
echo "Async Notify Demo Integration Test"
echo "Device: $DEVICE_PATH"
echo "========================================="

if [ ! -e "$DEVICE_PATH" ]; then
    echo "ERROR: Device $DEVICE_PATH not found"
    echo "Please load the async_notify_demo driver first"
    exit 1
fi

echo ""
echo "Test 1: Get statistics"
$TEST_BIN stats

echo ""
echo "Test 2: Monitor mode (press button within 10 seconds)"
echo "Press Ctrl+C to exit early"
timeout 10 $TEST_BIN monitor || echo "Monitor timeout (expected)"

echo ""
echo "Test 3: Final statistics"
$TEST_BIN stats

echo ""
echo "========================================="
echo "Integration test completed!"
echo "========================================="
