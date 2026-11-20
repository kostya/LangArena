#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <zane_ffi.h>
typedef struct arena_host {
  int unused;
} arena_host;
typedef struct arena_config arena_config;
typedef struct arena_buffer arena_buffer;
typedef struct arena_sorted arena_sorted;
extern arena_host arena_system;
void arena_announce(arena_host *host);
zane_bytes arena_read(arena_host *host, const char *path);
int64_t arena_start(arena_host *host, const char *name);
int64_t arena_finish(arena_host *host, int64_t started, int64_t actual,
                     int64_t expected);
void arena_summary(arena_host *host, double seconds, int64_t count,
                   int64_t failures);
void arena_fail(arena_host *host, const char *message);
void arena_exit(arena_host *host, int64_t status);
arena_config *arena_parse(zane_bytes text);
void arena_config_free(arena_config *config);
int64_t arena_count(const arena_config *config);
zane_bytes arena_name(const arena_config *config, int64_t index);
int64_t arena_integer(const arena_config *config, const char *name,
                      const char *key);
zane_bytes arena_text(const arena_config *config, const char *name,
                      const char *key);
bool arena_has(const arena_config *config, const char *name, const char *key);
bool arena_contains(zane_bytes text, zane_bytes pattern);
int64_t arena_length(zane_bytes text);
int64_t arena_byte(zane_bytes text, int64_t index);
zane_bytes arena_slice(zane_bytes text, int64_t start, int64_t length);
zane_bytes arena_character(int64_t value);
zane_bytes arena_fixed(double value, int64_t digits);
zane_bytes arena_hex(int64_t value);
arena_buffer *arena_buffer_new(int64_t size, int64_t value);
void arena_buffer_free(arena_buffer *buffer);
void arena_buffer_replace(arena_buffer *dst, arena_buffer *src);
int64_t arena_buffer_size(const arena_buffer *buffer);
int64_t arena_buffer_get(const arena_buffer *buffer, int64_t index);
void arena_buffer_set(arena_buffer *buffer, int64_t index, int64_t value);
void arena_buffer_push(arena_buffer *buffer, int64_t value);
void arena_buffer_append(arena_buffer *buffer, zane_bytes text);
zane_bytes arena_buffer_text(const arena_buffer *buffer);
void arena_buffer_clear(arena_buffer *buffer);
arena_sorted *arena_sort(zane_span input);
int64_t arena_sorted_get(const arena_sorted *sorted, int64_t index);
void arena_sorted_free(arena_sorted *sorted);

zane_bytes arena_base64_encode(zane_bytes input);
zane_bytes arena_base64_decode(zane_bytes input);
typedef struct arena_json arena_json;
arena_json *arena_json_new(void);
arena_json *arena_json_parse(zane_bytes text);
void arena_json_free(arena_json *json);
void arena_json_add(arena_json *json, double x, double y, double z,
                    zane_bytes name);
zane_bytes arena_json_string(const arena_json *json);
int64_t arena_json_count(const arena_json *json);
double arena_json_get(const arena_json *json, int64_t index, int64_t axis);
typedef struct arena_csv arena_csv;
arena_csv *arena_csv_parse(zane_bytes text);
void arena_csv_free(arena_csv *csv);
int64_t arena_csv_count(const arena_csv *csv);
double arena_csv_get(const arena_csv *csv, int64_t row, int64_t column);
typedef struct arena_regex arena_regex;
arena_regex *arena_regex_new(const char *pattern, bool insensitive);
void arena_regex_free(arena_regex *regex);
int64_t arena_regex_count(const arena_regex *regex, zane_bytes text);

int64_t arena_stop(arena_host *host, int64_t started);

typedef struct arena_matches arena_matches;
arena_matches *arena_regex_matches(const arena_regex *regex, zane_bytes text);
void arena_matches_free(arena_matches *matches);
int64_t arena_matches_count(const arena_matches *matches);
int64_t arena_matches_get(const arena_matches *matches, int64_t index, bool end);

zane_bytes arena_buffer_slice(const arena_buffer *buffer, int64_t start, int64_t size);
