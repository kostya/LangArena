#include "binding.h"
#include "vendor/base64/include/libbase64.h"
#include "vendor/yyjson.h"
#define PCRE2_CODE_UNIT_WIDTH 8
#include <pcre2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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
static zane_bytes copy(const char *s, size_t n) {
  uint8_t *p = zane_bytes_alloc(n);
  if (n)
    memcpy(p, s, n);
  return (zane_bytes){p, n};
}
/* Base64 through aklomp/base64, the library LangArena's C entry links, with
   the codec it picks for the processor at run time (vendor/base64). */
zane_bytes arena_base64_encode(zane_bytes input) {
  size_t n = (input.size + 2) / 3 * 4;
  uint8_t *p = zane_bytes_alloc(n);
  size_t written = 0;
  base64_encode((const char *)input.data, input.size, (char *)p, &written, 0);
  return (zane_bytes){p, written};
}
zane_bytes arena_base64_decode(zane_bytes input) {
  if (!input.size)
    return copy("", 0);
  uint8_t *p = zane_bytes_alloc(input.size / 4 * 3 + 3);
  size_t written = 0;
  if (base64_decode((const char *)input.data, input.size, (char *)p, &written,
                    0) != 1)
    die("invalid base64");
  return (zane_bytes){p, written};
}
struct arena_json {
  yyjson_mut_doc *mutable;
  yyjson_doc *parsed;
  yyjson_mut_val *coords;
  yyjson_val *array, *current;
  size_t count, index;
};
arena_json *arena_json_new(void) {
  arena_json *j = calloc(1, sizeof(*j));
  if (!j)
    die("out of memory");
  j->mutable = yyjson_mut_doc_new(NULL);
  if (!j->mutable)
    die("out of memory");
  yyjson_mut_val *root = yyjson_mut_obj(j->mutable);
  yyjson_mut_doc_set_root(j->mutable, root);
  j->coords = yyjson_mut_arr(j->mutable);
  yyjson_mut_obj_add_val(j->mutable, root, "coordinates", j->coords);
  yyjson_mut_obj_add_str(j->mutable, root, "info", "some info");
  return j;
}
arena_json *arena_json_parse(zane_bytes text) {
  arena_json *j = calloc(1, sizeof(*j));
  if (!j)
    die("out of memory");
  j->parsed = yyjson_read((const char *)text.data, text.size, 0);
  if (!j->parsed)
    die("invalid coordinate JSON");
  yyjson_val *coords =
      yyjson_obj_get(yyjson_doc_get_root(j->parsed), "coordinates");
  if (!yyjson_is_arr(coords))
    die("coordinates must be an array");
  j->array = coords;
  j->count = yyjson_arr_size(coords);
  return j;
}
void arena_json_free(arena_json *j) {
  if (j->mutable)
    yyjson_mut_doc_free(j->mutable);
  if (j->parsed)
    yyjson_doc_free(j->parsed);
  free(j);
}
void arena_json_add(arena_json *j, double x, double y, double z,
                    zane_bytes name) {
  yyjson_mut_doc *d = j->mutable;
  yyjson_mut_val *v = yyjson_mut_obj(d);
  yyjson_mut_obj_add_real(d, v, "x", x);
  yyjson_mut_obj_add_real(d, v, "y", y);
  yyjson_mut_obj_add_real(d, v, "z", z);
  yyjson_mut_obj_add_strncpy(d, v, "name", (const char *)name.data, name.size);
  yyjson_mut_val *opts = yyjson_mut_obj(d), *tuple = yyjson_mut_arr(d);
  yyjson_mut_arr_add_int(d, tuple, 1);
  yyjson_mut_arr_add_bool(d, tuple, true);
  yyjson_mut_obj_add_val(d, opts, "1", tuple);
  yyjson_mut_obj_add_val(d, v, "opts", opts);
  yyjson_mut_arr_append(j->coords, v);
}
zane_bytes arena_json_string(const arena_json *j) {
  size_t n = 0;
  char *s = yyjson_mut_write(j->mutable, 0, &n);
  if (!s)
    die("JSON serialization failed");
  zane_bytes out = copy(s, n);
  free(s);
  return out;
}
int64_t arena_json_count(const arena_json *j) { return (int64_t)j->count; }
/* Reads the array as C's yyjson_arr_foreach does, one element after the
   other: the next index is one step on from the current element, and any
   other is found from the start. Each key is a literal, as in C's
   yyjson_obj_get(coord, "x"), so its length and comparison fold. */
double arena_json_get(const arena_json *j, int64_t index, int64_t axis) {
  if (index < 1 || (uint64_t)index > j->count || axis < 0 || axis > 2)
    die("JSON index out of bounds");
  arena_json *at = (arena_json *)j;
  if ((size_t)index != at->index) {
    at->current = (size_t)index == at->index + 1 && at->current
                      ? unsafe_yyjson_get_next(at->current)
                      : yyjson_arr_get(at->array, (size_t)index - 1);
    at->index = (size_t)index;
  }
  yyjson_val *v = axis == 0   ? yyjson_obj_get(at->current, "x")
                  : axis == 1 ? yyjson_obj_get(at->current, "y")
                              : yyjson_obj_get(at->current, "z");
  return yyjson_get_num(v);
}
struct arena_csv {
  double *values;
  size_t rows;
};
arena_csv *arena_csv_parse(zane_bytes text) {
  arena_csv *out = calloc(1, sizeof(*out));
  if (!out)
    die("out of memory");
  size_t capacity = 16;
  out->values = alloc(capacity * 3 * sizeof(double));
  char *field = alloc(text.size + 1);
  size_t used = 0, col = 0;
  double values[3] = {0};
  bool quoted = false;
  const char *s = (const char *)text.data;
  for (size_t i = 0; i <= text.size; i++) {
    char c = i < text.size ? s[i] : '\n';
    if (c == '"') {
      if (quoted && i + 1 < text.size && s[i + 1] == '"') {
        field[used++] = '"';
        i++;
      } else
        quoted = !quoted;
    } else if (!quoted && (c == ',' || c == '\n')) {
      field[used] = '\0';
      if (col == 1)
        values[0] = strtod(field, NULL);
      if (col == 3)
        values[2] = strtod(field, NULL);
      if (col == 5)
        values[1] = strtod(field, NULL);
      used = 0;
      col++;
      if (c == '\n') {
        if (col == 6) {
          if (out->rows == capacity) {
            capacity *= 2;
            double *p = realloc(out->values, capacity * 3 * sizeof(double));
            if (!p)
              die("out of memory");
            out->values = p;
          }
          memcpy(out->values + out->rows * 3, values, sizeof(values));
          out->rows++;
        } else if (col > 1)
          die("invalid CSV row");
        col = 0;
      }
    } else
      field[used++] = c;
  }
  if (quoted)
    die("unterminated CSV quote");
  free(field);
  return out;
}
void arena_csv_free(arena_csv *csv) {
  free(csv->values);
  free(csv);
}
int64_t arena_csv_count(const arena_csv *csv) { return (int64_t)csv->rows; }
double arena_csv_get(const arena_csv *csv, int64_t row, int64_t column) {
  if (row < 1 || (uint64_t)row > csv->rows || column < 0 || column > 2)
    die("CSV index out of bounds");
  return csv->values[(row - 1) * 3 + column];
}
// PCRE2 with its JIT, as the C implementation uses. Byte mode, not UTF:
// the patterns are ASCII, and in UTF mode every pcre2_match call would
// re-validate the whole subject, making a count of n matches quadratic.
struct arena_regex {
  pcre2_code *code;
  pcre2_match_data *match;
};
arena_regex *arena_regex_new(const char *pattern, bool insensitive) {
  arena_regex *r = alloc(sizeof(*r));
  int error;
  PCRE2_SIZE offset;
  r->code = pcre2_compile((PCRE2_SPTR)pattern, PCRE2_ZERO_TERMINATED,
                          insensitive ? PCRE2_CASELESS : 0,
                          &error, &offset, NULL);
  if (!r->code) die("invalid regex");
  pcre2_jit_compile(r->code, PCRE2_JIT_COMPLETE);
  r->match = pcre2_match_data_create_from_pattern(r->code, NULL);
  if (!r->match) die("out of memory");
  return r;
}
void arena_regex_free(arena_regex *r) {
  pcre2_match_data_free(r->match);
  pcre2_code_free(r->code);
  free(r);
}

typedef struct { size_t rm_so, rm_eo; } arena_span;
static bool next_match(const arena_regex *regex, const char *text, size_t length,
                       size_t offset, arena_span *match) {
  if (pcre2_jit_match(regex->code, (PCRE2_SPTR)text, length, offset, 0, regex->match, NULL) < 0)
    return false;
  PCRE2_SIZE *ovector = pcre2_get_ovector_pointer(regex->match);
  match->rm_so = ovector[0];
  match->rm_eo = ovector[1];
  return true;
}
int64_t arena_regex_count(const arena_regex *regex, zane_bytes subject) {
  const char *text = (const char *)subject.data;
  size_t length = subject.size, offset = 0;
  int64_t count = 0;
  arena_span match;
  while (offset < length && next_match(regex, text, length, offset, &match)) {
    count++;
    offset = (size_t)match.rm_eo > offset ? (size_t)match.rm_eo : offset + 1;
  }
  return count;
}
typedef struct { int64_t start, end; } arena_range;
struct arena_matches { arena_range *ranges; size_t count; };
arena_matches *arena_regex_matches(const arena_regex *regex, zane_bytes subject) {
  arena_matches *result = calloc(1, sizeof(*result));
  if (!result) die("out of memory");
  const char *text = (const char *)subject.data;
  size_t length = subject.size, offset = 0, capacity = 0;
  arena_span match;
  while (offset < length && next_match(regex, text, length, offset, &match)) {
    if (result->count == capacity) {
      capacity = capacity ? capacity * 2 : 16;
      arena_range *ranges = realloc(result->ranges, capacity * sizeof(*ranges));
      if (!ranges) die("out of memory");
      result->ranges = ranges;
    }
    result->ranges[result->count++] = (arena_range){match.rm_so + 1, match.rm_eo + 1};
    offset = (size_t)match.rm_eo > offset ? (size_t)match.rm_eo : offset + 1;
  }
  return result;
}
void arena_matches_free(arena_matches *matches) {
  free(matches->ranges);
  free(matches);
}
int64_t arena_matches_count(const arena_matches *matches) {
  return (int64_t)matches->count;
}
int64_t arena_matches_get(const arena_matches *matches, int64_t index, bool end) {
  if (index < 1 || (uint64_t)index > matches->count) die("regex match index out of bounds");
  arena_range range = matches->ranges[index - 1];
  return end ? range.end : range.start;
}
