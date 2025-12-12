#!/bin/bash

# Script to open PIP project in Xcode
cd "$(dirname "$0")"

if [ -d "PIP.xcodeproj" ]; then
    echo "Opening PIP.xcodeproj in Xcode..."
    open PIP.xcodeproj
else
    echo "Error: PIP.xcodeproj not found!"
    exit 1
fi
