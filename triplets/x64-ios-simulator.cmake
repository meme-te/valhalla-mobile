set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME iOS)
set(VCPKG_OSX_SYSROOT iphonesimulator)

# Ensure C++20 standard is available
# P1隔離(is0p): vcpkg依存(absl/protobuf/boost等)をhidden visibilityでビルドし
# onnxruntime同梱のabsl/protobufとのシンボルinterpose(ThreadSafeArena SIGSEGV)を防ぐ
set(VCPKG_CXX_FLAGS "-std=c++20 -stdlib=libc++ -fvisibility=hidden -fvisibility-inlines-hidden")
set(VCPKG_C_FLAGS "-fvisibility=hidden")

# Set minimum iOS version to ensure C++20 standard library features
set(VCPKG_OSX_DEPLOYMENT_TARGET "16.4")