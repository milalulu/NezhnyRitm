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
/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Info.plist"
lipo -verify_arch arm64 "$app/NezhnyRitm"
# HealthKit entitlements must be embedded for resigners to discover them. This is
# an ad-hoc marker, NOT an Apple development/distribution signature.
if [[ "$configuration" == "HealthRelease" ]]; then
  codesign --force --sign - --entitlements App/Resources/HealthKit.entitlements "$app"
fi
stage="build/package-$output_name"
mkdir -p "$stage/Payload"
cp -R "$app" "$stage/Payload/NezhnyRitm.app"
(cd "$stage" && /usr/bin/zip -qry "../$output_name.ipa" Payload)
python3 scripts/verify_ipa.py "build/$output_name.ipa"
