#!/bin/bash
set -e

cd /src/kotlin
mkdir -p build/native
./gradlew fatJar --no-daemon -q
JAR_PATH="build/libs/benchmarks.jar"

NATIVE_FLAGS="--no-fallback --gc=serial -O3 -H:+UnlockExperimentalVMOptions -H:+AllowIncompleteClasspath"
EXTRA_FLAGS="${1:-}"
OUTPUT_NAME="${2:-benchmarks}"

native-image $NATIVE_FLAGS $EXTRA_FLAGS -jar "$JAR_PATH" "build/native/$OUTPUT_NAME"
