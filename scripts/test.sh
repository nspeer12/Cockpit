#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
PLUGINS="/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"
INTEROP="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

cd "$ROOT_DIR"

DYLD_LIBRARY_PATH="$INTEROP${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" \
DYLD_FRAMEWORK_PATH="$FRAMEWORKS${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}" \
swift test \
  -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
  -Xswiftc -plugin-path -Xswiftc "$PLUGINS" \
  -Xlinker -F -Xlinker "$FRAMEWORKS" \
  -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
  -Xlinker -rpath -Xlinker "$INTEROP"
