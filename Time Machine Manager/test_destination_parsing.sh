#!/bin/bash

echo "Testing destination info parsing..."
echo ""

# Get the raw output
output=$(tmutil destinationinfo 2>/dev/null)

echo "Raw output:"
echo "$output"
echo ""
echo "---"
echo ""

# Simulate Swift parsing
echo "$output" | while IFS= read -r line; do
    if [[ "$line" == *":"* ]]; then
        # Split by first colon
        key=$(echo "$line" | cut -d':' -f1 | xargs)
        value=$(echo "$line" | cut -d':' -f2- | xargs)
        echo "Key: '$key' -> Value: '$value'"
    fi
done
