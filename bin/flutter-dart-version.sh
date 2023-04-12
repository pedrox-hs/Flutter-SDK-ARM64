#!/bin/bash

set -xeu
set -o pipefail

FLUTTER_VERSION=${1:-$FLUTTER_VERSION}

if ! [[ "$FLUTTER_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]];
then 
    echo "Version number format invalid" 
    exit 1
fi

DART_VERSION=$(curl -s 'https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json' \
    | jq -r ".releases[]|select(.dart_sdk_version != null and .channel == \"stable\" and .version == \"$FLUTTER_VERSION\")|.dart_sdk_version")

if [ -z "$DART_VERSION" ]
then
    echo "Version not found"
    exit 1
fi

echo $DART_VERSION
