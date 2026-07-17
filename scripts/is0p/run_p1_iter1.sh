#!/bin/bash
# P1 iteration1: vcpkg依存をhidden visibilityで再ビルドし、absl/protobuf外部露出シンボルが激減するか検証
# baseline(P0-b default vis) = 4017 external absl/protobuf symbols
set -x
WS="$HOME/.company/dev/valhalla-rebuild-p0"
REPO="$WS/valhalla-mobile"
STATUS="$WS/p1i1_STATUS.txt"
STARTED=$(date "+%Y-%m-%d %H:%M:%S")
export VCPKG_ROOT="$REPO/vcpkg"
export PATH="$VCPKG_ROOT:$PATH"

fail() { echo "STATUS=FAILED stage=$1 at=$(date '+%H:%M:%S') started=$STARTED" > "$STATUS"; exit 1; }

cd "$REPO" || fail cd_repo

# hidden visibility triplet で clean 再ビルド (triplet hash変化でvcpkg依存フル再ビルド)
./build.sh ios clean || fail build

# 検証: 新xcframeworkのabsl/protobuf外部露出シンボル数 (baseline=4017)
LIB=$(find "$REPO/build/apple/valhalla-wrapper.xcframework" -name "*.a" | grep -i arm64 | grep -v simulator | head -1)
EXPOSED=$(nm -gU "$LIB" 2>/dev/null | grep -cE 'absl|protobuf')
# wrapper公開Cフリー関数が残っているか (シムが必要とする)
WRAP=$(nm -gU "$LIB" 2>/dev/null | grep -cE 'create_valhalla_actor|delete_valhalla_actor|_route')
XCF="$REPO/build/apple/valhalla-wrapper.xcframework"
SIZE=$(du -sh "$XCF" 2>/dev/null | cut -f1)
echo "STATUS=SUCCESS exposed_absl_protobuf=$EXPOSED (baseline=4017) wrapper_api_symbols=$WRAP xcframework_size=$SIZE lib=$LIB finished=$(date '+%H:%M:%S') started=$STARTED" > "$STATUS"
