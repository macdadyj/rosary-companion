#!/usr/bin/env bash
# Type-checks RosaryCore and the SwiftUI app target for iOS on Linux, without Xcode.
#
#   IOS_SDK=/path/to/iPhoneOS.sdk scripts/ios-typecheck.sh
#
# Any iPhoneOS SDK with Swift module interfaces works: the one inside xtool's
# ~/.swiftpm/swift-sdks/darwin.artifactbundle, or a standalone copy. This does not link or
# sign anything; use `xtool dev build` for a real app bundle.
set -euo pipefail

SDK="${IOS_SDK:?Set IOS_SDK to an iPhoneOS.sdk directory}"
TARGET="${IOS_TARGET:-arm64-apple-ios17.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TYPECHECK_DIR:-${TMPDIR:-/tmp}/rosary-ios-typecheck}"
mkdir -p "$OUT/resource"

# The Linux toolchain's resource dir also contains Linux libdispatch headers (os/object.h,
# dispatch/) that shadow the SDK's, so give the compiler only the parts it needs.
HOST_RESOURCES="$(swiftc -print-target-info | python3 -c 'import json,sys; print(json.load(sys.stdin)["paths"]["runtimeResourcePath"])')"
for dir in shims clang apinotes; do
  ln -sfn "$HOST_RESOURCES/$dir" "$OUT/resource/$dir"
done

COMMON=(
  -target "$TARGET"
  -sdk "$SDK"
  -resource-dir "$OUT/resource"
  -I "$OUT/resource/shims"
  -module-cache-path "$OUT/module-cache"
  -parse-as-library
)

cat > "$OUT/ResourceBundleStub.swift" <<'EOF'
import Foundation
extension Foundation.Bundle {
    static let module: Bundle = .main
}
EOF

echo "Type-checking RosaryCore for $TARGET…"
find "$ROOT/Sources/RosaryCore" -name '*.swift' -print0 | xargs -0 swiftc "${COMMON[@]}" \
  -module-name RosaryCore -swift-version 6 -emit-module -emit-module-path "$OUT/RosaryCore.swiftmodule" \
  "$OUT/ResourceBundleStub.swift"

echo "Type-checking Rosary (SwiftUI) for $TARGET…"
find "$ROOT/Sources/Rosary" -name '*.swift' -print0 | xargs -0 swiftc "${COMMON[@]}" \
  -module-name Rosary -swift-version 5 -typecheck -I "$OUT"

echo "iOS type-check passed."
