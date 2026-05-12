#!/bin/bash
set -e

DEVICE_PATH="${DEVICE_PATH:-/dev/blocking_io_demo}"
TEST_BIN="./buffer_test"

echo "========================================="
echo "Blocking I/O Demo Integration Test"
echo "Device: $DEVICE_PATH"
echo "========================================="

if [ ! -e "$DEVICE_PATH" ]; then
    echo "ERROR: Device $DEVICE_PATH not found"
    echo "Please load the blocking_io_demo driver first"
    exit 1
fi

echo ""
echo "Test 1: Write string"
$TEST_BIN write "Hello, World!"

echo ""
echo "Test 2: Read 13 bytes"
$TEST_BIN read 13

echo ""
echo "Test 3: Producer-consumer test"
$TEST_BIN prodcons

echo ""
echo "========================================="
echo "All integration tests passed!"
echo "========================================="
