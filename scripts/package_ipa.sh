#!/bin/bash
set -euo pipefail
configuration="${1:-Release}"
output_name="${2:-NezhnyRitm}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
xcodebuild -project NezhnyRitm.xcodeproj -scheme NezhnyRitm \
  -configuration "$configuration" -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "build/$configuration" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
app="build/$configuration/Build/Products/$configuration-iphoneos/NezhnyRitm.app"
test -f "$app/NezhnyRitm"
lipo "$app/NezhnyRitm" -verify_arch arm64
# Capability markers for resigners, not an Apple installation signature.
if [[ "$configuration" == "HealthRelease" ]]; then
  codesign --force --sign - --entitlements App/Resources/HealthKit.entitlements "$app"
elif [[ "$configuration" == "FullRelease" ]]; then
  extension="$app/PlugIns/RhythmWidgets.appex"
  test -f "$extension/RhythmWidgets"
  lipo "$extension/RhythmWidgets" -verify_arch arm64
  codesign --force --sign - --entitlements Widgets/Widgets.entitlements "$extension"
  codesign --force --sign - --entitlements App/Resources/Full.entitlements "$app"
fi
stage="build/package-$output_name"
# All paths are scoped to generated build products.
rm -rf "$stage"
rm -f "build/$output_name.ipa"
mkdir -p "$stage/Payload"
cp -R "$app" "$stage/Payload/NezhnyRitm.app"
(cd "$stage" && /usr/bin/zip -qry "../$output_name.ipa" Payload)
python3 scripts/verify_ipa.py "build/$output_name.ipa"
