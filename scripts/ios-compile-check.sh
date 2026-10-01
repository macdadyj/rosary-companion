#!/usr/bin/env bash
# Compiles RosaryCore and the SwiftUI app target to arm64 iOS object code on Linux, without Xcode.
#
#   IOS_SDK=/path/to/iPhoneOS.sdk scripts/ios-compile-check.sh
#
# Any iPhoneOS SDK with Swift module interfaces works: the one inside xtool's
# ~/.swiftpm/swift-sdks/darwin.artifactbundle, or a standalone copy. Compiling (rather than only
# type-checking) also runs the SIL diagnostics: definite initialization, missing returns,
# exclusivity, and actor isolation. Nothing is linked or signed; `xtool dev` does that.
set -euo pipefail

SDK="${IOS_SDK:?Set IOS_SDK to an iPhoneOS.sdk directory}"
TARGET="${IOS_TARGET:-arm64-apple-ios17.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${IOS_CHECK_DIR:-${TMPDIR:-/tmp}/rosary-ios-check}"
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
  -wmo
)

# SwiftPM generates Bundle.module for targets with resources; stand in for it here.
cat > "$OUT/ResourceBundleStub.swift" <<'EOF'
import Foundation
extension Foundation.Bundle {
    static let module: Bundle = .main
}
EOF

echo "Compiling RosaryCore for $TARGET…"
find "$ROOT/Sources/RosaryCore" -name '*.swift' -print0 | xargs -0 swiftc "${COMMON[@]}" \
  -module-name RosaryCore -swift-version 6 \
  -emit-module -emit-module-path "$OUT/RosaryCore.swiftmodule" \
  -c -o "$OUT/RosaryCore.o" "$OUT/ResourceBundleStub.swift"

echo "Compiling Rosary (SwiftUI) for $TARGET…"
find "$ROOT/Sources/Rosary" -name '*.swift' -print0 | xargs -0 swiftc "${COMMON[@]}" \
  -module-name Rosary -swift-version 5 -I "$OUT" \
  -c -o "$OUT/Rosary.o"

echo "iOS compile check passed: $OUT/RosaryCore.o and $OUT/Rosary.o (arm64 Mach-O)."
