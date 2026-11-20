#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
"${ZANE:-zane}" build
exec ./out/host/zane ../test.js "$@"
