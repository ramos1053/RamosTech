#!/bin/bash
#
# Test script to verify Time Machine commands work correctly
#

echo "=================================="
echo "Time Machine Command Test"
echo "=================================="
echo ""

echo "1. Testing tmutil status..."
tmutil status 2>/dev/null
echo ""

echo "2. Testing tmutil listlocalsnapshots..."
tmutil listlocalsnapshots / 2>/dev/null | head -5
echo ""

echo "3. Testing tmutil destinationinfo..."
tmutil destinationinfo 2>/dev/null | head -10
echo ""

echo "4. Testing disk space..."
df -h / | tail -1
echo ""

echo "5. Testing APFS snapshots..."
diskutil apfs listSnapshots / 2>/dev/null | head -15
echo ""

echo "=================================="
echo "Test Complete"
echo "=================================="
