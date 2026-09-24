#!/bin/zsh
# Author: Zeno Ren
set -euo pipefail
cd "${0:A:h:h}"
preview_build_args=(--build-system native --scratch-path "$PWD/build/menu-preview-build")
swift build "${preview_build_args[@]}"
preview_bin_dir="$(swift build "${preview_build_args[@]}" --show-bin-path)"
preview_app="$PWD/build/Usage Menu Preview.app"
mkdir -p "$preview_app/Contents/MacOS" "$preview_app/Contents/Resources"
preview_objects=()
for preview_object in "$preview_bin_dir"/UsageTracking.build/*.o "$preview_bin_dir"/UsageCore.build/*.o; do
  case "$preview_object" in */main.swift.o|*/UsageTrackingApp.swift.o) continue;; esac
  preview_objects+=("$preview_object")
done
xcrun swiftc -parse-as-library -I "$preview_bin_dir/Modules" -I Sources/CSQLite \
  Scripts/MenuPreview.swift "${preview_objects[@]}" -lsqlite3 -o "$preview_app/Contents/MacOS/UsageMenuPreview"
cp -R Sources/UsageTracking/Assets/Brands "$preview_app/Contents/Resources/"
cat > "$preview_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!-- Author: Zeno Ren -->
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.zenoren.UsageTracking.MenuPreview</string>
<key>CFBundleName</key><string>Usage Menu Preview</string>
<key>CFBundleExecutable</key><string>UsageMenuPreview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.5.0</string>
<key>CFBundleVersion</key><string>10</string>
</dict></plist>
PLIST
codesign --force --sign - "$preview_app"
print "Built isolated fixture preview: $preview_app"
