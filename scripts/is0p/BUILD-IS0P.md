# IS-0P 向け valhalla-mobile ビルド手順（trace_route facade ＋ protobuf 局所化）

このフォークは、株式会社ミモタイプの IS-0P（AI パッセンジャー）オンデバイス経路案内のために
`Rallista/valhalla-mobile` を fork し、以下2点を追加したものです。

1. **trace_route facade**（`src/wrapper` C++ ＋ `apple/Sources` Swift/ObjC++）
   — map-matching 結果（形状点付き）を返す `trace_route` を C facade / `ValhallaActor` /
   `ValhallaWrapper` / Swift `Valhalla` の4層に露出。ナビの現在地スナップに使う。
2. **protobuf シンボル局所化**（`triplets/*.cmake` ＋ 後処理 `run_p1_iter2.sh`）
   — onnxruntime（Parakeet STT）と同一プロセスで共存させると、別バージョンの
   protobuf（valhalla=lts_20240722 / onnx=lts_20240116）の ThreadSafeArena ABI 不整合で
   SIGSEGV する。valhalla 側 protobuf シンボルを private extern 化して根治する。

いずれも IS-0P 固有の要求であり、upstream への還元は想定しない（fork 専用ブランチ
`feat/is0p-trace-route` で保持）。

---

## 再現ビルド手順（macOS / Xcode）

前提: `ninja`・`pkg-config`（Homebrew）、Xcode コマンドラインツール。

### 1. from-source ベースビルド（`scripts/is0p/run_p0b.sh` 相当）
```bash
git submodule update --init --recursive        # valhalla 本体＋依存
git clone https://github.com/microsoft/vcpkg    # README 準拠 tag 2025.12.12
./build.sh ios clean                            # → build/apple/valhalla-wrapper.xcframework (約328MB)
```
この時点の xcframework は absl/protobuf 外部露出シンボル ≒ 4017 個で、onnx 共存時に SIGSEGV する。

### 2. protobuf 局所化（`scripts/is0p/run_p1_iter2.sh`）
```bash
scripts/is0p/run_p1_iter2.sh [xcframework パス]
# 既定 = build/apple/valhalla-wrapper.xcframework
```
- 各 slice/arch の `libvalhalla_all.a` について、valhalla 側 protobuf シンボルを
  単一オブジェクトへ prelink → private extern(local) 化する（absl は非衝突ゆえ対象外）。
- 冪等: 初回の `.iter1bak` を退避し毎回そこから再生成する。
- 結果: protobuf 外部露出 2091 → **0**（全 slice）。これで onnx 共存 SIGSEGV が根治する。

> `scripts/is0p/run_p1_iter1.sh` は hidden-visibility triplet 単独の検証段（それだけでは不足＝
> 局所化が必須と確定した経緯）。参考として同梱。

### 3. 成果物
- `build/apple/valhalla-wrapper.xcframework`（trace_route 付き・protobuf 局所化済み）
  — これを**自前 GitHub Release として配布**し、IS-0P（is-series）は SPM binaryTarget で
  opt-in 参照する。**xcframework 自体はこの git 履歴に入れない**（`.gitignore` で除外・共有リポ汚染回避）。

---

## ⚠️ 重要な落とし穴（SPM フォールバック事故）

`Package.swift` は SPM 解決時に環境変数 `VALHALLA_MOBILE_DEV=true` が**無い**と、
upstream remote の v0.5.1 xcframework（**trace_route 無し**）へフォールバックし、
`DerivedData/SourcePackages/artifacts/.../valhalla-wrapper.xcframework` に固定キャッシュされる
（`rm -rf DerivedData` だけでは直らない）。

- **このフォークをソースからビルドする時**は `export VALHALLA_MOBILE_DEV=true` を xcodebuild の前に必ず実行。
- **消費側（is-series）は事前ビルド版 xcframework を Release から binaryTarget で pin して引く**運用にすれば、
  この地雷を下流ビルドから排除できる（S3-b/S3-c の方針）。

---

## 由来
- 隔離検証ワークスペース: `~/.company/dev/valhalla-rebuild-p0`（P0-b/P1/P2 ログ・STATUS）
- 統合の型（SPM 共存）: `~/is-series-ios-coexist-poc`（onnx/sherpa/VVOX 共存リンク）
- P2 検証: coexist ハーネスで trace_route matched=true / SIGSEGV なし（arm64 sim）を実証済み（2026-07-17）
