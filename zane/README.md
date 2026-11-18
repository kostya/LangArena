# Zane

All 50 LangArena workloads, ported from the Crystal reference. The manifest
pins compiler **v0.40** and core **v0.14**, built from source (the `core`
package, from [`zane-lang/std`](https://github.com/zane-lang/std)).

## Run

Install the [Zane CLI](https://github.com/zane-lang/zane) and the PCRE2
development files (`libpcre2-dev` on Debian and Ubuntu), which the `arena`
package links, then:

```sh
cd zane
zane toolchain install v0.40
zane fetch
./test.sh                    # all test.js checksums
./run                     # full run.js workloads
./test.sh Graph              # case-insensitive substring filter
zane test                 # codec/support regression tests
python3 tests/runner.py    # executable protocol tests
```

Set `ZANE` to your CLI path if it is not on PATH. The scripts build an optimized
executable before running. For custom configurations, use
`./out/host/zane path/to/config.json [filter]`.

Checksum mismatches exit 1. Invalid configuration, unknown workloads, and
filters matching nothing exit 2. Output follows the suite's startup, result,
and summary protocol. Warmup mutations count exactly as in the reference;
the RNG resets between preparation/warmup and measurement.

## Structure

- `bin/zane`: command-line dispatch and runtime thread configuration.
- `lib/<workload>`: native algorithms and benchmark state, one family per package.
- `lib/codec`: compression test data and bit streams.
- `lib/arena`: configuration, RNG, checksums, containers, and C bindings.
- `test` and `tests`: regression checks.

The quicksort, mergesort, hash maps, priority queue, parsers, neural network,
graph/maze traversals, and four compression codecs are native Zane.
The parallel matrix variants spawn 4, 8, or 16 row workers and configure the
runtime pool before measurement.

## C boundary and layouts

C supplies APIs core does not have: JSON through yyjson,
Base64 through aklomp/base64 (the library C links, with the codec it picks
for the processor at run time), mutable byte storage, string byte access,
decimal formatting, file input and timing. CSV::Parse reads its fields and Sort::Self sorts in Zane, with core's `parseFloat(start, count)` and `sort`; LogParser and Template::Regex match with core's `regex` package. The `arena` package still links PCRE2 (the system `libpcre2-8`, as C does); only `test/codecs` uses it.
Foreign data handles own their allocations. Only the root's foreign `Host`
capability reads files, observes clocks, prints, or exits; computation
bindings have no mutable global state.

Graph connectivity, maze cells, and calculator AST links use indices into
native containers. Bulk integer data whose range is bounded by the workload
size is stored as core's 32-bit `I32`: graph and maze adjacency, BWT
suffix positions and ranks, sort inputs (including the `qsort` copy for
`Sort::Self`), binary-tree arena nodes, and priority-queue entries. Loop
counters, scalar indices, checksums, hashes, RNG state, the hash maps'
values (the calculator stores 64-bit results there), and Life's
eight-entry neighbor lists (measured slower as `I32`, since every read
widens) use core's 64-bit `Int`.
Byte workloads use a C-backed byte buffer. These layouts affect memory and
speed.
The reference's `Hash::SHA256` is a custom small hash; this implementation
preserves it rather than substituting cryptographic SHA-256. The reference
priority queue's exact sift/tie ordering is retained for traversal checksums.

## Docker

```sh
docker compose build base zane
docker compose run --rm zane ./test.sh
TEST=1 ruby benchmarks.rb Zane
PROD=1 ruby benchmarks.rb Zane
```

The image pins CLI v0.16 with its SHA-256 and installs compiler v0.40.
The suite records both versions. Source-size measurements include bindings
and exclude everything under `lib/arena/vendor`.

## Dependency

`lib/arena/vendor/yyjson.{c,h}` and `LICENSE` are from
[ibireme/yyjson](https://github.com/ibireme/yyjson), commit
`ebb8d7e5aaa51bea4edefb39ee73a235066b0023` (MIT).
`lib/arena/vendor/base64` is the library part of
[aklomp/base64](https://github.com/aklomp/base64), commit
`5d5074cb856b9a53fe64f04ddf47812a85f4fb5a` (BSD-2-Clause), unchanged except
for `lib/config.h`, which its Makefile generates: it enables the codecs C
builds. Its Makefile compiles each x86 codec with that codec's `-m` flag; the
`lib/arena/vendor/base64_*.c` wrappers do the same with a clang `target`
attribute, since `c.coda` has one set of flags per package.
Vendoring keeps the package's declarative C build self-contained.
