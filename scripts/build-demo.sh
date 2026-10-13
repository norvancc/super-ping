#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
swift build --disable-sandbox
BIN=$(swift build --show-bin-path)
mkdir -p .build/demo-frames docs/images
swiftc -parse-as-library -I "$BIN/Modules" \
    scripts/render-demo.swift Sources/PingAgent/Overlay.swift \
    Sources/PingAgent/PingAssets.swift Sources/PingAgent/PingAudio.swift \
    "$BIN/PingAgent.build/DerivedSources/resource_bundle_accessor.swift" \
    "$BIN"/PingCore.build/*.o -o .build/render-demo
.build/render-demo "$PWD/.build/demo-frames"
ffmpeg -hide_banner -loglevel error -y -framerate 20 -i .build/demo-frames/%03d.png \
    -filter_complex '[0:v]split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3' \
    -loop 0 docs/images/ping-demo.gif
cp .build/demo-frames/070.png docs/images/ping-wheel.png
