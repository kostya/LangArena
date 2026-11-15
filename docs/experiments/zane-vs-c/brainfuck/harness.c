// harness.c: C's Brainfuck::Array interpreter (c/src/brainfuck_array.c),
// with the Zane port's differences switched on one at a time, to price
// each by wall time. Prints the run's time and result.
//
//   gcc -O2 -fno-omit-frame-pointer [-D...] harness.c -o h && taskset -c 2 ./h prog.bf
//
// -DWIDE     commands and jumps as int64_t (the port's List<Int>), C: char, int32_t
// -DCHECKS   the port's bounds checks: commands[pc], jumps[pc], tape[pos]
// -DCHAIN    `[` and `]` tested before the switch (the port's if/elif/else)
// -DSTEPS    the port's step!to(2^63) counter beside the pc test
// -DSTORES   position and result written to memory after each change
//            (FRAME_SHADOW's write-through copy)
// -DONEBASED pc and position counted from 1, as the port's indices are
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef WIDE
typedef int64_t op_t;
typedef int64_t jump_t;
#else
typedef char op_t;
typedef int32_t jump_t;
#endif

#ifdef CHECKS
#define CHECK(i, n) do { if ((uint64_t)(i) >= (uint64_t)(n)) abort(); } while (0)
#else
#define CHECK(i, n) do { } while (0)
#endif

#ifdef ONEBASED
#define B 1
#else
#define B 0
#endif

typedef struct { uint8_t *tape; size_t size, pos; uint32_t result; } Tape;
// Where STORES writes: a place the compiler must keep up to date.
Tape *volatile escape;

__attribute__((noinline)) static uint32_t run(const op_t *program, int64_t n, const jump_t *jumps) {
  Tape t = { calloc(30000, 1), 30000, B, 0 };
  Tape *home = malloc(sizeof *home);
  escape = home;
  int64_t pc = B;
#ifdef STEPS
  for (int64_t step = INT64_MAX; step; step--) {
    if (pc > n - 1 + B) break;
#else
  while (pc < n + B) {
#endif
    CHECK(pc - B, n);
    op_t c = program[pc - B];
    if (0) {
#ifdef CHAIN
    } else if (c == '[') {
      CHECK(t.pos - B, t.size);
      if (t.tape[t.pos - B] == 0) { CHECK(pc - B, n); pc = jumps[pc - B]; }
    } else if (c == ']') {
      CHECK(t.pos - B, t.size);
      if (t.tape[t.pos - B] != 0) { CHECK(pc - B, n); pc = jumps[pc - B]; }
#endif
    } else {
      CHECK(t.pos - B, t.size);
      switch (c) {
      case '+': t.tape[t.pos - B]++; break;
      case '-': t.tape[t.pos - B]--; break;
      case '>':
        t.pos++;
#ifdef STORES
        home->pos = t.pos;
#endif
        if (t.pos - B >= t.size) { t.tape = realloc(t.tape, t.size + 1); t.tape[t.size++] = 0; }
        break;
      case '<':
        if (t.pos > B) t.pos--;
#ifdef STORES
        home->pos = t.pos;
#endif
        break;
#ifndef CHAIN
      case '[': if (t.tape[t.pos - B] == 0) { CHECK(pc - B, n); pc = jumps[pc - B]; } break;
      case ']': if (t.tape[t.pos - B] != 0) { CHECK(pc - B, n); pc = jumps[pc - B]; } break;
#endif
      case '.':
        t.result = (t.result << 2) + t.tape[t.pos - B];
#ifdef STORES
        home->result = t.result;
#endif
        break;
      default: break;
      }
    }
    pc++;
  }
  free(t.tape);
  free(home);
  return t.result;
}

int main(int argc, char **argv) {
  if (argc < 2) { fprintf(stderr, "usage: %s PROGRAM.b\n", argv[0]); return 2; }
  FILE *f = fopen(argv[1], "rb");
  if (!f) { perror(argv[1]); return 1; }
  static char text[1 << 16];
  size_t len = fread(text, 1, sizeof text - 1, f);
  op_t *program = malloc(len * sizeof *program);
  int64_t n = 0;
  for (size_t i = 0; i < len; i++)
    if (strchr("[]<>+-,.", text[i]) && text[i]) program[n++] = text[i];
  jump_t *jumps = calloc(n, sizeof *jumps);
  int64_t *stack = malloc(n * sizeof *stack), top = 0;
  for (int64_t pc = 0; pc < n; pc++) {
    if (program[pc] == '[') stack[top++] = pc;
    else if (program[pc] == ']') { int64_t l = stack[--top]; jumps[l] = pc + B; jumps[pc] = l + B; }
  }
  struct timespec a, b;
  clock_gettime(CLOCK_MONOTONIC, &a);
  uint32_t r = run(program, n, jumps);
  clock_gettime(CLOCK_MONOTONIC, &b);
  printf("%.3f s  result %u\n", (b.tv_sec - a.tv_sec) + (b.tv_nsec - a.tv_nsec) * 1e-9, r);
}
