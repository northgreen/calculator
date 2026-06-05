#!/bin/bash
# ============================================================
# pack.sh — 统一打包脚本
# 
# 用法:
#   ./build/pack.sh                       构建所有支持的格式
#   ./build/pack.sh --platform linux-x64  仅构建 x64
#   ./build/pack.sh --format zip          仅构建 zip
#   ./build/pack.sh --check               仅检查先决条件
# ============================================================

set -euo pipefail
trap 'echo "ERROR: Build failed at line $LINENO"; exit 1' ERR

# 切换到项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

# ============================================================
# 默认配置
# ============================================================
TARGET_PLATFORM="all"       # all, linux-x64, linux-arm64
TARGET_FORMAT="all"         # all, zip, snap
CHECK_ONLY=false

# ============================================================
# 参数解析
# ============================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --platform)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --platform requires a value (linux-x64, linux-arm64)"
                    exit 1
                fi
                TARGET_PLATFORM="$2"
                shift 2
                ;;
            --format)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --format requires a value (zip, snap)"
                    exit 1
                fi
                TARGET_FORMAT="$2"
                shift 2
                ;;
            --check)
                CHECK_ONLY=true
                shift
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --platform <platform>  目标平台 (linux-x64, linux-arm64, all)"
                echo "  --format <format>      输出格式 (zip, snap, all)"
                echo "  --check                仅检查先决条件"
                echo "  --help, -h             显示帮助信息"
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# ============================================================
# 先决条件检查
# ============================================================
check_prerequisites() {
    echo "=== 检查基础先决条件 ==="
    
    # .NET 9 SDK
    if ! command -v dotnet &> /dev/null; then
        echo "ERROR: .NET SDK not found. Install .NET 9 SDK first."
        echo "  https://dotnet.microsoft.com/download/dotnet/9.0"
        exit 1
    fi
    
    local dotnet_version
    dotnet_version=$(dotnet --version 2>/dev/null || echo "unknown")
    echo "✓ dotnet $dotnet_version"
    
    # g++ 编译器
    if ! command -v g++ &> /dev/null; then
        echo "ERROR: g++ not found. Install build-essential."
        echo "  Ubuntu/Debian: sudo apt install build-essential"
        exit 1
    fi
    
    local gpp_version
    gpp_version=$(g++ --version 2>/dev/null | head -n1 || echo "unknown")
    echo "✓ g++: $gpp_version"
    
    # snapcraft (仅当需要构建 snap 时)
    if [[ "$TARGET_FORMAT" == "all" || "$TARGET_FORMAT" == "snap" ]]; then
        if ! command -v snapcraft &> /dev/null; then
            echo "WARNING: snapcraft not found. Snap builds will be skipped."
            echo "  Install: sudo snap install snapcraft --classic"
        else
            local snap_version
            snap_version=$(snapcraft --version 2>/dev/null || echo "unknown")
            echo "✓ snapcraft: $snap_version"
        fi
    fi
}

# ARM64 交叉编译先决条件
check_arm64_prerequisites() {
    echo "=== 检查 ARM64 交叉编译先决条件 ==="
    
    if ! command -v aarch64-linux-gnu-g++ &> /dev/null; then
        echo "ERROR: aarch64-linux-gnu-g++ not found."
        echo "  Ubuntu/Debian: sudo apt install g++-aarch64-linux-gnu gcc-aarch64-linux-gnu"
        exit 1
    fi
    
    local arm_gpp_version
    arm_gpp_version=$(aarch64-linux-gnu-g++ --version 2>/dev/null | head -n1 || echo "unknown")
    echo "✓ aarch64-linux-gnu-g++: $arm_gpp_version"
}

# ============================================================
# 构建 C++ 引擎
# ============================================================
build_calcmanager() {
    local arch="${1:-x64}"
    echo "=== 构建 CalcManager for $arch ==="
    
    local build_script="src/CalcManager/build_linux.sh"
    if [[ ! -f "$build_script" ]]; then
        echo "ERROR: Build script not found: $build_script"
        exit 1
    fi
    
    # 调用构建脚本，捕获输出和退出码
    if bash "$build_script"; then
        echo "✓ CalcManager for $arch 构建成功"
    else
        local exit_code=$?
        echo "ERROR: CalcManager for $arch build failed with exit code $exit_code"
        exit $exit_code
    fi
}

# ============================================================
# .NET 自包含发布
# ============================================================
build_dotnet() {
    local runtime="${1:-linux-x64}"
    echo "=== .NET 自包含发布 for $runtime ==="
    
    dotnet publish src/Calculator.Skia.Gtk/Calculator.Skia.Gtk.csproj \
        -c Release \
        -r "$runtime" \
        --self-contained true \
        -o "dist/Calculator-$runtime/publish"
    
    echo "✓ .NET publish for $runtime complete"
}

# ============================================================
# 写入 VERSION 文件
# ============================================================
write_version_file() {
    local output_dir="${1:-dist}"
    echo "=== 写入 VERSION 文件 ==="
    
    local version="v0.0.0-dev"
    
    # 尝试从 git tag 获取版本
    if command -v git &> /dev/null; then
        # 优先使用 git describe --tags
        if version=$(git describe --tags --exact-match 2>/dev/null); then
            version="${version#v}"  # 移除前导 v
        elif version=$(git describe --tags --abbrev=0 2>/dev/null); then
            # 获取最新 tag 并附加当前提交信息
            local short_hash
            short_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
            version="${version#v}-${short_hash}"
        else
            # 无 tag，使用 git describe  fallback
            if version=$(git describe --long 2>/dev/null); then
                version="${version#v}"
            fi
        fi
    fi
    
    # 检查环境变量覆盖
    if [[ -n "${VERSION:-}" ]]; then
        version="$VERSION"
    fi
    
    echo "$version" > "$output_dir/VERSION"
    echo "✓ VERSION: $version"
}

# ============================================================
# ZIP 打包
# ============================================================
package_zip() {
    local runtime="${1:-linux-x64}"
    local arch_suffix="${2:-x64}"
    echo "=== ZIP 打包 for $runtime ==="
    
    local publish_dir="dist/Calculator-$runtime/publish"
    local zip_name="Calculator-linux-${arch_suffix}.zip"
    local zip_path="dist/$zip_name"
    
    if [[ ! -d "$publish_dir" ]]; then
        echo "ERROR: Publish directory not found: $publish_dir"
        exit 1
    fi
    
    # 创建扁平结构的 zip 文件
    # cd 到发布目录确保 zip 内不包含路径前缀
    (cd "$publish_dir" && zip -r "$PROJECT_DIR/$zip_path" .)
    
    echo "✓ 打包完成: $zip_path"
}

# ============================================================
# 准备 Snap 目录
# ============================================================
prepare_snap_dir() {
    echo "=== 准备 Snap 目录 ==="
    
    local snap_source_dir="build/Calculator/skia"
    mkdir -p "$snap_source_dir"
    
    # 复制 zip 文件到 snap 源目录
    for zip_file in dist/Calculator-linux-*.zip; do
        if [[ -f "$zip_file" ]]; then
            cp "$zip_file" "$snap_source_dir/"
            echo "✓ 复制 $(basename "$zip_file") 到 $snap_source_dir/"
        fi
    done
    
    # 复制 VERSION 文件
    if [[ -f "dist/VERSION" ]]; then
        cp dist/VERSION "$snap_source_dir/"
        echo "✓ 复制 VERSION 到 $snap_source_dir/"
    fi
}

# ============================================================
# Snap 包构建
# ============================================================
package_snap() {
    if ! command -v snapcraft &> /dev/null; then
        echo "WARNING: snapcraft not available. Skipping snap build."
        return 0
    fi
    
    echo "=== Snap 包构建 ==="
    
    # 确保 snap 源目录已准备
    if [[ ! -d "build/Calculator/skia" ]]; then
        echo "ERROR: Snap source directory not found. Run prepare_snap_dir first."
        exit 1
    fi
    
    # snapcraft 需要在 build 目录下运行
    (cd build && snapcraft)
    
    echo "✓ Snap 包构建完成"
    echo "  输出: build/*.snap"
}

# ============================================================
# 主构建流程
# ============================================================
main() {
    parse_args "$@"
    
    echo "============================================"
    echo "  Calculator Build & Pack"
    echo "  Platform: $TARGET_PLATFORM"
    echo "  Format:   $TARGET_FORMAT"
    echo "  Check only: $CHECK_ONLY"
    echo "============================================"
    
    # 1. 检查基础先决条件
    check_prerequisites
    
    if [[ "$CHECK_ONLY" == true ]]; then
        echo ""
        echo "=== 先决条件检查完成 ==="
        exit 0
    fi
    
    # 2. 根据平台检查 ARM64 交叉编译先决条件
    if [[ "$TARGET_PLATFORM" == "all" || "$TARGET_PLATFORM" == "linux-arm64" ]]; then
        check_arm64_prerequisites
    fi
    
    # 创建输出目录
    mkdir -p dist
    
    # 3. 编译 C++ 引擎
    echo ""
    echo "=== 阶段 1: 编译 C++ 引擎 ==="
    
    if [[ "$TARGET_PLATFORM" == "all" || "$TARGET_PLATFORM" == "linux-x64" ]]; then
        build_calcmanager "x64"
    fi
    
    if [[ "$TARGET_PLATFORM" == "all" || "$TARGET_PLATFORM" == "linux-arm64" ]]; then
        build_calcmanager "arm64"
    fi
    
    # 4. .NET 自包含发布
    echo ""
    echo "=== 阶段 2: .NET 自包含发布 ==="
    
    if [[ "$TARGET_PLATFORM" == "all" || "$TARGET_PLATFORM" == "linux-x64" ]]; then
        build_dotnet "linux-x64"
    fi
    
    if [[ "$TARGET_PLATFORM" == "all" || "$TARGET_PLATFORM" == "linux-arm64" ]]; then
        build_dotnet "linux-arm64"
    fi
    
    # 5. 写入 VERSION 文件
    echo ""
    echo "=== 阶段 3: 版本管理 ==="
    write_version_file "dist"
    
    # 6. ZIP 打包
    if [[ "$TARGET_FORMAT" == "all" || "$TARGET_FORMAT" == "zip" ]]; then
        echo ""
        echo "=== 阶段 4: ZIP 打包 ==="
        
        if [[ "$TARGET_PLATFORM" == "all" || "$TARGET_PLATFORM" == "linux-x64" ]]; then
            package_zip "linux-x64" "x64"
        fi
        
        if [[ "$TARGET_PLATFORM" == "all" || "$TARGET_PLATFORM" == "linux-arm64" ]]; then
            package_zip "linux-arm64" "arm64"
        fi
    fi
    
    # 7 & 8. Snap 构建
    if [[ "$TARGET_FORMAT" == "all" || "$TARGET_FORMAT" == "snap" ]]; then
        echo ""
        echo "=== 阶段 5: Snap 包构建 ==="
        
        prepare_snap_dir
        package_snap
    fi
    
    # 9. 输出汇总
    echo ""
    echo "============================================"
    echo "  构建完成!"
    echo "============================================"
    echo "输出目录: $(pwd)/dist"
    echo ""
    
    if [[ -d "dist" ]]; then
        echo "文件列表:"
        ls -lh dist/
    fi
    
    echo ""
    echo "至此结束，会话正常无需压缩"
}

main "$@"
