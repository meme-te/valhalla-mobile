// swift-tools-version:5.8
import PackageDescription

// Use the local binary if true
let useLocalBinary = Context.environment["VALHALLA_MOBILE_DEV"].flatMap(Bool.init) ?? false

// Use the local binary
var binaryTarget: Target = .binaryTarget(
    name: "ValhallaWrapper",
    path: "build/apple/valhalla-wrapper.xcframework"
)

// IS-0P fork: 既定で自前ビルドの xcframework(trace_route + trace_attributes + protobuf局所化版)を参照する。
// これにより消費側(is-series)は VALHALLA_MOBILE_DEV を設定せずとも正しい版を
// pin して引ける(upstream v0.5.1=trace_route無しへのフォールバック地雷を排除)。
// ソースからビルドし直す時のみ VALHALLA_MOBILE_DEV=true で build/ のローカル版を使う。
//
// 配信先: 常駐Mac の Tailscale serve（**Tailnet内限定**・Funnel無し・2026-08-13 CEO方針で移行）。
//   - ポート 8444 は **Funnel対象外**を意図して選んでいる(443/8443/10000 は Funnel 可能ポート)。
//   - 実体 = 常駐Mac `~/tailnet-assets/`、静的サーバ = LaunchAgent `com.is-series.tailnet-assets`
//     (127.0.0.1:8790 のみ bind)、消えた時の復旧 = `~/scripts/funnel-health.sh` の ASSETS ガード。
//   - ⚠️ **Tailnet に居ないマシンでは解決できない**（＝ビルドできない）。これは意図した制約で、
//     コア成果物を「自分のみ」に保つための設計。CIを足す時はこの前提を先に解くこと。
//   - 旧: GitHub Releases(`valhalla-mobile-trace-v1`) は**誰でもDL可能**だったため既定から外した。
let binaryURL: String =
    "https://macbook-pro.tailbd464b.ts.net:8444/assets/valhalla/trace-attrs-v1/valhalla-wrapper.xcframework.zip"
let binaryChecksum: String = "435f33be38d0e8c1531ec3b6d3b47c705ebb49140bdc03d466fd108d6f133cdc"

if !useLocalBinary {
    binaryTarget = .binaryTarget(
        name: "ValhallaWrapper",
        url: binaryURL,
        checksum: binaryChecksum
    )
}

let package = Package(
    name: "ValhallaMobile",
    platforms: [
        .iOS("16.4")
        // .tvOS(.v13),
        // .watchOS(.v6),
        // .macOS(.v10_13)
    ],
    products: [
        .library(
            name: "Valhalla",
            targets: ["Valhalla"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/Rallista/valhalla-openapi-models-swift.git",
            .upToNextMinor(from: "0.3.0")),
        .package(
            url: "https://github.com/UInt2048/Light-Swift-Untar.git", .upToNextMajor(from: "1.0.4")),
        .package(url: "https://github.com/apple/swift-docc-plugin", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "Valhalla",
            dependencies: [
                "ValhallaObjc",
                "ValhallaWrapper",
                .product(name: "ValhallaConfigModels", package: "valhalla-openapi-models-swift"),
                .product(name: "ValhallaModels", package: "valhalla-openapi-models-swift"),
                .product(name: "Light-Swift-Untar", package: "Light-Swift-Untar"),
            ],
            path: "apple/Sources/Valhalla",
            resources: [
                .process("SupportData")
            ]
        ),
        .target(
            name: "ValhallaObjc",
            dependencies: ["ValhallaWrapper"],
            path: "apple/Sources/ValhallaObjc",
            linkerSettings: [.linkedLibrary("z")]
        ),
        binaryTarget,
        .testTarget(
            name: "ValhallaTests",
            dependencies: ["Valhalla"],
            path: "apple/Tests/ValhallaTests",
            resources: [.copy("TestData")]
        ),
    ],
    cLanguageStandard: .gnu17,
    cxxLanguageStandard: .cxx20
)
