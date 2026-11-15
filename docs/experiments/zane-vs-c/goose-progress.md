# Closing the Goose gap: progress

Working state for the overnight run (user's request 2026-11-14: bring every
Zane / Goose gap down, worst first, all in one session). Kept current and
committed as each step lands, so it survives a context compaction.

## Setup

- Compiler: `/home/user/compiler`, branch `perf/zane-vs-goose` (pushed).
  zane-lang/compiler#377 (perf/zane-vs-c) is in the merge queue; its fixes are
  cherry-picked here.
- Port build: `env $SW sh docs/experiments/zane-vs-c/build.sh OUT` with
  `SW="ZANE_LOOP_REGS=1 ZANE_ASSIGN_MOVES=1 ZANE_VERSION_CALLS=1 ZANE_LENT_OWNERS=1 ZANE_FRAME_SHADOW=1 ZANE_MERGE_CHECKS=1 ZANE_ENDLESS=1 ZANE_SIZED_TBAA=1 ZANE_FRAME_SCOPES=1"`.
- Checks: `ZANE_CHECK=1 BIN ../test.js` from `zane/` (all 50), then
  `just test-compiler` in the compiler.
- Timing: `tri.py ROUNDS NAME=BIN…` (pinned to CPU 2, interleaved). Goose
  binaries: scratchpad `gb/goose_gcc`, `gb/goose_clang` (rebuild: `goose/`
  Makefile `prod`, Goose v2026.4).
- Profile: `prof/sampler.so` (LD_PRELOAD), `prof/symbolize.py`.
- Rule (memory `zane-perf-fix-in-compiler`): fix the compiler or library, not
  the port; the port may take Goose's structure where that is the design,
  not a dodge.

## Baseline (step 19, `step19-goose.json`)

Zane / Goose-clang 1.31 geomean. Worst: LZWDecode 6.2, Sort::Self 5.8,
CSV::Parse 4.0, Calculator::Ast 3.9, LZWEncode 3.2, LogParser 2.4, SHA256 2.4,
HuffDecode 2.3, BWTEncode 2.0, NGram 1.9, Binarytrees::Arena 1.8,
Maze::Generator 1.8, Words 1.7, Interpreter 1.6, Sort::Merge 1.5.

## Log

- Compiler branch also has `core` changes: `/home/user/core` branch
  `perf/zane-vs-goose` (pushed; add_repo zane-lang/core with push access).

### LZWDecode: 0.87 → 0.37 s (Goose/clang 0.14; 6.2× → 2.6×)

- Goose: every entry's bytes in one byte array, an entry a slice into it;
  no allocation per entry, appends are memcpy; the result is a byte list.
- Port now has that layout (`List<U8>` strings + starts/lengths) and gives
  back a `List<U8>` (a String only for the final checksum compare).
- A byte loop was 1.5 s (bounds + room check + count store per byte), so:
  compiler 4d88987 + core cc30133: `List.appendRange(from, start, count)`
  and `appendOwn(start, count)`, one `zane_list_append` copy, elements
  that own no blocks only (fixtures `listAppend`, `reject/appendOwners`).
- Left: ~3.2 MB/iteration of list growth copies under 1 MiB (doublings).
  Tried making a list past 256 KiB an oversized growable block at once:
  0.58 s, worse (a mapping per iteration); reverted.


### Sort::Self: 1.98 → 0.33 s (Goose/clang 0.34; 5.8× → 1.0×)

- Port sorted with C's `qsort` (comparator through a pointer) via the arena
  FFI; Goose's std `sort` is a pdqsort with a branchless Lomuto partition.
- Compiler + core: `List.sort()` for I32/I64/U8, runtime `zane_list_sort`,
  the same algorithm written out per width (fixtures `listSort`,
  `reject/sortFloats`). Port: copy the data, `sort()`, as Goose's port.

### CSV::Parse: 1.89 → 0.72 s (Goose/clang 0.47; 4.0× → 1.5×)

- Port parsed through the arena FFI's C reader with glibc `strtod` (52%
  of the time). Goose reads with its std `csv::each_record` and its own
  `parse_flt` over slices. Port now has that structure: one Zane pass over
  the bytes, each float field parsed where it lies.
- Compiler 1a23e7c + core 912d211: `zane_parse_f64` checks and folds
  the digits in one pass, with Clinger's fast path (≤19 digits, ≤2^53,
  ≤22 after the point: one exact division) before `strtod`;
  `String.parseFloat(start, count)` reads a range with no copy (fixture
  `parseRange`).
- Left: the scan is ~2 cycles/byte against Goose's ~1. Goose's reader
  runs a tight inner loop per field kind (`while` with 3 compares); Zane
  has only counted loops (`to`/`repeat`), no `while`/`break`, so the
  port toggles a quote flag per byte. A conditional loop is a language
  decision → question for the user.

### Calculator::Ast: 0.41 → 0.19 s (Goose/clang 0.11); Interpreter 0.48 → 0.425 (Goose 0.445)

- Goose's AST names are slices of the input (`p.input[start..pos]`), and
  its interpreter's dictionary is keyed by `const u8[:]`. Port had a
  String per name (`slice` → an allocation, a held block, a free, a
  Node move) and read bytes through the FFI `Buffer`.
- Port now: `Name { start; length }` in the nodes, the parser reads its
  String with `byteAt`, and the interpreter uses `SliceMap`
  (`arena/maps.zn`), StringMap's slots keyed by ranges of the one text.
- Left (Ast): `whitespace` is 35%, nearly all of it IRCE's safe-range
  setup for a loop that runs 0–1 times (`i!to(bound)` stands for a
  `while`). Without IRCE: 0.133 s.
- IRCE measured (`ZANE_NO_IRCE_BUILD=1`, and `ZANE_TRY_LLVM` for options;
  both experiment switches, out before any PR). Off: geomean 0.987, Ast
  0.70, BFS 0.84, but Matmul::T8 1.15, GameOfLife 1.17, BWTEncode 1.11.
  `-irce-min-eliminated-checks=40` (default 10): Ast 0.71 but Maze::AStar
  1.32, Template::Regex 1.28, Maze::BFS 1.24, geomean 1.021. No global
  setting wins; the default stays. A fix needs IRCE to skip a short
  search loop (an exit on loaded data) and keep counted ones.

### LZWEncode: 1.46 → 0.72 s (Goose/clang 0.51; 3.2× → 1.4×)

- Goose: every string a slice of one growing byte array (`new_string`,
  `concat` append there), its dictionary keyed by slices, hashed by
  lanes and compared by `memeq`. Port had String concatenation and a
  StringMap; now has that layout with `BytesMap` (`arena/maps.zn`) keyed
  by ranges of a `List<U8>`, sized for every code (≤65536).
- Byte-at-a-time hash and compare in Zane were 90%, so compiler 9b72f6d
  + core 0ca5428: `List.sameRange` (one memcmp) and `List.hashRange` (four
  lanes over 32-byte blocks, the tail read with fixed loads, no memcpy
  call); integers only (fixtures `listRanges`, `reject/rangeFloats`).
- Left: the hash (one per lookup, three per miss, as Goose) and cache
  misses on the slot and the stored key, which Goose has too.

### LogParser (2.4×): not attempted

- Port uses PCRE2 JIT through the arena FFI, as C's entry does (72% in
  JIT code). Goose has its own regex engine: literal-pair prefilters
  (`gs_find_pair`, `gs_scan_pair_tables`) and a DFA (`regex_find_end`).
  Closing it means a regex library for Zane: a library project, left.

### SHA256: 0.78 → 0.75 s (Goose/clang 0.33, gcc 0.57); open

- Port now as Goose's: `List<U8>` data, `Array<I32, 8>` hashes with
  wrapping 32-bit arithmetic (CRC32 shares the list).
- Goose/clang: unrolled by 8, `i % 8` folds to constants, the 8 hashes
  live in two xmm registers (SLP). Ours: unrolled by 4, hashes stay in a
  stack array, the index computed (`&0x1c`) and each lane a store→load.
  `-unroll-count=8` and `-unroll-runtime-epilog=true` (ZANE_TRY_LLVM) do
  not change it: the unrolled loop's start alignment is not known, so
  the index does not fold. Needs the IR read; left open.

### HuffDecode: 1.33 → 1.20–1.25 s (Goose/clang 0.58); open

- Port read the encoded bytes and pushed each decoded byte through the
  FFI `Buffer` (a foreign call per byte). Now as Goose's: `byteAt` on
  the String, a `List<U8>` out, given back as bytes (a String only for
  the final compare).
- Reading the node once before the left/right choice (so it can be a
  select) was slower, 1.34: the predicted branch beats the select on the
  load chain. Goose: branchless child offset from the bit, the 8-bit loop
  fully unrolled, a leaf flag byte, node pointers (no index scaling).
  Ours: `b!to(min(8, remaining))` is not unrolled, the leaf test reads two
  fields. Whole bytes in a constant `b!to(8)` loop (the last byte after)
  was slower too, 1.30. Left open.

### BWTEncode (2.0×): open

- Same rounds as Goose (prefix doubling to n). Goose sorts each round
  with its std `stable_sort`, an adaptive natural merge sort with a
  comparator over rank pairs: the suffix array is already in rank order
  from the round before, so its runs are long. Ours: two full counting
  sorts per round, as C. 32-bit counts: no change. Matching Goose needs a
  comparator (or key-pair) stable sort in core; left.

## Re-measure (step 20, `step20-goose.json`, before NGram)

Zane / Goose-clang 1.15 geomean (was 1.31), faster on 15; Zane /
Goose-gcc 0.94 (was 1.08), faster on 26. Worst vs clang now: LZWDecode
2.8, LogParser 2.5, SHA256 2.2, HuffDecode 2.1, BWTEncode 1.9, NGram 1.8,
Binarytrees::Arena 1.8, Ast 1.7, Words 1.7, CSV 1.6, Sort::Merge 1.6,
Maze::Generator 1.5, Template::Parse 1.5, LZWEncode 1.4.

### NGram: 0.57 → 0.244 s (Goose/clang 0.31; 1.8× → 0.8×)

- Port probed its IntMap 2 times per gram of the first string and 4 per
  gram of the second (get, put, has, get), each probe starting with a
  `rem` division, and read bytes through the arena FFI. Goose: one
  probe per gram (`update`), two for the second (`get_or_insert`, `get`).
- `IntMap` now has power-of-two slots from a Fibonacci hash and a
  one-probe `add` (as StringMap's); NGram as Goose's, with `byteAt`.

### Words: 0.88 → 0.54 s (Goose/clang 0.55; 1.7× → 1.0×)

- Goose's dictionary is keyed by word slices of the text; the port made a
  String per word (`slice` of an FFI Buffer). Now the text is a String
  and the words count in a `SliceMap` (new one-probe `add`).

### LZWEncode: 0.72 → 0.67 s; Template::Parse tried, reverted

- `BytesMap` keeps each entry in its slot (`ByteSlot`, three I32s): a
  lookup reads one slot rather than a slot, then the entry's start and
  length elsewhere. LZWEncode 0.72 → 0.67 (Goose 0.51).
- Template::Parse as Goose's (byte lists, the name a trimmed range looked
  up with `findIn`, values appended with `appendRange`): 1.10 s, no better
  than the String version (1.0–1.1; Goose 0.67). The time is the slot
  load missing cache in a 6 MB table (3×50000 keys); reverted. Copying
  `this.textBytes` into a local cost a whole-list copy per step (lists
  are values): read fields in place.

### Binarytrees::Arena (1.5–1.8×): open

- Same structure and node layout (three 32-bit values). Same page
  faults and system time; user time 0.73 vs 0.49 s, all in `build`
  (`sum` is even). Goose/clang's `build` handles depth 1 in place, both
  leaf children written with no call (half of all nodes), and pushes
  through a cursor; ours calls itself for every leaf. A codegen matter
  (recursion peeling); left.

### Sort::Merge (1.56×), Maze::Generator (1.35×): looked at, open

- Sort::Merge: Goose copies the range into temp with one `copy_into`
  and merges until a side runs out, then copies the left rest only.
  Goose/gcc is 1.63 s, near ours (1.77); clang's 1.13 likely comes from a
  branchless pick. Ours: nested branches whose arms read different
  checked indices. Would want a range-copy intrinsic and if-conversion
  across checked reads; left.
- Maze::Generator: same structure (neighbours as 32-bit indices, Goose's
  as compressed 32-bit references); `adjacentOpen` compiles to a tight
  unrolled count. Bound by the scattered cell loads; left.

## Re-measure (step 21, `step21-goose.json`)

Zane / Goose-clang 1.14 geomean (step 19: 1.31), faster on 17; Zane /
Goose-gcc 0.91 (1.08), faster on 28. Worst vs clang: LZWDecode 2.8,
LogParser 2.5, SHA256 2.3, HuffDecode 2.1, BWTEncode 1.9,
Binarytrees::Arena 1.8, Template::Parse 1.8, CSV 1.7, Ast 1.6,
GameOfLife 1.55, Sort::Merge 1.5. Single-test runs are noisy at ±10%.

## Decisions from the user (2026-11-15)

- No unbounded `while`: bounded loops are what lets Zane evaluate
  aggressively at compile time, and `guard` already breaks out of a
  loop. The port's `i!to(bound)` loops with an early exit are the
  intended shape; a loop's exit belongs in `guard`, not a new construct.
- No regex library or comparator sort in core yet (LogParser, BWTEncode
  stay as they are).
- The compiler work goes to a PR.

## Compiler PR

Opened zane-lang/compiler#378 (branch `perf/list-ranges-float-reads`) on 2026-11-15 with the compiler side of this work.
