# Uno Calculator

The Uno Calculator is a port of the [Windows Calculator](https://github.com/microsoft/calculator) to C# and to the [Uno Platform](https://platform.uno) for iOS, macOS, Android, WebAssembly and Linux.

The app provides standard, scientific, and programmer calculator functionality, as well as a set of converters between various units of measurement and currencies.

The Uno Calculator will regularly follow with the Windows Calculator updates. You can get it from the [App Store](https://apps.apple.com/us/app/uno-calculator/id1464736591), [Play Store](https://play.google.com/store/apps/details?id=uno.platform.calculator), [in your browser](https://calculator.platform.uno), [Snap Store for Linux](https://snapcraft.io/uno-calculator) and of course the original calculator on the [Microsoft Store](https://www.microsoft.com/store/apps/9WZDNCRFHVN5).

[![Build Status](https://uno-platform.visualstudio.com/Uno%20Platform/_apis/build/status/Uno%20Platform/Calculator%20CI?branchName=uno)](https://uno-platform.visualstudio.com/Uno%20Platform/_build?definitionId=55&_a=summary)

 ![Calculator Screenshot](docs/Images/CalculatorScreenshot.png)

## Features
- Standard Calculator functionality which offers basic operations and evaluates commands immediately as they are entered.
- Scientific Calculator functionality which offers expanded operations and evaluates commands using order of operations.
- Programmer Calculator functionality which offers common mathematical operations for developers including conversion between common bases.
- Date Calculation functionality which offers the difference between two dates, as well as the ability to add/subtract years, months and/or days to/from a given input date.
- Calculation history and memory capabilities.
- Conversion between many units of measurement.
- Currency conversion based on data retrieved from [Bing](https://www.bing.com).
- [Infinite precision](https://en.wikipedia.org/wiki/Arbitrary-precision_arithmetic) for basic
  arithmetic operations (addition, subtraction, multiplication, division) so that calculations
  never lose precision.

## Getting started
Prerequisites:
- Your computer must be running Windows 10, version 1803 or newer.
- Install the latest version of [Visual Studio](https://developer.microsoft.com/en-us/windows/downloads).
  - Install the "Universal Windows Platform Development" workload.
  - Install the optional "C++ Universal Windows Platform tools" component.
  - Install the Xamarin Development component
  - Install the optional "Mobile C++ development tools" component.
  - Install the latest Windows 10 SDK.

> When using Visual Studio 2019, the `.vsconfig` feature will automatically prompt to install missing components.

- Get the code:
    ```
    git clone https://github.com/unoplatform/calculator
    ```

- Open [src\Calculator.sln](/src/Calculator.sln) in Visual Studio to build and run the Calculator app.

If building for WebAssembly fails, make sure to follow the notes in the `calculator/src/CalcManager/build.sh` file.

## Contributing
We ❤ contributions. The team encourages community feedback and contributions. Please follow our [contributing guidelines](CONTRIBUTING.md).

If Calculator is not working properly, please [file an issue](https://github.com/nventive/calculator/issues).

## Data / Telemetry
This project collects usage data and sends it to App Center to help improve the quality of the calculator.

## Reporting Security Issues
Security issues and bugs should be reported through the [GitHub security tab](https://github.com/nventive/calculator/security).

## 打包

本项目提供统一的打包脚本 `build/pack.sh`，支持构建 Linux x64/ARM64 zip 包和 Snap 包。

### 先决条件

- [.NET 9 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)
- g++ (C++20)
- snapcraft (可选，用于构建 Snap 包)
- aarch64-linux-gnu-g++ (可选，用于 ARM64 交叉编译)
- Android NDK r26+ (可选，用于构建 Android APK)
- JDK 17+ (可选，用于 Android 构建)

### 用法

```bash
# 构建所有支持的格式
./build/pack.sh

# 仅构建 Linux x64 zip 包
./build/pack.sh --platform linux-x64 --format zip

# 仅构建 Snap 包
./build/pack.sh --platform linux-x64 --format snap

# 检查先决条件
./build/pack.sh --check

# 查看帮助
./build/pack.sh --help

# 构建 Android arm64 APK
./build/pack.sh --platform android-arm64

# 构建 Android 全部 ABI APK
./build/pack.sh --platform android
```

### 输出产物

打包产物位于 `dist/` 目录：

| 平台        | 格式 | 输出文件                        |
| ----------- | ---- | ------------------------------- |
| Linux x64   | zip  | `dist/Calculator-linux-x64.zip`   |
| Linux x64   | Snap | `dist/uno-calculator_*.snap`      |
| Linux ARM64 | zip  | `dist/Calculator-linux-arm64.zip` |
| Linux ARM64 | Snap | `dist/uno-calculator_*.snap`      |
| Android arm64-v8a | APK | `src/Calculator.Mobile/bin/` |
| Android armeabi-v7a | APK | `src/Calculator.Mobile/bin/` |
| Android x86_64 | APK | `src/Calculator.Mobile/bin/` |
| Android x86 | APK | `src/Calculator.Mobile/bin/` |

### CI/CD

本项目使用 GitHub Actions 进行自动化构建：

- **Push/PR**: 自动触发 x64 zip/Snap 和 ARM64 zip 构建
- **Android**: 触发 arm64 Debug 构建和全部 ABI Release 构建（需配置签名 Secrets）
- **手动触发**: 可通过 GitHub Actions 页面手动触发构建
- **产物**: 构建产物保留 30 天

也可在 [GitHub Actions](https://github.com/unoplatform/calculator/actions) 中查看构建状态。
