# Experiment: bring Zane as far below C as possible

An open-ended experiment: take the `zane-perf` port (76bc235) and push its
time against the C reference down as far as it goes, by port changes that
make it do what C does and, where the compiler is the reason, by prototype
compiler changes behind environment switches. Spec rules do not bind the
prototypes; where one departs from the spec, the step says so.

Earlier work and the issue list (R1–R8, B1–B3) are on the
`zane-perf-issues` branch, `zane/perf-issues/README.md`.

## How to build and measure

- Zane CLI v0.15, compiler **v0.36** (22397fc), core v0.10. The port's
  `zane.coda` is moved to `zane-version v0.36`.
- C: `make -j4 prod` in `c/` (gcc 13, `-O2`), needs `uthash-dev`.
- The compiler is built from `zane-lang/compiler` branch `perf/zane-vs-c`
  (`pixi run just build`). `build.sh` builds the port with it, run inside a
  copy of the v0.36 release toolchain: a bare dev `zanec` compiles the
  runtime with the system `clang` instead of the release's `zig cc`, which
  changes the program's code (HuffEncode 5.96G → 5.69G instructions and
  slower). Inside the release toolchain, the unchanged branch builds a
  binary byte-identical to the v0.36 release's.
- `ab.py A B` interleaves two Zane binaries and reports B / A per test.
- `measure.py` runs both binaries on `run.js`, interleaved, `--rounds N`
  times, and reports each test's minimum time and the geomean of Zane / C:

  ```
  python3 docs/experiments/zane-vs-c/measure.py --rounds 3 --out results.json
  ```

  It swaps the C/Zane order on every other round. The runs recorded up to
  step 18 predate that and ran C first in every round, so their Zane / C
  ratios may carry an order bias; from step 19 on, `tri.py` rotates the order.

- Timings come from a 4-core cloud container, so they are noisy (a few %);
  each number is the minimum of its rounds.

## Step 0: baseline

`baseline.md` (table) and `baseline.json` (every round's times), 3 rounds:
**geomean 0.934** (the earlier run on another machine: 0.93). Tests at 1.2× C
or slower here: BWTDecode 1.87, Brainfuck::Recursion 1.70, BWTEncode 1.54,
Matmul::T4 1.54 (threads; noisy), Brainfuck::Array 1.45, Json::ParseDom
1.33, Graph::DFS 1.31, Json::ParseMapping 1.30, NeuralNet 1.28, HuffDecode
1.27, LZWEncode 1.24, CacheSimulation 1.20.

Run to run, a test's time moves by up to 10% on this machine, so a change
is judged by `ab.py` (interleaved) and, where it can be, by Callgrind
instruction counts.

## Step 1: port changes toward C (dropped)

Three changes that make the port do what C does, measured with `ab.py`, 4
rounds, against the unchanged port:

| change | test | B / A |
| --- | --- | ---: |
| filter + jump table made once in `prepare`, as C | Brainfuck::Array | 1.09 |
| ranks as C's interleaved `(first, second)` pairs | BWTEncode | 1.03 |
| a leaf flag (C's `is_leaf`) + output reserved up front | HuffDecode | 1.17 |

None helped (the leaf flag grows a node from 32 to 40 bytes), so all three
were reverted. Two other port rewrites, Brainfuck ops as a variant case per
operation and LZWEncode building its string in place, only dodge compiler
issues (R8, R7) and were dropped in favour of fixing the compiler.

## Step 2: one call site for a loop's callee (R8), `ZANE_VERSION_CALLS=0`

**Design.** `Emit.versioned` emits a loop that indexes a list twice, a
long and a short copy, so IRCE can drop the long one's checks. A call in
its body then has two call sites, and LLVM's inliner, which gives a
function with one caller a large bonus, leaves a mid-sized callee out of
line (Brainfuck's `command`: cost 315, threshold 225). With the switch, a
loop that calls any function is emitted once (`lib/codegen/emit.ml`,
`calls_stay_single`).

**Results.** `instr.py`, all 50 tests (iterations / 10; Brainfuck runs its
warmup program 10000 times): Brainfuck::Recursion 0.596G → 0.560G (−6%),
`command` now inlined into `runOps`; every other test within 0.5%
(CSV, CacheSimulation, LogParser, Template, BWTEncode slightly lower).

## Step 3: move a held local at its last read (R7), `ZANE_ASSIGN_MOVES=1`

**Design.** The perf-issues R7 prototype (`Regions.assigned_moves`,
`lib/cgt/regions.ml`), moved onto v0.36 and made opt-in, plus one case it
lacked: when the last read of the held local is the `else` of a flag,
`let f = { …; if(c) { T }; f := c }` … `{ if(~f) { E } }`, the copy that is
last in T is also made a move, since the two branches are exclusive. Reads
before the `if` (LZWEncode's `dict:has(combined)`) come before the move.

**Results.** `perf-issues/repros/string-assign` plus a form 4 shaped as
LZWEncode (an `else` that reads `combined`), Callgrind, 1000000 rounds:

| form | off | on |
| --- | ---: | ---: |
| 1 `combined=…; current=combined` | 675.3M | 301.3M |
| 2 the same in an `if` | 675.3M | 300.3M |
| 4 `if/else`, else reads it | 592.0M | 284.3M |

Memcheck clean on form 4 and on `test.js` LZW. Compress::LZWEncode:
1.994G → 1.353G instructions (−32%); `ab.py` 4 rounds 2.238 s → 1.688 s
(C: 1.889 s). All 50 checksums OK.

## Step 4: the Json gap (open)

Json::ParseDom / ParseMapping are 1.30–1.33× C. Callgrind (10 iterations):
Zane runs 237M instructions against C's 208M, though fewer inside
`yyjson_read_opts` (126M vs 140M); the rest is `arena_json_get`'s
lookups and about 9M more `memcpy`. Simulated branch and cache misses are
about equal (1.00M vs 0.91M mispredicts), minor faults are equal (2654 vs
2438), and C built with clang is as fast as with gcc. Dropping the LLVM
options Zane starts with (`ZANE_LLVM_OPTIONS=`, keeps none) changed
nothing. Without hardware counters (no `perf` here), the remaining 15% of
wall time is not explained.

## Step 5: BWTDecode, and why every byte-oriented port is slow

Callgrind of the decode loop `index=next[index]; out!push(byte(input,
index))`: 20 instructions per byte, against C's 5. Core has no byte type,
so the port keeps bytes in `arena$Buffer`, a C struct behind a handle.
Each `push` stores a `uint8_t`, which may alias anything, so every
iteration reloads both handles from the frame and each Buffer's size,
capacity and data pointer. The same holds in every port that works on
bytes (BWT, Huffman, LZW, Base64, Arith, CRC32, the Brainfuck tape).

Side finding: `filled(Int(256), Int(0))` (arena's push loop) is unrolled
into 256 checked pushes, about 50 KB of code in `bwt$decode` alone.

## Step 6: a native byte type, `U8`

**Design.** Compiler (`perf/zane-vs-c`): a primitive `@primitives$U8`
lowered to LLVM `i8` (`Ty.I8`), with `==`, `<`, conversions to and from
`I64`/`I32` (`wrap` towards U8), literals 0–255, and three intrinsics:
`String:byteCount()`, `String:byteAt(i)` (a checked load of the text's
byte, lowered to `Array_at` like a list read) and `List<T>:text()`, a
String copied from a byte list (runtime `zane_text_bytes`). Core
(`zane-lang/core` branch `perf/zane-vs-c`): `U8`, `Int(U8)`, `U8.wrap`,
`String.byteCount/byteAt`, `String(List<U8>)`. The port's `zane.coda`
points at a local core checkout (`core v0.10 /home/user/core`) while this
runs.

Port: `codec.frequencies` and `bwt.encode/decode` read the String's bytes
and build a `List<U8>` instead of an `arena$Buffer`.

**Results.** `decode` 450M → 290M instructions (C: 264M), `frequencies`
143M → 77M. Compress::BWTDecode 4.392G → 3.932G (−10.5%; 3.890G with the
runtime bundled, step 7); BWTEncode
unchanged (its time is the suffix sort). All 50 checksums OK; compiler
tests and core's tests pass.

What is left in the decode loop is the output list: its count and block
are loaded from and stored to the frame on every push. LICM does not
promote them to registers because the loop's bounds check makes the push
conditionally executed (reproduced in a small IR file: without the check,
no count access stays in the loop).

## Step 7: the runtime bundle, and a correction

The dev toolchain is a copy of v0.36's, whose `share/runtime` bundles
the runtime compiled from v0.36's sources. Once the experiment branch
changed the runtime (step 6's `zane_text_bytes`), zanec no longer found it
in the bundle and compiled it with `zig cc`, whose bitcode its LLVM 21
cannot read, so no runtime body was inlined (Runtime_bodies): CacheSimulation
+10% instructions, Words +4.5%, CSV +2%, with the port unchanged.
`build.sh` now bundles the changed runtime as a release does
(`zanec --bundle-runtime`, bitcode by the pixi environment's clang 21
through `dev/release/bitcode-cc`), once per runtime. Step 6's totals are
restated with it: BWTDecode 4.392G → 3.890G, HuffEncode 1.433G → 1.273G and
ArithEncode 0.876G → 0.836G (both use `codec.frequencies`).

## Step 8: three switches revisited

`instr.py` over all 50 tests, each switch alone against the build without
switches, found two regressions, both fixed:

- `ZANE_ASSIGN_MOVES=1` made Brainfuck::Recursion +22% (0.596G → 0.725G).
  Its "taken once, so a `let`" rewrite also caught holds whose move a
  return had already made (`returned_moves`), which the later fold turns
  into a plain value with no arena at all; the rewrite left an empty arena
  around `ops!push(Op.loop(this!parse()))`, and each push moved the value
  through the runtime. The rewrite now applies only to a hold this pass
  gave its move. Recursion 0.596G again; LZWEncode keeps −32%.
- `ZANE_VERSION_CALLS=0` (any call keeps a loop single) cost SHA256 +3.5%
  and Maze a little: their loops call small functions with many callers,
  which LLVM inlines anyway, and lost IRCE's unchecked copy.
  `ZANE_VERSION_CALLS=1` keeps a loop single only when it calls a function
  with one call site in the program, the case where two copies cost LLVM's
  single-caller inline bonus: Recursion −6% as before, SHA256 and Maze
  unchanged.

`ZANE_LOOP_REGS=1` (new, `lib/codegen/emit.ml`): a loop whose pushes were
reserved up front (`Loop_shapes.looped_pushes`) reads the list's block once
before it and keeps its count in a local, storing the count back after each
push, so the push reloads nothing. LICM could not do it: the loop's bounds
checks make the push conditionally executed, which blocks its scalar
promotion. BWT's decode loop is now 13 instructions per byte; with U8,
Compress::BWTDecode went from 2.04× C to 0.99× (3 rounds, `measure.py`).

## Step 9: a timed run, and more byte ports

`measure.py`, 3 rounds, with `ZANE_LOOP_REGS=1 ZANE_ASSIGN_MOVES=1
ZANE_VERSION_CALLS=1` and the U8 ports of step 6: **geomean 0.917**
(baseline 0.934). BWTDecode 1.87 → 1.02, LZWEncode 1.24 → 0.86, LZWDecode
→ 0.72. Still 1.2× C or slower: Brainfuck::Array 1.51, Recursion 1.47,
Matmul::T8/T16 ~1.4 (threads; a direct run of T4 gives 1.5–1.9 s for both
languages run to run), Json 1.31/1.34, NeuralNet 1.32, BWTEncode 1.31, DFS
1.27, HuffDecode 1.25, Binarytrees::Arena 1.22, CacheSimulation 1.20.

More ports to `U8`, each against the build before it (`ab.py`, 4 rounds):

| change | test | instructions | time B / A |
| --- | --- | ---: | ---: |
| Brainfuck tape `List<U8>` (was `Buffer`) | Array (real program) | 27.6G → 28.1G | — |
| Huffman encode: String bytes in, `List<U8>` out | HuffEncode | 1.273G → 0.927G | 0.86 |
| Huffman decode, the same | HuffDecode | 2.389G → 2.472G | 1.31 |
| Huffman decode, input only | HuffDecode | | 1.11 |

The decode's inner loop is the same instructions in both builds and
Cachegrind's branch and cache simulation shows no difference (13.3% vs
12.1% mispredicted), so the 31% is something the simulator does not model;
without hardware counters it stays unexplained. Huffman's decode keeps its
`Buffer`; its encode uses U8. The Brainfuck tape stays `List<U8>`, which
is what C does (a `uint8_t` array).

## Step 10: frame slots and alias analysis (two switches, little effect)

Brainfuck::Array's interpreter loop reloads the command list, the jump
list and the tape (block, count, position) from the frame on every step:
the cold `zane_list_push` that grows the tape may, as far as LLVM knows,
write any slot of the frame, since the runtime can reach it. C's tape is a
local whose address escapes only to inlined code.

- `ZANE_FRAME_SCOPES=1` (`lib/codegen/frame_scopes.ml`): after the `-O2`
  pipeline, accesses at constant offsets from one base are grouped by the
  bytes they touch and each group gets an alias scope
  (`llvm.experimental.noalias.scope.decl` where the base is made); the
  runtime's list growth calls get their header's group. Then LICM and GVN
  run again. Tagging before the pipeline missed the calls, which reach the
  loop only by inlining `core`'s `push`. The command and jump lists' loads
  then leave the loop, but the tape's fields are written in the loop, and
  LLVM promotes a conditionally written location only when its object
  does not escape, which a frame does. Brainfuck::Array unchanged; Json
  −1.5% to −3.6% instructions, Spectralnorm +1.7%.
- `ZANE_SIZED_TBAA=1` (`lib/codegen/emit.ml`): one-byte scalars (Bool, U8)
  get a TBAA tag apart from wider ones, both children of the scalar tag,
  since a place is only read back as a type of the size it was written as.
  It did not keep Huffman decode's `tree.root` in a register (the reload
  there is register pressure, not aliasing).

## Step 11: what the remaining slow tests do differently

`hotasm.py TEST BIN` profiles one test in both languages with Callgrind
and prints each side's hottest functions and their hot instructions beside
the disassembly. Both get the same explicit warmup count: the C harness
reads a warmup of 0 as its default, a fifth of the iterations and at least
one, so a Zane run with warmup 0 against C compares unequal work (every
C-vs-Zane instruction ratio before this step that used warmup 0 overcounts
C by that much).

Same work, Zane / C:

| test | instructions | time | what differs |
| --- | ---: | ---: | --- |
| Json::ParseDom | 1.32 | 1.31 | text copied per parse; yyjson +8% under zanec's LLVM |
| NeuralNet | 1.31 | 1.32 | indices where C has pointers |
| CacheSimulation | 1.34 | 1.20 | strings allocated and freed per access |
| BWTEncode | 1.72 | 1.31 | data-dependent bounds checks; lists zeroed |
| HuffDecode | 1.72 | 1.25 | index chase and a branch where C has a pointer and `cmov` |
| Binarytrees::Arena | 0.82 | 1.17 | same code; unexplained |
| Graph::DFS | 0.87 | 1.27 | stack count kept in the frame |
| Brainfuck::Array (real program) | ~2.1 | 1.51 | interpreter state in the frame, checks |

- **Json.** `jsonParse(this.text)` deep-copies the String field
  (`copy … layout: %primitives$String` in the CGT, 11M instructions of
  memcpy) and hands the copy to C, whose parameter is a read-only view.
  The yyjson parser itself, the same C source, runs 151.5M instructions
  compiled by zanec's pipeline against 139.9M by gcc `-O2`, and the port
  reads each coordinate by three FFI calls (`arena_json_get`, 30M against
  C's 16M loop).
- **NeuralNet.** C's synapse holds `NeuralNetNeuron *source_neuron`; the
  port holds a 1-based `Int` into `neurons`. Each hop is then `dec`, a
  bounds check (`cmp`, `jae`) and a shift where C has one load: 13
  instructions per synapse in `feed` against C's 7, 20 against 13 in
  `update`. C also stores weight and previous weight as one `movups`.
- **CacheSimulation.** `String("item_")+String(n)` allocates twice per
  access, and the node's value string is replaced each hit: the runtime's
  `zane_alloc_held`, `zane_free`, `zane_region_at` (finding a block's
  region from its address) and memcpy take about 400M instructions
  against C's 120M of malloc and free, where C formats the key into a
  stack buffer.
- **BWTEncode.** The rank loop does six bounds checks per element, two
  indices against three lists that all have `n` elements, which C does not
  check at all; the indices come from data, so IRCE cannot drop them. Each
  round allocates five lists through `filled(n, 0)`: memset is 221M
  instructions against C's 53M (C mallocs its scratch arrays unzeroed;
  Callgrind counts a `rep stosb` byte as an instruction, so time pays
  less than that).
- **HuffDecode.** C walks pointers and picks the child with `cmovae`; the
  port walks 1-based indices (`dec`, `shl $5`, bounds check, load) and
  branches on the bit, then checks the same bound on both sides. A switch
  that sends every failed check of a function to one block
  (`ZANE_ONE_STOP=1`, `Emit.element`) lets LLVM make the choice a select,
  branch-free as in C, and HuffDecode gets 24% slower: without the
  prediction the CPU waits on the longer index-to-address chain at every
  bit. Off by default.
- **Graph::DFS.** Fewer instructions than C (1363M against 1575M) and
  fewer simulated misses and mispredicts, yet slower. The stack's count
  lives in the frame (`0xf8(%rdi)`): every pop loads, decrements and
  stores it, and the next push or pop loads it again, a chain through
  memory each step; C's `stack_top` is a register.
- **Binarytrees::Arena.** `build` and `sum` are instruction for
  instruction what C's are (Zane's count field is 32-bit, its `sum` turns
  the right call into a loop), 562M against 687M, with fewer simulated
  misses; 0.64 s against 0.55 s is not explained by the code.
- **Brainfuck::Array / Recursion** (steps 9–10): the tape's block, count
  and position, and in Recursion `ops`'s count, are reloaded from memory
  each step; each `ops[i]` and tape access is checked; Recursion
  dispatches twice (the variant's tag, then the command byte) where C
  switches once over its op type.

Page faults are not it: over full runs system time is near 0 on both
sides, and Zane faults less than C (Binarytrees::Arena 6445 vs 12383).

The two switches of step 10 over all 50 tests (instructions, against the
three kept switches): `ZANE_SIZED_TBAA=1` Maze::Generator −9.5%, Maze::BFS
−7.8%, Maze::AStar −6.7%; `ZANE_FRAME_SCOPES=1` on top, Distance::Jaro
−16%, Json −1.3% to −3.6%, Spectralnorm +1.7%.

## Step 12: a three-way wall-clock re-bench

`rebench3.py` runs three binaries on `run.js`, interleaved, and appends each
round to `rebench3.json`. This step used 5 rounds and takes each test's median
time. Wall time only; no Callgrind.

- **C:** `make -j4 prod`.
- **base:** `zane-perf` 76bc235 built with the v0.36 release, the port's
  `zane-version` moved to v0.36, no switches.
- **new:** this branch at fad9277 (the U8 ports), built by `build.sh` with
  compiler `perf/zane-vs-c` 082f244 and `ZANE_LOOP_REGS=1
  ZANE_ASSIGN_MOVES=1 ZANE_VERSION_CALLS=1`.

**Geomean: base 0.921× C, new 0.905× C** (new / base 0.982). At 1.2× C or
slower: 10 tests in base, 8 in new. LZWEncode, Maze::BFS and BWTEncode left
that list; Matmul::T4 joined it, at 1.23. The Claude Doc's chart shows the
new column.

These changed by more than 5%, and the new build's five times and the base
build's five times do not overlap:

| test | base × C | new × C | new / base |
| --- | ---: | ---: | ---: |
| Calculator::Interpreter | 0.38 | 0.24 | 0.65 |
| Maze::Generator | 0.82 | 0.57 | 0.70 |
| Maze::AStar | 0.98 | 0.71 | 0.72 |
| Maze::BFS | 1.20 | 0.88 | 0.73 |
| Compress::LZWEncode | 1.26 | 0.94 | 0.75 |
| Brainfuck::Recursion | 1.56 | 1.36 | 0.87 |
| Compress::BWTDecode | 1.15 | 1.06 | 0.91 |
| Compress::HuffEncode | 0.75 | 0.69 | 0.92 |
| Brainfuck::Array | 1.43 | 1.33 | 0.93 |
| Json::ParseMapping | 1.26 | 1.45 | 1.15 |

- **Gains the earlier steps explain:**
  - LZWEncode: step 3.
  - Brainfuck::Recursion: step 8.
  - BWTDecode and HuffEncode: steps 6–9.
- **Gains no step explains:** Maze and Calculator::Interpreter. Graph::AStar
  (0.92) and Graph::DFS (0.94) are faster too, but their times overlap.
  Step 11 counts Maze −7% to −10% instructions with `ZANE_SIZED_TBAA`, but
  that switch was off here. An A/B of one switch at a time would show which
  switch does it.
- **Json::ParseMapping, +15%:** a regression with no overlap between the
  two builds (base 0.269–0.288 s, new 0.306–0.332 s). Json::ParseDom moved
  +11%, with overlap. Its cause is not known yet. It needs explaining
  before any of the switches goes to `main`.
- **Times that jump:** Etc::Words, Template::Regex, Template::Parse and
  Etc::GameOfLife each come out at one of two levels, about 30% apart, in
  both builds (Template::Regex: 1.07 s or 1.72 s). Their medians differ by
  23–30% between the builds, but the ranges overlap almost fully, so this
  run says nothing about them. Etc::Sieve and Graph::BFS also jump, C
  included (C's Graph::BFS ran 0.81–1.38 s).
## Step 13: the three compiler fixes of step 11, timed

Each is a switch on `perf/zane-vs-c`, off by default, judged by wall time
(`ab.py`, interleaved rounds) against the step-9 set (`ZANE_LOOP_REGS=1
ZANE_ASSIGN_MOVES=1 ZANE_VERSION_CALLS=1`). All 50 checksums pass with
each on.

- **`ZANE_LENT_OWNERS=1`** (`Lower_calls.owner_path`, 40b806c). Json's
  copy came from the conversion `@primitives$String(this.text)`: a lent
  conversion (L11) reads a member where it is only when its place is
  rooted in plain values, and `State` is a reference type (it holds a
  `Json`), so the conversion was expanded and its `return` copied the
  String. The switch lets the place be a member of an owner a local
  holds, unless a spawned call may write it back (`snapshots`). Only
  `jsonbench$step` and `csvbench$step` change: Json::ParseDom −6%,
  ParseMapping −5%, CSV::Parse −4% (7 rounds). This does not account for step 12's +15% ParseMapping regression, which predates it.
- **`ZANE_FRAME_SHADOW=1`** (`lib/codegen/frame_shadow.ml`, ec31bb6). DFS's
  push goes through core's `push`, which LLVM inlines, so emit cannot keep
  the header in registers itself; this is an IR pass after O2. Each slot
  of a frame (a base an `llvm.assume dereferenceable` names) past the
  record that is only loaded and stored whole, always as one scalar type,
  gets a write-through copy in an alloca: filled where the frame is
  placed, stored with every store, filled again after any call given an
  address in the frame. Where a slot's address is stored (a deferred
  `.move` job keeps it, and may rewrite the list's block), the copy is
  filled again after every call the frame dominates. Loads read the copy,
  which SROA makes a register. 34 functions get copies; Graph::DFS −10%
  in each of three runs; Brainfuck::Recursion and Jaro −11% in one run
  and within noise in others.
- **`ZANE_MERGE_CHECKS=1`** (`lib/codegen/merged_checks.ml`, 897de93).
  The lists BWTEncode indexes together have the same length, but `indices`
  comes back from `byKey` (not inlined) and `ranks` is reassigned each
  round, so LLVM cannot prove it. Proving it is not needed: a failed check
  flushes output and exits, so a later check of the same index on the
  same straight path, with no call between, can be folded into the
  earlier one, which then compares with the smaller bound
  (`llvm.umin`). In BWTEncode's ranking loop `prior` is now checked once
  where it was checked three times; `index` keeps three checks, and two
  of the merged bounds are spilled and reloaded each time round.
  BWTEncode's instructions 395M → 374M, wall time −2%. (Its other costs
  are `byKey`, 37%, and the zeroing in `filled`, 19%.) A known loosening:
  output written by inlined code, without a call, between two merged
  checks is lost if the later check fails. LOOP_REGS now also reads a
  list's count before `zane_list_room`, which keeps it, so a filled list's
  count is known after the room is made.

Layout dominates many of these tests. HuffDecode's hot loop with
FRAME_SHADOW is two loads shorter and otherwise the same code, and runs
23% slower (1.45 s → 1.83 s); built with every loop aligned to 64 bytes
(`ZANE_LLVM_OPTIONS=-align-loops=64`), both builds run it in about 1.8 s
and the shadow is 2% faster, so 1.45 s was a lucky placement. Maze::BFS
(+7% twice) runs the same instruction count either way (1105M vs 1108M).
Aligning every loop is no fix: over all 50 tests it is 3.7% slower
(Jaro ×1.95). The CPU is an Emerald Rapids Xeon (model 207), so this is
not the JCC erratum.

With all three switches on, `ab.py` against the step-9 build over all 50
tests gives a geomean of 1.008, gains and placement swings cancelling
(HuffDecode +25%, LogParser +19%, Template::Parse +15% against
CacheSimulation −15%, GameOfLife −13%, CSV −9%); a `measure.py` run right
after gives Zane / C **0.879** (step 9: 0.917), but C's own times moved by
up to 5% between those runs, so the two are not comparable to that
precision.

## Step 14: the Json gap, by wall time

Json::ParseMapping, taken apart by running variants and timing them; no
Callgrind. `bench1.py ROUNDS TEST BIN...` interleaves binaries on one test,
pinned to one CPU, and gives each one's median; every number here is a
median of 10–20 rounds. C is `make prod` (gcc 13 `-O2`). Both sides
parse the same yyjson source (0.13.0, the C build's clone and the port's
`vendor/yyjson.c` are byte-identical) and link glibc's `malloc`. Minor
faults (6138 vs 6741) and system time (0.012 s each) are equal, so the
gap is user code.

**Where the time goes (v0.36, port at `zane-perf`).** A parse-only build
of each side (C: the coordinate loop skipped; Zane: `i!to(Int(0))`, the
checksum then fails but the time is kept):

| part, 100 iterations | C | Zane | gap |
| --- | ---: | ---: | ---: |
| parse (Zane's text copy included) | 0.191 s | 0.203 s | +0.012 s |
| reading the coordinates | 0.040 s | 0.082 s | +0.042 s |
| whole test | 0.231 s | 0.285 s | +0.054 s |

Reading the coordinates is three quarters of the gap. In the assembly,
C's coordinate loop (`JsonParseMapping_run`) makes no calls at all: gcc
inlines `yyjson_obj_get(coord, "x")` with the key a literal, so its
`strlen` is the constant 1 and its compare is one byte. The port's
`arena_json_get` (`lib/arena/ecosystem.c`) picks the key as
`keys[axis]`, so the inlined `yyjson_obj_get` calls `strlen@plt` once and
`bcmp@plt` for each key it passes: 3 `strlen` and 6 `bcmp` calls per point,
behind 3 calls to `arena_json_get` that LLVM does not inline into
`jsonbench$step` (the C is linked into the module before the pipeline,
`-O2 -Xclang -disable-llvm-passes`, so the inliner saw it and declined).
`arena_json_parse` also walks the array once to fill an array of element
pointers, which the reads then walk again; C walks the parsed document
(about 6 MB, more than L2) once, inside its `yyjson_arr_foreach`.

`json/harness.c` repeats C's loop body outside the arena, with variants
for each of those shapes. The copy of the 2.3 MB text into a fresh buffer
costs 0.25–0.4 ms of a 2.1 ms iteration there, and yyjson built by clang
18 `-O2` parses as fast as by gcc. The harness overstates the port's
second walk and its list (glibc's `realloc` of a growing list faults pages
each iteration; Zane reuses the list's span), so the split above is from
the real binaries.

**Port change: the binding reads as C does.** `arena_json_get` now keeps a
cursor: the next index is one step on (`unsafe_yyjson_get_next`), any
other is found from the start, and the pointer array is gone. Each key is
a literal (`axis == 0 ? yyjson_obj_get(v, "x") : …`), as in C. The cursor
alone on v0.36: ParseMapping −5%, ParseDom −6%.

**Results** with compiler `perf/zane-vs-c` 897de93 (`build.sh`), port at
this step; Zane / C, medians of 15 rounds:

| build | ParseMapping | ParseDom |
| --- | ---: | ---: |
| switches off | 1.24 | 1.18 |
| switches off, binding | 1.05 | 1.02 |
| step-9 set | 1.23 | 1.21 |
| step-9 set, binding | 1.05 | 1.03 |
| step-9 set + `ZANE_LENT_OWNERS=1` | 1.15 | 1.15 |
| step-9 set + `ZANE_LENT_OWNERS=1`, binding | **1.00** | **0.96** |

So the binding is worth about 15%, `LENT_OWNERS` (no text copy) about 5%,
and with both the Json tests run as fast as C. All three Json checksums
pass.

**Step 12's +15% ParseMapping regression does not reproduce.** Pinned and
interleaved, the same port built by v0.36 (0.286 s), by the branch with
its switches off (0.280 s) and with the step-9 set (0.284 s) are within
noise of each other; the step-9 set with `LENT_OWNERS` is faster (0.271
s). Step 12's runs were unpinned, on all four CPUs.

**Whole-suite check of the branch (wall time).** `ab.py`, 4 rounds,
unpinned:

- `zane-perf` port, v0.36 against the branch with every switch off
  (`step14-ab-v036-vs-branch-off.md`): geomean 1.027. Two branch changes
  apply with the switches off: f577873's `moved_here` condition in the
  default assign-moves pass, and the U8 runtime function, which makes
  `build.sh` bundle the runtime itself.
- This step's port, switches off against the step-9 set with
  `LENT_OWNERS` (`step14-ab-off-vs-switches.md`): geomean 1.007.

The tests that came out slowest (Graph::AStar +28%/+32%, Maze::AStar
+24%, Calculator::Interpreter +26%/+19%), run again with `bench1.py`, 8
rounds pinned, over all five builds: every median is within 7% of
v0.36's, and every build's range overlaps the others'. Graph::AStar's
switches-off build was 0.988 s in one A/B and 0.733 s in the other. No
regression stood out from the noise, so nothing on the branch was
reverted. Template::Regex, GameOfLife and Words keep step 12's two levels.

**All 50 tests against C** (`measure.py --rounds 5`, best of 5,
`step14.md`, `step14.json`), the step-9 set with `LENT_OWNERS` and this
step's port: **geomean 0.880**. At 1.10× C or slower: Brainfuck::Array
1.46, Brainfuck::Recursion 1.44, BWTEncode 1.29, Graph::DFS 1.27,
NeuralNet 1.25, HuffDecode 1.25, Matmul::T16/T4/T8 1.19/1.17/1.17,
CacheSimulation 1.18, Sort::Merge 1.16, Etc::TextRaytracer 1.12,
Sort::Quick 1.12, Matmul::Single 1.10.

## Step 15: the Brainfuck gap, by wall time

Brainfuck::Array 1.41× C and Brainfuck::Recursion 1.41× (`bench1.py`, 6
rounds pinned, step 14's best build). Compiler `perf/zane-vs-c` 53f09ab.

**The assembly.** C's `BrainfuckArray_execute_program` keeps pc, tape
pointer, position, size and result in registers and dispatches every
command, brackets included, through one jump table: 12 instructions for a
`+`. Zane's `runArray` loop: 22. It loads the tape's items, count and
position from the frame for every command, and the commands list's count
and items too; tests `[` and `]` with two compares before a jump table of
the rest; checks `commands[pc]` and `bytes[position]`; and counts a second
counter down, `step!to(Int(9223372036854775807))`, the port's way to write
C's `while`, since core's only loop is the counted `to`.

**Pricing each difference in C first** (`brainfuck/harness.c`: C's
interpreter with the port's differences switched on one at a time, gcc
`-O2`, 3 runs): checks +33%, the two bracket compares +20%, the second
counter +21%, 8-byte commands and jumps +14%, the write-through stores
nothing. They do not add: all of them together is 1.35×, and taking any one
away from that makes it slower (1.40–1.76×). An interpreter's dispatch is
that sensitive to its branches' placement, so each difference was then
measured in Zane.

**In Zane** (Zane / C, medians of 6 pinned rounds; the step-9 set with
`LENT_OWNERS` under each row):

| build | Array | Recursion |
| --- | ---: | ---: |
| step 14's best | 1.41 | 1.38 |
| `ZANE_FRAME_SHADOW=1` | 1.36 | 1.39 |
| shadow, `ZANE_ENDLESS=1` | 1.10 | 1.12 |
| shadow, `ENDLESS`, `ZANE_NO_CHECKS=1` (unsound) | 0.88 | 1.01 |
| shadow, `ENDLESS`, `ZANE_NO_CHECKS=stride:1` (tape only) | 0.97 | 0.96 |
| shadow, `ENDLESS`, `ZANE_NO_CHECKS=stride:8` (commands, jumps) | 1.16 | 1.05 |
| shadow, port reads the cell where C does | 1.13 | 1.21 |
| shadow, `ENDLESS`, port reads the cell where C does | 1.11 | 1.24 |

- **`ZANE_FRAME_SHADOW`** (step 13) keeps the tape's fields in registers
  here, since `arrayCommand` is inlined and the tape is a local; −4% on
  Array. It keeps writing them through to the frame, which the harness
  says costs nothing.
- **`ZANE_ENDLESS=1`** (new, `emit.ml`): a `repeat` whose count is a
  constant of at least 2^62 is not tested. Going round that often takes
  centuries, so only a loop its body leaves ends; it departs from the spec,
  which stops the loop after its count. It removes one fused `dec`/`je` per
  command and is worth 19% on both tests (Recursion's `runLoop` uses the
  same idiom). The loop's "search" branch weight is not the reason:
  `ZANE_ENDLESS=2`, the test kept without the weight, changes nothing.
  Graph and Maze use the idiom too, around loops with more work in them;
  all six are unchanged within noise.
- **The checks are the rest.** `ZANE_NO_CHECKS` (new, unsound, for
  pricing only) drops every list index check, or those of `stride:N`-byte
  elements. The tape's checks, one per command, are what costs: without
  them both tests are faster than C.
- **Port change: read the cell only where C does.** `command` and
  `arrayCommand` began with `value Int=Int(this.bytes[this.position])`
  for every command, `<` and `>` included, which in C never touch the
  tape; a checked read may stop the program, so LLVM cannot sink it into
  the arms that use it. Now `+`, `-` and `.` read it themselves. With
  it, `runArray`'s dispatch is one jump table over all seven commands, as
  C's switch is. Alone it is worth as much as `ENDLESS`; the two together
  are no faster than either.

What is left in `runArray`'s loop with both: a `+` is 20 instructions
against C's 12. The extra ones are the exit test `pc > count` followed by
the check `pc - 1 <u count` (two compares of nearly one bound), the tape
check `position - 1 <u count`, and a `mov` that zero-extends the 32-bit
list count before each compare.

**All 50 tests with every sound switch on.** `LOOP_REGS`,
`ASSIGN_MOVES`, `VERSION_CALLS`, `LENT_OWNERS`, `FRAME_SHADOW`,
`MERGE_CHECKS`, `ENDLESS`, `SIZED_TBAA` and `FRAME_SCOPES`; off:
`ONE_STOP` (HuffDecode +24%, step 11), `NO_CHECKS` (unsound),
`LLVM_OPTIONS` (unset keeps every option). Compiler 53f09ab, port at this
step; all 50 checksums pass.

- Against C (`measure.py --rounds 5`, `step15.md`, `step15.json`):
  **geomean 0.863** (step 14's run with the step-9 set and `LENT_OWNERS`:
  0.880). At 1.10× C or slower: HuffDecode 1.65, NeuralNet 1.28,
  Sort::Merge 1.23, Brainfuck::Recursion 1.22, Matmul::T16 1.19,
  Brainfuck::Array 1.14, Sort::Quick 1.14, TextRaytracer 1.13,
  CacheSimulation 1.13, BWTEncode 1.13, Matmul::T8 1.12.
- Against the step-9 set with `LENT_OWNERS` on the same port (`ab.py`, 4
  rounds, `step15-ab-base-vs-all.md`): geomean 0.992. Sieve −22%,
  GameOfLife −18%, Graph::DFS −14%, Matmul::Single −12%; HuffDecode
  +29%, Template::Parse +23%, Binarytrees::Obj +17%. Pinned (`bench1.py`,
  6 rounds), Template::Parse and Binarytrees::Obj are within noise and
  HuffDecode is not: 1.14 s → 1.41 s. Without `FRAME_SHADOW` (everything
  else on) it is 1.07 s, so the shadow is the cause, as in step 13, which
  found the loop two loads shorter and placed worse. The Brainfuck tests
  are the same in both builds here (Array 1.00, Recursion 0.99): the cell change is in the
  base too, and `ENDLESS` and the shadow add nothing to it.

## Step 16: why `ZANE_FRAME_SHADOW` slows HuffDecode

Step 15's full set (every sound switch) runs HuffDecode 30% slower than
the same set without `FRAME_SHADOW`. Compiler `perf/zane-vs-c` 5c95fa1,
which adds the switches below; times are `bench1.py` medians, 5–6
rounds pinned. No hardware counters here (`perf_event_open` gives
ENOENT), so wall time only.

**Not placement.** The hot loop is the same code in both builds. Aligning
it differently doesn't close the gap: every loop to 16, 32 or 64 bytes
(`ZANE_LLVM_EXTRA=-align-loops=N`, new) leaves the shadow build at
1.35–1.41 s. Every non-fallthrough block aligned gives 1.34 s against
1.13 s without the shadow, and every block aligned 1.48 s against 1.22 s.

**One slot of one function.** `ZANE_FRAME_SHADOW_ONLY` / `_SKIP` (new:
function-name substrings) and `ZANE_FRAME_SHADOW_OFFSETS` (new: slot
offsets) bisect it. Copies only in `huffman$decode`: 1.38 s; everywhere
but there: 1.07 s; the passes re-run with no copies (`SKIP=` empty):
1.11 s. Of `decode`'s five slots (`tree.nodes` items 224 and count 232,
`tree.root` 256, the `data` and `out` buffers 296 and 312), the copy of
`root` alone gives the whole loss (1.47 s); each other one alone is as
fast as none (1.15–1.27 s).

The two loops then differ by one instruction. At a leaf, `current =
tree.root` is `mov 0x100(%rsi),%r13` without the copy and `mov %rdi,%r15`
with it; every other instruction is the same up to register names. The
register copy runs 25% slower than a load from the frame. Without counters
the reason is not known. `root` is written by the tree's build, through
the frame's address, and `decode` never stores it: the copy holds a value
in a register across the loop that the loop reads only once per symbol.

**Two rules tried, neither a fix.** `ZANE_FRAME_SHADOW_DEBUG` now prints
each slot's store count; 121 of the program's 275 copied slots have no
store in their function, 105 one.

| build | HuffDecode | HuffEncode | GameOfLife | Graph::DFS |
| --- | ---: | ---: | ---: | ---: |
| no shadow | 1.16–1.20 | 0.54–0.57 | 0.66–0.83 | 1.23 |
| full shadow | 1.44–1.47 | 0.58 | 0.66–0.90 | 1.24–1.31 |
| `ZANE_FRAME_SHADOW_WRITTEN=1` (only slots stored twice or more) | 1.22 | 0.70 | 0.77 | 1.28 |
| `ZANE_FRAME_SHADOW_WRITTEN=2` (only slots stored at least once) | 1.24 | 0.68 | 0.75 | 1.27 |

Both rules fix most of HuffDecode and make HuffEncode slower than both no
shadow and full shadow. Over all 50 tests (`ab.py`, 4 rounds),
`WRITTEN=1` is 1.024 against full shadow (`step16-ab-shadow-vs-written.md`)
and 0.985 against no shadow (`step16-ab-noshadow-vs-written.md`). Graph::DFS,
whose −10% under the shadow step 13 measured, shows no gain from it in
these pinned runs.

## Step 17: held locals as plain values? (investigated, not built)

The idea: emit a held local as a plain value, which LLVM keeps in a
register as it does a C local, and write it into its frame slot only
around the runtime calls that need it there. That would make
`FRAME_SHADOW`'s post-`-O2` reconstruction unnecessary.

**The slot has to stay the local's home.** The runtime finds a block's
region from an address (`zane_region_at`, `runtime/arena.c`), and a
list's first block goes in the region of its handle's address
(`zane_list_grow`, `runtime/list.c`). A handle on the machine stack counts
as the innermost scope's, whichever that is when the first push runs.
A list moved to an `alloca` and first pushed by a callee that opens its
own arena (`tree!build()` filling `tree.nodes`) would get its block in
the callee's region, freed when the callee returns. So "plain values" can
only be a copy the function works on, written to the slot before calls
that read it and reloaded after calls that may write it (what is handed
on with `!`, and the runtime's own scope, spawn and move calls). That is
what `FRAME_SHADOW` does after `-O2`; codegen would only make it more
precise (stores only before calls that read, a reload only after calls
given that slot).

**What that could still buy is small.** With `ZANE_FRAME_SHADOW_DEBUG`,
51 functions have frames with slots to copy, and the shadow gives up on
62 frames (a frame base merged by a `phi` or `select`): 56 in `zane$main`,
the rest in `template$step`, `matmul$step` and `arithmetic$Table`. On the
tests still 1.10× C or slower, the shadow changes little (`bench1.py`, 4
rounds pinned, step 15's set without and with it):

| test | no shadow | shadow | slots copied in the hot function |
| --- | ---: | ---: | --- |
| Etc::NeuralNet | 1.20 s | 1.22 s | none |
| Sort::Merge | 1.74 s | 1.76 s | 1 |
| Sort::Quick | 1.42 s | 1.43 s | 1 |
| Etc::TextRaytracer | 1.01 s | 1.00 s | none |
| Etc::CacheSimulation | 0.83 s | 0.78 s | 1 |
| Compress::BWTEncode | 0.74 s | 0.73 s | 12 |

Their hot code holds few frame slots, and keeping those in registers
does not move them. Step 15's harness also priced the write-through
stores at nothing. So emitting held locals as plain values would reach
about where the shadow already is, and the remaining gaps lie elsewhere:
indices where C has pointers (NeuralNet, HuffDecode), bounds checks
(Brainfuck), and allocation (CacheSimulation). Not built.

## Step 18: re-runs against C and against Goose

**C again.** Step 15's set rebuilt with compiler 5c95fa1 is byte-identical
to step 15's binary (the switches added since are off unless set).
`measure.py --rounds 5` (`step18.md`, `step18.json`): **geomean 0.863**,
as in step 15. At 1.10× C or slower: HuffDecode 1.56, Matmul::T4 1.30,
NeuralNet 1.24, Matmul::T8 1.22, Matmul::T16 1.19, Brainfuck::Recursion
1.18, Sort::Merge 1.17, Brainfuck::Array 1.15, TextRaytracer 1.13,
CacheSimulation 1.13, BWTEncode 1.13, Sort::Quick 1.11, Graph::BFS 1.10.
Between the two runs Matmul::T4 moved 1.07 → 1.30, Template::Regex 0.84 →
0.63 and GameOfLife 0.59 → 0.47, the tests already known to jump.

**Goose.** The port in `goose/` built with the Goose v2026.4 release
(`goose -O2 --standalone`, the Makefile's `prod`) and its C compiled at
`-O2` by gcc 13 and by clang 18. All 50 checksums pass. `tri.py 3`
interleaves Goose/gcc, Goose/clang, Zane (the set above) and C, pinned
to one core, rotating the order each round (`step18-goose.md`,
`step18-goose.json`). Geomeans: Zane / Goose-gcc **1.041**, Zane /
Goose-clang **1.258**, Goose-gcc / C 0.807, Goose-clang / C 0.668
(published: 0.79 and 0.66), Zane / C 0.841. Goose is far ahead on
Sort::Self (×5.7), Calculator::Ast (×7.3), LZWDecode (×5.7), CSV::Parse
(×4.1), LZWEncode, LogParser, SHA256 (clang), HuffDecode, NGram, Words,
BWTEncode and Binarytrees::Arena; Zane is ahead on Base64 (Goose/gcc
×14), CacheSimulation (×2), Maze::AStar, Jaro and the Json tests.

**`ASSIGN_MOVES` was unsound in LZWEncode.** Review of the compiler PR
(zane-lang/compiler#377) found that the pass replaced a hold with a `let`
when its only take sat in an `if` body. `lzw$encode`'s `combined` moves
into `current` on one path and into the dictionary on another, and on the
third (dictionary full) nothing owned it. A checked run of this step's
binary (`ZANE_CHECK=1`) stops with "a dynamic block outlived its owner";
unchecked runs release the loop scope's region in bulk, which hid it.
Compiler 168a61a keeps the hold unless the take is outside every `if`.
LZWEncode is then about 19% slower (`bench1.py 5`, median 1.31 s → 1.56 s),
so this step's LZWEncode figure (0.95× C) was bought by the leak. The
fixed build passes all 50 tests checked and unchecked.

## Step 19: closing the gap with Goose, Calculator::Ast

Step 18 left Calculator::Ast at 7.3× Goose. Sampling (`prof/`, now on a
50 µs `CLOCK_MONOTONIC` timer, `SAMPLER_US`; `symbolize.py SAMPLES TOP
FUNCTION` shows the hottest addresses in one function) put about a third
of its time in copying, moving, allocating and freeing `Node`s and their
name Strings, and in per-call frames. Goose's port allocates nothing per
node: a node pool and names as slices of the input.

`calculator$add` held a copy of its `node` (`copy Node=node`), then
called `core$push`, which copied it again into the list; the caller's
fresh node was held and dropped around the call. Compiler
zane-lang/compiler `perf/zane-vs-goose` d08d7d1, behind `ASSIGN_MOVES`
(`ZANE_SINK_HOLDS=0` turns the new parts off):

- A hold read once, as an argument of the next statement's call, is held
  in that argument, the shape lowering gives a fresh argument, so a
  callee that takes the parameter (`push`'s `.taken` copy) is given the
  value itself.
- `taken_params` counts a taken parameter as keeping a fresh argument,
  and searches until it finds no more, so `add`, whose only use of
  `node` is to pass a copy on to `push`, takes its parameter too.
- `assigned_moves` runs again after `take_params`: a last-read copy
  passed to a parameter the callee owns becomes a move, and a copy bound
  by a `let` moves as an assigned one does.

`add` now makes no copy and opens no scope: the caller's fresh `Node`
goes into the list as it is. `expression`, `term` and `factor` shrink to
about half (inlined `add`s, no holds).

Baseline: zane-lang/compiler#377's head with the fix below (`pr`).
`tri.py 3` on both, pinned, interleaved (`step19.json`): **Calculator::Ast
0.831 → 0.421 s** (Goose/clang 0.115: 7.2× → 3.7×). All 50 tests pass
checked (`ZANE_CHECK=1`) and unchecked; `just test-compiler` passes with
and without the switch.

Calculator::Interpreter looked 37% slower in the full run. It is not
this change: alone, or with only the two Calculator tests, the two builds
match; with the 32 tests before it the order flips (pr 0.658, new
0.507). It moves between 0.48 and 0.80 s with the heap that the earlier
tests leave, in either build. The others within ±10% are the usual
placement swings (Sieve's baseline itself moved 1.93 → 2.45 between
runs).

**#377's merge-queue perf run failed.** Removing `ZANE_ONE_STOP` had kept
the order that commit built an element check's blocks in (in-range block,
then stop). Unoptimized builds keep that order in the machine code, so
every check took a jump more: plain builds up to 4.25% more estimated
cycles (particles; flips 3.05%). Main's order (4551d99) puts every plain row
within 0.1% of main.

**Against Goose again.** `tri.py 3` with this step's build (every
switch, compiler 59810c8), Goose/gcc and Goose/clang (`step19-goose.json`):
Zane / Goose-gcc **1.08** (Zane faster on 21 of 50), Zane / Goose-clang
**1.31** (12 of 50). Both are above step 18's 1.041 and 1.258, whose build
had the LZWEncode leak. Furthest behind (× Goose/clang): LZWDecode 6.2,
Sort::Self 5.8, CSV::Parse 4.0, Calculator::Ast 3.9, LZWEncode 3.2,
LogParser 2.4, SHA256 2.4, HuffDecode 2.3.

## What remains

- Calculator::Ast is still 3.7× Goose: each name is a fresh String
  (`slice`), and the Interpreter's lookups hash them again.

- `FRAME_SHADOW`'s HuffDecode loss (step 16) is one register copy of a
  value read once per symbol; a store count does not tell such a slot
  from the ones worth copying. Next: a rule on where the slot is read
  (only off the loop's hot path), or hardware counters on another
  machine to learn why the register copy is slower.

- Base64 is a C library call in both languages; CRC32 and SHA256 (0.97,
  0.86) and Arith (1.00, 1.08) were left on `Buffer`.
- Brainfuck (step 15) is at 1.10–1.24× C with `FRAME_SHADOW`, `ENDLESS`
  and the cell change. Without the tape's checks both tests beat C. The
  tape check stands on an invariant LLVM does not prove (1 ≤ position ≤
  count: `>` pushes when position passes the count, `<` stops at 1, the
  list never shrinks). Cheaper: fold `runArray`'s exit test `pc > count`
  and the check of `commands[pc]` into one unsigned compare, with the exit
  and the stop told apart off the hot path. A conditional loop in core
  would replace `ENDLESS`.
- Placement: a 25% swing on HuffDecode from code layout alone makes small
  gains unmeasurable one test at a time.
- Brainfuck::Recursion re-reads `ops`'s count and checks `ops[i]` on every
  step; `ListRef` is a reference type, so hoisting needs proof that nothing
  in the loop can reach it mutably.
- Json is at C's speed with `ZANE_LENT_OWNERS` and step 14's binding.
  `arena_json_get` is still a call per coordinate that LLVM declines to
  inline, and `step` reloads the handle from the frame before each call
  and stores the list's count after each push; none of it shows in the
  times now.
