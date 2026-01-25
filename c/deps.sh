#!/bin/sh

# brew install gmp
# brew install uthash

if [ ! -d "cJSON" ]; then
  git clone https://github.com/DaveGamble/cJSON.git
  cd cJSON
  gcc -O2 -c cJSON.c
  cd -
fi

if [ ! -d "base64" ]; then
  git clone https://github.com/aklomp/base64.git
  cd base64
  
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
fi
