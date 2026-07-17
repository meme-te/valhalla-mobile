#!/bin/bash
# ============================================================================
# P1 iteration2: 共存SIGSEGV根治（protobufシンボル局所化）
#
# 手法（spec §11-2「二段構え」第2段）:
#   valhalla-wrapper.xcframework の各slice/archについて、valhalla側 protobuf
#   シンボルを「単一オブジェクトへ prelink してから private extern(local) 化」する。
#   これにより onnxruntime の protobuf と weak/global マージされなくなり、
#   別バージョン protobuf の ThreadSafeArena ABI 不整合による SIGSEGV を根治する。
#
#   absl は valhalla=lts_20240722 / onnx=lts_20240116 で別 inline namespace ＝
#   非衝突なので局所化対象は protobuf のみ（absl を巻き込まない＝重要）。
#
# 冪等性: 各 .a の初回 iter1 版を <a>.iter1bak に退避し、毎回そこから再生成する。
# ============================================================================
# pipefail は使わない: 成功時に protobuf外部残=0 で grep がマッチ0件→exit1 となり
# カウント用パイプが失敗扱いになるため。ld/ar/lipo/cp はパイプ外なので set -e で捕捉継続。
set -eu

XCF="${1:-$HOME/.company/dev/valhalla-rebuild-p0/valhalla-mobile/build/apple/valhalla-wrapper.xcframework}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SDK_SIM="$(xcrun --sdk iphonesimulator --show-sdk-version)"
SDK_IOS="$(xcrun --sdk iphoneos --show-sdk-version)"
MIN=16.4

echo "== P1 iter2 protobuf局所化 =="
echo "xcframework: $XCF"
echo "SDK: ios=$SDK_IOS  sim=$SDK_SIM  min=$MIN"

process_slice() {
  local slice_dir="$1" platform="$2" sdkver="$3"
  local a="$slice_dir/libvalhalla_all.a"
  [ -f "$a" ] || { echo "  skip: $a 無し"; return; }

  # 初回 iter1 版を退避（以後はここから冪等再生成）
  [ -f "$a.iter1bak" ] || { cp "$a" "$a.iter1bak"; echo "  backup: $a.iter1bak"; }

  local archs
  archs="$(lipo -archs "$a.iter1bak" 2>/dev/null || true)"
  [ -n "$archs" ] || archs="$(lipo -info "$a.iter1bak" 2>/dev/null | sed -E 's/.*architecture: //' )"
  echo "  slice=$(basename "$slice_dir")  platform=$platform  archs=$archs"

  local out_slices=()
  for arch in $archs; do
    local thin="$TMP/${arch}.a"
    if ! lipo "$a.iter1bak" -thin "$arch" -output "$thin" 2>/dev/null; then
      cp "$a.iter1bak" "$thin"   # 既にthin
    fi
    # protobuf定義シンボルのみ抽出（absl除外・U除外）
    nm -g "$thin" 2>/dev/null | grep -E ' [TDSBWV] ' | awk '{print $NF}' \
      | grep '6google8protobuf' | grep -v '4absl' | sort -u > "$TMP/pb_${arch}.txt"
    local pbn; pbn="$(wc -l < "$TMP/pb_${arch}.txt" | tr -d ' ')"
    # 冗長メンバー（date/tz二重バンドル）を除去して -all_load 時の重複を回避
    cp "$thin" "$TMP/w_${arch}.a"
    ar d "$TMP/w_${arch}.a" tz_alt.o ios.o 2>/dev/null || true
    # 単一objへ prelink（内部protobuf参照を先に解決）＋ protobuf を local 化
    xcrun ld -r -arch "$arch" -platform_version "$platform" "$MIN" "$sdkver" \
      -all_load "$TMP/w_${arch}.a" -o "$TMP/h_${arch}.o" \
      -unexported_symbols_list "$TMP/pb_${arch}.txt"
    ar cr "$TMP/h_${arch}.a" "$TMP/h_${arch}.o"; ranlib "$TMP/h_${arch}.a" 2>/dev/null || true
    # protobuf外部残の検証（0期待）。grep 0件=exit1 を set -e で拾わないよう +e で囲う
    set +e
    remain="$(nm -g "$TMP/h_${arch}.a" 2>/dev/null | grep -E ' [TDSBWV] ' | grep '6google8protobuf' | grep -v '4absl' | wc -l | tr -d ' ')"
    set -e
    echo "    arch=$arch  protobuf局所化=$pbn  外部残=${remain}（0期待）"
    out_slices+=("$TMP/h_${arch}.a")
  done

  # fat再構成して .a を置換
  if [ "${#out_slices[@]}" -gt 1 ]; then
    lipo -create "${out_slices[@]}" -output "$a"
  else
    cp "${out_slices[0]}" "$a"
  fi
  echo "    -> 置換完了: $a ($(lipo -archs "$a" 2>/dev/null || echo thin))"
}

# device slice（ios-arm64）
process_slice "$XCF/ios-arm64" "ios" "$SDK_IOS"
# simulator slice（ios-arm64_x86_64-simulator）
process_slice "$XCF/ios-arm64_x86_64-simulator" "ios-simulator" "$SDK_SIM"

echo "== 完了：全slice protobuf局所化済 =="
