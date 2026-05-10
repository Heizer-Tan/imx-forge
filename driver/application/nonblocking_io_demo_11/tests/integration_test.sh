#!/bin/bash
set -e

DEVICE_PATH="${DEVICE_PATH:-/dev/nonblocking_io_demo}"
TEST_BIN="./poll_test"

echo "========================================="
echo "Nonblocking I/O Demo Integration Test"
echo "Device: $DEVICE_PATH"
echo "========================================="

if [ ! -e "$DEVICE_PATH" ]; then
    echo "ERROR: Device $DEVICE_PATH not found"
    echo "Please load the nonblocking_io_demo driver first"
    exit 1
fi

echo ""
echo "Test 1: Write string"
$TEST_BIN write "Hello, Nonblocking!"

echo ""
echo "Test 2: Read 20 bytes"
$TEST_BIN read 20

echo ""
echo "Test 3: Nonblocking write test"
$TEST_BIN nonblock "Test message"

echo ""
echo "========================================="
echo "All integration tests passed!"
echo "========================================="
