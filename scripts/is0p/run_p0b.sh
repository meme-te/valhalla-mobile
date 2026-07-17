#!/bin/bash
# P0-b: valhalla-mobile from-source iOS baseline build (隔離前の素ビルド成立/衝突再現を実測)
# ログ=p0b_build.log / 完了マーカー=p0b_STATUS.txt
set -x
WS="$HOME/.company/dev/valhalla-rebuild-p0"
REPO="$WS/valhalla-mobile"
STATUS="$WS/p0b_STATUS.txt"
STARTED=$(date "+%Y-%m-%d %H:%M:%S")

fail() { echo "STATUS=FAILED stage=$1 at=$(date '+%H:%M:%S') started=$STARTED" > "$STATUS"; exit 1; }

# 1. 前提ツール
brew list ninja >/dev/null 2>&1 || brew install ninja || fail brew_ninja
brew list pkg-config >/dev/null 2>&1 || brew install pkg-config || true

cd "$REPO" || fail cd_repo

# 2. submodule (valhalla本体 + その依存) を取得。浅いクローンの取りこぼし防止に unshallow
git fetch --unshallow 2>/dev/null || true
git submodule update --init --recursive || fail submodules

# 3. vcpkg セットアップ (README準拠: tag 2025.12.12)
if [ ! -d "$REPO/vcpkg" ]; then
  git clone https://github.com/microsoft/vcpkg "$REPO/vcpkg" || fail vcpkg_clone
fi
git -C "$REPO/vcpkg" checkout 2025.12.12 || fail vcpkg_checkout
"$REPO/vcpkg/bootstrap-vcpkg.sh" || fail vcpkg_bootstrap
export VCPKG_ROOT="$REPO/vcpkg"
export PATH="$VCPKG_ROOT:$PATH"

# 4. iOS xcframework ビルド (3 triplet)
./build.sh ios clean || fail build_ios

# 5. 成果確認
XCF=$(find "$REPO" -maxdepth 4 -name "*.xcframework" -type d 2>/dev/null | head)
SIZE=$(du -sh "$XCF" 2>/dev/null | cut -f1)
echo "STATUS=SUCCESS xcframework=$XCF size=$SIZE finished=$(date '+%H:%M:%S') started=$STARTED" > "$STATUS"
