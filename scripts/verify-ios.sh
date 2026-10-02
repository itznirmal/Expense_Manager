#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo "Install XcodeGen: brew install xcodegen" >&2; exit 1; }
xcodebuild -version
xcodegen generate

# Select an installed iPhone instead of assuming a simulator name or OS version.
simulator_id="${IOS_SIMULATOR_ID:-}"
if [ -z "$simulator_id" ]; then
  sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
  simulator_id="$(xcrun simctl list devices available -j | /usr/bin/python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
sdk = tuple(int(v) for v in sys.argv[1].split("."))
def version(runtime):
    return tuple(int(v) for v in runtime.split(".iOS-")[-1].split("-"))
for runtime in sorted((r for r in devices if ".iOS-" in r), key=version, reverse=True):
    if version(runtime) <= sdk:
        phones = [d for d in devices[runtime] if d["name"].startswith("iPhone") and d.get("isAvailable", True)]
        if phones:
            print(phones[0]["udid"])
            break
' "$sdk_version")"
fi
[ -n "$simulator_id" ] || { echo "Install an iOS simulator runtime in Xcode Settings > Components." >&2; exit 1; }

run_directory="build/verification/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$run_directory"
git rev-parse HEAD > "$run_directory/commit.txt"
xcrun simctl boot "$simulator_id" 2>/dev/null || true
xcrun simctl bootstatus "$simulator_id" -b

xcodebuild -project ExpenseManager.xcodeproj -scheme ExpenseManager \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath "$run_directory/ExpenseManager.xcresult" \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tee "$run_directory/xcodebuild.log"

echo "Verification results: $run_directory"
