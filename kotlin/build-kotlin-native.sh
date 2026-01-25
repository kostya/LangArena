#!/bin/bash
set -e

cd /src/kotlin

# Создаем директорию для native бинарников
mkdir -p build/native

# Сборка JAR
./gradlew fatJar --no-daemon -q

# Находим JAR
JAR_PATH="build/libs/benchmarks.jar"

# Параметры нативной сборки
NATIVE_FLAGS="--no-fallback --gc=serial -O3 -H:+UnlockExperimentalVMOptions -H:+AllowIncompleteClasspath"
EXTRA_FLAGS="${1:-}"  # Дополнительные флаги
OUTPUT_NAME="${2:-benchmarks}"  # Имя выходного файла

# Запускаем native-image
native-image $NATIVE_FLAGS $EXTRA_FLAGS -jar "$JAR_PATH" "build/native/$OUTPUT_NAME"