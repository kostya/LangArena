#!/bin/sh

# brew install gmp
# brew install uthash

mkdir -p deps

if [ ! -d "deps/cJSON" ]; then
  git clone https://github.com/DaveGamble/cJSON.git deps/cJSON
fi

if [ ! -d "deps/base64" ]; then
  git clone https://github.com/aklomp/base64.git deps/base64
fi

if [ ! -d "deps/yyjson" ]; then
  git clone https://github.com/ibireme/yyjson.git deps/yyjson
fi
