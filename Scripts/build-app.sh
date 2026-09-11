#!/bin/zsh
# Author: Zeno Ren
set -euo pipefail
cd "${0:A:h:h}"
usage_swift_args=(-c release --arch arm64 -Xswiftc -gnone)
if [[ $# -gt 0 ]]; then
  print -u2 'Usage: Scripts/build-app.sh (Apple Silicon only)'
  exit 2
fi
swift build "${usage_swift_args[@]}"
usage_bin_dir="$(swift build "${usage_swift_args[@]}" --show-bin-path)"
mkdir -p "$PWD/build"
usage_stage_dir="$(mktemp -d "$PWD/build/.stage.XXXXXX")"
usage_app_dir="$usage_stage_dir/Usage Tracking.app"
mkdir -p "$usage_app_dir/Contents/MacOS" "$usage_app_dir/Contents/Resources"
cp "$usage_bin_dir/UsageTracking" "$usage_app_dir/Contents/MacOS/UsageTracking"
cp "$usage_bin_dir/usage-tracking" "$usage_app_dir/Contents/MacOS/usage-tracking"
cp Resources/Info.plist "$usage_app_dir/Contents/Info.plist"
cp -R Sources/UsageTracking/Assets/Brands "$usage_app_dir/Contents/Resources/Brands"
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$usage_app_dir/Contents/Resources/AppIcon.icns"
fi
cp THIRD_PARTY_NOTICES.md "$usage_app_dir/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp LICENSE "$usage_app_dir/Contents/Resources/LICENSE"
usage_signing_identity="${USAGE_SIGN_IDENTITY:--}"
usage_timestamp_args=(--timestamp=none)
if [[ "$usage_signing_identity" != "-" ]]; then usage_timestamp_args=(--timestamp); fi
codesign --force --sign "$usage_signing_identity" --options runtime "${usage_timestamp_args[@]}" "$usage_app_dir/Contents/MacOS/usage-tracking"
codesign --force --sign "$usage_signing_identity" --options runtime "${usage_timestamp_args[@]}" "$usage_app_dir"
codesign --verify --deep --strict "$usage_app_dir"
if [[ -d "$PWD/build/Usage Tracking.app" ]]; then
  mkdir -p "$PWD/build/previous"
  mv "$PWD/build/Usage Tracking.app" "$PWD/build/previous/Usage Tracking-$(date +%s)-$RANDOM.app"
fi
mv "$usage_app_dir" "$PWD/build/Usage Tracking.app"
rmdir "$usage_stage_dir"
print "Built: $PWD/build/Usage Tracking.app"
print "Author: Zeno Ren"
