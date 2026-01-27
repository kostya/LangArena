#!/bin/bash

# brew install re2

mkdir -p deps

if [ ! -d "deps/simdjson" ]; then
    mkdir -p deps/simdjson
    wget https://github.com/simdjson/simdjson/releases/download/v4.2.4/simdjson.h -O deps/simdjson/simdjson.h
    wget https://github.com/simdjson/simdjson/releases/download/v4.2.4/simdjson.cpp -O deps/simdjson/simdjson.cpp
fi

if [ ! -d "deps/base64" ]; then
  git clone https://github.com/aklomp/base64.git deps/base64
fi

if [ ! -f "deps/json.hpp" ]; then
  wget https://github.com/nlohmann/json/releases/download/v3.12.0/json.hpp -O deps/json.hpp
fi
