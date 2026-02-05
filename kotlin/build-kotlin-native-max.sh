#!/bin/bash
set -e

cd /src/kotlin

mkdir -p build/native
./gradlew fatJar --no-daemon -q

JAR_PATH="build/libs/benchmarks.jar"

native-image \
  --no-fallback \
  -H:+UnlockExperimentalVMOptions \
  -H:+AllowIncompleteClasspath \
  --gc=serial \
  -O3 \
  -march=native \
  -H:+StripDebugInfo \
  -jar "$JAR_PATH" \
  "build/native/benchmarks-max"
