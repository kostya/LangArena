#!/bin/sh
# Build the LangArena Zane port with the compiler built from the experiment
# branch (zane-lang/compiler perf/zane-vs-c in $COMPILER, default
# /home/user/compiler), run inside a copy of the v0.36 release toolchain so
# the runtime and linker are the release's (a bare dev zanec compiles the
# runtime with the system clang, which changes the code). Copies the result
# to $1 if given. Environment switches (ZANE_*) pass through to zanec.
set -e
COMPILER=${COMPILER:-/home/user/compiler}
T=$HOME/.zane/toolchains
[ -d "$T/dev" ] || cp -r "$T/v0.36" "$T/dev"
cp "$COMPILER/_build/default/bin/zanec/zanec.exe" "$T/dev/libexec/zanec"
# A changed runtime is not in the release's bundle, and zanec would compile
# it with `zig cc`, whose bitcode its LLVM cannot read, so no runtime body
# would be inlined. Bundle it as a release does (dev/release/common.py),
# its bitcode by the pixi environment's clang 21, once per runtime.
stamp=$(cat "$COMPILER"/runtime/*.[ch] | md5sum | cut -c1-32)
# Skip bundling only when this runtime's stamp is the only one: stamps left
# by older runs of this script do not say which runtime is bundled.
stamps=$(ls -A "$T/dev/share/runtime" | grep -c '^\.stamp-' || true)
if [ "$stamps" -ne 1 ] || [ ! -e "$T/dev/share/runtime/.stamp-$stamp" ]; then
  rm -f "$T"/dev/share/runtime/.stamp-*
  for o in "" --optimize; do
    env -u ZIG -u ZANE_RUNTIME_OBJECTS ZANE_CC="$T/dev/bin/zig-cc" \
      ZANE_BITCODE_CC="$COMPILER/dev/release/bitcode-cc" \
      ZANE_BITCODE_CLANG="$COMPILER/.pixi/envs/default/bin/clang" \
      "$T/dev/bin/zanec" --bundle-runtime "$T/dev/share/runtime" --target x86_64-linux-gnu $o
  done
  touch "$T/dev/share/runtime/.stamp-$stamp"
fi
cd "$(dirname "$(readlink -f "$0")")/../../../zane"
# Drop two harmless linker warnings without losing zane's exit status.
log=$(mktemp)
ZANE_COMPILER="$T/dev/bin/zanec" "${ZANE:-zane}" build >"$log" 2>&1 && ok=0 || ok=$?
grep -v 'LLD could not\|unable to find library' "$log" || true
rm -f "$log"
[ "$ok" -eq 0 ] || exit "$ok"
if [ -n "${1:-}" ]; then cp out/host/zane "$1"; fi
