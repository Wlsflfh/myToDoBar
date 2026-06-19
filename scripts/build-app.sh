#!/bin/zsh

set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
swift_bin="${SWIFT_BIN:-swift}"
scratch_path="${BUILD_PATH:-$root_dir/.build}"
output_dir="${OUTPUT_DIR:-$root_dir/dist}"
bundle_path="$output_dir/MyToDoBar.app"
identity="${CODESIGN_IDENTITY:--}"
mkdir -p "$output_dir"
staging_dir="$(mktemp -d "$output_dir/.mytodobar-build.XXXXXX")"
staging_bundle="$staging_dir/MyToDoBar.app"
trap '/bin/rm -rf -- "$staging_dir"' EXIT

"$swift_bin" build \
    --disable-sandbox \
    --scratch-path "$scratch_path" \
    --product MyToDoBar

bin_path="$("$swift_bin" build --disable-sandbox --show-bin-path --scratch-path "$scratch_path")"

mkdir -p "$staging_bundle/Contents/MacOS" "$staging_bundle/Contents/Resources"
/usr/bin/ditto "$bin_path/MyToDoBar" "$staging_bundle/Contents/MacOS/MyToDoBar"
/usr/bin/ditto "$root_dir/App/Info.plist" "$staging_bundle/Contents/Info.plist"
/usr/bin/codesign \
    --force \
    --sign "$identity" \
    --identifier com.jinriro.MyToDoBar \
    "$staging_bundle"

/bin/rm -rf -- "$bundle_path"
/usr/bin/ditto "$staging_bundle" "$bundle_path"

echo "$bundle_path"
