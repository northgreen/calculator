#!/bin/bash

buildManager() {
	CALCMANAGER_PATH=bin/runtimes/linux-$2/native
	mkdir -p $CALCMANAGER_PATH

	echo "Building CalcManager for $2 - $CALCMANAGER_PATH"

	$1 \
		-std=c++20 \
		-D__LINUX__=1 \
		-fPIC \
		-shared \
		-static-libstdc++ \
		-Bstatic\
		-lgcc \
		-lstdc++ \
		-o $CALCMANAGER_PATH/libCalcManager.so \
		CEngine/*.cpp Ratpack/*.cpp *.cpp -I.
}

# 接受可选架构参数：x64 / arm / arm64 / all（默认）
ARCH="${1:-all}"

if [[ "$ARCH" == "all" || "$ARCH" == "x64" ]]; then
    buildManager "g++" "x64"
fi

if [[ "$ARCH" == "all" || "$ARCH" == "arm" ]]; then
    buildManager "arm-linux-gnueabihf-g++" "arm"
fi

if [[ "$ARCH" == "all" || "$ARCH" == "arm64" ]]; then
    buildManager "aarch64-linux-gnu-g++" "arm64"
fi
