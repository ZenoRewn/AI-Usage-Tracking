#!/bin/zsh
# Author: Zeno Ren
set -euo pipefail
cd "${0:A:h:h}"
zsh Scripts/build-app.sh
usage_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
usage_stem="Usage-Tracking-${usage_version}-arm64"
usage_app="$PWD/build/Usage Tracking.app"
for usage_binary in UsageTracking usage-tracking; do
  usage_arches="$(lipo -archs "$usage_app/Contents/MacOS/$usage_binary")"
  [[ "$usage_arches" == "arm64" ]] || { print -u2 "Expected arm64-only binary: $usage_binary"; exit 1; }
done
mkdir -p dist
usage_stage="$(mktemp -d "$PWD/build/release-stage.XXXXXX")"
trap 'rm -rf "$usage_stage"' EXIT
ditto --noextattr --noacl "$usage_app" "$usage_stage/Usage Tracking.app"
cp INSTALL.md "$usage_stage/INSTALL.md"
cp LICENSE "$usage_stage/LICENSE"
ln -s /Applications "$usage_stage/Applications"
codesign --verify --deep --strict "$usage_stage/Usage Tracking.app"
ditto -c -k --norsrc --noextattr --noacl --keepParent "$usage_stage/Usage Tracking.app" "$PWD/dist/$usage_stem.zip"
hdiutil create -volname 'Usage Tracking' -srcfolder "$usage_stage" -format UDZO -ov "$PWD/dist/$usage_stem.dmg"
(
  cd dist
  shasum -a 256 "$usage_stem.dmg" "$usage_stem.zip" > "$usage_stem-SHA256SUMS.txt"
)
print "Release assets: $PWD/dist/$usage_stem.{dmg,zip}"
print 'Author: Zeno Ren'
