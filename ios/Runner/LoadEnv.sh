#!/bin/sh

# Script to load environment variables from .env file for iOS builds
# This script reads the .env file and exports variables for use in the build process

ENV_FILE="${SRCROOT}/../../.env"

if [ -f "$ENV_FILE" ]; then
  echo "Loading environment variables from .env file"

  # Read the .env file and export variables
  while IFS='=' read -r key value; do
    # Skip empty lines and comments
    if [[ -z "$key" || "$key" =~ ^#.* ]]; then
      continue
    fi

    # Remove quotes from value if present
    value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

    # Export the variable
    export "$key=$value"
    echo "Loaded: $key"
  done < "$ENV_FILE"
else
  echo "Warning: .env file not found at $ENV_FILE"
  echo "Please create a .env file with your GOOGLE_MAPS_API_KEY"
fi
