#!/bin/sh

mkdir -p target
sh fetch-deps.sh

if [ ! -f "target/simdjson.o" ]; then
  cd deps/simdjson
  g++ -O3 -march=native -c -std=c++20 simdjson.cpp
  cd -
  cp deps/simdjson/simdjson.o target/
fi

if [ ! -f "target/libbase64.o" ]; then
  cd deps/base64
  make clean
  ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
    echo "Building for x86_64 with AVX2..."
    AVX2_CFLAGS=-mavx2 SSSE3_CFLAGS=-mssse3 SSE41_CFLAGS=-msse4.1 SSE42_CFLAGS=-msse4.2 AVX_CFLAGS=-mavx make lib/libbase64.o
  elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    echo "Building for ARM64 with NEON..."
    CFLAGS="-arch arm64 -O3" NEON64_CFLAGS=" " make lib/libbase64.o
  else
    echo "Building generic for $ARCH..."
    make lib/libbase64.o
  fi
  cd -
  cp deps/base64/lib/libbase64.o target/
fi
