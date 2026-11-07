#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ "$(uname -s)" != "Darwin" ]; then echo "Build on macOS with Xcode Command Line Tools." >&2; exit 1; fi
xcrun clang++ -std=c++17 -O2 -Wall -Wextra -arch arm64 -mmacosx-version-min=12.0 -fobjc-arc -framework Cocoa -framework AVFoundation -x objective-c++ space_invaders.mm -o CatsSpaceInvaders-MChip
file CatsSpaceInvaders-MChip
printf '\nRun: ./CatsSpaceInvaders-MChip\n'
