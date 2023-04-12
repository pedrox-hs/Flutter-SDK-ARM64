#!/bin/bash

set -xeu
set -o pipefail

FLUTTER_VERSION=${1:-$FLUTTER_VERSION}

revision=$(curl -S https://raw.githubusercontent.com/flutter/flutter/$FLUTTER_VERSION/bin/internal/engine.version)
engine_version=$(git ls-remote --tags --sort="v:refname" https://github.com/flutter/engine.git | grep $revision | head -n1 | grep -o '[^/]*$' | cut -d'^' -f1)

if [ -z "$engine_version" ]
then
    echo "Version not found"
    exit 1
fi

echo $engine_version