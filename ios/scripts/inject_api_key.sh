#!/bin/bash

# Script to inject Google Maps API key from .env into Info.plist

# Path to .env file
ENV_FILE="${SRCROOT}/../../.env"
PLIST_FILE="${SRCROOT}/Runner/Info.plist"

# Read API key from .env
if [ -f "$ENV_FILE" ]; then
    API_KEY=$(grep "^GOOGLE_API_KEY=" "$ENV_FILE" | cut -d '=' -f2)

    if [ -n "$API_KEY" ]; then
        # Use PlistBuddy to set the API key
        /usr/libexec/PlistBuddy -c "Set :GOOGLE_MAPS_API_KEY $API_KEY" "$PLIST_FILE" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :GOOGLE_MAPS_API_KEY string $API_KEY" "$PLIST_FILE"

        echo "✓ Google Maps API key injected into Info.plist"
    else
        echo "⚠️  Warning: GOOGLE_API_KEY not found in .env file"
    fi
else
    echo "⚠️  Warning: .env file not found at $ENV_FILE"
fi
