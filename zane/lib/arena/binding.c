#define _POSIX_C_SOURCE 200809L
#include "binding.h"
#include "vendor/yyjson.h"
#include <ctype.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
arena_host arena_system;
struct arena_config {
  yyjson_doc *doc;
};
static void die(const char *s) {
  fprintf(stderr, "LangArena: %s\n", s);
  exit(2);
}
static void *alloc(size_t n) {
  void *p = malloc(n ? n : 1);
  if (!p)
    die("out of memory");
  return p;
}
static zane_bytes bytes(const char *s, size_t n) {
  uint8_t *p = zane_bytes_alloc(n);
  if (n)
    memcpy(p, s, n);
  return (zane_bytes){p, n};
}
void arena_announce(arena_host *host) {
  (void)host;
  struct timespec t;
  clock_gettime(CLOCK_REALTIME, &t);
  printf("start: %" PRId64 "\n",
         (int64_t)t.tv_sec * 1000 + t.tv_nsec / 1000000);
  fflush(stdout);
}
zane_bytes arena_read(arena_host *host, const char *path) {
  (void)host;
  FILE *f = fopen(path, "rb");
  if (!f)
    die("cannot open config");
  if (fseek(f, 0, SEEK_END))
    die("cannot seek config");
  long n = ftell(f);
  if (n < 0 || fseek(f, 0, SEEK_SET))
    die("cannot size config");
  uint8_t *data = zane_bytes_alloc((size_t)n);
  if (fread(data, 1, (size_t)n, f) != (size_t)n)
    die("cannot read config");
  fclose(f);
  return (zane_bytes){data, (size_t)n};
}
int64_t arena_start(arena_host *host, const char *name) {
  (void)host;
  printf("%s: ", name);
  fflush(stdout);
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return (int64_t)t.tv_sec * 1000000000 + t.tv_nsec;
}
int64_t arena_stop(arena_host *host, int64_t started) {
  (void)host;
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return (int64_t)t.tv_sec * 1000000000 + t.tv_nsec - started;
}
int64_t arena_finish(arena_host *host, int64_t elapsed, int64_t actual,
                     int64_t expected) {
  (void)host;
  if ((uint32_t)actual == (uint32_t)expected)
    printf("OK ");
  else
    printf("ERR[actual=%" PRIu32 ", expected=%" PRIu32 "] ", (uint32_t)actual,
           (uint32_t)expected);
  printf("in %.3fs\n", elapsed / 1e9);
  return elapsed;
}
void arena_summary(arena_host *host, double seconds, int64_t count,
                   int64_t failures) {
  (void)host;
  printf("Summary: %.4fs, %" PRId64 ", %" PRId64 ", %" PRId64 "\n", seconds,
         count, count - failures, failures);
}
void arena_fail(arena_host *host, const char *s) {
  (void)host;
  die(s);
}
void arena_exit(arena_host *host, int64_t status) {
  (void)host;
  exit((int)status);
}
arena_config *arena_parse(zane_bytes text) {
  arena_config *c = alloc(sizeof(*c));
  c->doc = yyjson_read((const char *)text.data, text.size, 0);
  if (!c->doc || !yyjson_is_arr(yyjson_doc_get_root(c->doc)))
    die("config must be a JSON array");
  yyjson_val *root = yyjson_doc_get_root(c->doc);
  size_t index, count;
  yyjson_val *row;
  yyjson_arr_foreach(root, index, count, row) {
    const char *name = yyjson_get_str(yyjson_obj_get(row, "name"));
    if (!name) die("missing benchmark name");
    size_t previous_index, previous_count;
    yyjson_val *previous;
    yyjson_arr_foreach(root, previous_index, previous_count, previous) {
      if (previous_index >= index) break;
      const char *previous_name = yyjson_get_str(yyjson_obj_get(previous, "name"));
      if (!strcmp(name, previous_name)) die("duplicate benchmark name");
    }
  }
  return c;
}
void arena_config_free(arena_config *c) {
  yyjson_doc_free(c->doc);
  free(c);
}
int64_t arena_count(const arena_config *c) {
  return (int64_t)yyjson_arr_size(yyjson_doc_get_root(c->doc));
}
zane_bytes arena_name(const arena_config *c, int64_t index) {
  yyjson_val *v = yyjson_obj_get(
      yyjson_arr_get(yyjson_doc_get_root(c->doc), (size_t)(index - 1)), "name");
  if (!yyjson_is_str(v))
    die("missing benchmark name");
  return bytes(yyjson_get_str(v), yyjson_get_len(v));
}
static yyjson_val *get(const arena_config *c, const char *name,
                       const char *key) {
  size_t i, n;
  yyjson_val *row;
  yyjson_arr_foreach(yyjson_doc_get_root(c->doc), i, n, row) {
    const char *s = yyjson_get_str(yyjson_obj_get(row, "name"));
    if (s && !strcmp(s, name))
      return yyjson_obj_get(row, key);
  }
  return NULL;
}
int64_t arena_integer(const arena_config *c, const char *name,
                      const char *key) {
  yyjson_val *v = get(c, name, key);
  if (!yyjson_is_int(v))
    die("missing integer config field");
  return yyjson_get_sint(v);
}
zane_bytes arena_text(const arena_config *c, const char *name,
                      const char *key) {
  yyjson_val *v = get(c, name, key);
  if (!yyjson_is_str(v))
    die("missing string config field");
  return bytes(yyjson_get_str(v), yyjson_get_len(v));
}
bool arena_has(const arena_config *c, const char *name, const char *key) {
  return get(c, name, key) != NULL;
}
bool arena_contains(zane_bytes text, zane_bytes pattern) {
  if (pattern.size > text.size)
    return false;
  for (size_t i = 0; i <= text.size - pattern.size; i++) {
    size_t j = 0;
    for (; j < pattern.size; j++)
      if (tolower(text.data[i + j]) != tolower(pattern.data[j]))
        break;
    if (j == pattern.size)
      return true;
  }
  return false;
}
int64_t arena_length(zane_bytes text) { return (int64_t)text.size; }
int64_t arena_byte(zane_bytes text, int64_t i) {
  if (i < 1 || (uint64_t)i > text.size)
    die("byte index out of bounds");
  return text.data[i - 1];
}
zane_bytes arena_slice(zane_bytes text, int64_t start, int64_t n) {
  if (start < 1 || n < 0 || (uint64_t)(start - 1) > text.size ||
      (uint64_t)n > text.size - (size_t)(start - 1))
    die("slice out of bounds");
  return bytes((const char *)text.data + start - 1, (size_t)n);
}
zane_bytes arena_character(int64_t v) {
  char c = (char)v;
  return bytes(&c, 1);
}
zane_bytes arena_fixed(double v, int64_t digits) {
  if (digits < 0 || digits > 20)
    die("invalid precision");
  char s[512];
  int n = snprintf(s, sizeof(s), "%.*f", (int)digits, v);
  if (n < 0 || (size_t)n >= sizeof(s))
    die("number too long");
  return bytes(s, (size_t)n);
}
zane_bytes arena_hex(int64_t v) {
  char s[32];
  int n = snprintf(s, sizeof(s), "%" PRIx64, (uint64_t)v);
  return bytes(s, (size_t)n);
}
struct arena_buffer {
  uint8_t *data;
  size_t size, capacity;
};
static void reserve(arena_buffer *b, size_t n) {
  if (n <= b->capacity)
    return;
  size_t cap = b->capacity ? b->capacity : 16;
  while (cap < n) {
    if (cap > SIZE_MAX / 2)
      die("buffer too large");
    cap *= 2;
  }
  uint8_t *p = realloc(b->data, cap);
  if (!p)
    die("out of memory");
  b->data = p;
  b->capacity = cap;
}
arena_buffer *arena_buffer_new(int64_t n, int64_t v) {
  if (n < 0)
    die("negative buffer size");
  arena_buffer *b = calloc(1, sizeof(*b));
  if (!b)
    die("out of memory");
  reserve(b, (size_t)n);
  b->size = (size_t)n;
  if (n)
    memset(b->data, (unsigned char)v, (size_t)n);
  return b;
}
void arena_buffer_free(arena_buffer *b) {
  free(b->data);
  free(b);
}
// Setter for a settled Buffer: dst keeps its address and takes src's bytes;
// src is consumed (ffi.md section 4.3).
void arena_buffer_replace(arena_buffer *dst, arena_buffer *src) {
  free(dst->data);
  *dst = *src;
  free(src);
}
int64_t arena_buffer_size(const arena_buffer *b) { return (int64_t)b->size; }
int64_t arena_buffer_get(const arena_buffer *b, int64_t i) {
  if (i < 1 || (uint64_t)i > b->size)
    die("buffer index out of bounds");
  return b->data[i - 1];
}
void arena_buffer_set(arena_buffer *b, int64_t i, int64_t v) {
  if (i < 1 || (uint64_t)i > b->size)
    die("buffer index out of bounds");
  b->data[i - 1] = (uint8_t)v;
}
void arena_buffer_push(arena_buffer *b, int64_t v) {
  reserve(b, b->size + 1);
  b->data[b->size++] = (uint8_t)v;
}
void arena_buffer_append(arena_buffer *b, zane_bytes text) {
  if (text.size > SIZE_MAX - b->size)
    die("buffer too large");
  reserve(b, b->size + text.size);
  if (text.size)
    memcpy(b->data + b->size, text.data, text.size);
  b->size += text.size;
}
zane_bytes arena_buffer_text(const arena_buffer *b) {
  return bytes((const char *)b->data, b->size);
}
void arena_buffer_clear(arena_buffer *b) { b->size = 0; }
struct arena_sorted {
  int32_t *data;
  size_t size;
};
static int compare_ints(const void *a, const void *b) {
  int32_t x = *(const int32_t *)a, y = *(const int32_t *)b;
  return (x > y) - (x < y);
}
// `input` is a list of 32-bit integers.
arena_sorted *arena_sort(zane_span input) {
  arena_sorted *s = alloc(sizeof(*s));
  s->size = input.count;
  s->data = alloc(input.count * sizeof(int32_t));
  if (input.count)
    memcpy(s->data, input.data, input.count * sizeof(int32_t));
  qsort(s->data, s->size, sizeof(int32_t), compare_ints);
  return s;
}
int64_t arena_sorted_get(const arena_sorted *s, int64_t i) {
  if (i < 1 || (uint64_t)i > s->size)
    die("sorted index out of bounds");
  return s->data[i - 1];
}
void arena_sorted_free(arena_sorted *s) {
  free(s->data);
  free(s);
}

zane_bytes arena_buffer_slice(const arena_buffer *b, int64_t start, int64_t n) {
  if (start < 1 || n < 0 || (uint64_t)(start - 1) > b->size ||
      (uint64_t)n > b->size - (size_t)(start - 1))
    die("buffer slice out of bounds");
  return n ? bytes((const char *)b->data + start - 1, (size_t)n) : bytes("", 0);
}
