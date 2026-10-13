#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
swift build --disable-sandbox
BIN=$(swift build --show-bin-path)
swiftc -parse-as-library -I "$BIN/Modules" scripts/verify-parity.swift \
  Sources/PingAgent/Overlay.swift Sources/PingAgent/PingAssets.swift Sources/PingAgent/PingAudio.swift \
  Sources/PingAgent/EmoteLibrary.swift Sources/PingAgent/ActionFailure.swift Sources/PingAgent/InputMonitor.swift \
  "$BIN/PingAgent.build/DerivedSources/resource_bundle_accessor.swift" "$BIN"/PingCore.build/*.o -o .build/verify-parity
.build/verify-parity "${1:-$PWD/.build/parity-evidence}"
