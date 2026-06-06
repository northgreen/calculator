#!/bin/bash
set -euo pipefail
trap 'echo "ERROR: Build failed at line $LINENO"; exit 1' ERR

# ============================================================
# 1. NDK Path Detection
# ============================================================
NDK=""

if [[ -n "${ANDROID_NDK_HOME:-}" && -d "$ANDROID_NDK_HOME" ]]; then
    NDK="$ANDROID_NDK_HOME"
elif [[ -n "${ANDROID_HOME:-}" && -d "$ANDROID_HOME/ndk/latest" ]]; then
    NDK="$ANDROID_HOME/ndk/latest"
elif [[ -n "${ANDROID_SDK_ROOT:-}" && -d "$ANDROID_SDK_ROOT/ndk/latest" ]]; then
    NDK="$ANDROID_SDK_ROOT/ndk/latest"
elif [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
    # Pick newest version from ndk/*
    latest_ndk=$(ls -1d "$ANDROID_SDK_ROOT"/ndk/* 2>/dev/null | sort -V | tail -n1 || true)
    if [[ -n "$latest_ndk" ]]; then
        NDK="$latest_ndk"
    fi
fi

if [[ -z "$NDK" ]]; then
    echo "ERROR: Android NDK not found." >&2
    echo "Set ANDROID_NDK_HOME, ANDROID_HOME, or ANDROID_SDK_ROOT." >&2
    exit 1
fi

echo "Using NDK: $NDK"

# ============================================================
# 2. Host OS Detection
# ============================================================
HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$HOST_OS" in
    linux)  HOST_TAG="linux-x86_64" ;;
    darwin)
        # Detect Apple Silicon vs Intel
        ARCH="$(uname -m)"
        if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
            HOST_TAG="darwin-aarch64"
        else
            HOST_TAG="darwin-x86_64"
        fi
        ;;
    *)      echo "ERROR: Unsupported host OS: $HOST_OS" >&2; exit 1 ;;
esac

HOST_TAG="${ANDROID_NDK_HOST_TAG:-$HOST_TAG}"
echo "Host: $HOST_TAG"

# ============================================================
# 3. NDK Version Check (>= r26)
# ============================================================
PROPS_FILE="$NDK/source.properties"
if [[ ! -f "$PROPS_FILE" ]]; then
    echo "ERROR: Cannot find source.properties at $NDK" >&2
    exit 1
fi

NDK_VERSION=$(grep -E '^Pkg\.Revision\s*=' "$PROPS_FILE" | head -n1 | sed 's/.*=\s*//' | tr -d '[:space:]')
if [[ -z "$NDK_VERSION" ]]; then
    echo "ERROR: Cannot parse NDK version from source.properties" >&2
    exit 1
fi

MAJOR="${NDK_VERSION%%.*}"
if [[ "$MAJOR" -lt 26 ]]; then
    echo "ERROR: NDK r26+ required (found r$NDK_VERSION)" >&2
    exit 1
fi

echo "NDK version: r$NDK_VERSION"

# ============================================================
# 4. Toolchain Setup
# ============================================================
CLANGXX="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin/clang++"

if [[ ! -x "$CLANGXX" ]]; then
    echo "ERROR: clang++ not found at $CLANGXX" >&2
    exit 1
fi

# ============================================================
# 5. ABI Mapping
# ============================================================
declare -A ABI_TARGET=(
    [armeabi-v7a]="armv7a-linux-androideabi21"
    [arm64-v8a]="aarch64-linux-android21"
    [x86]="i686-linux-android21"
    [x86_64]="x86_64-linux-android21"
)

declare -A ABI_OUTPUT=(
    [armeabi-v7a]="ARM"
    [arm64-v8a]="ARM64"
    [x86]="x86"
    [x86_64]="x64"
)

# ============================================================
# 6. Build Function
# ============================================================
build_abi() {
    local abi_name="$1"
    local target="${ABI_TARGET[$abi_name]}"
    local output_dir="${ABI_OUTPUT[$abi_name]}"
    local output_path="../Calculator.Mobile/Android/libs/${output_dir}/libCalcManager.so"

    mkdir -p "$(dirname "$output_path")"

    echo ""
    echo "=============================="
    echo "Building for $abi_name -> $output_dir"
    echo "=============================="

    "$CLANGXX" \
        -std=c++20 \
        -fPIC \
        -shared \
        -stdlib=libc++_static \
        -D__ANDROID__=1 \
        --target="$target" \
        -o "$output_path" \
        CEngine/*.cpp Ratpack/*.cpp *.cpp \
        -I.

    echo "Output: $output_path"
}

# ============================================================
# 7. Main Loop
# ============================================================
SELECTED_ABI="${1:-all}"

if [[ "$SELECTED_ABI" == "all" ]]; then
    for abi in armeabi-v7a arm64-v8a x86 x86_64; do
        build_abi "$abi"
    done
else
    if [[ -z "${ABI_TARGET[$SELECTED_ABI]:-}" ]]; then
        echo "ERROR: Unknown ABI '$SELECTED_ABI'" >&2
        echo "Supported: armeabi-v7a arm64-v8a x86 x86_64 all" >&2
        exit 1
    fi
    build_abi "$SELECTED_ABI"
fi

echo ""
echo "Build complete."
