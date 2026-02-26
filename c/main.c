#include "cJSON.h"
#include <ctype.h>
#include <gmp.h>
#include <limits.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <uthash.h>
#define PCRE2_CODE_UNIT_WIDTH 8
#include "libbase64.h"
#include <pcre2.h>
#include <pthread.h>
#include <unistd.h>

#define IM 139968
#define IA 3877
#define IC 29573
#define INIT 42

static uint32_t Helper_last = INIT;

static cJSON *global_config = NULL;

void Helper_reset(void) { Helper_last = INIT; }

uint32_t Helper_next_int(uint32_t max) {
  Helper_last = (Helper_last * IA + IC) % IM;
  return (uint32_t)((Helper_last * (int64_t)max) / IM);
}

uint32_t Helper_next_int_range(uint32_t from, uint32_t to) {
  return Helper_next_int(to - from + 1) + from;
}

double Helper_next_float(double max) {
  Helper_last = (Helper_last * IA + IC) % IM;
  return max * Helper_last / IM;
}

uint32_t Helper_checksum_string(const char *v) {
  uint32_t hash = 5381;
  while (*v) {
    unsigned char c = (unsigned char)(*v);
    hash = ((hash << 5) + hash) + c;
    v++;
  }
  return hash;
}

uint32_t Helper_checksum_bytes(const uint8_t *data, size_t length) {
  uint32_t hash = 5381;
  for (size_t i = 0; i < length; i++) {
    hash = ((hash << 5) + hash) + data[i];
  }
  return hash;
}

uint32_t Helper_checksum_f64(double v) {
  char buffer[32];
  snprintf(buffer, sizeof(buffer), "%.7f", v);
  return Helper_checksum_string(buffer);
}

void Helper_load_config(const char *filename) {

  FILE *file = fopen(filename, "rb");
  if (!file) {
    fprintf(stderr, "Cannot open config file: %s\n", filename);
    exit(1);
  }

  fseek(file, 0, SEEK_END);
  long file_size = ftell(file);
  fseek(file, 0, SEEK_SET);

  char *json_data = malloc(file_size + 1);
  if (!json_data) {
    fprintf(stderr, "Memory allocation error\n");
    fclose(file);
    exit(1);
  }

  size_t read_size = fread(json_data, 1, file_size, file);
  json_data[read_size] = '\0';
  fclose(file);

  global_config = cJSON_Parse(json_data);
  free(json_data);

  if (!global_config) {
    fprintf(stderr, "Error parsing JSON config: %s\n", cJSON_GetErrorPtr());
    exit(1);
  }
}

void Helper_free_config(void) {
  if (global_config) {
    cJSON_Delete(global_config);
    global_config = NULL;
  }
}

int64_t Helper_config_i64(const char *class_name, const char *field_name) {
  if (!global_config) {
    fprintf(stderr, "Config not loaded\n");
    return 0;
  }

  cJSON *class_obj =
      cJSON_GetObjectItemCaseSensitive(global_config, class_name);
  if (!class_obj) {

    return 0;
  }

  cJSON *field = cJSON_GetObjectItemCaseSensitive(class_obj, field_name);
  if (!field) {

    return 0;
  }

  if (cJSON_IsNumber(field)) {

    return (int64_t)field->valuedouble;
  } else if (cJSON_IsString(field)) {

    return atoll(field->valuestring);
  } else {

    return 0;
  }
}

const char *Helper_config_s(const char *class_name, const char *field_name) {
  if (!global_config) {
    fprintf(stderr, "Config not loaded\n");
    return "";
  }

  cJSON *class_obj =
      cJSON_GetObjectItemCaseSensitive(global_config, class_name);
  if (!class_obj) {
    fprintf(stderr, "Config not found for %s\n", class_name);
    return "";
  }

  cJSON *field = cJSON_GetObjectItemCaseSensitive(class_obj, field_name);
  if (!field || !cJSON_IsString(field)) {

    return "";
  }

  return field->valuestring;
}

typedef struct Benchmark Benchmark;

struct Benchmark {
  const char *name;
  double time_delta;
  uint32_t checksum_val;
  int64_t iterations_val;

  void (*prepare)(Benchmark *self);
  void (*run)(Benchmark *self, int iteration_id);
  void (*run_all)(Benchmark *self);
  void (*warmup)(Benchmark *self);
  uint32_t (*checksum)(Benchmark *self);
  int64_t (*iterations)(Benchmark *self);
  int64_t (*expected_checksum)(Benchmark *self);
  void (*cleanup)(Benchmark *self);

  void *data;
};

void Benchmark_default_prepare(Benchmark *self) {}

void Benchmark_default_warmup(Benchmark *self) {
  int64_t warmup_iters = Helper_config_i64(self->name, "warmup_iterations");
  if (warmup_iters == 0) {
    warmup_iters = self->iterations(self);
    warmup_iters = (int64_t)(warmup_iters * 0.2);
    if (warmup_iters < 1)
      warmup_iters = 1;
  }

  for (int64_t i = 0; i < warmup_iters; i++) {
    self->run(self, i);
  }
}

void Benchmark_default_run_all(Benchmark *self) {
  int64_t iters = self->iterations(self);
  for (int64_t i = 0; i < iters; i++) {
    self->run(self, i);
  }
}

uint32_t Benchmark_default_checksum(Benchmark *self) {
  return self->checksum_val;
}

int64_t Benchmark_default_iterations(Benchmark *self) {
  if (self->iterations_val > 0) {
    return self->iterations_val;
  }
  self->iterations_val = Helper_config_i64(self->name, "iterations");
  return self->iterations_val;
}

int64_t Benchmark_default_expected_checksum(Benchmark *self) {
  return Helper_config_i64(self->name, "checksum");
}

void Benchmark_default_cleanup(Benchmark *self) {}

Benchmark *Benchmark_create(const char *name) {
  Benchmark *bench = malloc(sizeof(Benchmark));
  bench->name = name;
  bench->time_delta = 0.0;
  bench->checksum_val = 0;
  bench->iterations_val = 0;
  bench->data = NULL;

  bench->prepare = Benchmark_default_prepare;
  bench->warmup = Benchmark_default_warmup;
  bench->run_all = Benchmark_default_run_all;
  bench->checksum = Benchmark_default_checksum;
  bench->iterations = Benchmark_default_iterations;
  bench->expected_checksum = Benchmark_default_expected_checksum;
  bench->cleanup = Benchmark_default_cleanup;

  return bench;
}

typedef struct {
  char name[100];
  Benchmark *(*create)(void);
} BenchmarkFactory;

static BenchmarkFactory *benchmark_factories = NULL;
static size_t benchmark_factories_count = 0;
static size_t benchmark_factories_capacity = 0;

void Benchmark_register(const char *name, Benchmark *(*factory)(void)) {
  if (benchmark_factories_count >= benchmark_factories_capacity) {
    benchmark_factories_capacity =
        benchmark_factories_capacity ? benchmark_factories_capacity * 2 : 16;
    benchmark_factories =
        realloc(benchmark_factories,
                sizeof(BenchmarkFactory) * benchmark_factories_capacity);
  }

  strncpy(benchmark_factories[benchmark_factories_count].name, name,
          sizeof(benchmark_factories[benchmark_factories_count].name) - 1);
  benchmark_factories[benchmark_factories_count].create = factory;
  benchmark_factories_count++;
}

static int strcasecmp_custom(const char *s1, const char *s2) {
  while (*s1 && *s2) {
    int c1 = tolower((unsigned char)*s1);
    int c2 = tolower((unsigned char)*s2);
    if (c1 != c2)
      return c1 - c2;
    s1++;
    s2++;
  }
  return tolower((unsigned char)*s1) - tolower((unsigned char)*s2);
}

void Benchmark_all(const char *single_bench) {
  struct timespec start, end;
  double summary_time = 0.0;
  int ok = 0;
  int fails = 0;

  FILE *results_file = fopen("/tmp/results.js", "w");
  if (results_file) {
    fprintf(results_file, "{");
  }

  int first_result = 1;

  for (size_t i = 0; i < benchmark_factories_count; i++) {
    const char *bench_name = benchmark_factories[i].name;

    if (single_bench && strlen(single_bench) > 0) {

      const char *haystack = bench_name;
      const char *needle = single_bench;

      char haystack_lower[100];
      char needle_lower[100];
      strncpy(haystack_lower, haystack, sizeof(haystack_lower) - 1);
      haystack_lower[sizeof(haystack_lower) - 1] = '\0';
      strncpy(needle_lower, needle, sizeof(needle_lower) - 1);
      needle_lower[sizeof(needle_lower) - 1] = '\0';

      for (char *p = haystack_lower; *p; p++)
        *p = tolower(*p);
      for (char *p = needle_lower; *p; p++)
        *p = tolower(*p);

      if (strstr(haystack_lower, needle_lower) == NULL) {
        continue;
      }
    }

    printf("%s: ", bench_name);
    fflush(stdout);

    Benchmark *bench = benchmark_factories[i].create();

    Helper_reset();

    bench->prepare(bench);

    bench->warmup(bench);

    Helper_reset();
    clock_gettime(CLOCK_MONOTONIC, &start);

    bench->run_all(bench);

    clock_gettime(CLOCK_MONOTONIC, &end);
    double duration =
        (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) * 1e-9;

    bench->time_delta = duration;
    summary_time += duration;

    uint32_t actual_checksum = bench->checksum(bench);
    uint32_t expected_checksum = (uint32_t)bench->expected_checksum(bench);

    if (actual_checksum == expected_checksum) {
      printf("OK ");
      ok++;
    } else {
      printf("ERR[actual=%u, expected=%u] ", actual_checksum,
             (long long)expected_checksum);
      fails++;
    }

    printf("in %.3fs\n", duration);

    if (results_file) {
      if (!first_result) {
        fprintf(results_file, ",");
      }
      fprintf(results_file, "\"%s\":%.6f", bench_name, duration);
      first_result = 0;
    }

    bench->cleanup(bench);
    free(bench->data);
    free(bench);

    usleep(1000);
  }

  if (results_file) {
    fprintf(results_file, "}");
    fclose(results_file);
  }

  if (ok + fails > 0) {
    printf("Summary: %.4fs, %d, %d, %d\n", summary_time, ok + fails, ok, fails);
  }

  if (fails > 0) {
    exit(1);
  }
}

typedef struct {
  int nn;
  char *result_str;
  size_t result_capacity;
  size_t result_length;
  char *full_result_str;
  size_t full_result_capacity;
  size_t full_result_length;
} PidigitsData;

void Pidigits_grow_result(PidigitsData *self, size_t needed) {
  size_t new_capacity = self->result_capacity;
  while (self->result_length + needed >= new_capacity) {
    new_capacity = new_capacity ? new_capacity * 2 : 1024;
  }
  if (new_capacity > self->result_capacity) {
    self->result_str = realloc(self->result_str, new_capacity);
    self->result_capacity = new_capacity;
  }
}

void Pidigits_append(PidigitsData *self, const char *str) {
  size_t len = strlen(str);
  Pidigits_grow_result(self, len + 1);
  memcpy(self->result_str + self->result_length, str, len);
  self->result_length += len;
  self->result_str[self->result_length] = '\0';
}

void Pidigits_grow_full_result(PidigitsData *self, size_t needed) {
  size_t new_capacity = self->full_result_capacity;
  while (self->full_result_length + needed >= new_capacity) {
    new_capacity = new_capacity ? new_capacity * 2 : 1024;
  }
  if (new_capacity > self->full_result_capacity) {
    self->full_result_str = realloc(self->full_result_str, new_capacity);
    self->full_result_capacity = new_capacity;
  }
}

void Pidigits_append_to_full(PidigitsData *self, const char *str) {
  size_t len = strlen(str);
  Pidigits_grow_full_result(self, len + 1);
  memcpy(self->full_result_str + self->full_result_length, str, len);
  self->full_result_length += len;
  self->full_result_str[self->full_result_length] = '\0';
}

void Pidigits_prepare(Benchmark *self) {
  PidigitsData *data = (PidigitsData *)self->data;

  data->nn = (int)Helper_config_i64(self->name, "amount");
  if (data->nn == 0) {
    data->nn = 100;
  }

  data->result_capacity = 1024;
  data->result_length = 0;
  data->result_str = malloc(data->result_capacity);
  data->result_str[0] = '\0';

  data->full_result_capacity = 1024;
  data->full_result_length = 0;
  data->full_result_str = malloc(data->full_result_capacity);
  data->full_result_str[0] = '\0';
}

void Pidigits_run(Benchmark *self, int iteration_id) {
  PidigitsData *data = (PidigitsData *)self->data;

  data->result_length = 0;
  data->result_str[0] = '\0';

  mpz_t ns, a, t, u, n, d, temp, q, a_minus_dq;
  mpz_init(ns);
  mpz_init(a);
  mpz_init(t);
  mpz_init(u);
  mpz_init(n);
  mpz_init(d);
  mpz_init(temp);
  mpz_init(q);
  mpz_init(a_minus_dq);

  int i = 0;
  int k = 0;
  int k1 = 1;
  mpz_set_ui(n, 1);
  mpz_set_ui(d, 1);
  mpz_set_ui(ns, 0);
  mpz_set_ui(a, 0);

  while (1) {
    k += 1;
    mpz_mul_ui(t, n, 2);
    mpz_mul_ui(n, n, k);
    k1 += 2;

    mpz_add(a, a, t);
    mpz_mul_ui(a, a, k1);

    mpz_mul_ui(d, d, k1);

    if (mpz_cmp(a, n) >= 0) {

      mpz_mul_ui(temp, n, 3);
      mpz_add(temp, temp, a);

      mpz_fdiv_q(q, temp, d);

      mpz_fdiv_r(u, temp, d);

      mpz_add(u, u, n);

      if (mpz_cmp(d, u) > 0) {

        mpz_mul_ui(ns, ns, 10);
        mpz_add(ns, ns, q);
        i++;

        if (i % 10 == 0) {
          char *ns_str = mpz_get_str(NULL, 10, ns);
          size_t len = strlen(ns_str);
          if (len < 10) {
            char padded[11] = {0};
            memset(padded, '0', 10 - len);
            strcpy(padded + 10 - len, ns_str);
            Pidigits_append(data, padded);
          } else {
            Pidigits_append(data, ns_str);
          }
          Pidigits_append(data, "\t:");

          char i_str[32];
          snprintf(i_str, sizeof(i_str), "%d\n", i);
          Pidigits_append(data, i_str);

          mpz_set_ui(ns, 0);
          free(ns_str);
        }

        if (i >= data->nn)
          break;

        mpz_mul(temp, d, q);
        mpz_sub(a_minus_dq, a, temp);
        mpz_mul_ui(a, a_minus_dq, 10);

        mpz_mul_ui(n, n, 10);
      }
    }
  }

  if (mpz_cmp_ui(ns, 0) > 0) {
    char *ns_str = mpz_get_str(NULL, 10, ns);
    size_t len = strlen(ns_str);
    if (len < 10) {
      char padded[11] = {0};
      memset(padded, '0', 10 - len);
      strcpy(padded + 10 - len, ns_str);
      Pidigits_append(data, padded);
    } else {
      Pidigits_append(data, ns_str);
    }
    Pidigits_append(data, "\t:");

    char i_str[32];
    snprintf(i_str, sizeof(i_str), "%d\n", i);
    Pidigits_append(data, i_str);
    free(ns_str);
  }

  mpz_clear(ns);
  mpz_clear(a);
  mpz_clear(t);
  mpz_clear(u);
  mpz_clear(n);
  mpz_clear(d);
  mpz_clear(temp);
  mpz_clear(q);
  mpz_clear(a_minus_dq);

  Pidigits_append_to_full(data, data->result_str);
}

uint32_t Pidigits_checksum(Benchmark *self) {
  PidigitsData *data = (PidigitsData *)self->data;

  return Helper_checksum_string(data->full_result_str);
}

void Pidigits_cleanup(Benchmark *self) {
  PidigitsData *data = (PidigitsData *)self->data;
  if (data->result_str) {
    free(data->result_str);
    data->result_str = NULL;
  }
  if (data->full_result_str) {
    free(data->full_result_str);
    data->full_result_str = NULL;
  }
}

Benchmark *Pidigits_create(void) {
  Benchmark *bench = Benchmark_create("CLBG::Pidigits");

  PidigitsData *data = malloc(sizeof(PidigitsData));
  memset(data, 0, sizeof(PidigitsData));

  bench->data = data;

  bench->prepare = Pidigits_prepare;
  bench->run = Pidigits_run;
  bench->checksum = Pidigits_checksum;
  bench->cleanup = Pidigits_cleanup;

  return bench;
}

typedef struct BinarytreesObj_TreeNode {
  struct BinarytreesObj_TreeNode *left;
  struct BinarytreesObj_TreeNode *right;
  int32_t item;
} BinarytreesObj_TreeNode;

static BinarytreesObj_TreeNode *BinarytreesObj_TreeNode_new(int32_t item,
                                                            int32_t depth) {
  BinarytreesObj_TreeNode *node = malloc(sizeof(BinarytreesObj_TreeNode));
  node->item = item;
  node->left = NULL;
  node->right = NULL;

  if (depth > 0) {
    int32_t shift = 1 << (depth - 1);
    node->left = BinarytreesObj_TreeNode_new(item - shift, depth - 1);
    node->right = BinarytreesObj_TreeNode_new(item + shift, depth - 1);
  }

  return node;
}

static void BinarytreesObj_TreeNode_free(BinarytreesObj_TreeNode *node) {
  if (!node)
    return;
  BinarytreesObj_TreeNode_free(node->left);
  BinarytreesObj_TreeNode_free(node->right);
  free(node);
}

static uint32_t BinarytreesObj_TreeNode_sum(BinarytreesObj_TreeNode *node) {
  uint32_t total = (uint32_t)node->item + 1;
  if (node->left)
    total += BinarytreesObj_TreeNode_sum(node->left);
  if (node->right)
    total += BinarytreesObj_TreeNode_sum(node->right);
  return total;
}

typedef struct {
  int64_t n;
  uint32_t result_val;
} BinarytreesObjData;

void BinarytreesObj_prepare(Benchmark *self) {
  BinarytreesObjData *data = (BinarytreesObjData *)self->data;
  data->n = Helper_config_i64(self->name, "depth");
  data->result_val = 0;
}

void BinarytreesObj_run(Benchmark *self, int iteration_id) {
  (void)iteration_id;
  BinarytreesObjData *data = (BinarytreesObjData *)self->data;

  BinarytreesObj_TreeNode *root =
      BinarytreesObj_TreeNode_new(0, (int32_t)data->n);
  data->result_val += BinarytreesObj_TreeNode_sum(root);
  BinarytreesObj_TreeNode_free(root);
}

uint32_t BinarytreesObj_checksum(Benchmark *self) {
  BinarytreesObjData *data = (BinarytreesObjData *)self->data;
  return data->result_val;
}

void BinarytreesObj_cleanup(Benchmark *self) {
  if (self && self->data) {
    BinarytreesObjData *data = (BinarytreesObjData *)self->data;

    free(data);
    self->data = NULL;
  }
}

Benchmark *BinarytreesObj_create(void) {
  Benchmark *bench = Benchmark_create("Binarytrees::Obj");
  if (!bench)
    return NULL;

  BinarytreesObjData *data = malloc(sizeof(BinarytreesObjData));
  if (!data) {
    free(bench);
    return NULL;
  }

  data->n = 0;
  data->result_val = 0;

  bench->data = data;
  bench->prepare = BinarytreesObj_prepare;
  bench->run = BinarytreesObj_run;
  bench->checksum = BinarytreesObj_checksum;
  bench->cleanup = BinarytreesObj_cleanup;

  return bench;
}

typedef struct {
  int32_t item;
  int32_t left;
  int32_t right;
} BinarytreesArena_Node;

typedef struct {
  BinarytreesArena_Node *nodes;
  size_t capacity;
  size_t size;
} BinarytreesArena_Arena;

static BinarytreesArena_Arena *BinarytreesArena_Arena_new(void) {
  BinarytreesArena_Arena *arena = malloc(sizeof(BinarytreesArena_Arena));
  if (!arena)
    return NULL;

  arena->nodes = NULL;
  arena->capacity = 0;
  arena->size = 0;
  return arena;
}

static void BinarytreesArena_Arena_free(BinarytreesArena_Arena *arena) {
  if (arena) {
    if (arena->nodes) {
      free(arena->nodes);
      arena->nodes = NULL;
    }
    arena->capacity = 0;
    arena->size = 0;
    free(arena);
  }
}

static int32_t BinarytreesArena_Arena_add(BinarytreesArena_Arena *arena,
                                          int32_t item) {
  if (!arena)
    return -1;

  if (arena->size >= arena->capacity) {
    size_t new_capacity = arena->capacity == 0 ? 1024 : arena->capacity * 2;
    BinarytreesArena_Node *new_nodes =
        realloc(arena->nodes, new_capacity * sizeof(BinarytreesArena_Node));
    if (!new_nodes)
      return -1;

    arena->nodes = new_nodes;
    arena->capacity = new_capacity;
  }

  int32_t idx = (int32_t)arena->size;
  arena->nodes[idx].item = item;
  arena->nodes[idx].left = -1;
  arena->nodes[idx].right = -1;
  arena->size++;

  return idx;
}

static int32_t BinarytreesArena_build_tree(BinarytreesArena_Arena *arena,
                                           int32_t item, int32_t depth) {
  if (!arena)
    return -1;

  int32_t idx = BinarytreesArena_Arena_add(arena, item);
  if (idx < 0)
    return -1;

  if (depth > 0) {
    int32_t shift = 1 << (depth - 1);
    int32_t left_idx =
        BinarytreesArena_build_tree(arena, item - shift, depth - 1);
    int32_t right_idx =
        BinarytreesArena_build_tree(arena, item + shift, depth - 1);

    if (left_idx >= 0 && right_idx >= 0) {
      arena->nodes[idx].left = left_idx;
      arena->nodes[idx].right = right_idx;
    }
  }

  return idx;
}

static uint32_t BinarytreesArena_sum(BinarytreesArena_Arena *arena,
                                     int32_t idx) {
  if (!arena || idx < 0 || (size_t)idx >= arena->size)
    return 0;

  BinarytreesArena_Node *node = &arena->nodes[idx];
  uint32_t total = (uint32_t)node->item + 1;

  if (node->left >= 0)
    total += BinarytreesArena_sum(arena, node->left);
  if (node->right >= 0)
    total += BinarytreesArena_sum(arena, node->right);

  return total;
}

typedef struct {
  int64_t n;
  uint32_t result_val;
  BinarytreesArena_Arena *arena;
} BinarytreesArenaData;

void BinarytreesArena_prepare(Benchmark *self) {
  if (!self || !self->data)
    return;

  BinarytreesArenaData *data = (BinarytreesArenaData *)self->data;
  data->n = Helper_config_i64(self->name, "depth");
  data->result_val = 0;
}

void BinarytreesArena_run(Benchmark *self, int iteration_id) {
  if (!self || !self->data)
    return;

  BinarytreesArenaData *data = (BinarytreesArenaData *)self->data;

  data->arena = BinarytreesArena_Arena_new();

  int32_t root_idx =
      BinarytreesArena_build_tree(data->arena, 0, (int32_t)data->n);
  if (root_idx >= 0) {
    data->result_val += BinarytreesArena_sum(data->arena, root_idx);
  }

  BinarytreesArena_Arena_free(data->arena);
  data->arena = NULL;
}

uint32_t BinarytreesArena_checksum(Benchmark *self) {
  if (!self || !self->data)
    return 0;
  BinarytreesArenaData *data = (BinarytreesArenaData *)self->data;
  return data->result_val;
}

void BinarytreesArena_cleanup(Benchmark *self) {
  if (self && self->data) {
    BinarytreesArenaData *data = (BinarytreesArenaData *)self->data;

    if (data->arena) {
      BinarytreesArena_Arena_free(data->arena);
      data->arena = NULL;
    }

    free(data);
    self->data = NULL;
  }
}

Benchmark *BinarytreesArena_create(void) {
  Benchmark *bench = Benchmark_create("Binarytrees::Arena");
  if (!bench)
    return NULL;

  BinarytreesArenaData *data = malloc(sizeof(BinarytreesArenaData));
  if (!data) {
    free(bench);
    return NULL;
  }

  data->n = 0;
  data->result_val = 0;
  data->arena = NULL;

  bench->data = data;
  bench->prepare = BinarytreesArena_prepare;
  bench->run = BinarytreesArena_run;
  bench->checksum = BinarytreesArena_checksum;
  bench->cleanup = BinarytreesArena_cleanup;

  return bench;
}

typedef struct {
  uint8_t *tape;
  size_t tape_size;
  size_t pos;
} BrainfuckArray_Tape;

typedef struct {
  char *program;
  char *warmup_program;
  int32_t program_length;
  int32_t warmup_length;
  int32_t *jumps;
  int32_t *warmup_jumps;
  uint32_t result_val;
} BrainfuckArrayData;

static void BrainfuckArray_Tape_init(BrainfuckArray_Tape *tape) {
  tape->tape_size = 30000;
  tape->tape = calloc(tape->tape_size, sizeof(uint8_t));
  tape->pos = 0;
}

static void BrainfuckArray_Tape_destroy(BrainfuckArray_Tape *tape) {
  if (tape && tape->tape) {
    free(tape->tape);
    tape->tape = NULL;
    tape->tape_size = 0;
    tape->pos = 0;
  }
}

static uint8_t BrainfuckArray_Tape_get(const BrainfuckArray_Tape *tape) {
  return tape->tape[tape->pos];
}

static void BrainfuckArray_Tape_inc(BrainfuckArray_Tape *tape) {
  tape->tape[tape->pos]++;
}

static void BrainfuckArray_Tape_dec(BrainfuckArray_Tape *tape) {
  tape->tape[tape->pos]--;
}

static void BrainfuckArray_Tape_advance(BrainfuckArray_Tape *tape) {
  tape->pos++;
  if (tape->pos >= tape->tape_size) {

    size_t new_size = tape->tape_size + 1;
    uint8_t *new_tape = realloc(tape->tape, new_size);
    if (new_tape) {
      tape->tape = new_tape;
      tape->tape[tape->tape_size] = 0;
      tape->tape_size = new_size;
    }
  }
}

static void BrainfuckArray_Tape_devance(BrainfuckArray_Tape *tape) {
  if (tape->pos > 0) {
    tape->pos--;
  }
}

static char *BrainfuckArray_filter_commands(const char *input,
                                            int32_t *out_length) {
  if (!input) {
    *out_length = 0;
    return NULL;
  }

  size_t input_len = strlen(input);
  char *program = malloc(input_len + 1);
  if (!program) {
    *out_length = 0;
    return NULL;
  }

  int32_t program_pos = 0;
  for (size_t i = 0; i < input_len; i++) {
    char c = input[i];
    if (strchr("[]<>+-,.", c)) {
      program[program_pos++] = c;
    }
  }
  program[program_pos] = '\0';

  *out_length = program_pos;
  return program;
}

static int32_t *BrainfuckArray_build_jumps(const char *program,
                                           int32_t program_length) {
  if (!program || program_length == 0)
    return NULL;

  int32_t *jumps = calloc(program_length, sizeof(int32_t));
  if (!jumps)
    return NULL;

  int32_t *stack = malloc(sizeof(int32_t) * (program_length / 2 + 1));
  if (!stack) {
    free(jumps);
    return NULL;
  }

  int32_t stack_top = -1;

  for (int32_t pc = 0; pc < program_length; pc++) {
    char c = program[pc];
    if (c == '[') {
      stack[++stack_top] = pc;
    } else if (c == ']') {
      if (stack_top >= 0) {
        int32_t left = stack[stack_top--];
        jumps[left] = pc;
        jumps[pc] = left;
      }
    }
  }

  free(stack);
  return jumps;
}

static uint32_t BrainfuckArray_execute_program(const char *program,
                                               int32_t program_length,
                                               const int32_t *jumps) {
  if (!program || program_length == 0 || !jumps) {
    return 0;
  }

  BrainfuckArray_Tape tape;
  BrainfuckArray_Tape_init(&tape);

  int32_t pc = 0;
  uint32_t result = 0;

  while (pc < program_length) {
    char c = program[pc];
    switch (c) {
    case '+':
      BrainfuckArray_Tape_inc(&tape);
      break;

    case '-':
      BrainfuckArray_Tape_dec(&tape);
      break;

    case '>':
      BrainfuckArray_Tape_advance(&tape);
      break;

    case '<':
      BrainfuckArray_Tape_devance(&tape);
      break;

    case '[':
      if (BrainfuckArray_Tape_get(&tape) == 0) {
        pc = jumps[pc];
      }
      break;

    case ']':
      if (BrainfuckArray_Tape_get(&tape) != 0) {
        pc = jumps[pc];
      }
      break;

    case '.':
      result = (result << 2) + BrainfuckArray_Tape_get(&tape);
      break;

    default:
      break;
    }
    pc++;
  }

  BrainfuckArray_Tape_destroy(&tape);
  return result;
}

void BrainfuckArray_prepare(Benchmark *self) {
  BrainfuckArrayData *data = (BrainfuckArrayData *)self->data;

  const char *program_text = Helper_config_s(self->name, "program");
  const char *warmup_text = Helper_config_s(self->name, "warmup_program");

  data->program =
      BrainfuckArray_filter_commands(program_text, &data->program_length);
  data->jumps = BrainfuckArray_build_jumps(data->program, data->program_length);

  data->warmup_program =
      BrainfuckArray_filter_commands(warmup_text, &data->warmup_length);
  data->warmup_jumps =
      BrainfuckArray_build_jumps(data->warmup_program, data->warmup_length);

  data->result_val = 0;
}

void BrainfuckArray_warmup(Benchmark *self) {
  BrainfuckArrayData *data = (BrainfuckArrayData *)self->data;

  if (!data->warmup_program || data->warmup_length == 0)
    return;

  int64_t warmup_iters = Helper_config_i64(self->name, "warmup_iterations");
  if (warmup_iters == 0) {
    warmup_iters = self->iterations(self) / 5;
    if (warmup_iters < 1)
      warmup_iters = 1;
  }

  for (int64_t i = 0; i < warmup_iters; i++) {
    BrainfuckArray_execute_program(data->warmup_program, data->warmup_length,
                                   data->warmup_jumps);
  }
}

void BrainfuckArray_run(Benchmark *self, int iteration_id) {
  BrainfuckArrayData *data = (BrainfuckArrayData *)self->data;

  if (iteration_id == 0) {
    data->result_val = 0;
  }

  if (data->program && data->program_length > 0 && data->jumps) {
    uint32_t run_result = BrainfuckArray_execute_program(
        data->program, data->program_length, data->jumps);
    data->result_val += run_result;
  }
}

uint32_t BrainfuckArray_checksum(Benchmark *self) {
  BrainfuckArrayData *data = (BrainfuckArrayData *)self->data;
  return data->result_val;
}

void BrainfuckArray_cleanup(Benchmark *self) {
  if (!self || !self->data)
    return;

  BrainfuckArrayData *data = (BrainfuckArrayData *)self->data;

  free(data->program);
  free(data->jumps);
  free(data->warmup_program);
  free(data->warmup_jumps);

  free(data);
  self->data = NULL;
}

Benchmark *BrainfuckArray_create(void) {
  Benchmark *bench = Benchmark_create("Brainfuck::Array");
  if (!bench)
    return NULL;

  BrainfuckArrayData *data = calloc(1, sizeof(BrainfuckArrayData));
  if (!data) {
    free(bench);
    return NULL;
  }

  bench->data = data;
  bench->prepare = BrainfuckArray_prepare;
  bench->warmup = BrainfuckArray_warmup;
  bench->run = BrainfuckArray_run;
  bench->checksum = BrainfuckArray_checksum;
  bench->cleanup = BrainfuckArray_cleanup;

  return bench;
}

typedef enum {
  BrainfuckRecursion_OP_INC,
  BrainfuckRecursion_OP_DEC,
  BrainfuckRecursion_OP_RIGHT,
  BrainfuckRecursion_OP_LEFT,
  BrainfuckRecursion_OP_PRINT,
  BrainfuckRecursion_OP_LOOP
} BrainfuckRecursion_OpType;

typedef struct BrainfuckRecursion_Op BrainfuckRecursion_Op;

struct BrainfuckRecursion_Op {
  BrainfuckRecursion_OpType type;
  BrainfuckRecursion_Op *loop_ops;
  int32_t loop_size;
};

typedef struct BrainfuckRecursion_Tape {
  uint8_t *tape;
  int32_t size;
  int32_t pos;
} BrainfuckRecursion_Tape;

static BrainfuckRecursion_Tape *BrainfuckRecursion_Tape_new(void) {
  BrainfuckRecursion_Tape *self = malloc(sizeof(BrainfuckRecursion_Tape));
  self->size = 30000;
  self->tape = calloc(self->size, sizeof(uint8_t));
  self->pos = 0;
  return self;
}

static uint8_t BrainfuckRecursion_Tape_get(BrainfuckRecursion_Tape *self) {
  return self->tape[self->pos];
}

static void BrainfuckRecursion_Tape_inc(BrainfuckRecursion_Tape *self) {
  self->tape[self->pos]++;
}

static void BrainfuckRecursion_Tape_dec(BrainfuckRecursion_Tape *self) {
  self->tape[self->pos]--;
}

static void BrainfuckRecursion_Tape_right(BrainfuckRecursion_Tape *self) {
  self->pos++;
  if (self->pos >= self->size) {
    self->size++;
    self->tape = realloc(self->tape, self->size);
    self->tape[self->size - 1] = 0;
  }
}

static void BrainfuckRecursion_Tape_left(BrainfuckRecursion_Tape *self) {
  if (self->pos > 0) {
    self->pos--;
  }
}

static void BrainfuckRecursion_Tape_free(BrainfuckRecursion_Tape *self) {
  free(self->tape);
  free(self);
}

static BrainfuckRecursion_Op *BrainfuckRecursion_parse_ops(const char **code,
                                                           int32_t *ops_count) {
  int32_t capacity = 16;
  BrainfuckRecursion_Op *ops = malloc(sizeof(BrainfuckRecursion_Op) * capacity);
  int32_t count = 0;

  while (**code) {
    if (count >= capacity) {
      capacity *= 2;
      ops = realloc(ops, sizeof(BrainfuckRecursion_Op) * capacity);
    }

    switch (**code) {
    case '+':
      ops[count].type = BrainfuckRecursion_OP_INC;
      ops[count].loop_ops = NULL;
      ops[count].loop_size = 0;
      count++;
      break;
    case '-':
      ops[count].type = BrainfuckRecursion_OP_DEC;
      ops[count].loop_ops = NULL;
      ops[count].loop_size = 0;
      count++;
      break;
    case '>':
      ops[count].type = BrainfuckRecursion_OP_RIGHT;
      ops[count].loop_ops = NULL;
      ops[count].loop_size = 0;
      count++;
      break;
    case '<':
      ops[count].type = BrainfuckRecursion_OP_LEFT;
      ops[count].loop_ops = NULL;
      ops[count].loop_size = 0;
      count++;
      break;
    case '.':
      ops[count].type = BrainfuckRecursion_OP_PRINT;
      ops[count].loop_ops = NULL;
      ops[count].loop_size = 0;
      count++;
      break;
    case '[':
      (*code)++;
      ops[count].type = BrainfuckRecursion_OP_LOOP;
      ops[count].loop_ops = NULL;
      ops[count].loop_size = 0;

      int32_t loop_ops_count = 0;
      ops[count].loop_ops = BrainfuckRecursion_parse_ops(code, &loop_ops_count);
      ops[count].loop_size = loop_ops_count;

      count++;
      continue;
    case ']':
      *ops_count = count;
      (*code)++;
      return ops;
    default:
      break;
    }
    (*code)++;
  }

  *ops_count = count;
  return ops;
}

static void BrainfuckRecursion_free_ops(BrainfuckRecursion_Op *ops,
                                        int32_t ops_size) {
  if (!ops)
    return;

  for (int32_t i = 0; i < ops_size; i++) {
    if (ops[i].type == BrainfuckRecursion_OP_LOOP && ops[i].loop_ops) {
      BrainfuckRecursion_free_ops(ops[i].loop_ops, ops[i].loop_size);
    }
  }
  free(ops);
}

static void BrainfuckRecursion_run_ops(BrainfuckRecursion_Op *ops,
                                       int32_t ops_size,
                                       BrainfuckRecursion_Tape *tape,
                                       uint32_t *result) {
  for (int32_t i = 0; i < ops_size; i++) {
    BrainfuckRecursion_Op *op = &ops[i];
    switch (op->type) {
    case BrainfuckRecursion_OP_INC:
      BrainfuckRecursion_Tape_inc(tape);
      break;
    case BrainfuckRecursion_OP_DEC:
      BrainfuckRecursion_Tape_dec(tape);
      break;
    case BrainfuckRecursion_OP_RIGHT:
      BrainfuckRecursion_Tape_right(tape);
      break;
    case BrainfuckRecursion_OP_LEFT:
      BrainfuckRecursion_Tape_left(tape);
      break;
    case BrainfuckRecursion_OP_PRINT: {
      uint8_t value = BrainfuckRecursion_Tape_get(tape);
      *result = (*result << 2) + value;
      break;
    }
    case BrainfuckRecursion_OP_LOOP:
      while (BrainfuckRecursion_Tape_get(tape) != 0) {
        BrainfuckRecursion_run_ops(op->loop_ops, op->loop_size, tape, result);
      }
      break;
    }
  }
}

static uint32_t BrainfuckRecursion_run_program(const char *code) {
  if (!code || !code[0]) {
    return 0;
  }

  const char *code_ptr = code;
  int32_t ops_count = 0;
  BrainfuckRecursion_Op *ops =
      BrainfuckRecursion_parse_ops(&code_ptr, &ops_count);

  if (!ops) {
    return 0;
  }

  BrainfuckRecursion_Tape *tape = BrainfuckRecursion_Tape_new();
  uint32_t result = 0;
  BrainfuckRecursion_run_ops(ops, ops_count, tape, &result);

  BrainfuckRecursion_Tape_free(tape);
  BrainfuckRecursion_free_ops(ops, ops_count);

  return result;
}

typedef struct {
  const char *program;
  const char *warmup_program;
  uint32_t result_val;
} BrainfuckRecursionData;

void BrainfuckRecursion_prepare(Benchmark *self) {
  BrainfuckRecursionData *data = (BrainfuckRecursionData *)self->data;
  data->program = Helper_config_s(self->name, "program");
  data->warmup_program = Helper_config_s(self->name, "warmup_program");
  data->result_val = 0;
}

void BrainfuckRecursion_warmup(Benchmark *self) {
  BrainfuckRecursionData *data = (BrainfuckRecursionData *)self->data;
  int64_t warmup_iters = Helper_config_i64(self->name, "warmup_iterations");

  if (warmup_iters == 0) {
    warmup_iters = self->iterations(self);
    warmup_iters = (int64_t)(warmup_iters * 0.2);
    if (warmup_iters < 1)
      warmup_iters = 1;
  }

  for (int64_t i = 0; i < warmup_iters; i++) {
    BrainfuckRecursion_run_program(data->warmup_program);
  }
}

void BrainfuckRecursion_run(Benchmark *self, int iteration_id) {
  BrainfuckRecursionData *data = (BrainfuckRecursionData *)self->data;

  if (iteration_id == 0) {
    data->result_val = 0;
  }

  uint32_t run_result = BrainfuckRecursion_run_program(data->program);
  data->result_val += run_result;
}

uint32_t BrainfuckRecursion_checksum(Benchmark *self) {
  BrainfuckRecursionData *data = (BrainfuckRecursionData *)self->data;
  return data->result_val;
}

void BrainfuckRecursion_cleanup(Benchmark *self) {
  BrainfuckRecursionData *data = (BrainfuckRecursionData *)self->data;
}

Benchmark *BrainfuckRecursion_create(void) {
  Benchmark *bench = Benchmark_create("Brainfuck::Recursion");

  BrainfuckRecursionData *data = malloc(sizeof(BrainfuckRecursionData));
  data->program = NULL;
  data->warmup_program = NULL;
  data->result_val = 0;

  bench->data = data;
  bench->prepare = BrainfuckRecursion_prepare;
  bench->warmup = BrainfuckRecursion_warmup;
  bench->run = BrainfuckRecursion_run;
  bench->checksum = BrainfuckRecursion_checksum;
  bench->cleanup = BrainfuckRecursion_cleanup;

  return bench;
}

typedef struct {
  char c;
  double prob;
} Fasta_Gene;

typedef struct {
  int64_t n;
  char *result_str;
  size_t result_capacity;
  size_t result_length;
  uint32_t result_val;
} FastaData;

static void Fasta_grow_result(FastaData *self, size_t needed) {
  size_t min_capacity = self->result_length + needed + 1;
  if (min_capacity <= self->result_capacity)
    return;

  size_t new_capacity =
      self->result_capacity ? self->result_capacity * 2 : 1024;
  while (new_capacity < min_capacity)
    new_capacity *= 2;

  self->result_str = realloc(self->result_str, new_capacity);
  self->result_capacity = new_capacity;
}

static void Fasta_append(FastaData *self, const char *str) {
  size_t len = strlen(str);
  Fasta_grow_result(self, len + 1);
  memcpy(self->result_str + self->result_length, str, len);
  self->result_length += len;
  self->result_str[self->result_length] = '\0';
}

static void Fasta_append_char(FastaData *self, char c) {
  Fasta_grow_result(self, 2);
  self->result_str[self->result_length++] = c;
  self->result_str[self->result_length] = '\0';
}

static void Fasta_append_substring(FastaData *self, const char *str,
                                   size_t len) {
  Fasta_grow_result(self, len + 1);
  memcpy(self->result_str + self->result_length, str, len);
  self->result_length += len;
  self->result_str[self->result_length] = '\0';
}

static char Fasta_select_random(Fasta_Gene *genelist, size_t size) {
  double r = Helper_next_float(1.0);
  if (r < genelist[0].prob)
    return genelist[0].c;

  int lo = 0, hi = size - 1;
  while (hi > lo + 1) {
    int i = (hi + lo) / 2;
    if (r < genelist[i].prob)
      hi = i;
    else
      lo = i;
  }
  return genelist[hi].c;
}

static void Fasta_make_random_fasta(FastaData *self, const char *id,
                                    const char *desc, Fasta_Gene *genelist,
                                    size_t genelist_size, int n_iter) {
  char header[256];
  snprintf(header, sizeof(header), ">%s %s\n", id, desc);
  Fasta_append(self, header);

  const int LINE_LENGTH = 60;
  int todo = n_iter;

  while (todo > 0) {
    int m = (todo < LINE_LENGTH) ? todo : LINE_LENGTH;

    for (int i = 0; i < m; i++) {
      char c = Fasta_select_random(genelist, genelist_size);
      Fasta_append_char(self, c);
    }
    Fasta_append_char(self, '\n');
    todo -= LINE_LENGTH;
  }
}

static void Fasta_make_repeat_fasta(FastaData *self, const char *id,
                                    const char *desc, const char *s,
                                    int n_iter) {
  char header[256];
  snprintf(header, sizeof(header), ">%s %s\n", id, desc);
  Fasta_append(self, header);

  const int LINE_LENGTH = 60;
  int todo = n_iter;
  size_t pos = 0;
  size_t s_len = strlen(s);

  while (todo > 0) {
    int m = (todo < LINE_LENGTH) ? todo : LINE_LENGTH;
    int remaining = m;

    while (remaining > 0) {
      int chunk = (remaining < (int)(s_len - pos)) ? remaining : (s_len - pos);
      Fasta_append_substring(self, s + pos, chunk);
      pos = (pos + chunk) % s_len;
      remaining -= chunk;
    }

    Fasta_append_char(self, '\n');
    todo -= LINE_LENGTH;
  }
}

void Fasta_prepare(Benchmark *self) {
  FastaData *data = (FastaData *)self->data;

  data->result_length = 0;
  if (data->result_str) {
    free(data->result_str);
    data->result_str = NULL;
  }
  data->result_capacity = 0;
}

void Fasta_run(Benchmark *self, int iteration_id) {
  FastaData *data = (FastaData *)self->data;

  if (iteration_id == 0 && data->result_str == NULL) {
    data->result_str = malloc(1024);
    data->result_capacity = 1024;
    data->result_str[0] = '\0';
    data->result_length = 0;
  }

  Fasta_Gene IUB[] = {{'a', 0.27},
                      {'c', 0.39},
                      {'g', 0.51},
                      {'t', 0.78},
                      {'B', 0.8},
                      {'D', 0.8200000000000001},
                      {'H', 0.8400000000000001},
                      {'K', 0.8600000000000001},
                      {'M', 0.8800000000000001},
                      {'N', 0.9000000000000001},
                      {'R', 0.9200000000000002},
                      {'S', 0.9400000000000002},
                      {'V', 0.9600000000000002},
                      {'W', 0.9800000000000002},
                      {'Y', 1.0000000000000002}};

  Fasta_Gene HOMO[] = {{'a', 0.302954942668},
                       {'c', 0.5009432431601},
                       {'g', 0.6984905497992},
                       {'t', 1.0}};

  const char *ALU =
      "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTC"
      "AGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCG"
      "TGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGG"
      "AGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

  Fasta_make_repeat_fasta(data, "ONE", "Homo sapiens alu", ALU,
                          (int)data->n * 2);
  Fasta_make_random_fasta(data, "TWO", "IUB ambiguity codes", IUB,
                          sizeof(IUB) / sizeof(IUB[0]), (int)data->n * 3);
  Fasta_make_random_fasta(data, "THREE", "Homo sapiens frequency", HOMO,
                          sizeof(HOMO) / sizeof(HOMO[0]), (int)data->n * 5);
}

uint32_t Fasta_checksum(Benchmark *self) {
  FastaData *data = (FastaData *)self->data;

  return Helper_checksum_string(data->result_str);
}

void Fasta_cleanup(Benchmark *self) {
  FastaData *data = (FastaData *)self->data;
  if (data->result_str) {
    free(data->result_str);
    data->result_str = NULL;
  }
}

Benchmark *Fasta_create(void) {
  Benchmark *bench = Benchmark_create("CLBG::Fasta");

  FastaData *data = malloc(sizeof(FastaData));
  data->n = Helper_config_i64("CLBG::Fasta", "n");
  if (data->n == 0) {
    data->n = 1000;
  }

  data->result_str = NULL;
  data->result_capacity = 0;
  data->result_length = 0;
  data->result_val = 0;

  bench->data = data;
  bench->prepare = Fasta_prepare;
  bench->run = Fasta_run;
  bench->checksum = Fasta_checksum;
  bench->cleanup = Fasta_cleanup;

  return bench;
}

typedef struct {
  int64_t n;
  uint32_t result_val;
} FannkuchreduxData;

static void fannkuchredux_swap(int *a, int *b) {
  int temp = *a;
  *a = *b;
  *b = temp;
}

static void fannkuchredux_calculate(int n, int *checksum, int *max_flips) {

  int perm1[32];
  int perm[32];
  int count[32];

  if (n > 32)
    n = 32;

  for (int i = 0; i < n; i++)
    perm1[i] = i;

  *max_flips = 0;
  *checksum = 0;
  int permCount = 0;
  int r = n;

  while (1) {
    while (r > 1) {
      count[r - 1] = r;
      r--;
    }

    memcpy(perm, perm1, n * sizeof(int));
    int flipsCount = 0;

    int k = perm[0];
    while (k != 0) {
      int k2 = (k + 1) >> 1;
      for (int i = 0; i < k2; i++) {
        int j = k - i;
        fannkuchredux_swap(&perm[i], &perm[j]);
      }
      flipsCount++;
      k = perm[0];
    }

    if (flipsCount > *max_flips)
      *max_flips = flipsCount;
    *checksum += (permCount % 2 == 0) ? flipsCount : -flipsCount;

    while (1) {
      if (r == n) {
        return;
      }

      int perm0 = perm1[0];
      for (int i = 0; i < r; i++) {
        perm1[i] = perm1[i + 1];
      }
      perm1[r] = perm0;

      count[r]--;
      if (count[r] > 0)
        break;
      r++;
    }
    permCount++;
  }
}

void Fannkuchredux_prepare(Benchmark *self) {
  FannkuchreduxData *data = (FannkuchreduxData *)self->data;
  data->n = Helper_config_i64(self->name, "n");
  if (data->n == 0) {
    data->n = 12;
  }
  data->result_val = 0;
}

void Fannkuchredux_run(Benchmark *self, int iteration_id) {
  FannkuchreduxData *data = (FannkuchreduxData *)self->data;

  int checksum, max_flips;
  fannkuchredux_calculate((int)data->n, &checksum, &max_flips);

  data->result_val =
      (data->result_val + (uint32_t)(checksum * 100 + max_flips)) & 0xFFFFFFFFu;
}

uint32_t Fannkuchredux_checksum(Benchmark *self) {
  FannkuchreduxData *data = (FannkuchreduxData *)self->data;
  return data->result_val;
}

void Fannkuchredux_cleanup(Benchmark *self) {
  FannkuchreduxData *data = (FannkuchreduxData *)self->data;
}

Benchmark *Fannkuchredux_create(void) {
  Benchmark *bench = Benchmark_create("CLBG::Fannkuchredux");

  FannkuchreduxData *data = malloc(sizeof(FannkuchreduxData));
  data->n = 0;
  data->result_val = 0;

  bench->data = data;
  bench->prepare = Fannkuchredux_prepare;
  bench->run = Fannkuchredux_run;
  bench->checksum = Fannkuchredux_checksum;
  bench->cleanup = Fannkuchredux_cleanup;

  return bench;
}

typedef struct {
  int64_t n;
  char *seq;
  size_t seq_length;
  char *result_str;
  size_t result_capacity;
  size_t result_length;
} KnuckeotideData;

typedef struct {
  char *key;
  int count;
} FrequencyEntry;

static int compare_entries(const void *a, const void *b) {
  const FrequencyEntry *ea = (const FrequencyEntry *)a;
  const FrequencyEntry *eb = (const FrequencyEntry *)b;

  if (ea->count != eb->count) {
    return eb->count - ea->count;
  }

  return strcmp(ea->key, eb->key);
}

static void Knuckeotide_grow_result(KnuckeotideData *self, size_t needed) {
  size_t new_capacity = self->result_capacity;
  while (self->result_length + needed >= new_capacity) {
    new_capacity = new_capacity ? new_capacity * 2 : 1024;
  }
  if (new_capacity > self->result_capacity) {
    self->result_str = realloc(self->result_str, new_capacity);
    self->result_capacity = new_capacity;
  }
}

static void Knuckeotide_append(KnuckeotideData *self, const char *str) {
  size_t len = strlen(str);
  Knuckeotide_grow_result(self, len + 1);
  memcpy(self->result_str + self->result_length, str, len);
  self->result_length += len;
  self->result_str[self->result_length] = '\0';
}

static void Knuckeotide_sort_by_freq(KnuckeotideData *self, int length) {
#define TABLE_SIZE 8192
  FrequencyEntry *table = calloc(TABLE_SIZE, sizeof(FrequencyEntry));

  int n = (int)(self->seq_length - length + 1);

  for (int i = 0; i < n; i++) {
    char key[length + 1];
    strncpy(key, self->seq + i, length);
    key[length] = '\0';

    unsigned int hash = 0;
    for (int j = 0; j < length; j++) {
      hash = hash * 31 + key[j];
    }
    hash %= TABLE_SIZE;

    if (table[hash].key == NULL) {
      table[hash].key = strdup(key);
      table[hash].count = 1;
    } else if (strcmp(table[hash].key, key) == 0) {
      table[hash].count++;
    } else {

      int j = (hash + 1) % TABLE_SIZE;
      while (j != hash && table[j].key != NULL &&
             strcmp(table[j].key, key) != 0) {
        j = (j + 1) % TABLE_SIZE;
      }
      if (table[j].key == NULL) {
        table[j].key = strdup(key);
        table[j].count = 1;
      } else {
        table[j].count++;
      }
    }
  }

  FrequencyEntry *entries = malloc(TABLE_SIZE * sizeof(FrequencyEntry));
  int entry_count = 0;
  for (int i = 0; i < TABLE_SIZE; i++) {
    if (table[i].key != NULL) {
      entries[entry_count++] = table[i];
    }
  }

  qsort(entries, entry_count, sizeof(FrequencyEntry), compare_entries);

  for (int i = 0; i < entry_count; i++) {
    double percent = (entries[i].count * 100.0) / n;

    for (char *p = entries[i].key; *p; p++) {
      if (*p >= 'a' && *p <= 'z')
        *p = *p - 'a' + 'A';
    }

    char line[256];
    snprintf(line, sizeof(line), "%s %.3f\n", entries[i].key, percent);
    Knuckeotide_append(self, line);
    free(entries[i].key);
  }
  Knuckeotide_append(self, "\n");

  free(table);
  free(entries);
}

static void Knuckeotide_find_seq(KnuckeotideData *self, const char *s) {
  size_t s_len = strlen(s);
  int count = 0;

  for (size_t i = 0; i <= self->seq_length - s_len; i++) {
    if (strncasecmp(self->seq + i, s, s_len) == 0) {
      count++;
    }
  }

  char upper_s[32];
  strcpy(upper_s, s);
  for (char *p = upper_s; *p; p++) {
    if (*p >= 'a' && *p <= 'z')
      *p = *p - 'a' + 'A';
  }

  char line[256];
  snprintf(line, sizeof(line), "%d\t%s\n", count, upper_s);
  Knuckeotide_append(self, line);
}

void Knuckeotide_prepare(Benchmark *self) {
  KnuckeotideData *data = (KnuckeotideData *)self->data;

  data->result_length = 0;
  if (data->result_str) {
    free(data->result_str);
    data->result_str = NULL;
  }
  data->result_capacity = 0;

  FastaData fasta_instance;
  memset(&fasta_instance, 0, sizeof(FastaData));
  fasta_instance.n = data->n;
  fasta_instance.result_str = NULL;
  fasta_instance.result_capacity = 0;
  fasta_instance.result_length = 0;

  Benchmark temp_bench;
  memset(&temp_bench, 0, sizeof(Benchmark));
  temp_bench.data = &fasta_instance;
  temp_bench.name = "CLBG::Fasta";

  Fasta_run(&temp_bench, 0);

  if (!fasta_instance.result_str) {
    printf("  ERROR: Fasta returned NULL result\n");
    data->seq = strdup("");
    data->seq_length = 0;
    return;
  }

  const char *result = fasta_instance.result_str;
  bool in_three = false;
  data->seq_length = 0;

  if (data->seq)
    free(data->seq);
  data->seq = malloc(strlen(result) + 1);

  const char *ptr = result;
  while (*ptr) {
    if (strncmp(ptr, ">THREE", 6) == 0) {
      in_three = true;
      while (*ptr && *ptr != '\n')
        ptr++;
      if (*ptr == '\n')
        ptr++;
      continue;
    }

    if (in_three) {
      if (*ptr == '>')
        break;

      if (*ptr != '\n') {
        data->seq[data->seq_length++] = *ptr;
      }
    }

    ptr++;
  }
  data->seq[data->seq_length] = '\0';

  free(fasta_instance.result_str);
}

void Knuckeotide_run(Benchmark *self, int iteration_id) {
  KnuckeotideData *data = (KnuckeotideData *)self->data;

  if (iteration_id == 0 && data->result_str == NULL) {
    data->result_str = malloc(1024);
    data->result_capacity = 1024;
    data->result_str[0] = '\0';
    data->result_length = 0;
  }

  for (int i = 1; i <= 2; i++) {
    Knuckeotide_sort_by_freq(data, i);
  }

  const char *searches[] = {"ggt", "ggta", "ggtatt", "ggtattttaatt",
                            "ggtattttaatttatagt"};
  for (int i = 0; i < 5; i++) {
    Knuckeotide_find_seq(data, searches[i]);
  }
}

uint32_t Knuckeotide_checksum(Benchmark *self) {
  KnuckeotideData *data = (KnuckeotideData *)self->data;

  if (!data->result_str) {
    return 0;
  }

  uint32_t checksum = Helper_checksum_string(data->result_str);
  return checksum;
}

void Knuckeotide_cleanup(Benchmark *self) {
  KnuckeotideData *data = (KnuckeotideData *)self->data;

  if (data->seq) {
    free(data->seq);
    data->seq = NULL;
  }

  if (data->result_str) {
    free(data->result_str);
    data->result_str = NULL;
  }

  data->result_capacity = 0;
  data->result_length = 0;
  data->seq_length = 0;
}

Benchmark *Knuckeotide_create(void) {
  Benchmark *bench = Benchmark_create("CLBG::Knuckeotide");

  KnuckeotideData *data = malloc(sizeof(KnuckeotideData));

  data->n = Helper_config_i64("CLBG::Knuckeotide", "n");
  if (data->n == 0) {
    data->n = 1000;
  }

  data->seq = NULL;
  data->seq_length = 0;
  data->result_str = NULL;
  data->result_capacity = 0;
  data->result_length = 0;

  bench->data = data;
  bench->prepare = Knuckeotide_prepare;
  bench->run = Knuckeotide_run;
  bench->checksum = Knuckeotide_checksum;
  bench->cleanup = Knuckeotide_cleanup;

  return bench;
}

static const char *REGEXDNA_PATTERNS[] = {
    "agggtaaa|tttaccct",         "[cgt]gggtaaa|tttaccc[acg]",
    "a[act]ggtaaa|tttacc[agt]t", "ag[act]gtaaa|tttac[agt]ct",
    "agg[act]taaa|ttta[agt]cct", "aggg[acg]aaa|ttt[cgt]ccct",
    "agggt[cgt]aa|tt[acg]accct", "agggta[cgt]a|t[acg]taccct",
    "agggtaa[cgt]|[acg]ttaccct"};
static const int REGEXDNA_PATTERNS_COUNT = 9;

static const struct {
  char from;
  const char *to;
  int len;
} REGEXDNA_REPLACEMENTS[] = {
    {'B', "(c|g|t)", 7}, {'D', "(a|g|t)", 7}, {'H', "(a|c|t)", 7},
    {'K', "(g|t)", 5},   {'M', "(a|c)", 5},   {'N', "(a|c|g|t)", 9},
    {'R', "(a|g)", 5},   {'S', "(c|t)", 5},   {'V', "(a|c|g)", 7},
    {'W', "(a|t)", 5},   {'Y', "(c|t)", 5},
};
static const int REGEXDNA_REPLACEMENTS_COUNT =
    sizeof(REGEXDNA_REPLACEMENTS) / sizeof(REGEXDNA_REPLACEMENTS[0]);

typedef struct {
  char *seq;
  int seq_len;
  int ilen;
  int clen;
  char *result_str;
  size_t result_capacity;
  size_t result_length;

  pcre2_code *compiled_patterns[9];
  pcre2_match_data *match_data[9];
} RegexDnaData;

static void RegexDna_grow_result(RegexDnaData *self, size_t needed) {
  size_t min_capacity = self->result_length + needed + 1;
  if (min_capacity <= self->result_capacity)
    return;

  size_t new_capacity =
      self->result_capacity ? self->result_capacity * 2 : 1024;
  while (new_capacity < min_capacity)
    new_capacity *= 2;

  char *new_buffer = realloc(self->result_str, new_capacity);
  if (!new_buffer) {
    fprintf(stderr, "RegexDna_grow_result: Failed to reallocate memory\n");
    return;
  }

  self->result_str = new_buffer;
  self->result_capacity = new_capacity;
}

static void RegexDna_append(RegexDnaData *self, const char *str) {
  size_t len = strlen(str);
  RegexDna_grow_result(self, len + 1);
  memcpy(self->result_str + self->result_length, str, len);
  self->result_length += len;
  self->result_str[self->result_length] = '\0';
}

static size_t RegexDna_count_pattern_optimized(RegexDnaData *self,
                                               int pattern_idx) {
  pcre2_code *re = self->compiled_patterns[pattern_idx];
  pcre2_match_data *match_data = self->match_data[pattern_idx];

  if (re == NULL || match_data == NULL) {
    return 0;
  }

  size_t count = 0;
  PCRE2_SIZE start_offset = 0;
  PCRE2_SPTR subject = (PCRE2_SPTR)self->seq;
  PCRE2_SIZE subject_length = self->seq_len;

  while (1) {
    int rc = pcre2_jit_match(re, subject, subject_length, start_offset, 0,
                             match_data, NULL);

    if (rc < 0) {
      if (rc == PCRE2_ERROR_NOMATCH)
        break;
      break;
    }

    count++;

    PCRE2_SIZE *ovector = pcre2_get_ovector_pointer(match_data);
    start_offset = ovector[1];

    if (ovector[0] == ovector[1]) {
      start_offset++;
    }

    if (start_offset > subject_length)
      break;
  }

  return count;
}

void RegexDna_prepare(Benchmark *self) {
  RegexDnaData *data = (RegexDnaData *)self->data;

  int64_t n = Helper_config_i64(self->name, "n");
  if (n == 0) {
    n = 1000;
  }

  if (data->result_str) {
    free(data->result_str);
  }
  data->result_str = NULL;
  data->result_capacity = 0;
  data->result_length = 0;

  FastaData fasta_instance;
  memset(&fasta_instance, 0, sizeof(FastaData));
  fasta_instance.n = n;
  fasta_instance.result_str = NULL;
  fasta_instance.result_capacity = 0;
  fasta_instance.result_length = 0;

  Benchmark temp_bench;
  memset(&temp_bench, 0, sizeof(Benchmark));
  temp_bench.data = &fasta_instance;
  temp_bench.name = "CLBG::Fasta";

  Fasta_run(&temp_bench, 0);

  if (!fasta_instance.result_str || fasta_instance.result_length == 0) {
    fprintf(stderr, "Fasta returned empty result\n");
    data->seq = strdup("");
    data->seq_len = 0;
    data->ilen = 0;
    data->clen = 0;
    if (fasta_instance.result_str)
      free(fasta_instance.result_str);
    return;
  }

  data->ilen = 0;
  data->clen = 0;

  data->seq = malloc(fasta_instance.result_length + 1);
  if (!data->seq) {
    fprintf(stderr, "Failed to allocate memory for seq\n");
    free(fasta_instance.result_str);
    return;
  }

  size_t seq_pos = 0;
  char *current = fasta_instance.result_str;

  while (*current) {
    char *line_start = current;

    while (*current && *current != '\n') {
      current++;
    }

    int line_length = current - line_start;
    data->ilen += line_length + 1;

    if (line_length > 0 && line_start[0] != '>') {
      memcpy(data->seq + seq_pos, line_start, line_length);
      seq_pos += line_length;
    }

    if (*current == '\n') {
      current++;
    }
  }

  data->seq[seq_pos] = '\0';
  data->seq_len = seq_pos;
  data->clen = seq_pos;

  free(fasta_instance.result_str);

  for (int i = 0; i < REGEXDNA_PATTERNS_COUNT; i++) {
    if (data->compiled_patterns[i]) {
      pcre2_code_free(data->compiled_patterns[i]);
      data->compiled_patterns[i] = NULL;
    }
    if (data->match_data[i]) {
      pcre2_match_data_free(data->match_data[i]);
      data->match_data[i] = NULL;
    }
  }

  for (int i = 0; i < REGEXDNA_PATTERNS_COUNT; i++) {
    int errornumber;
    PCRE2_SIZE erroroffset;

    data->compiled_patterns[i] = pcre2_compile(
        (PCRE2_SPTR)REGEXDNA_PATTERNS[i], PCRE2_ZERO_TERMINATED,
        PCRE2_UTF | PCRE2_NO_UTF_CHECK, &errornumber, &erroroffset, NULL);

    if (data->compiled_patterns[i]) {
      pcre2_jit_compile(data->compiled_patterns[i], PCRE2_JIT_COMPLETE);
      data->match_data[i] = pcre2_match_data_create_from_pattern(
          data->compiled_patterns[i], NULL);
    } else {
      PCRE2_UCHAR buffer[256];
      pcre2_get_error_message(errornumber, buffer, sizeof(buffer));
      fprintf(stderr, "PCRE2 compilation failed for pattern %d: %s\n", i,
              buffer);
      data->match_data[i] = NULL;
    }
  }
}

void RegexDna_run(Benchmark *self, int iteration_id) {
  RegexDnaData *data = (RegexDnaData *)self->data;

  char buffer[256];
  for (int i = 0; i < REGEXDNA_PATTERNS_COUNT; i++) {
    size_t count = RegexDna_count_pattern_optimized(data, i);
    snprintf(buffer, sizeof(buffer), "%s %zu\n", REGEXDNA_PATTERNS[i], count);
    RegexDna_append(data, buffer);
  }

  char *seq2 = malloc(data->seq_len * 9 + 1);
  if (!seq2) {
    fprintf(stderr, "Failed to allocate memory for seq2\n");
    return;
  }

  int seq2_len = 0;
  for (int i = 0; i < data->seq_len; i++) {
    char c = data->seq[i];
    int found = 0;

    for (int j = 0; j < REGEXDNA_REPLACEMENTS_COUNT; j++) {
      if (c == REGEXDNA_REPLACEMENTS[j].from) {
        memcpy(seq2 + seq2_len, REGEXDNA_REPLACEMENTS[j].to,
               REGEXDNA_REPLACEMENTS[j].len);
        seq2_len += REGEXDNA_REPLACEMENTS[j].len;
        found = 1;
        break;
      }
    }

    if (!found) {
      seq2[seq2_len++] = c;
    }
  }
  seq2[seq2_len] = '\0';

  snprintf(buffer, sizeof(buffer), "\n%d\n%d\n%d\n", data->ilen, data->clen,
           seq2_len);
  RegexDna_append(data, buffer);

  free(seq2);
}

uint32_t RegexDna_checksum(Benchmark *self) {
  RegexDnaData *data = (RegexDnaData *)self->data;

  if (!data->result_str) {
    return 0;
  }

  uint32_t checksum = Helper_checksum_string(data->result_str);
  return checksum;
}

void RegexDna_cleanup(Benchmark *self) {
  RegexDnaData *data = (RegexDnaData *)self->data;

  if (!data)
    return;

  for (int i = 0; i < REGEXDNA_PATTERNS_COUNT; i++) {
    if (data->compiled_patterns[i]) {
      pcre2_code_free(data->compiled_patterns[i]);
      data->compiled_patterns[i] = NULL;
    }
    if (data->match_data[i]) {
      pcre2_match_data_free(data->match_data[i]);
      data->match_data[i] = NULL;
    }
  }

  if (data->seq) {
    free(data->seq);
    data->seq = NULL;
  }

  if (data->result_str) {
    free(data->result_str);
    data->result_str = NULL;
  }

  data->result_capacity = 0;
  data->result_length = 0;
  data->seq_len = 0;
  data->ilen = 0;
  data->clen = 0;
}

Benchmark *RegexDna_create(void) {
  Benchmark *bench = Benchmark_create("CLBG::RegexDna");

  RegexDnaData *data = calloc(1, sizeof(RegexDnaData));

  data->seq = NULL;
  data->result_str = NULL;
  data->result_capacity = 0;
  data->result_length = 0;

  for (int i = 0; i < REGEXDNA_PATTERNS_COUNT; i++) {
    data->compiled_patterns[i] = NULL;
    data->match_data[i] = NULL;
  }

  bench->data = data;
  bench->prepare = RegexDna_prepare;
  bench->run = RegexDna_run;
  bench->checksum = RegexDna_checksum;
  bench->cleanup = RegexDna_cleanup;

  return bench;
}

typedef struct {
  char *input;
  uint32_t checksum_val;
} RevcompData;

static char Revcomp_complement(char c) {
  static const char *from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
  static const char *to = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";
  static char lookup[256];
  static int initialized = 0;

  if (!initialized) {
    for (int i = 0; i < 256; i++)
      lookup[i] = (char)i;
    for (size_t i = 0; from[i] && to[i]; i++) {
      lookup[(unsigned char)from[i]] = to[i];
    }
    initialized = 1;
  }

  return lookup[(unsigned char)c];
}

static char *Revcomp_process(const char *input) {
  size_t len = strlen(input);

  static char lookup[256];
  static int initialized = 0;

  if (!initialized) {
    for (int i = 0; i < 256; i++)
      lookup[i] = (char)i;

    const char *from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
    const char *to = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";

    for (size_t i = 0; from[i] && to[i]; i++) {
      lookup[(unsigned char)from[i]] = to[i];
    }
    initialized = 1;
  }

  size_t result_len = len + (len / 60) + 1;
  if (len % 60 == 0 && len > 0)
    result_len--;

  char *result = malloc(result_len + 1);
  if (!result)
    return NULL;

  char *out = result;
  size_t processed = 0;

  while (processed < len) {

    size_t block_size = 60;
    if (len - processed < 60) {
      block_size = len - processed;
    }

    for (size_t i = 0; i < block_size; i++) {
      char c = input[len - 1 - processed - i];
      *out++ = lookup[(unsigned char)c];
    }

    *out++ = '\n';
    processed += block_size;
  }

  if (len > 0 && len % 60 == 0) {
    out--;
  }

  *out = '\0';
  return result;
}

void Revcomp_prepare(Benchmark *self) {
  RevcompData *data = (RevcompData *)self->data;

  if (data->input)
    free(data->input);
  data->input = NULL;
  data->checksum_val = 0;

  int64_t n = Helper_config_i64(self->name, "n");
  if (n == 0)
    n = 1000;

  FastaData fasta_instance;
  memset(&fasta_instance, 0, sizeof(FastaData));
  fasta_instance.n = n;
  fasta_instance.result_str = NULL;
  fasta_instance.result_capacity = 0;
  fasta_instance.result_length = 0;

  Benchmark temp_bench;
  memset(&temp_bench, 0, sizeof(Benchmark));
  temp_bench.data = &fasta_instance;
  temp_bench.name = "CLBG::Fasta";

  Fasta_run(&temp_bench, 0);

  if (!fasta_instance.result_str) {
    data->input = strdup("");
    if (fasta_instance.result_str)
      free(fasta_instance.result_str);
    return;
  }

  char *ptr = fasta_instance.result_str;
  size_t buffer_size = 0;
  size_t buffer_capacity = 0;
  char *buffer = NULL;

  while (*ptr) {
    char *line_start = ptr;
    while (*ptr && *ptr != '\n')
      ptr++;
    size_t line_len = ptr - line_start;

    if (line_len > 0) {
      if (line_start[0] == '>') {

        const char *sep = "\n---\n";
        size_t sep_len = 5;

        if (buffer_size + sep_len + 1 > buffer_capacity) {
          buffer_capacity = (buffer_size + sep_len + 1) * 2;
          char *new_buf = realloc(buffer, buffer_capacity);
          if (!new_buf) {
            free(buffer);
            free(fasta_instance.result_str);
            data->input = strdup("");
            return;
          }
          buffer = new_buf;
        }
        memcpy(buffer + buffer_size, sep, sep_len);
        buffer_size += sep_len;
      } else {

        if (buffer_size + line_len + 1 > buffer_capacity) {
          buffer_capacity = (buffer_size + line_len + 1) * 2;
          char *new_buf = realloc(buffer, buffer_capacity);
          if (!new_buf) {
            free(buffer);
            free(fasta_instance.result_str);
            data->input = strdup("");
            return;
          }
          buffer = new_buf;
        }
        memcpy(buffer + buffer_size, line_start, line_len);
        buffer_size += line_len;
      }
    }

    if (*ptr == '\n')
      ptr++;
  }

  if (buffer) {
    buffer[buffer_size] = '\0';
    data->input = buffer;
  } else {
    data->input = strdup("");
  }

  free(fasta_instance.result_str);
}

void Revcomp_run(Benchmark *self, int iteration_id) {
  RevcompData *data = (RevcompData *)self->data;

  if (!data->input)
    return;

  char *processed = Revcomp_process(data->input);
  if (!processed)
    return;

  data->checksum_val += Helper_checksum_string(processed);

  free(processed);
}

uint32_t Revcomp_checksum(Benchmark *self) {
  RevcompData *data = (RevcompData *)self->data;
  return data->checksum_val;
}

void Revcomp_cleanup(Benchmark *self) {
  RevcompData *data = (RevcompData *)self->data;

  if (data->input)
    free(data->input);
}

Benchmark *Revcomp_create(void) {
  Benchmark *bench = Benchmark_create("CLBG::Revcomp");

  RevcompData *data = calloc(1, sizeof(RevcompData));

  bench->data = data;
  bench->prepare = Revcomp_prepare;
  bench->run = Revcomp_run;
  bench->checksum = Revcomp_checksum;
  bench->cleanup = Revcomp_cleanup;

  return bench;
}

typedef struct {
  int64_t w;
  int64_t h;
  uint8_t *result_bin;
  size_t result_size;
  size_t result_capacity;
} MandelbrotData;

static void Mandelbrot_grow_result(MandelbrotData *self, size_t needed) {
  size_t new_capacity = self->result_capacity;
  while (self->result_size + needed >= new_capacity) {
    new_capacity = new_capacity ? new_capacity * 2 : 1024;
  }
  if (new_capacity > self->result_capacity) {
    self->result_bin = realloc(self->result_bin, new_capacity);
    if (!self->result_bin) {
      fprintf(stderr, "Mandelbrot_grow_result: Failed to reallocate memory\n");
      return;
    }
    self->result_capacity = new_capacity;
  }
}

static void Mandelbrot_append(MandelbrotData *self, const uint8_t *data,
                              size_t size) {
  Mandelbrot_grow_result(self, size);
  memcpy(self->result_bin + self->result_size, data, size);
  self->result_size += size;
}

void Mandelbrot_prepare(Benchmark *self) {
  MandelbrotData *data = (MandelbrotData *)self->data;

  data->w = Helper_config_i64(self->name, "w");
  data->h = Helper_config_i64(self->name, "h");

  if (data->w == 0)
    data->w = 200;
  if (data->h == 0)
    data->h = 200;

  data->result_size = 0;
}

void Mandelbrot_run(Benchmark *self, int iteration_id) {
  MandelbrotData *data = (MandelbrotData *)self->data;

  volatile int w = (int)data->w;
  int h = (int)data->h;

  char header[256];
  int header_len = snprintf(header, sizeof(header), "P4\n%d %d\n", w, h);
  Mandelbrot_append(data, (uint8_t *)header, header_len);

  const int ITER = 50;
  const double LIMIT = 2.0;

  int bit_num = 0;
  uint8_t byte_acc = 0;

  for (int y = 0; y < h; y++) {
    double ci = 2.0 * y / (double)h - 1.0;

    for (int x = 0; x < w; x++) {
      double cr = 2.0 * x / (double)w - 1.5;

      double zr = 0.0, zi = 0.0;
      double tr = 0.0, ti = 0.0;

      int i = 0;
      while (i < ITER && tr + ti <= LIMIT * LIMIT) {
        zi = 2.0 * zr * zi + ci;
        zr = tr - ti + cr;
        tr = zr * zr;
        ti = zi * zi;
        i++;
      }

      byte_acc <<= 1;
      if (tr + ti <= LIMIT * LIMIT) {
        byte_acc |= 0x01;
      }
      bit_num++;

      if (bit_num == 8) {
        Mandelbrot_append(data, &byte_acc, 1);
        byte_acc = 0;
        bit_num = 0;
      } else if (x == w - 1) {

        byte_acc <<= (8 - (w % 8));
        Mandelbrot_append(data, &byte_acc, 1);
        byte_acc = 0;
        bit_num = 0;
      }
    }
  }
}

uint32_t Mandelbrot_checksum(Benchmark *self) {
  MandelbrotData *data = (MandelbrotData *)self->data;

  if (!data->result_bin || data->result_size == 0) {
    return 0;
  }

  return Helper_checksum_bytes(data->result_bin, data->result_size);
}

void Mandelbrot_cleanup(Benchmark *self) {
  MandelbrotData *data = (MandelbrotData *)self->data;

  if (data->result_bin) {
    free(data->result_bin);
    data->result_bin = NULL;
  }

  data->result_size = 0;
  data->result_capacity = 0;
}

Benchmark *Mandelbrot_create(void) {
  Benchmark *bench = Benchmark_create("CLBG::Mandelbrot");

  MandelbrotData *data = calloc(1, sizeof(MandelbrotData));

  data->w = Helper_config_i64("CLBG::Mandelbrot", "w");
  data->h = Helper_config_i64("CLBG::Mandelbrot", "h");

  if (data->w == 0)
    data->w = 200;
  if (data->h == 0)
    data->h = 200;

  data->result_bin = NULL;
  data->result_size = 0;
  data->result_capacity = 0;

  bench->data = data;
  bench->prepare = Mandelbrot_prepare;
  bench->run = Mandelbrot_run;
  bench->checksum = Mandelbrot_checksum;
  bench->cleanup = Mandelbrot_cleanup;

  return bench;
}

static double **matgen(int n) {
  double tmp = 1.0 / n / n;
  double **a = malloc(n * sizeof(double *));

  for (int i = 0; i < n; i++) {
    a[i] = malloc(n * sizeof(double));
    for (int j = 0; j < n; j++) {
      a[i][j] = tmp * (i - j) * (i + j);
    }
  }
  return a;
}

static void free_matrix(double **a, int n) {
  if (!a)
    return;
  for (int i = 0; i < n; i++) {
    free(a[i]);
  }
  free(a);
}

static double **transpose(double **b, int n) {
  double **b_t = malloc(n * sizeof(double *));
  for (int j = 0; j < n; j++) {
    b_t[j] = malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
      b_t[j][i] = b[i][j];
    }
  }
  return b_t;
}

typedef struct {
  int64_t n;
  uint32_t result_val;
  double **a;
  double **b;
} MatmulBaseData;

static uint32_t Matmul_checksum(Benchmark *self) {
  MatmulBaseData *data = (MatmulBaseData *)self->data;
  return data->result_val;
}

static void MatmulBase_prepare(Benchmark *self) {
  MatmulBaseData *data = (MatmulBaseData *)self->data;
  int n = (int)data->n;

  data->a = matgen(n);
  data->b = matgen(n);
  data->result_val = 0;
}

static void MatmulBase_cleanup(Benchmark *self) {
  MatmulBaseData *data = (MatmulBaseData *)self->data;
  int n = (int)data->n;

  if (data->a) {
    free_matrix(data->a, n);
    data->a = NULL;
  }
  if (data->b) {
    free_matrix(data->b, n);
    data->b = NULL;
  }
}

static double **matmul_sequential(double **a, double **b, int n) {
  double **b_t = transpose(b, n);
  double **c = malloc(n * sizeof(double *));

  for (int i = 0; i < n; i++) {
    c[i] = malloc(n * sizeof(double));
    double *ai = a[i];
    for (int j = 0; j < n; j++) {
      double s = 0.0;
      double *b_tj = b_t[j];

      for (int k = 0; k < n; k++) {
        s += ai[k] * b_tj[k];
      }
      c[i][j] = s;
    }
  }

  free_matrix(b_t, n);
  return c;
}

static void Matmul_run(Benchmark *self, int iteration_id) {
  MatmulBaseData *data = (MatmulBaseData *)self->data;
  int n = (int)data->n;

  double **c = matmul_sequential(data->a, data->b, n);
  double center_value = c[n >> 1][n >> 1];
  free_matrix(c, n);

  uint32_t iter_checksum = Helper_checksum_f64(center_value);
  data->result_val += iter_checksum;
}

Benchmark *Matmul_create(void) {
  Benchmark *bench = Benchmark_create("Matmul::Single");
  MatmulBaseData *data = malloc(sizeof(MatmulBaseData));

  data->n = Helper_config_i64("Matmul::Single", "n");
  if (data->n == 0)
    data->n = 100;
  data->result_val = 0;
  data->a = NULL;
  data->b = NULL;

  bench->data = data;
  bench->prepare = MatmulBase_prepare;
  bench->run = Matmul_run;
  bench->checksum = Matmul_checksum;
  bench->cleanup = MatmulBase_cleanup;

  return bench;
}

typedef struct {
  MatmulBaseData base;
  int num_threads;
} MatmulParallelData;

typedef struct {
  double **a;
  double **b_t;
  double **c;
  int n;
  int start_row;
  int end_row;
} MatmulThreadData;

static void *thread_func(void *arg) {
  MatmulThreadData *data = (MatmulThreadData *)arg;

  for (int i = data->start_row; i < data->end_row; i++) {
    double *ai = data->a[i];
    double *ci = data->c[i];

    for (int j = 0; j < data->n; j++) {
      double sum = 0.0;
      double *b_tj = data->b_t[j];

      for (int k = 0; k < data->n; k++) {
        sum += ai[k] * b_tj[k];
      }
      ci[j] = sum;
    }
  }
  return NULL;
}

static double **matmul_parallel(double **a, double **b, int n,
                                int num_threads) {
  pthread_t threads[num_threads];
  MatmulThreadData thread_data[num_threads];

  double **b_t = transpose(b, n);
  double **c = malloc(n * sizeof(double *));
  for (int i = 0; i < n; i++) {
    c[i] = calloc(n, sizeof(double));
  }

  int rows_per_thread = (n + num_threads - 1) / num_threads;

  for (int t = 0; t < num_threads; t++) {
    thread_data[t].a = a;
    thread_data[t].b_t = b_t;
    thread_data[t].c = c;
    thread_data[t].n = n;
    thread_data[t].start_row = t * rows_per_thread;
    thread_data[t].end_row = thread_data[t].start_row + rows_per_thread;
    if (thread_data[t].end_row > n || t == num_threads - 1) {
      thread_data[t].end_row = n;
    }

    int rc = pthread_create(&threads[t], NULL, thread_func, &thread_data[t]);
    if (rc != 0) {
      fprintf(stderr, "Failed to create thread %d\n", t);
      thread_func(&thread_data[t]);
      threads[t] = 0;
    }
  }

  for (int t = 0; t < num_threads; t++) {
    if (threads[t] != 0) {
      pthread_join(threads[t], NULL);
    }
  }

  free_matrix(b_t, n);
  return c;
}

static void MatmulParallel_run(Benchmark *self, int iteration_id) {
  MatmulParallelData *data = (MatmulParallelData *)self->data;
  int n = (int)data->base.n;

  double **c =
      matmul_parallel(data->base.a, data->base.b, n, data->num_threads);
  double center_value = c[n >> 1][n >> 1];
  free_matrix(c, n);

  uint32_t iter_checksum = Helper_checksum_f64(center_value);
  data->base.result_val += iter_checksum;
}

Benchmark *Matmul4T_create(void) {
  Benchmark *bench = Benchmark_create("Matmul::T4");
  MatmulParallelData *data = malloc(sizeof(MatmulParallelData));

  data->base.n = Helper_config_i64("Matmul::T4", "n");
  if (data->base.n == 0)
    data->base.n = 100;
  data->base.result_val = 0;
  data->base.a = NULL;
  data->base.b = NULL;
  data->num_threads = 4;

  bench->data = data;
  bench->prepare = MatmulBase_prepare;
  bench->run = MatmulParallel_run;
  bench->checksum = Matmul_checksum;
  bench->cleanup = MatmulBase_cleanup;

  return bench;
}

Benchmark *Matmul8T_create(void) {
  Benchmark *bench = Benchmark_create("Matmul::T8");
  MatmulParallelData *data = malloc(sizeof(MatmulParallelData));

  data->base.n = Helper_config_i64("Matmul::T8", "n");
  if (data->base.n == 0)
    data->base.n = 100;
  data->base.result_val = 0;
  data->base.a = NULL;
  data->base.b = NULL;
  data->num_threads = 8;

  bench->data = data;
  bench->prepare = MatmulBase_prepare;
  bench->run = MatmulParallel_run;
  bench->checksum = Matmul_checksum;
  bench->cleanup = MatmulBase_cleanup;

  return bench;
}

Benchmark *Matmul16T_create(void) {
  Benchmark *bench = Benchmark_create("Matmul::T16");
  MatmulParallelData *data = malloc(sizeof(MatmulParallelData));

  data->base.n = Helper_config_i64("Matmul::T16", "n");
  if (data->base.n == 0)
    data->base.n = 100;
  data->base.result_val = 0;
  data->base.a = NULL;
  data->base.b = NULL;
  data->num_threads = 16;

  bench->data = data;
  bench->prepare = MatmulBase_prepare;
  bench->run = MatmulParallel_run;
  bench->checksum = Matmul_checksum;
  bench->cleanup = MatmulBase_cleanup;

  return bench;
}

typedef struct {
  int64_t size_val;
  double *u;
  double *v;
} SpectralnormData;

void Spectralnorm_prepare(Benchmark *self) {
  SpectralnormData *data = (SpectralnormData *)self->data;
  data->size_val = Helper_config_i64(self->name, "size");
  if (data->size_val <= 0) {
    data->size_val = 100;
  }

  data->u = malloc(data->size_val * sizeof(double));
  data->v = malloc(data->size_val * sizeof(double));

  for (int64_t i = 0; i < data->size_val; i++) {
    data->u[i] = 1.0;
    data->v[i] = 1.0;
  }
}

static double eval_A(int64_t i, int64_t j) {
  return 1.0 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0);
}

static double *eval_A_times_u(const double *u, int64_t n) {
  double *result = malloc(n * sizeof(double));
  for (int64_t i = 0; i < n; i++) {
    double sum = 0.0;
    for (int64_t j = 0; j < n; j++) {
      sum += eval_A(i, j) * u[j];
    }
    result[i] = sum;
  }
  return result;
}

static double *eval_At_times_u(const double *u, int64_t n) {
  double *result = malloc(n * sizeof(double));
  for (int64_t i = 0; i < n; i++) {
    double sum = 0.0;
    for (int64_t j = 0; j < n; j++) {
      sum += eval_A(j, i) * u[j];
    }
    result[i] = sum;
  }
  return result;
}

static double *eval_AtA_times_u(const double *u, int64_t n) {
  double *temp = eval_A_times_u(u, n);
  double *result = eval_At_times_u(temp, n);
  free(temp);
  return result;
}

void Spectralnorm_run(Benchmark *self, int iteration_id) {
  SpectralnormData *data = (SpectralnormData *)self->data;

  double *new_v = eval_AtA_times_u(data->u, data->size_val);
  double *new_u = eval_AtA_times_u(new_v, data->size_val);

  free(data->u);
  free(data->v);

  data->u = new_u;
  data->v = new_v;
}

uint32_t Spectralnorm_checksum(Benchmark *self) {
  SpectralnormData *data = (SpectralnormData *)self->data;

  double vBv = 0.0, vv = 0.0;
  for (int64_t i = 0; i < data->size_val; i++) {
    vBv += data->u[i] * data->v[i];
    vv += data->v[i] * data->v[i];
  }

  double result = sqrt(vBv / vv);
  return Helper_checksum_f64(result);
}

void Spectralnorm_cleanup(Benchmark *self) {
  SpectralnormData *data = (SpectralnormData *)self->data;
  if (data->u)
    free(data->u);
  if (data->v)
    free(data->v);
}

Benchmark *Spectralnorm_create(void) {
  Benchmark *bench = Benchmark_create("CLBG::Spectralnorm");

  SpectralnormData *data = malloc(sizeof(SpectralnormData));
  memset(data, 0, sizeof(SpectralnormData));

  bench->data = data;

  bench->prepare = Spectralnorm_prepare;
  bench->run = Spectralnorm_run;
  bench->checksum = Spectralnorm_checksum;
  bench->cleanup = Spectralnorm_cleanup;

  return bench;
}

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#define SOLAR_MASS (4 * M_PI * M_PI)
#define DAYS_PER_YEAR 365.24

typedef struct {
  double x, y, z;
  double vx, vy, vz;
  double mass;
} NbodyPlanet;

typedef struct {
  int64_t iterations;
  NbodyPlanet *bodies;
  int64_t nbodies;
  double energy_before;
} NbodyData;

static void Nbody_Planet_init(NbodyPlanet *p, double x, double y, double z,
                              double vx, double vy, double vz, double mass) {
  p->x = x;
  p->y = y;
  p->z = z;
  p->vx = vx * DAYS_PER_YEAR;
  p->vy = vy * DAYS_PER_YEAR;
  p->vz = vz * DAYS_PER_YEAR;
  p->mass = mass * SOLAR_MASS;
}

static double Nbody_energy(NbodyPlanet *bodies, int64_t nbodies) {
  double e = 0.0;

  for (int64_t i = 0; i < nbodies; i++) {
    NbodyPlanet *b = &bodies[i];
    e += 0.5 * b->mass * (b->vx * b->vx + b->vy * b->vy + b->vz * b->vz);
    for (int64_t j = i + 1; j < nbodies; j++) {
      NbodyPlanet *b2 = &bodies[j];
      double dx = b->x - b2->x;
      double dy = b->y - b2->y;
      double dz = b->z - b2->z;
      double distance = sqrt(dx * dx + dy * dy + dz * dz);
      e -= (b->mass * b2->mass) / distance;
    }
  }
  return e;
}

static void Nbody_offset_momentum(NbodyPlanet *bodies, int64_t nbodies) {
  double px = 0.0, py = 0.0, pz = 0.0;

  for (int64_t i = 0; i < nbodies; i++) {
    NbodyPlanet *b = &bodies[i];
    px += b->vx * b->mass;
    py += b->vy * b->mass;
    pz += b->vz * b->mass;
  }

  NbodyPlanet *b = &bodies[0];
  b->vx = -px / SOLAR_MASS;
  b->vy = -py / SOLAR_MASS;
  b->vz = -pz / SOLAR_MASS;
}

static void Nbody_Planet_move_from_i(NbodyPlanet *bodies, int64_t nbodies,
                                     double dt, int64_t start) {

  NbodyPlanet *b1 = &bodies[start - 1];

  for (int64_t j = start; j < nbodies; j++) {
    NbodyPlanet *b2 = &bodies[j];
    double dx = b1->x - b2->x;
    double dy = b1->y - b2->y;
    double dz = b1->z - b2->z;

    double distance_sq = dx * dx + dy * dy + dz * dz;
    double distance = sqrt(distance_sq);
    double mag = dt / (distance * distance * distance);
    double b1_mass_mag = b1->mass * mag;
    double b2_mass_mag = b2->mass * mag;

    b1->vx -= dx * b2_mass_mag;
    b1->vy -= dy * b2_mass_mag;
    b1->vz -= dz * b2_mass_mag;
    b2->vx += dx * b1_mass_mag;
    b2->vy += dy * b1_mass_mag;
    b2->vz += dz * b1_mass_mag;
  }

  b1->x += dt * b1->vx;
  b1->y += dt * b1->vy;
  b1->z += dt * b1->vz;
}

void Nbody_prepare(Benchmark *self) {
  NbodyData *data = (NbodyData *)self->data;

  if (!data->bodies) {
    data->nbodies = 5;
    data->bodies = malloc(data->nbodies * sizeof(NbodyPlanet));

    Nbody_Planet_init(&data->bodies[0], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);

    Nbody_Planet_init(&data->bodies[1], 4.84143144246472090e+00,
                      -1.16032004402742839e+00, -1.03622044471123109e-01,
                      1.66007664274403694e-03, 7.69901118419740425e-03,
                      -6.90460016972063023e-05, 9.54791938424326609e-04);

    Nbody_Planet_init(&data->bodies[2], 8.34336671824457987e+00,
                      4.12479856412430479e+00, -4.03523417114321381e-01,
                      -2.76742510726862411e-03, 4.99852801234917238e-03,
                      2.30417297573763929e-05, 2.85885980666130812e-04);

    Nbody_Planet_init(&data->bodies[3], 1.28943695621391310e+01,
                      -1.51111514016986312e+01, -2.23307578892655734e-01,
                      2.96460137564761618e-03, 2.37847173959480950e-03,
                      -2.96589568540237556e-05, 4.36624404335156298e-05);

    Nbody_Planet_init(&data->bodies[4], 1.53796971148509165e+01,
                      -2.59193146099879641e+01, 1.79258772950371181e-01,
                      2.68067772490389322e-03, 1.62824170038242295e-03,
                      -9.51592254519715870e-05, 5.15138902046611451e-05);
  }

  Nbody_offset_momentum(data->bodies, data->nbodies);
  data->energy_before = Nbody_energy(data->bodies, data->nbodies);
}

void Nbody_run(Benchmark *self, int iteration_id) {
  NbodyData *data = (NbodyData *)self->data;

  double dt = 0.01;
  int nbodies = (int)data->nbodies;

  for (int n = 0; n < 1000; n++) {
    for (int i = 0; i < nbodies; i++) {
      Nbody_Planet_move_from_i(data->bodies, data->nbodies, dt, i + 1);
    }
  }
}

uint32_t Nbody_checksum(Benchmark *self) {
  NbodyData *data = (NbodyData *)self->data;

  double energy_after = Nbody_energy(data->bodies, data->nbodies);

  uint32_t checksum_before = Helper_checksum_f64(data->energy_before);
  uint32_t checksum_after = Helper_checksum_f64(energy_after);

  return ((int64_t)checksum_before << 5) & checksum_after;
}

void Nbody_cleanup(Benchmark *self) {
  NbodyData *data = (NbodyData *)self->data;

  if (data) {
    if (data->bodies) {
      free(data->bodies);
      data->bodies = NULL;
    }
  }
}

Benchmark *Nbody_create(void) {
  Benchmark *bench = Benchmark_create("CLBG::Nbody");

  NbodyData *data = malloc(sizeof(NbodyData));
  memset(data, 0, sizeof(NbodyData));

  bench->data = data;

  bench->prepare = Nbody_prepare;
  bench->run = Nbody_run;
  bench->checksum = Nbody_checksum;
  bench->cleanup = Nbody_cleanup;

  return bench;
}

typedef struct {
  char *input_str;
  size_t input_len;
  char *encoded_str;
  size_t encoded_len;
  uint32_t result_val;
} Base64EncodeData;

static size_t b64_encode_size(size_t size) {
  return (size_t)(size * 4 / 3.0) + 6;
}

static size_t b64_encode(char *dst, const char *src, size_t src_size) {
  size_t encoded_size;
  base64_encode(src, src_size, dst, &encoded_size, 0);
  return encoded_size;
}

void Base64Encode_prepare(Benchmark *self) {
  Base64EncodeData *data = (Base64EncodeData *)self->data;

  int64_t n = Helper_config_i64(self->name, "size");
  if (n <= 0) {
    n = 100;
  }

  data->input_len = (size_t)n;
  data->input_str = malloc(data->input_len + 1);
  memset(data->input_str, 'a', data->input_len);
  data->input_str[data->input_len] = '\0';

  data->encoded_len = b64_encode_size(data->input_len);
  data->encoded_str = malloc(data->encoded_len);
  data->encoded_len =
      b64_encode(data->encoded_str, data->input_str, data->input_len);

  data->result_val = 0;
}

void Base64Encode_run(Benchmark *self, int iteration_id) {
  Base64EncodeData *data = (Base64EncodeData *)self->data;

  size_t encoded_size = b64_encode_size(data->input_len);
  char *encoded_buf = (char *)malloc(encoded_size);

  size_t actual_len = b64_encode(encoded_buf, data->input_str, data->input_len);

  data->result_val += actual_len;
  free(encoded_buf);
}

uint32_t Base64Encode_checksum(Benchmark *self) {
  Base64EncodeData *data = (Base64EncodeData *)self->data;

  char result_str[256];

  char input_preview[32];
  if (data->input_len > 4) {

    strncpy(input_preview, data->input_str, 4);
    input_preview[4] = '.';
    input_preview[5] = '.';
    input_preview[6] = '.';
    input_preview[7] = '\0';
  } else {
    strncpy(input_preview, data->input_str, data->input_len);
    input_preview[data->input_len] = '\0';
  }

  char encoded_preview[32];
  if (data->encoded_len > 4) {

    strncpy(encoded_preview, data->encoded_str, 4);
    encoded_preview[4] = '.';
    encoded_preview[5] = '.';
    encoded_preview[6] = '.';
    encoded_preview[7] = '\0';
  } else {
    strncpy(encoded_preview, data->encoded_str, data->encoded_len);
    encoded_preview[data->encoded_len] = '\0';
  }

  snprintf(result_str, sizeof(result_str), "encode %s to %s: %u", input_preview,
           encoded_preview, data->result_val);

  return Helper_checksum_string(result_str);
}

void Base64Encode_cleanup(Benchmark *self) {
  Base64EncodeData *data = (Base64EncodeData *)self->data;
  if (data->input_str)
    free(data->input_str);
  if (data->encoded_str)
    free(data->encoded_str);
}

Benchmark *Base64Encode_create(void) {
  Benchmark *bench = Benchmark_create("Base64::Encode");

  Base64EncodeData *data = malloc(sizeof(Base64EncodeData));
  memset(data, 0, sizeof(Base64EncodeData));

  bench->data = data;

  bench->prepare = Base64Encode_prepare;
  bench->run = Base64Encode_run;
  bench->checksum = Base64Encode_checksum;
  bench->cleanup = Base64Encode_cleanup;

  return bench;
}

typedef struct {
  char *encoded_str;
  size_t encoded_len;
  char *decoded_str;
  size_t decoded_len;
  uint32_t result_val;
  size_t total_decoded_size;
} Base64DecodeData;

static size_t b64_decode_size(size_t size) {
  return (size_t)(size * 3 / 4.0) + 6;
}

static size_t b64_decode(char *dst, const char *src, size_t src_size) {
  size_t decoded_size;
  if (base64_decode(src, src_size, dst, &decoded_size, 0) != 1) {
    return 0;
  }
  return decoded_size;
}

void Base64Decode_prepare(Benchmark *self) {
  Base64DecodeData *data = (Base64DecodeData *)self->data;

  int64_t n = Helper_config_i64(self->name, "size");
  if (n <= 0) {
    n = 100;
  }

  size_t input_len = (size_t)n;
  char *input_str = malloc(input_len + 1);
  memset(input_str, 'a', input_len);
  input_str[input_len] = '\0';

  size_t encoded_size = b64_encode_size(input_len);
  data->encoded_str = malloc(encoded_size);
  size_t actual_encoded = 0;
  base64_encode(input_str, input_len, data->encoded_str, &actual_encoded, 0);
  data->encoded_len = actual_encoded;

  size_t decoded_size = b64_decode_size(data->encoded_len);
  data->decoded_str = malloc(decoded_size);
  data->decoded_len =
      b64_decode(data->decoded_str, data->encoded_str, data->encoded_len);

  data->result_val = 0;

  free(input_str);
}

void Base64Decode_run(Benchmark *self, int iteration_id) {
  Base64DecodeData *data = (Base64DecodeData *)self->data;

  size_t decoded_size = b64_decode_size(data->encoded_len);
  char *decoded_buf = (char *)malloc(decoded_size);

  size_t actual_len =
      b64_decode(decoded_buf, data->encoded_str, data->encoded_len);

  data->result_val += actual_len;
  free(decoded_buf);
}

uint32_t Base64Decode_checksum(Benchmark *self) {
  Base64DecodeData *data = (Base64DecodeData *)self->data;

  char result_str[256];

  char encoded_preview[32];
  if (data->encoded_len > 4) {

    strncpy(encoded_preview, data->encoded_str, 4);
    encoded_preview[4] = '.';
    encoded_preview[5] = '.';
    encoded_preview[6] = '.';
    encoded_preview[7] = '\0';
  } else {
    strncpy(encoded_preview, data->encoded_str, data->encoded_len);
    encoded_preview[data->encoded_len] = '\0';
  }

  char decoded_preview[32];
  if (data->decoded_len > 4) {

    strncpy(decoded_preview, data->decoded_str, 4);
    decoded_preview[4] = '.';
    decoded_preview[5] = '.';
    decoded_preview[6] = '.';
    decoded_preview[7] = '\0';
  } else {
    strncpy(decoded_preview, data->decoded_str, data->decoded_len);
    decoded_preview[data->decoded_len] = '\0';
  }

  snprintf(result_str, sizeof(result_str), "decode %s to %s: %u",
           encoded_preview, decoded_preview, data->result_val);

  return Helper_checksum_string(result_str);
}

void Base64Decode_cleanup(Benchmark *self) {
  Base64DecodeData *data = (Base64DecodeData *)self->data;
  if (data->encoded_str)
    free(data->encoded_str);
  if (data->decoded_str)
    free(data->decoded_str);
}

Benchmark *Base64Decode_create(void) {
  Benchmark *bench = Benchmark_create("Base64::Decode");

  Base64DecodeData *data = malloc(sizeof(Base64DecodeData));
  memset(data, 0, sizeof(Base64DecodeData));

  bench->data = data;

  bench->prepare = Base64Decode_prepare;
  bench->run = Base64Decode_run;
  bench->checksum = Base64Decode_checksum;
  bench->cleanup = Base64Decode_cleanup;

  return bench;
}

typedef struct {
  int64_t limit;
  uint32_t checksum;
} SieveData;

static int *sieve_generate(int64_t limit, int *count) {
  if (limit < 2) {
    *count = 0;
    return NULL;
  }

  uint8_t *primes = malloc((limit + 1) * sizeof(uint8_t));
  if (!primes)
    return NULL;

  memset(primes, 1, (limit + 1) * sizeof(uint8_t));
  primes[0] = 0;
  primes[1] = 0;

  int sqrt_limit = (int)sqrt((double)limit);

  for (int p = 2; p <= sqrt_limit; p++) {
    if (primes[p] == 1) {

      for (int multiple = p * p; multiple <= limit; multiple += p) {
        primes[multiple] = 0;
      }
    }
  }

  int last_prime = 2;
  int count_primes = 1;

  for (int n = 3; n <= limit; n += 2) {
    if (primes[n] == 1) {
      last_prime = n;
      count_primes++;
    }
  }

  free(primes);

  *count = last_prime + count_primes;
  return NULL;
}

void Sieve_prepare(Benchmark *self) {
  SieveData *data = (SieveData *)self->data;
  data->limit = Helper_config_i64(self->name, "limit");
  if (data->limit <= 0)
    data->limit = 1000000;
  data->checksum = 0;
}

void Sieve_run(Benchmark *self, int iteration_id) {
  SieveData *data = (SieveData *)self->data;

  int sum;
  sieve_generate(data->limit, &sum);

  data->checksum += (uint32_t)sum;
}

uint32_t Sieve_checksum(Benchmark *self) {
  SieveData *data = (SieveData *)self->data;
  return data->checksum;
}

Benchmark *Sieve_create(void) {
  Benchmark *bench = Benchmark_create("Etc::Sieve");

  SieveData *data = malloc(sizeof(SieveData));
  memset(data, 0, sizeof(SieveData));

  bench->data = data;
  bench->prepare = Sieve_prepare;
  bench->run = Sieve_run;
  bench->checksum = Sieve_checksum;

  return bench;
}

#include <yyjson.h>

typedef struct {
  char *result_str;
  uint32_t result_val;
  int64_t n;
  int prepared;
} JsonGenerateData;

static const char *INFO_STR = "some info";

static double round_to_8_digits(double value) {
  return round(value * 1e8) / 1e8;
}

void JsonGenerate_prepare(Benchmark *self) {
  JsonGenerateData *data = (JsonGenerateData *)self->data;

  if (data->result_str) {
    free(data->result_str);
    data->result_str = NULL;
  }

  data->result_val = 0;
  data->prepared = 1;
}

void JsonGenerate_run(Benchmark *self, int iteration_id) {
  JsonGenerateData *data = (JsonGenerateData *)self->data;

  if (data->result_str) {
    free(data->result_str);
    data->result_str = NULL;
  }

  yyjson_mut_doc *doc = yyjson_mut_doc_new(NULL);
  if (!doc)
    return;

  yyjson_mut_val *root = yyjson_mut_obj(doc);
  yyjson_mut_doc_set_root(doc, root);

  yyjson_mut_val *coordinates = yyjson_mut_arr(doc);
  yyjson_mut_obj_add(root, yyjson_mut_str(doc, "coordinates"), coordinates);

  for (int64_t i = 0; i < data->n; i++) {

    yyjson_mut_val *coord = yyjson_mut_obj(doc);

    yyjson_mut_obj_add(
        coord, yyjson_mut_str(doc, "x"),
        yyjson_mut_real(doc, round_to_8_digits(Helper_next_float(1.0))));

    yyjson_mut_obj_add(
        coord, yyjson_mut_str(doc, "y"),
        yyjson_mut_real(doc, round_to_8_digits(Helper_next_float(1.0))));

    yyjson_mut_obj_add(
        coord, yyjson_mut_str(doc, "z"),
        yyjson_mut_real(doc, round_to_8_digits(Helper_next_float(1.0))));

    char name_buf[64];
    snprintf(name_buf, sizeof(name_buf), "%.7f %u", Helper_next_float(1.0),
             Helper_next_int(10000));

    yyjson_mut_obj_add(coord, yyjson_mut_str(doc, "name"),
                       yyjson_mut_strcpy(doc, name_buf));

    yyjson_mut_val *opts = yyjson_mut_obj(doc);
    yyjson_mut_val *arr = yyjson_mut_arr(doc);
    yyjson_mut_arr_add_uint(doc, arr, 1);
    yyjson_mut_arr_add_bool(doc, arr, true);
    yyjson_mut_obj_add(opts, yyjson_mut_str(doc, "1"), arr);
    yyjson_mut_obj_add(coord, yyjson_mut_str(doc, "opts"), opts);

    yyjson_mut_arr_append(coordinates, coord);
  }

  yyjson_mut_obj_add(root, yyjson_mut_str(doc, "info"),
                     yyjson_mut_str(doc, INFO_STR));

  data->result_str = yyjson_mut_write(doc, 0, NULL);

  if (data->result_str && strlen(data->result_str) >= 15 &&
      strncmp(data->result_str, "{\"coordinates\":", 15) == 0) {
    data->result_val++;
  }

  yyjson_mut_doc_free(doc);
}

uint32_t JsonGenerate_checksum(Benchmark *self) {
  JsonGenerateData *data = (JsonGenerateData *)self->data;
  return data->result_val;
}

void JsonGenerate_cleanup(Benchmark *self) {
  JsonGenerateData *data = (JsonGenerateData *)self->data;

  if (data->result_str) {
    free(data->result_str);
    data->result_str = NULL;
  }
}

Benchmark *JsonGenerate_create(void) {
  Benchmark *bench = Benchmark_create("Json::Generate");

  JsonGenerateData *data = malloc(sizeof(JsonGenerateData));
  memset(data, 0, sizeof(JsonGenerateData));

  data->n = Helper_config_i64(bench->name, "coords");

  bench->data = data;
  bench->prepare = JsonGenerate_prepare;
  bench->run = JsonGenerate_run;
  bench->checksum = JsonGenerate_checksum;
  bench->cleanup = JsonGenerate_cleanup;

  return bench;
}

char *JsonGenerate_get_result(Benchmark *self) {
  JsonGenerateData *data = (JsonGenerateData *)self->data;
  return data->result_str ? strdup(data->result_str) : NULL;
}

typedef struct {
  char *json_text;
  uint32_t result_val;
  int64_t coords_count;
} JsonParseDomData;

static char *generate_json_for_parsing(int64_t coords_count) {
  Benchmark *json_gen_bench = JsonGenerate_create();
  JsonGenerateData *gen_data = (JsonGenerateData *)json_gen_bench->data;

  gen_data->n = coords_count;
  json_gen_bench->prepare(json_gen_bench);
  json_gen_bench->run(json_gen_bench, 0);

  char *json_text = strdup(gen_data->result_str);

  json_gen_bench->cleanup(json_gen_bench);
  free(json_gen_bench->data);
  free(json_gen_bench);

  return json_text;
}

void JsonParseDom_prepare(Benchmark *self) {
  JsonParseDomData *data = (JsonParseDomData *)self->data;

  data->coords_count = Helper_config_i64(self->name, "coords");

  data->json_text = generate_json_for_parsing(data->coords_count);
  data->result_val = 0;
}

void JsonParseDom_run(Benchmark *self, int iteration_id) {
  JsonParseDomData *data = (JsonParseDomData *)self->data;

  yyjson_doc *doc = yyjson_read(data->json_text, strlen(data->json_text), 0);
  if (!doc) {
    return;
  }

  yyjson_val *root = yyjson_doc_get_root(doc);
  if (!root) {
    yyjson_doc_free(doc);
    return;
  }

  yyjson_val *coordinates = yyjson_obj_get(root, "coordinates");
  if (!coordinates || !yyjson_is_arr(coordinates)) {
    yyjson_doc_free(doc);
    return;
  }

  double x_sum = 0.0, y_sum = 0.0, z_sum = 0.0;
  size_t len = 0;

  yyjson_val *coord;
  size_t idx, max;
  yyjson_arr_foreach(coordinates, idx, max, coord) {
    if (!yyjson_is_obj(coord))
      continue;

    yyjson_val *x_val = yyjson_obj_get(coord, "x");
    yyjson_val *y_val = yyjson_obj_get(coord, "y");
    yyjson_val *z_val = yyjson_obj_get(coord, "z");

    if (x_val && y_val && z_val && yyjson_is_num(x_val) &&
        yyjson_is_num(y_val) && yyjson_is_num(z_val)) {

      x_sum += yyjson_get_num(x_val);
      y_sum += yyjson_get_num(y_val);
      z_sum += yyjson_get_num(z_val);
      len++;
    }
  }

  yyjson_doc_free(doc);

  if (len > 0) {
    double x_avg = x_sum / len;
    double y_avg = y_sum / len;
    double z_avg = z_sum / len;

    uint32_t checksum = Helper_checksum_f64(x_avg) +
                        Helper_checksum_f64(y_avg) + Helper_checksum_f64(z_avg);
    data->result_val += checksum;
  }
}

uint32_t JsonParseDom_checksum(Benchmark *self) {
  JsonParseDomData *data = (JsonParseDomData *)self->data;
  return data->result_val;
}

void JsonParseDom_cleanup(Benchmark *self) {
  JsonParseDomData *data = (JsonParseDomData *)self->data;
  if (data->json_text) {
    free(data->json_text);
    data->json_text = NULL;
  }
}

Benchmark *JsonParseDom_create(void) {
  Benchmark *bench = Benchmark_create("Json::ParseDom");

  JsonParseDomData *data = malloc(sizeof(JsonParseDomData));
  memset(data, 0, sizeof(JsonParseDomData));

  bench->data = data;

  bench->prepare = JsonParseDom_prepare;
  bench->run = JsonParseDom_run;
  bench->checksum = JsonParseDom_checksum;
  bench->cleanup = JsonParseDom_cleanup;

  return bench;
}

typedef struct {
  char *json_text;
  uint32_t result_val;
  int64_t coords_count;
} JsonParseMappingData;

void JsonParseMapping_prepare(Benchmark *self) {
  JsonParseMappingData *data = (JsonParseMappingData *)self->data;

  data->coords_count = Helper_config_i64(self->name, "coords");
  if (data->coords_count <= 0) {
    data->coords_count = 1000;
  }

  data->json_text = generate_json_for_parsing(data->coords_count);
  data->result_val = 0;
}

void JsonParseMapping_run(Benchmark *self, int iteration_id) {
  JsonParseMappingData *data = (JsonParseMappingData *)self->data;

  yyjson_doc *doc = yyjson_read(data->json_text, strlen(data->json_text), 0);
  if (!doc) {
    return;
  }

  yyjson_val *root = yyjson_doc_get_root(doc);
  if (!root) {
    yyjson_doc_free(doc);
    return;
  }

  yyjson_val *coordinates = yyjson_obj_get(root, "coordinates");
  if (!coordinates || !yyjson_is_arr(coordinates)) {
    yyjson_doc_free(doc);
    return;
  }

  double x_sum = 0.0, y_sum = 0.0, z_sum = 0.0;
  size_t len = 0;

  yyjson_val *coord;
  size_t idx, max;
  yyjson_arr_foreach(coordinates, idx, max, coord) {
    if (!yyjson_is_obj(coord))
      continue;

    yyjson_val *x_val = yyjson_obj_get(coord, "x");
    yyjson_val *y_val = yyjson_obj_get(coord, "y");
    yyjson_val *z_val = yyjson_obj_get(coord, "z");

    if (x_val && y_val && z_val) {

      x_sum += yyjson_get_num(x_val);
      y_sum += yyjson_get_num(y_val);
      z_sum += yyjson_get_num(z_val);
      len++;
    }
  }

  yyjson_doc_free(doc);

  if (len > 0) {
    double x_avg = x_sum / len;
    double y_avg = y_sum / len;
    double z_avg = z_sum / len;

    uint32_t checksum = Helper_checksum_f64(x_avg) +
                        Helper_checksum_f64(y_avg) + Helper_checksum_f64(z_avg);
    data->result_val += checksum;
  }
}

uint32_t JsonParseMapping_checksum(Benchmark *self) {
  JsonParseMappingData *data = (JsonParseMappingData *)self->data;
  return data->result_val;
}

void JsonParseMapping_cleanup(Benchmark *self) {
  JsonParseMappingData *data = (JsonParseMappingData *)self->data;
  if (data->json_text) {
    free(data->json_text);
    data->json_text = NULL;
  }
}

Benchmark *JsonParseMapping_create(void) {
  Benchmark *bench = Benchmark_create("Json::ParseMapping");

  JsonParseMappingData *data = malloc(sizeof(JsonParseMappingData));
  memset(data, 0, sizeof(JsonParseMappingData));

  bench->data = data;

  bench->prepare = JsonParseMapping_prepare;
  bench->run = JsonParseMapping_run;
  bench->checksum = JsonParseMapping_checksum;
  bench->cleanup = JsonParseMapping_cleanup;

  return bench;
}

#include <math.h>
#include <stdlib.h>

#define M_PI 3.14159265358979323846

typedef struct {
  double x, y;
} NoiseVec2;

typedef struct {
  NoiseVec2 *rgradients;
  int *permutations;
  int size_val;
} Noise2DContext;

typedef struct {
  int64_t size_val;
  uint32_t result_val;
  Noise2DContext *n2d;
} NoiseData;

static NoiseVec2 random_gradient(void) {
  double v = Helper_next_float(1.0) * M_PI * 2.0;
  NoiseVec2 result;
  result.x = cos(v);
  result.y = sin(v);
  return result;
}

static double lerp(double a, double b, double v) {
  return a * (1.0 - v) + b * v;
}

static double smooth(double v) { return v * v * (3.0 - 2.0 * v); }

static double gradient(const NoiseVec2 *orig, const NoiseVec2 *grad,
                       const NoiseVec2 *p) {
  double sp_x = p->x - orig->x;
  double sp_y = p->y - orig->y;
  return grad->x * sp_x + grad->y * sp_y;
}

static Noise2DContext *noise2dcontext_new(int size) {
  Noise2DContext *ctx = malloc(sizeof(Noise2DContext));
  if (!ctx)
    return NULL;

  ctx->size_val = size;
  ctx->rgradients = malloc(size * sizeof(NoiseVec2));
  ctx->permutations = malloc(size * sizeof(int));

  if (!ctx->rgradients || !ctx->permutations) {
    free(ctx->rgradients);
    free(ctx->permutations);
    free(ctx);
    return NULL;
  }

  for (int i = 0; i < size; i++) {
    ctx->rgradients[i] = random_gradient();
    ctx->permutations[i] = i;
  }

  for (int i = 0; i < size; i++) {
    int a = Helper_next_int(size);
    int b = Helper_next_int(size);
    int temp = ctx->permutations[a];
    ctx->permutations[a] = ctx->permutations[b];
    ctx->permutations[b] = temp;
  }

  return ctx;
}

static void noise2dcontext_free(Noise2DContext *ctx) {
  if (!ctx)
    return;
  free(ctx->rgradients);
  free(ctx->permutations);
  free(ctx);
}

static NoiseVec2 get_gradient(const Noise2DContext *ctx, int x, int y) {
  int mask = ctx->size_val - 1;
  int idx = ctx->permutations[x & mask] + ctx->permutations[y & mask];
  return ctx->rgradients[idx & mask];
}

static void get_gradients(const Noise2DContext *ctx, double x, double y,
                          NoiseVec2 gradients[4], NoiseVec2 origins[4]) {
  double x0f = floor(x);
  double y0f = floor(y);
  int x0 = (int)x0f;
  int y0 = (int)y0f;
  int x1 = x0 + 1;
  int y1 = y0 + 1;

  gradients[0] = get_gradient(ctx, x0, y0);
  gradients[1] = get_gradient(ctx, x1, y0);
  gradients[2] = get_gradient(ctx, x0, y1);
  gradients[3] = get_gradient(ctx, x1, y1);

  origins[0].x = x0f + 0.0;
  origins[0].y = y0f + 0.0;
  origins[1].x = x0f + 1.0;
  origins[1].y = y0f + 0.0;
  origins[2].x = x0f + 0.0;
  origins[2].y = y0f + 1.0;
  origins[3].x = x0f + 1.0;
  origins[3].y = y0f + 1.0;
}

static double noise_get(const Noise2DContext *ctx, double x, double y) {
  NoiseVec2 gradients[4];
  NoiseVec2 origins[4];
  get_gradients(ctx, x, y, gradients, origins);

  NoiseVec2 p = {x, y};

  double v0 = gradient(&origins[0], &gradients[0], &p);
  double v1 = gradient(&origins[1], &gradients[1], &p);
  double v2 = gradient(&origins[2], &gradients[2], &p);
  double v3 = gradient(&origins[3], &gradients[3], &p);

  double fx = smooth(x - origins[0].x);
  double vx0 = lerp(v0, v1, fx);
  double vx1 = lerp(v2, v3, fx);

  double fy = smooth(y - origins[0].y);
  return lerp(vx0, vx1, fy);
}

static const uint32_t SYM[6] = {32, 0x2591, 0x2592, 0x2593, 0x2588, 0x2588};

void Noise_prepare(Benchmark *self) {
  NoiseData *data = (NoiseData *)self->data;

  data->size_val = Helper_config_i64(self->name, "size");
  if (data->size_val <= 0) {
    data->size_val = 64;
  }

  int size = (int)data->size_val;

  size--;
  size |= size >> 1;
  size |= size >> 2;
  size |= size >> 4;
  size |= size >> 8;
  size |= size >> 16;
  size++;
  data->size_val = size;

  if (data->n2d) {
    noise2dcontext_free(data->n2d);
    data->n2d = NULL;
  }

  data->n2d = noise2dcontext_new(size);

  data->result_val = 0;
}

void Noise_run(Benchmark *self, int iteration_id) {
  NoiseData *data = (NoiseData *)self->data;

  if (!data->n2d) {
    return;
  }

  uint32_t iteration_result = 0;

  for (int64_t y = 0; y < data->size_val; y++) {
    for (int64_t x = 0; x < data->size_val; x++) {
      double v =
          noise_get(data->n2d, x * 0.1, (y + (iteration_id * 128)) * 0.1);
      v = v * 0.5 + 0.5;

      int idx = (int)(v / 0.2);
      if (idx >= 6)
        idx = 5;
      if (idx < 0)
        idx = 0;

      iteration_result += SYM[idx];
    }
  }

  data->result_val += iteration_result;
}

uint32_t Noise_checksum(Benchmark *self) {
  NoiseData *data = (NoiseData *)self->data;
  return data->result_val;
}

void Noise_cleanup(Benchmark *self) {
  NoiseData *data = (NoiseData *)self->data;

  if (data->n2d) {
    noise2dcontext_free(data->n2d);
    data->n2d = NULL;
  }
}

Benchmark *Noise_create(void) {
  Benchmark *bench = Benchmark_create("Etc::Noise");

  NoiseData *data = malloc(sizeof(NoiseData));
  if (!data)
    return NULL;

  memset(data, 0, sizeof(NoiseData));

  bench->data = data;

  bench->prepare = Noise_prepare;
  bench->run = Noise_run;
  bench->checksum = Noise_checksum;
  bench->cleanup = Noise_cleanup;

  return bench;
}

typedef struct {
  double x, y, z;
} TRVector;

typedef struct {
  TRVector orig, dir;
} TRRay;

typedef struct {
  double r, g, b;
} TRColor;

typedef struct {
  TRVector center;
  double radius;
  TRColor color;
} TRSphere;

typedef struct {
  TRVector position;
  TRColor color;
} TRLight;

typedef struct {
  int32_t width;
  int32_t height;
  uint32_t result_val;
} TextRaytracerData;

static TRVector tr_vector_scale(TRVector v, double s) {
  return (TRVector){v.x * s, v.y * s, v.z * s};
}

static TRVector tr_vector_add(TRVector a, TRVector b) {
  return (TRVector){a.x + b.x, a.y + b.y, a.z + b.z};
}

static TRVector tr_vector_sub(TRVector a, TRVector b) {
  return (TRVector){a.x - b.x, a.y - b.y, a.z - b.z};
}

static double tr_vector_dot(TRVector a, TRVector b) {
  return a.x * b.x + a.y * b.y + a.z * b.z;
}

static double tr_vector_magnitude(TRVector v) {
  return sqrt(tr_vector_dot(v, v));
}

static TRVector tr_vector_normalize(TRVector v) {
  double mag = tr_vector_magnitude(v);
  if (mag == 0.0)
    return (TRVector){0, 0, 0};
  return tr_vector_scale(v, 1.0 / mag);
}

static TRColor tr_color_scale(TRColor c, double s) {
  return (TRColor){c.r * s, c.g * s, c.b * s};
}

static TRColor tr_color_add(TRColor a, TRColor b) {
  return (TRColor){a.r + b.r, a.g + b.g, a.b + b.b};
}

static TRVector tr_sphere_get_normal(TRSphere *sphere, TRVector pt) {
  return tr_vector_normalize(tr_vector_sub(pt, sphere->center));
}

static double tr_clamp(double x, double a, double b) {
  if (x < a)
    return a;
  if (x > b)
    return b;
  return x;
}

static double tr_intersect_sphere(TRRay ray, TRVector center, double radius) {
  TRVector l = tr_vector_sub(center, ray.orig);
  double tca = tr_vector_dot(l, ray.dir);
  if (tca < 0.0)
    return -1.0;

  double d2 = tr_vector_dot(l, l) - tca * tca;
  double r2 = radius * radius;
  if (d2 > r2)
    return -1.0;

  double thc = sqrt(r2 - d2);
  double t0 = tca - thc;
  if (t0 > 10000.0)
    return -1.0;

  return t0;
}

static TRColor tr_diffuse_shading(TRVector pi, TRSphere *obj, TRLight light) {
  TRVector n = tr_sphere_get_normal(obj, pi);
  TRVector light_dir = tr_vector_normalize(tr_vector_sub(light.position, pi));
  double lam1 = tr_vector_dot(light_dir, n);
  double lam2 = tr_clamp(lam1, 0.0, 1.0);

  TRColor light_color = tr_color_scale(light.color, lam2 * 0.5);
  TRColor obj_color = tr_color_scale(obj->color, 0.3);
  return tr_color_add(light_color, obj_color);
}

static const char LUT[6] = {'.', '-', '+', '*', 'X', 'M'};

void TextRaytracer_prepare(Benchmark *self) {
  TextRaytracerData *data = (TextRaytracerData *)self->data;

  data->width = (int32_t)Helper_config_i64(self->name, "w");
  data->height = (int32_t)Helper_config_i64(self->name, "h");

  if (data->width <= 0)
    data->width = 10;
  if (data->height <= 0)
    data->height = 10;

  data->result_val = 0;
}

void TextRaytracer_run(Benchmark *self, int iteration_id) {
  TextRaytracerData *data = (TextRaytracerData *)self->data;

  TRSphere scene[3] = {{{-1.0, 0.0, 3.0}, 0.3, {1.0, 0.0, 0.0}},
                       {{0.0, 0.0, 3.0}, 0.8, {0.0, 1.0, 0.0}},
                       {{1.0, 0.0, 3.0}, 0.4, {0.0, 0.0, 1.0}}};

  TRLight light1 = {{0.7, -1.0, 1.7}, {1.0, 1.0, 1.0}};

  uint32_t iteration_result = 0;

  for (int32_t j = 0; j < data->height; j++) {
    for (int32_t i = 0; i < data->width; i++) {
      double fw = data->width;
      double fh = data->height;
      double fi = i;
      double fj = j;

      TRRay ray;
      ray.orig = (TRVector){0.0, 0.0, 0.0};

      TRVector dir = {(fi - fw / 2.0) / fw, (fj - fh / 2.0) / fh, 1.0};
      ray.dir = tr_vector_normalize(dir);

      double tval = -1.0;
      TRSphere *hit_obj = NULL;

      for (int k = 0; k < 3; k++) {
        double intersect =
            tr_intersect_sphere(ray, scene[k].center, scene[k].radius);
        if (intersect >= 0.0) {
          tval = intersect;
          hit_obj = &scene[k];
          break;
        }
      }

      char pixel = ' ';
      if (hit_obj && tval >= 0.0) {
        TRVector pi = tr_vector_add(ray.orig, tr_vector_scale(ray.dir, tval));
        TRColor color = tr_diffuse_shading(pi, hit_obj, light1);
        double col = (color.r + color.g + color.b) / 3.0;
        int idx = (int)(col * 6.0);
        if (idx < 0)
          idx = 0;
        if (idx >= 6)
          idx = 5;
        pixel = LUT[idx];
      }

      iteration_result += (uint8_t)pixel;
    }
  }

  data->result_val += iteration_result;
}

uint32_t TextRaytracer_checksum(Benchmark *self) {
  TextRaytracerData *data = (TextRaytracerData *)self->data;
  return data->result_val;
}

void TextRaytracer_cleanup(Benchmark *self) {}

Benchmark *TextRaytracer_create(void) {
  Benchmark *bench = Benchmark_create("Etc::TextRaytracer");

  TextRaytracerData *data = malloc(sizeof(TextRaytracerData));
  memset(data, 0, sizeof(TextRaytracerData));

  bench->data = data;

  bench->prepare = TextRaytracer_prepare;
  bench->run = TextRaytracer_run;
  bench->checksum = TextRaytracer_checksum;
  bench->cleanup = TextRaytracer_cleanup;

  return bench;
}

#define LEARNING_RATE 1.0
#define MOMENTUM 0.3
#define TRAIN_RATE 0.3

typedef struct NeuralNetNeuron NeuralNetNeuron;
typedef struct NeuralNetSynapse NeuralNetSynapse;

struct NeuralNetSynapse {
  double weight;
  double prev_weight;
  NeuralNetNeuron *source_neuron;
  NeuralNetNeuron *dest_neuron;
};

struct NeuralNetNeuron {

  NeuralNetSynapse **synapses_in;
  int synapses_in_count;
  int synapses_in_capacity;

  NeuralNetSynapse **synapses_out;
  int synapses_out_count;
  int synapses_out_capacity;

  double threshold;
  double prev_threshold;
  double error;
  double output;
};

static void neuron_update_weights(NeuralNetNeuron *neuron);

typedef struct {
  NeuralNetNeuron *neurons;
  int total_neurons;

  int *input_layer;
  int input_count;
  int *hidden_layer;
  int hidden_count;
  int *output_layer;
  int output_count;

  NeuralNetSynapse *synapses;
  int synapse_count;
  int synapse_capacity;
} NeuralNetwork;

typedef struct {
  uint32_t result_val;
  double sum_outputs;
  NeuralNetwork *xor_net;
} NeuralNetData;

static void neuron_init(NeuralNetNeuron *neuron) {

  double r = Helper_next_float(1.0);
  neuron->threshold = neuron->prev_threshold = r * 2.0 - 1.0;
  neuron->output = 0.0;
  neuron->error = 0.0;

  neuron->synapses_in_count = 0;
  neuron->synapses_in_capacity = 4;
  neuron->synapses_in =
      malloc(neuron->synapses_in_capacity * sizeof(NeuralNetSynapse *));

  neuron->synapses_out_count = 0;
  neuron->synapses_out_capacity = 4;
  neuron->synapses_out =
      malloc(neuron->synapses_out_capacity * sizeof(NeuralNetSynapse *));
}

static void neuron_add_synapse_in(NeuralNetNeuron *neuron,
                                  NeuralNetSynapse *synapse) {
  if (neuron->synapses_in_count >= neuron->synapses_in_capacity) {
    neuron->synapses_in_capacity *= 2;
    neuron->synapses_in =
        realloc(neuron->synapses_in,
                neuron->synapses_in_capacity * sizeof(NeuralNetSynapse *));
  }
  neuron->synapses_in[neuron->synapses_in_count++] = synapse;
}

static void neuron_add_synapse_out(NeuralNetNeuron *neuron,
                                   NeuralNetSynapse *synapse) {
  if (neuron->synapses_out_count >= neuron->synapses_out_capacity) {
    neuron->synapses_out_capacity *= 2;
    neuron->synapses_out =
        realloc(neuron->synapses_out,
                neuron->synapses_out_capacity * sizeof(NeuralNetSynapse *));
  }
  neuron->synapses_out[neuron->synapses_out_count++] = synapse;
}

static double neuron_derivative(NeuralNetNeuron *neuron) {
  return neuron->output * (1.0 - neuron->output);
}

static void neuron_calculate_output(NeuralNetNeuron *neuron) {
  double activation = 0.0;
  for (int i = 0; i < neuron->synapses_in_count; i++) {
    NeuralNetSynapse *synapse = neuron->synapses_in[i];
    activation += synapse->weight * synapse->source_neuron->output;
  }
  activation -= neuron->threshold;
  neuron->output = 1.0 / (1.0 + exp(-activation));
}

static void neuron_output_train(NeuralNetNeuron *neuron, double target) {
  neuron->error = (target - neuron->output) * neuron_derivative(neuron);
  neuron_update_weights(neuron);
}

static void neuron_hidden_train(NeuralNetNeuron *neuron) {
  double sum = 0.0;
  for (int i = 0; i < neuron->synapses_out_count; i++) {
    NeuralNetSynapse *synapse = neuron->synapses_out[i];
    sum += synapse->prev_weight * synapse->dest_neuron->error;
  }
  neuron->error = sum * neuron_derivative(neuron);
  neuron_update_weights(neuron);
}

static void neuron_update_weights(NeuralNetNeuron *neuron) {

  for (int i = 0; i < neuron->synapses_in_count; i++) {
    NeuralNetSynapse *synapse = neuron->synapses_in[i];
    double temp_weight = synapse->weight;
    synapse->weight += (TRAIN_RATE * LEARNING_RATE * neuron->error *
                        synapse->source_neuron->output) +
                       (MOMENTUM * (synapse->weight - synapse->prev_weight));
    synapse->prev_weight = temp_weight;
  }

  double temp_threshold = neuron->threshold;
  neuron->threshold +=
      (TRAIN_RATE * LEARNING_RATE * neuron->error * -1.0) +
      (MOMENTUM * (neuron->threshold - neuron->prev_threshold));
  neuron->prev_threshold = temp_threshold;
}

static NeuralNetwork *network_new(int inputs, int hidden, int outputs) {
  NeuralNetwork *net = malloc(sizeof(NeuralNetwork));

  net->total_neurons = inputs + hidden + outputs;
  net->neurons = malloc(net->total_neurons * sizeof(NeuralNetNeuron));

  for (int i = 0; i < net->total_neurons; i++) {
    neuron_init(&net->neurons[i]);
  }

  net->input_count = inputs;
  net->hidden_count = hidden;
  net->output_count = outputs;

  net->input_layer = malloc(inputs * sizeof(int));
  net->hidden_layer = malloc(hidden * sizeof(int));
  net->output_layer = malloc(outputs * sizeof(int));

  for (int i = 0; i < inputs; i++) {
    net->input_layer[i] = i;
  }
  for (int i = 0; i < hidden; i++) {
    net->hidden_layer[i] = inputs + i;
  }
  for (int i = 0; i < outputs; i++) {
    net->output_layer[i] = inputs + hidden + i;
  }

  net->synapse_count = 0;
  net->synapse_capacity = (inputs * hidden) + (hidden * outputs);
  net->synapses = malloc(net->synapse_capacity * sizeof(NeuralNetSynapse));

  for (int i = 0; i < inputs; i++) {
    NeuralNetNeuron *source = &net->neurons[net->input_layer[i]];
    for (int j = 0; j < hidden; j++) {
      NeuralNetNeuron *dest = &net->neurons[net->hidden_layer[j]];

      NeuralNetSynapse *synapse = &net->synapses[net->synapse_count++];

      double r = Helper_next_float(1.0);
      synapse->weight = synapse->prev_weight = r * 2.0 - 1.0;

      synapse->source_neuron = source;
      synapse->dest_neuron = dest;

      neuron_add_synapse_out(source, synapse);
      neuron_add_synapse_in(dest, synapse);
    }
  }

  for (int i = 0; i < hidden; i++) {
    NeuralNetNeuron *source = &net->neurons[net->hidden_layer[i]];
    for (int j = 0; j < outputs; j++) {
      NeuralNetNeuron *dest = &net->neurons[net->output_layer[j]];

      NeuralNetSynapse *synapse = &net->synapses[net->synapse_count++];

      double r = Helper_next_float(1.0);
      synapse->weight = synapse->prev_weight = r * 2.0 - 1.0;

      synapse->source_neuron = source;
      synapse->dest_neuron = dest;

      neuron_add_synapse_out(source, synapse);
      neuron_add_synapse_in(dest, synapse);
    }
  }

  return net;
}

static void network_free(NeuralNetwork *net) {
  if (!net)
    return;

  for (int i = 0; i < net->total_neurons; i++) {
    free(net->neurons[i].synapses_in);
    free(net->neurons[i].synapses_out);
  }

  free(net->neurons);
  free(net->input_layer);
  free(net->hidden_layer);
  free(net->output_layer);
  free(net->synapses);
  free(net);
}

static void network_train(NeuralNetwork *net, double *inputs, double *targets) {

  for (int i = 0; i < net->input_count; i++) {
    net->neurons[net->input_layer[i]].output = inputs[i];
  }

  for (int i = 0; i < net->hidden_count; i++) {
    neuron_calculate_output(&net->neurons[net->hidden_layer[i]]);
  }

  for (int i = 0; i < net->output_count; i++) {
    neuron_calculate_output(&net->neurons[net->output_layer[i]]);
  }

  for (int i = 0; i < net->output_count; i++) {
    neuron_output_train(&net->neurons[net->output_layer[i]], targets[i]);
  }

  for (int i = 0; i < net->hidden_count; i++) {
    neuron_hidden_train(&net->neurons[net->hidden_layer[i]]);
  }
}

static void network_feed_forward(NeuralNetwork *net, double *inputs) {
  for (int i = 0; i < net->input_count; i++) {
    net->neurons[net->input_layer[i]].output = inputs[i];
  }

  for (int i = 0; i < net->hidden_count; i++) {
    neuron_calculate_output(&net->neurons[net->hidden_layer[i]]);
  }

  for (int i = 0; i < net->output_count; i++) {
    neuron_calculate_output(&net->neurons[net->output_layer[i]]);
  }
}

static double network_get_output(NeuralNetwork *net) {
  return net->neurons[net->output_layer[0]].output;
}

void NeuralNet_prepare(Benchmark *self) {
  NeuralNetData *data = (NeuralNetData *)self->data;

  data->result_val = 0;
  data->sum_outputs = 0.0;

  if (data->xor_net) {
    network_free(data->xor_net);
  }

  Helper_reset();

  data->xor_net = network_new(2, 10, 1);
}

void NeuralNet_run(Benchmark *self, int iteration_id) {
  NeuralNetData *data = (NeuralNetData *)self->data;

  double inputs_00[2] = {0, 0};
  double targets_0[1] = {0};

  double inputs_10[2] = {1, 0};
  double inputs_01[2] = {0, 1};
  double targets_1[1] = {1};

  double inputs_11[2] = {1, 1};

  network_train(data->xor_net, inputs_00, targets_0);
  network_train(data->xor_net, inputs_10, targets_1);
  network_train(data->xor_net, inputs_01, targets_1);
  network_train(data->xor_net, inputs_11, targets_0);
}

uint32_t NeuralNet_checksum(Benchmark *self) {
  NeuralNetData *data = (NeuralNetData *)self->data;

  if (!data->xor_net) {
    return 0;
  }

  double inputs_00[2] = {0, 0};
  double inputs_01[2] = {0, 1};
  double inputs_10[2] = {1, 0};
  double inputs_11[2] = {1, 1};

  double sum = 0.0;

  network_feed_forward(data->xor_net, inputs_00);
  sum += network_get_output(data->xor_net);

  network_feed_forward(data->xor_net, inputs_01);
  sum += network_get_output(data->xor_net);

  network_feed_forward(data->xor_net, inputs_10);
  sum += network_get_output(data->xor_net);

  network_feed_forward(data->xor_net, inputs_11);
  sum += network_get_output(data->xor_net);

  data->sum_outputs = sum;

  return Helper_checksum_f64(sum);
}

void NeuralNet_cleanup(Benchmark *self) {
  NeuralNetData *data = (NeuralNetData *)self->data;

  if (data->xor_net) {
    network_free(data->xor_net);
    data->xor_net = NULL;
  }
}

Benchmark *NeuralNet_create(void) {
  Benchmark *bench = Benchmark_create("Etc::NeuralNet");

  NeuralNetData *data = malloc(sizeof(NeuralNetData));
  memset(data, 0, sizeof(NeuralNetData));

  bench->data = data;

  bench->prepare = NeuralNet_prepare;
  bench->run = NeuralNet_run;
  bench->checksum = NeuralNet_checksum;
  bench->cleanup = NeuralNet_cleanup;

  return bench;
}

typedef struct {
  int64_t size_val;
  int32_t *data;
  uint32_t result_val;
} SortBaseData;

static void sort_base_prepare(Benchmark *self, const char *bench_name) {
  SortBaseData *data = (SortBaseData *)self->data;

  data->size_val = Helper_config_i64(bench_name, "size");
  if (data->size_val <= 0) {
    data->size_val = 100000;
  }

  data->data = malloc(data->size_val * sizeof(int32_t));

  for (int64_t i = 0; i < data->size_val; i++) {
    data->data[i] = Helper_next_int(1000000);
  }

  data->result_val = 0;
}

static void sort_base_cleanup(SortBaseData *data) {
  if (data->data) {
    free(data->data);
    data->data = NULL;
  }
}

typedef struct {
  SortBaseData base;
  int32_t *sorted_data;
} SortQuickData;

static void sort_quick_quick_sort(int32_t *arr, int64_t low, int64_t high) {
  if (low >= high)
    return;

  int32_t pivot = arr[(low + high) / 2];
  int64_t i = low, j = high;

  while (i <= j) {
    while (arr[i] < pivot)
      i++;
    while (arr[j] > pivot)
      j--;
    if (i <= j) {
      int32_t temp = arr[i];
      arr[i] = arr[j];
      arr[j] = temp;
      i++;
      j--;
    }
  }

  sort_quick_quick_sort(arr, low, j);
  sort_quick_quick_sort(arr, i, high);
}

static void sort_quick_test(SortQuickData *data) {
  if (data->sorted_data) {
    free(data->sorted_data);
  }

  data->sorted_data = malloc(data->base.size_val * sizeof(int32_t));
  memcpy(data->sorted_data, data->base.data,
         data->base.size_val * sizeof(int32_t));

  sort_quick_quick_sort(data->sorted_data, 0, data->base.size_val - 1);
}

void SortQuick_prepare(Benchmark *self) {
  SortQuickData *data = (SortQuickData *)self->data;
  sort_base_prepare(self, "Sort::Quick");
  data->sorted_data = NULL;
}

void SortQuick_run(Benchmark *self, int iteration_id) {
  SortQuickData *data = (SortQuickData *)self->data;

  sort_quick_test(data);

  int32_t random_index1 = Helper_next_int((uint32_t)data->base.size_val);
  int32_t random_index2 = Helper_next_int((uint32_t)data->base.size_val);

  uint32_t iteration_result = (uint32_t)data->base.data[random_index1] +
                              (uint32_t)data->sorted_data[random_index2];
  data->base.result_val += iteration_result;
}

uint32_t SortQuick_checksum(Benchmark *self) {
  SortQuickData *data = (SortQuickData *)self->data;
  return data->base.result_val;
}

void SortQuick_cleanup(Benchmark *self) {
  SortQuickData *data = (SortQuickData *)self->data;
  sort_base_cleanup(&data->base);
  if (data->sorted_data) {
    free(data->sorted_data);
    data->sorted_data = NULL;
  }
}

Benchmark *SortQuick_create(void) {
  Benchmark *bench = Benchmark_create("Sort::Quick");

  SortQuickData *data = malloc(sizeof(SortQuickData));
  memset(data, 0, sizeof(SortQuickData));

  bench->data = data;

  bench->prepare = SortQuick_prepare;
  bench->run = SortQuick_run;
  bench->checksum = SortQuick_checksum;
  bench->cleanup = SortQuick_cleanup;

  return bench;
}

typedef struct {
  SortBaseData base;
  int32_t *sorted_data;
} SortMergeData;

static void sort_merge_merge(int32_t *arr, int32_t *temp, int64_t left,
                             int64_t mid, int64_t right) {
  for (int64_t i = left; i <= right; i++) {
    temp[i] = arr[i];
  }

  int64_t i = left, j = mid + 1, k = left;

  while (i <= mid && j <= right) {
    if (temp[i] <= temp[j]) {
      arr[k] = temp[i];
      i++;
    } else {
      arr[k] = temp[j];
      j++;
    }
    k++;
  }

  while (i <= mid) {
    arr[k] = temp[i];
    i++;
    k++;
  }
}

static void sort_merge_merge_sort_helper(int32_t *arr, int32_t *temp,
                                         int64_t left, int64_t right) {
  if (left >= right)
    return;

  int64_t mid = (left + right) / 2;
  sort_merge_merge_sort_helper(arr, temp, left, mid);
  sort_merge_merge_sort_helper(arr, temp, mid + 1, right);
  sort_merge_merge(arr, temp, left, mid, right);
}

static void sort_merge_merge_sort_inplace(int32_t *arr, int64_t size) {
  int32_t *temp = malloc(size * sizeof(int32_t));
  sort_merge_merge_sort_helper(arr, temp, 0, size - 1);
  free(temp);
}

static void sort_merge_test(SortMergeData *data) {
  if (data->sorted_data) {
    free(data->sorted_data);
  }

  data->sorted_data = malloc(data->base.size_val * sizeof(int32_t));
  memcpy(data->sorted_data, data->base.data,
         data->base.size_val * sizeof(int32_t));

  sort_merge_merge_sort_inplace(data->sorted_data, data->base.size_val);
}

void SortMerge_prepare(Benchmark *self) {
  SortMergeData *data = (SortMergeData *)self->data;
  sort_base_prepare(self, "Sort::Merge");
  data->sorted_data = NULL;
}

void SortMerge_run(Benchmark *self, int iteration_id) {
  SortMergeData *data = (SortMergeData *)self->data;

  sort_merge_test(data);

  int32_t random_index1 = Helper_next_int((uint32_t)data->base.size_val);
  int32_t random_index2 = Helper_next_int((uint32_t)data->base.size_val);

  uint32_t iteration_result = (uint32_t)data->base.data[random_index1] +
                              (uint32_t)data->sorted_data[random_index2];
  data->base.result_val += iteration_result;
}

uint32_t SortMerge_checksum(Benchmark *self) {
  SortMergeData *data = (SortMergeData *)self->data;
  return data->base.result_val;
}

void SortMerge_cleanup(Benchmark *self) {
  SortMergeData *data = (SortMergeData *)self->data;
  sort_base_cleanup(&data->base);
  if (data->sorted_data) {
    free(data->sorted_data);
    data->sorted_data = NULL;
  }
}

Benchmark *SortMerge_create(void) {
  Benchmark *bench = Benchmark_create("Sort::Merge");

  SortMergeData *data = malloc(sizeof(SortMergeData));
  memset(data, 0, sizeof(SortMergeData));

  bench->data = data;

  bench->prepare = SortMerge_prepare;
  bench->run = SortMerge_run;
  bench->checksum = SortMerge_checksum;
  bench->cleanup = SortMerge_cleanup;

  return bench;
}

typedef struct {
  SortBaseData base;
  int32_t *sorted_data;
} SortSelfData;

static int sort_self_compare(const void *a, const void *b) {
  int32_t ia = *(const int32_t *)a;
  int32_t ib = *(const int32_t *)b;
  return (ia > ib) - (ia < ib);
}

static void sort_self_test(SortSelfData *data) {
  if (data->sorted_data) {
    free(data->sorted_data);
  }

  data->sorted_data = malloc(data->base.size_val * sizeof(int32_t));
  memcpy(data->sorted_data, data->base.data,
         data->base.size_val * sizeof(int32_t));

  qsort(data->sorted_data, (size_t)data->base.size_val, sizeof(int32_t),
        sort_self_compare);
}

void SortSelf_prepare(Benchmark *self) {
  SortSelfData *data = (SortSelfData *)self->data;
  sort_base_prepare(self, "Sort::Self");
  data->sorted_data = NULL;
}

void SortSelf_run(Benchmark *self, int iteration_id) {
  SortSelfData *data = (SortSelfData *)self->data;

  sort_self_test(data);

  int32_t random_index1 = Helper_next_int((uint32_t)data->base.size_val);
  int32_t random_index2 = Helper_next_int((uint32_t)data->base.size_val);

  uint32_t iteration_result = (uint32_t)data->base.data[random_index1] +
                              (uint32_t)data->sorted_data[random_index2];
  data->base.result_val += iteration_result;
}

uint32_t SortSelf_checksum(Benchmark *self) {
  SortSelfData *data = (SortSelfData *)self->data;
  return data->base.result_val;
}

void SortSelf_cleanup(Benchmark *self) {
  SortSelfData *data = (SortSelfData *)self->data;
  sort_base_cleanup(&data->base);
  if (data->sorted_data) {
    free(data->sorted_data);
    data->sorted_data = NULL;
  }
}

Benchmark *SortSelf_create(void) {
  Benchmark *bench = Benchmark_create("Sort::Self");

  SortSelfData *data = malloc(sizeof(SortSelfData));
  memset(data, 0, sizeof(SortSelfData));

  bench->data = data;

  bench->prepare = SortSelf_prepare;
  bench->run = SortSelf_run;
  bench->checksum = SortSelf_checksum;
  bench->cleanup = SortSelf_cleanup;

  return bench;
}

typedef struct {
  int vertices;
  int jumps;
  int jump_len;
  int **adj;
  int *adj_count;
  int *adj_capacity;
} GraphPathGraph;

typedef struct {
  GraphPathGraph *graph;
  uint32_t result_val;
} GraphPathBaseData;

static GraphPathGraph *graph_path_graph_new(int vertices, int jumps,
                                            int jump_len) {
  GraphPathGraph *graph = malloc(sizeof(GraphPathGraph));
  graph->vertices = vertices;
  graph->jumps = jumps;
  graph->jump_len = jump_len;

  graph->adj = malloc(vertices * sizeof(int *));
  graph->adj_count = malloc(vertices * sizeof(int));
  graph->adj_capacity = malloc(vertices * sizeof(int));

  for (int i = 0; i < vertices; i++) {
    graph->adj_capacity[i] = 4;
    graph->adj[i] = malloc(graph->adj_capacity[i] * sizeof(int));
    graph->adj_count[i] = 0;
  }

  return graph;
}

static void graph_path_graph_free(GraphPathGraph *graph) {
  if (!graph)
    return;

  if (graph->adj) {
    for (int i = 0; i < graph->vertices; i++) {
      if (graph->adj[i])
        free(graph->adj[i]);
    }
    free(graph->adj);
  }
  if (graph->adj_count)
    free(graph->adj_count);
  if (graph->adj_capacity)
    free(graph->adj_capacity);
  free(graph);
}

static void graph_path_graph_add_edge(GraphPathGraph *graph, int u, int v) {
  if (graph->adj_count[u] >= graph->adj_capacity[u]) {
    graph->adj_capacity[u] *= 2;
    graph->adj[u] =
        realloc(graph->adj[u], graph->adj_capacity[u] * sizeof(int));
  }
  graph->adj[u][graph->adj_count[u]++] = v;

  if (graph->adj_count[v] >= graph->adj_capacity[v]) {
    graph->adj_capacity[v] *= 2;
    graph->adj[v] =
        realloc(graph->adj[v], graph->adj_capacity[v] * sizeof(int));
  }
  graph->adj[v][graph->adj_count[v]++] = u;
}

static void graph_path_graph_generate_random(GraphPathGraph *graph) {
  for (int i = 1; i < graph->vertices; i++) {
    graph_path_graph_add_edge(graph, i, i - 1);
  }

  for (int v = 0; v < graph->vertices; v++) {
    int num_jumps = Helper_next_int(graph->jumps);
    for (int j = 0; j < num_jumps; j++) {
      int offset = Helper_next_int(graph->jump_len) - graph->jump_len / 2;
      int u = v + offset;

      if (u >= 0 && u < graph->vertices && u != v) {
        graph_path_graph_add_edge(graph, v, u);
      }
    }
  }
}

static void graph_path_base_prepare(Benchmark *self, const char *bench_name,
                                    GraphPathBaseData *data) {
  int vertices = (int)Helper_config_i64(bench_name, "vertices");
  int jumps = (int)Helper_config_i64(bench_name, "jumps");
  int jump_len = (int)Helper_config_i64(bench_name, "jump_len");

  data->graph = graph_path_graph_new(vertices, jumps, jump_len);
  graph_path_graph_generate_random(data->graph);
  data->result_val = 0;
}

static void graph_path_base_cleanup(GraphPathBaseData *data) {
  if (data->graph) {
    graph_path_graph_free(data->graph);
    data->graph = NULL;
  }
}

typedef struct {
  GraphPathBaseData base;
} GraphPathBFSData;

static int graph_path_bfs_search(GraphPathGraph *graph, int start, int target) {
  if (start == target)
    return 0;

  uint8_t *visited = calloc(graph->vertices, sizeof(uint8_t));
  int *queue = malloc(graph->vertices * 2 * sizeof(int));
  int front = 0, rear = 0;

  visited[start] = 1;
  queue[rear++] = start;
  queue[rear++] = 0;

  while (front < rear) {
    int v = queue[front++];
    int dist = queue[front++];

    for (int i = 0; i < graph->adj_count[v]; i++) {
      int neighbor = graph->adj[v][i];
      if (neighbor == target) {
        free(visited);
        free(queue);
        return dist + 1;
      }

      if (!visited[neighbor]) {
        visited[neighbor] = 1;
        queue[rear++] = neighbor;
        queue[rear++] = dist + 1;
      }
    }
  }

  free(visited);
  free(queue);
  return -1;
}

void GraphPathBFS_prepare(Benchmark *self) {
  GraphPathBFSData *data = (GraphPathBFSData *)self->data;
  graph_path_base_prepare(self, "Graph::BFS", &data->base);
}

void GraphPathBFS_run(Benchmark *self, int iteration_id) {
  GraphPathBFSData *data = (GraphPathBFSData *)self->data;
  int length = graph_path_bfs_search(data->base.graph, 0,
                                     data->base.graph->vertices - 1);
  data->base.result_val += length;
}

uint32_t GraphPathBFS_checksum(Benchmark *self) {
  GraphPathBFSData *data = (GraphPathBFSData *)self->data;
  return data->base.result_val;
}

void GraphPathBFS_cleanup(Benchmark *self) {
  GraphPathBFSData *data = (GraphPathBFSData *)self->data;
  graph_path_base_cleanup(&data->base);
}

Benchmark *GraphPathBFS_create(void) {
  Benchmark *bench = Benchmark_create("Graph::BFS");
  GraphPathBFSData *data = malloc(sizeof(GraphPathBFSData));
  memset(data, 0, sizeof(GraphPathBFSData));
  bench->data = data;
  bench->prepare = GraphPathBFS_prepare;
  bench->run = GraphPathBFS_run;
  bench->checksum = GraphPathBFS_checksum;
  bench->cleanup = GraphPathBFS_cleanup;
  return bench;
}

typedef struct {
  GraphPathBaseData base;
} GraphPathDFSData;

static int graph_path_dfs_search(GraphPathGraph *graph, int start, int target) {
  if (start == target)
    return 0;

  uint8_t *visited = calloc(graph->vertices, sizeof(uint8_t));
  int *stack = malloc(graph->vertices * 2 * sizeof(int));
  int stack_top = -1;
  int best_path = INT_MAX;

  stack[++stack_top] = start;
  stack[++stack_top] = 0;

  while (stack_top >= 0) {
    int dist = stack[stack_top--];
    int v = stack[stack_top--];

    if (visited[v] || dist >= best_path)
      continue;
    visited[v] = 1;

    for (int i = 0; i < graph->adj_count[v]; i++) {
      int neighbor = graph->adj[v][i];
      if (neighbor == target) {
        if (dist + 1 < best_path)
          best_path = dist + 1;
      } else if (!visited[neighbor]) {
        stack[++stack_top] = neighbor;
        stack[++stack_top] = dist + 1;
      }
    }
  }

  free(visited);
  free(stack);
  return best_path == INT_MAX ? -1 : best_path;
}

void GraphPathDFS_prepare(Benchmark *self) {
  GraphPathDFSData *data = (GraphPathDFSData *)self->data;
  graph_path_base_prepare(self, "Graph::DFS", &data->base);
}

void GraphPathDFS_run(Benchmark *self, int iteration_id) {
  GraphPathDFSData *data = (GraphPathDFSData *)self->data;
  int length = graph_path_dfs_search(data->base.graph, 0,
                                     data->base.graph->vertices - 1);
  data->base.result_val += length;
}

uint32_t GraphPathDFS_checksum(Benchmark *self) {
  GraphPathDFSData *data = (GraphPathDFSData *)self->data;
  return data->base.result_val;
}

void GraphPathDFS_cleanup(Benchmark *self) {
  GraphPathDFSData *data = (GraphPathDFSData *)self->data;
  graph_path_base_cleanup(&data->base);
}

Benchmark *GraphPathDFS_create(void) {
  Benchmark *bench = Benchmark_create("Graph::DFS");
  GraphPathDFSData *data = malloc(sizeof(GraphPathDFSData));
  memset(data, 0, sizeof(GraphPathDFSData));
  bench->data = data;
  bench->prepare = GraphPathDFS_prepare;
  bench->run = GraphPathDFS_run;
  bench->checksum = GraphPathDFS_checksum;
  bench->cleanup = GraphPathDFS_cleanup;
  return bench;
}

typedef struct {
  GraphPathBaseData base;
} GraphPathAStarData;

typedef struct {
  int vertex;
  int priority;
} PriorityQueueItem;

typedef struct {
  PriorityQueueItem *items;
  int size;
  int capacity;
} PriorityQueue;

static void priority_queue_push(PriorityQueue *pq, int vertex, int priority) {
  if (pq->size >= pq->capacity) {
    pq->capacity = pq->capacity == 0 ? 16 : pq->capacity * 2;
    pq->items = realloc(pq->items, pq->capacity * sizeof(PriorityQueueItem));
  }

  int i = pq->size++;
  while (i > 0) {
    int parent = (i - 1) / 2;
    if (pq->items[parent].priority <= priority)
      break;
    pq->items[i] = pq->items[parent];
    i = parent;
  }
  pq->items[i] = (PriorityQueueItem){vertex, priority};
}

static PriorityQueueItem priority_queue_pop(PriorityQueue *pq) {
  PriorityQueueItem min = pq->items[0];
  pq->size--;
  if (pq->size > 0) {
    PriorityQueueItem last = pq->items[pq->size];
    int i = 0;
    while (true) {
      int left = 2 * i + 1;
      int right = 2 * i + 2;
      int smallest = i;

      if (left < pq->size &&
          pq->items[left].priority < pq->items[smallest].priority)
        smallest = left;
      if (right < pq->size &&
          pq->items[right].priority < pq->items[smallest].priority)
        smallest = right;

      if (smallest == i)
        break;

      pq->items[i] = pq->items[smallest];
      i = smallest;
    }
    pq->items[i] = last;
  }
  return min;
}

static int heuristic(int v, int target) { return target - v; }

static int graph_path_astar_search(GraphPathGraph *graph, int start,
                                   int target) {
  if (start == target)
    return 0;

  int *g_score = malloc(graph->vertices * sizeof(int));
  int *f_score = malloc(graph->vertices * sizeof(int));
  uint8_t *visited = calloc(graph->vertices, sizeof(uint8_t));

  for (int i = 0; i < graph->vertices; i++) {
    g_score[i] = INT_MAX;
    f_score[i] = INT_MAX;
  }
  g_score[start] = 0;
  f_score[start] = heuristic(start, target);

  PriorityQueue open_set = {0};
  priority_queue_push(&open_set, start, f_score[start]);

  uint8_t *in_open_set = calloc(graph->vertices, sizeof(uint8_t));
  in_open_set[start] = 1;

  while (open_set.size > 0) {
    PriorityQueueItem current_item = priority_queue_pop(&open_set);
    int current = current_item.vertex;
    in_open_set[current] = 0;

    if (current == target) {
      int result = g_score[current];
      free(g_score);
      free(f_score);
      free(visited);
      free(in_open_set);
      free(open_set.items);
      return result;
    }

    visited[current] = 1;

    for (int i = 0; i < graph->adj_count[current]; i++) {
      int neighbor = graph->adj[current][i];
      if (visited[neighbor])
        continue;

      int tentative_g = g_score[current] + 1;

      if (tentative_g < g_score[neighbor]) {
        g_score[neighbor] = tentative_g;
        int f = tentative_g + heuristic(neighbor, target);
        f_score[neighbor] = f;

        if (!in_open_set[neighbor]) {
          priority_queue_push(&open_set, neighbor, f);
          in_open_set[neighbor] = 1;
        }
      }
    }
  }

  free(g_score);
  free(f_score);
  free(visited);
  free(in_open_set);
  free(open_set.items);
  return -1;
}

void GraphPathAStar_prepare(Benchmark *self) {
  GraphPathAStarData *data = (GraphPathAStarData *)self->data;
  graph_path_base_prepare(self, "Graph::AStar", &data->base);
}

void GraphPathAStar_run(Benchmark *self, int iteration_id) {
  GraphPathAStarData *data = (GraphPathAStarData *)self->data;
  int length = graph_path_astar_search(data->base.graph, 0,
                                       data->base.graph->vertices - 1);
  data->base.result_val += length;
}

uint32_t GraphPathAStar_checksum(Benchmark *self) {
  GraphPathAStarData *data = (GraphPathAStarData *)self->data;
  return data->base.result_val;
}

void GraphPathAStar_cleanup(Benchmark *self) {
  GraphPathAStarData *data = (GraphPathAStarData *)self->data;
  graph_path_base_cleanup(&data->base);
}

Benchmark *GraphPathAStar_create(void) {
  Benchmark *bench = Benchmark_create("Graph::AStar");
  GraphPathAStarData *data = malloc(sizeof(GraphPathAStarData));
  memset(data, 0, sizeof(GraphPathAStarData));
  bench->data = data;
  bench->prepare = GraphPathAStar_prepare;
  bench->run = GraphPathAStar_run;
  bench->checksum = GraphPathAStar_checksum;
  bench->cleanup = GraphPathAStar_cleanup;
  return bench;
}

typedef struct {
  uint8_t *data;
  int64_t size_val;
  uint32_t result_val;
} BufferHashBaseData;

static void buffer_hash_base_prepare(Benchmark *self, const char *bench_name,
                                     BufferHashBaseData *data) {
  data->size_val = Helper_config_i64(bench_name, "size");
  if (data->size_val <= 0) {
    data->size_val = 1000000;
  }

  data->data = malloc(data->size_val * sizeof(uint8_t));

  for (int64_t i = 0; i < data->size_val; i++) {
    data->data[i] = (uint8_t)Helper_next_int(256);
  }

  data->result_val = 0;
}

static void buffer_hash_base_cleanup(BufferHashBaseData *data) {
  if (data->data) {
    free(data->data);
    data->data = NULL;
  }
}

typedef struct {
  BufferHashBaseData base;
} BufferHashSHA256Data;

static uint32_t buffer_hash_sha256_digest(uint8_t *data, int64_t size) {
  uint32_t hashes[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};

  for (int64_t i = 0; i < size; i++) {
    uint32_t hash_idx = (uint32_t)(i & 7);
    uint32_t *hash = &hashes[hash_idx];

    uint32_t temp = (*hash << 5) + *hash;
    temp = temp + data[i];
    *hash = temp;

    temp = *hash + (*hash << 10);
    *hash = temp ^ (*hash >> 6);
  }

  uint8_t result[32];
  for (int i = 0; i < 8; i++) {
    result[i * 4] = (hashes[i] >> 24) & 0xFF;
    result[i * 4 + 1] = (hashes[i] >> 16) & 0xFF;
    result[i * 4 + 2] = (hashes[i] >> 8) & 0xFF;
    result[i * 4 + 3] = hashes[i] & 0xFF;
  }

  return (uint32_t)result[0] | ((uint32_t)result[1] << 8) |
         ((uint32_t)result[2] << 16) | ((uint32_t)result[3] << 24);
}

void BufferHashSHA256_prepare(Benchmark *self) {
  BufferHashSHA256Data *data = (BufferHashSHA256Data *)self->data;
  buffer_hash_base_prepare(self, "Hash::SHA256", &data->base);
}

void BufferHashSHA256_run(Benchmark *self, int iteration_id) {
  BufferHashSHA256Data *data = (BufferHashSHA256Data *)self->data;

  uint32_t hash_result =
      buffer_hash_sha256_digest(data->base.data, data->base.size_val);

  data->base.result_val = (data->base.result_val + hash_result) & 0xFFFFFFFFu;
}

uint32_t BufferHashSHA256_checksum(Benchmark *self) {
  BufferHashSHA256Data *data = (BufferHashSHA256Data *)self->data;
  return data->base.result_val;
}

void BufferHashSHA256_cleanup(Benchmark *self) {
  BufferHashSHA256Data *data = (BufferHashSHA256Data *)self->data;
  buffer_hash_base_cleanup(&data->base);
}

Benchmark *BufferHashSHA256_create(void) {
  Benchmark *bench = Benchmark_create("Hash::SHA256");

  BufferHashSHA256Data *data = malloc(sizeof(BufferHashSHA256Data));
  memset(data, 0, sizeof(BufferHashSHA256Data));

  bench->data = data;

  bench->prepare = BufferHashSHA256_prepare;
  bench->run = BufferHashSHA256_run;
  bench->checksum = BufferHashSHA256_checksum;
  bench->cleanup = BufferHashSHA256_cleanup;

  return bench;
}

typedef struct {
  BufferHashBaseData base;
} BufferHashCRC32Data;

static uint32_t buffer_hash_crc32_digest(uint8_t *data, int64_t size) {
  uint32_t crc = 0xFFFFFFFFu;

  for (int64_t i = 0; i < size; i++) {
    crc = crc ^ data[i];
    for (int j = 0; j < 8; j++) {
      if (crc & 1) {
        crc = (crc >> 1) ^ 0xEDB88320u;
      } else {
        crc = crc >> 1;
      }
    }
  }
  return crc ^ 0xFFFFFFFFu;
}

void BufferHashCRC32_prepare(Benchmark *self) {
  BufferHashCRC32Data *data = (BufferHashCRC32Data *)self->data;
  buffer_hash_base_prepare(self, "Hash::CRC32", &data->base);
}

void BufferHashCRC32_run(Benchmark *self, int iteration_id) {
  BufferHashCRC32Data *data = (BufferHashCRC32Data *)self->data;

  uint32_t crc_result =
      buffer_hash_crc32_digest(data->base.data, data->base.size_val);

  data->base.result_val += crc_result;
}

uint32_t BufferHashCRC32_checksum(Benchmark *self) {
  BufferHashCRC32Data *data = (BufferHashCRC32Data *)self->data;
  return data->base.result_val;
}

void BufferHashCRC32_cleanup(Benchmark *self) {
  BufferHashCRC32Data *data = (BufferHashCRC32Data *)self->data;
  buffer_hash_base_cleanup(&data->base);
}

Benchmark *BufferHashCRC32_create(void) {
  Benchmark *bench = Benchmark_create("Hash::CRC32");

  BufferHashCRC32Data *data = malloc(sizeof(BufferHashCRC32Data));
  memset(data, 0, sizeof(BufferHashCRC32Data));

  bench->data = data;

  bench->prepare = BufferHashCRC32_prepare;
  bench->run = BufferHashCRC32_run;
  bench->checksum = BufferHashCRC32_checksum;
  bench->cleanup = BufferHashCRC32_cleanup;

  return bench;
}

typedef struct CacheNode {
  char *key;
  char *value;
  int64_t timestamp;
  struct CacheNode *prev;
  struct CacheNode *next;
  UT_hash_handle hh;
} CacheNode;

typedef struct {
  CacheNode *head;
  CacheNode *tail;
  CacheNode *hash_table;
  size_t capacity;
  size_t size;
  int64_t time;
} CacheSimulationCache;

typedef struct {
  uint32_t result_val;
  int64_t values_size;
  int64_t cache_size;
  int64_t hits;
  int64_t misses;
  CacheSimulationCache *cache;
} CacheSimulationData;

static CacheSimulationCache *cache_simulation_cache_new(size_t capacity) {
  CacheSimulationCache *cache = malloc(sizeof(CacheSimulationCache));
  cache->head = NULL;
  cache->tail = NULL;
  cache->hash_table = NULL;
  cache->capacity = capacity;
  cache->size = 0;
  cache->time = 0;
  return cache;
}

static void cache_simulation_cache_move_to_front(CacheSimulationCache *cache,
                                                 CacheNode *node) {
  if (node == cache->head)
    return;

  if (node->prev)
    node->prev->next = node->next;
  if (node->next)
    node->next->prev = node->prev;

  if (node == cache->tail)
    cache->tail = node->prev;

  node->prev = NULL;
  node->next = cache->head;
  if (cache->head)
    cache->head->prev = node;
  cache->head = node;
  if (!cache->tail)
    cache->tail = node;
}

static CacheNode *cache_simulation_cache_get(CacheSimulationCache *cache,
                                             const char *key) {
  CacheNode *node = NULL;
  HASH_FIND_STR(cache->hash_table, key, node);

  if (node) {
    cache_simulation_cache_move_to_front(cache, node);
    node->timestamp = ++cache->time;
    return node;
  }
  return NULL;
}

static void cache_simulation_cache_remove_oldest(CacheSimulationCache *cache) {
  if (!cache->tail)
    return;

  CacheNode *oldest = cache->tail;

  HASH_DEL(cache->hash_table, oldest);

  if (oldest->prev)
    oldest->prev->next = oldest->next;
  if (oldest->next)
    oldest->next->prev = oldest->prev;

  if (cache->head == oldest)
    cache->head = oldest->next;
  if (cache->tail == oldest)
    cache->tail = oldest->prev;

  free(oldest->key);
  free(oldest->value);
  free(oldest);

  cache->size--;
}

static void cache_simulation_cache_put(CacheSimulationCache *cache,
                                       const char *key, const char *value) {
  CacheNode *node = NULL;
  HASH_FIND_STR(cache->hash_table, key, node);

  if (node) {

    free(node->value);
    node->value = strdup(value);
    cache_simulation_cache_move_to_front(cache, node);
    node->timestamp = ++cache->time;
    return;
  }

  if (cache->size >= cache->capacity) {
    cache_simulation_cache_remove_oldest(cache);
  }

  node = malloc(sizeof(CacheNode));
  node->key = strdup(key);
  node->value = strdup(value);
  node->timestamp = ++cache->time;
  node->prev = NULL;
  node->next = NULL;

  HASH_ADD_STR(cache->hash_table, key, node);

  node->next = cache->head;
  if (cache->head)
    cache->head->prev = node;
  cache->head = node;
  if (!cache->tail)
    cache->tail = node;

  cache->size++;
}

static void cache_simulation_cache_free(CacheSimulationCache *cache) {
  CacheNode *node, *tmp;
  HASH_ITER(hh, cache->hash_table, node, tmp) {
    HASH_DEL(cache->hash_table, node);
    free(node->key);
    free(node->value);
    free(node);
  }
  free(cache);
}

void CacheSimulation_prepare(Benchmark *self) {
  CacheSimulationData *data = (CacheSimulationData *)self->data;

  data->values_size = Helper_config_i64(self->name, "values");
  if (data->values_size <= 0) {
    data->values_size = 2000;
  }

  data->cache_size = Helper_config_i64(self->name, "size");
  if (data->cache_size <= 0) {
    data->cache_size = 1000;
  }

  data->result_val = 5432;
  data->hits = 0;
  data->misses = 0;
  data->cache = cache_simulation_cache_new((size_t)data->cache_size);
}

void CacheSimulation_run(Benchmark *self, int iteration_id) {
  CacheSimulationData *data = (CacheSimulationData *)self->data;

  for (int i = 0; i < 1000; i++) {
    char key_buf[32];
    snprintf(key_buf, sizeof(key_buf), "item_%u",
             Helper_next_int((uint32_t)data->values_size));

    if (cache_simulation_cache_get(data->cache, key_buf)) {
      data->hits++;
      char value_buf[32];
      snprintf(value_buf, sizeof(value_buf), "updated_%d", iteration_id);
      cache_simulation_cache_put(data->cache, key_buf, value_buf);
    } else {
      data->misses++;
      char value_buf[32];
      snprintf(value_buf, sizeof(value_buf), "new_%d", iteration_id);
      cache_simulation_cache_put(data->cache, key_buf, value_buf);
    }
  }
}

uint32_t CacheSimulation_checksum(Benchmark *self) {
  CacheSimulationData *data = (CacheSimulationData *)self->data;

  uint32_t final_result = data->result_val;
  final_result = ((int64_t)final_result << 5) + (uint32_t)data->hits;
  final_result = ((int64_t)final_result << 5) + (uint32_t)data->misses;
  final_result = ((int64_t)final_result << 5) + (uint32_t)data->cache->size;

  return final_result;
}

void CacheSimulation_cleanup(Benchmark *self) {
  CacheSimulationData *data = (CacheSimulationData *)self->data;

  if (data->cache) {
    cache_simulation_cache_free(data->cache);
    data->cache = NULL;
  }
}

Benchmark *CacheSimulation_create(void) {
  Benchmark *bench = Benchmark_create("Etc::CacheSimulation");

  CacheSimulationData *data = malloc(sizeof(CacheSimulationData));
  memset(data, 0, sizeof(CacheSimulationData));

  bench->data = data;

  bench->prepare = CacheSimulation_prepare;
  bench->run = CacheSimulation_run;
  bench->checksum = CacheSimulation_checksum;
  bench->cleanup = CacheSimulation_cleanup;

  return bench;
}

typedef enum {
  AST_NUMBER,
  AST_VARIABLE,
  AST_BINARY_OP,
  AST_ASSIGNMENT
} AST_NodeType;

typedef struct AST_Node AST_Node;
typedef struct AST_BinaryOp AST_BinaryOp;
typedef struct AST_Assignment AST_Assignment;

struct AST_BinaryOp {
  char op;
  AST_Node *left;
  AST_Node *right;
};

struct AST_Assignment {
  char *var_name;
  AST_Node *expr;
};

struct AST_Node {
  AST_NodeType type;
  union {
    int64_t number_value;
    char *variable_name;
    AST_BinaryOp *binary_op;
    AST_Assignment *assignment;
  } data;
};

typedef struct {
  AST_Node **expressions;
  int64_t expressions_count;
  int64_t expressions_capacity;
  uint32_t result_val;
  char *text;
  int64_t operations;
} CalculatorAstData;

static AST_Node *ast_node_new_number(int64_t value) {
  AST_Node *node = malloc(sizeof(AST_Node));
  node->type = AST_NUMBER;
  node->data.number_value = value;
  return node;
}

static AST_Node *ast_node_new_variable(const char *name) {
  AST_Node *node = malloc(sizeof(AST_Node));
  node->type = AST_VARIABLE;
  node->data.variable_name = strdup(name);
  return node;
}

static AST_Node *ast_node_new_binary_op(char op, AST_Node *left,
                                        AST_Node *right) {
  AST_BinaryOp *binary_op = malloc(sizeof(AST_BinaryOp));
  binary_op->op = op;
  binary_op->left = left;
  binary_op->right = right;

  AST_Node *node = malloc(sizeof(AST_Node));
  node->type = AST_BINARY_OP;
  node->data.binary_op = binary_op;
  return node;
}

static AST_Node *ast_node_new_assignment(const char *var_name, AST_Node *expr) {
  AST_Assignment *assignment = malloc(sizeof(AST_Assignment));
  assignment->var_name = strdup(var_name);
  assignment->expr = expr;

  AST_Node *node = malloc(sizeof(AST_Node));
  node->type = AST_ASSIGNMENT;
  node->data.assignment = assignment;
  return node;
}

static void ast_node_free(AST_Node *node) {
  if (!node)
    return;

  switch (node->type) {
  case AST_VARIABLE:
    free(node->data.variable_name);
    break;
  case AST_BINARY_OP:
    if (node->data.binary_op) {
      ast_node_free(node->data.binary_op->left);
      ast_node_free(node->data.binary_op->right);
      free(node->data.binary_op);
    }
    break;
  case AST_ASSIGNMENT:
    if (node->data.assignment) {
      free(node->data.assignment->var_name);
      ast_node_free(node->data.assignment->expr);
      free(node->data.assignment);
    }
    break;
  default:
    break;
  }
  free(node);
}

typedef struct {
  const char *input;
  size_t pos;
  char current_char;
} CalculatorAstParser;

static AST_Node *
calculator_ast_parser_parse_expression(CalculatorAstParser *parser);

static void calculator_ast_parser_init(CalculatorAstParser *parser,
                                       const char *input) {
  parser->input = input;
  parser->pos = 0;
  parser->current_char = input[0];
}

static void calculator_ast_parser_advance(CalculatorAstParser *parser) {
  parser->pos++;
  parser->current_char = parser->input[parser->pos];
}

static void calculator_ast_parser_skip_whitespace(CalculatorAstParser *parser) {
  while (parser->current_char && isspace((unsigned char)parser->current_char)) {
    calculator_ast_parser_advance(parser);
  }
}

static AST_Node *
calculator_ast_parser_parse_number(CalculatorAstParser *parser) {
  int64_t value = 0;
  while (parser->current_char && isdigit((unsigned char)parser->current_char)) {
    value = value * 10 + (parser->current_char - '0');
    calculator_ast_parser_advance(parser);
  }
  return ast_node_new_number(value);
}

static AST_Node *
calculator_ast_parser_parse_variable(CalculatorAstParser *parser) {
  size_t start = parser->pos;
  while (parser->current_char &&
         (isalpha((unsigned char)parser->current_char) ||
          isdigit((unsigned char)parser->current_char))) {
    calculator_ast_parser_advance(parser);
  }

  size_t len = parser->pos - start;
  char *var_name = malloc(len + 1);
  strncpy(var_name, parser->input + start, len);
  var_name[len] = '\0';

  calculator_ast_parser_skip_whitespace(parser);

  if (parser->current_char == '=') {
    calculator_ast_parser_advance(parser);
    AST_Node *expr = calculator_ast_parser_parse_expression(parser);
    AST_Node *node = ast_node_new_assignment(var_name, expr);
    free(var_name);
    return node;
  }

  AST_Node *node = ast_node_new_variable(var_name);
  free(var_name);
  return node;
}

static AST_Node *
calculator_ast_parser_parse_factor(CalculatorAstParser *parser) {
  calculator_ast_parser_skip_whitespace(parser);

  if (!parser->current_char) {
    return ast_node_new_number(0);
  }

  if (isdigit((unsigned char)parser->current_char)) {
    return calculator_ast_parser_parse_number(parser);
  }

  if (isalpha((unsigned char)parser->current_char)) {
    return calculator_ast_parser_parse_variable(parser);
  }

  if (parser->current_char == '(') {
    calculator_ast_parser_advance(parser);
    AST_Node *node = calculator_ast_parser_parse_expression(parser);
    calculator_ast_parser_skip_whitespace(parser);
    if (parser->current_char == ')') {
      calculator_ast_parser_advance(parser);
    }
    return node;
  }

  return ast_node_new_number(0);
}

static AST_Node *calculator_ast_parser_parse_term(CalculatorAstParser *parser) {
  AST_Node *node = calculator_ast_parser_parse_factor(parser);

  while (1) {
    calculator_ast_parser_skip_whitespace(parser);
    if (!parser->current_char)
      break;

    if (parser->current_char == '*' || parser->current_char == '/' ||
        parser->current_char == '%') {
      char op = parser->current_char;
      calculator_ast_parser_advance(parser);
      AST_Node *right = calculator_ast_parser_parse_factor(parser);
      node = ast_node_new_binary_op(op, node, right);
    } else {
      break;
    }
  }

  return node;
}

static AST_Node *
calculator_ast_parser_parse_expression(CalculatorAstParser *parser) {
  AST_Node *node = calculator_ast_parser_parse_term(parser);

  while (1) {
    calculator_ast_parser_skip_whitespace(parser);
    if (!parser->current_char)
      break;

    if (parser->current_char == '+' || parser->current_char == '-') {
      char op = parser->current_char;
      calculator_ast_parser_advance(parser);
      AST_Node *right = calculator_ast_parser_parse_term(parser);
      node = ast_node_new_binary_op(op, node, right);
    } else {
      break;
    }
  }

  return node;
}

static void calculator_ast_parser_parse_all(CalculatorAstParser *parser,
                                            CalculatorAstData *data) {
  data->expressions_count = 0;

  while (parser->current_char) {
    calculator_ast_parser_skip_whitespace(parser);
    if (!parser->current_char)
      break;

    if (data->expressions_count >= data->expressions_capacity) {
      data->expressions_capacity =
          data->expressions_capacity ? data->expressions_capacity * 2 : 16;
      data->expressions = realloc(
          data->expressions, data->expressions_capacity * sizeof(AST_Node *));
    }

    data->expressions[data->expressions_count++] =
        calculator_ast_parser_parse_expression(parser);
  }
}

static char *calculator_ast_generate_random_program(int64_t operations) {
  size_t capacity = operations * 100;
  char *result = malloc(capacity);
  size_t len = 0;

  len += snprintf(result + len, capacity - len, "v0 = 1\n");
  for (int i = 0; i < 10; i++) {
    len += snprintf(result + len, capacity - len, "v%d = v%d + %d\n", i + 1, i,
                    i + 1);
  }

  for (int64_t i = 0; i < operations; i++) {
    int v = (int)(i + 10);

    len += snprintf(result + len, capacity - len, "v%d = v%d + ", v, v - 1);

    switch (Helper_next_int(10)) {
    case 0:
      len += snprintf(result + len, capacity - len,
                      "(v%d / 3) * 4 - %ld / (3 + (18 - v%d)) %% v%d + 2 * ((9 "
                      "- v%d) * (v%d + 7))",
                      v - 1, i, v - 2, v - 3, v - 6, v - 5);
      break;
    case 1:
      len += snprintf(result + len, capacity - len,
                      "v%d + (v%d + v%d) * v%d - (v%d / v%d)", v - 1, v - 2,
                      v - 3, v - 4, v - 5, v - 6);
      break;
    case 2:
      len += snprintf(result + len, capacity - len, "(3789 - (((v%d)))) + 1",
                      v - 7);
      break;
    case 3:
      len += snprintf(result + len, capacity - len, "4/2 * (1-3) + v%d/v%d",
                      v - 9, v - 5);
      break;
    case 4:
      len += snprintf(result + len, capacity - len, "1+2+3+4+5+6+v%d", v - 1);
      break;
    case 5:
      len += snprintf(result + len, capacity - len, "(99999 / v%d)", v - 3);
      break;
    case 6:
      len += snprintf(result + len, capacity - len, "0 + 0 - v%d", v - 8);
      break;
    case 7:
      len += snprintf(result + len, capacity - len,
                      "((((((((((v%d)))))))))) * 2", v - 6);
      break;
    case 8:
      len +=
          snprintf(result + len, capacity - len, "%ld * (v%d%%6)%%7", i, v - 1);
      break;
    case 9:
      len += snprintf(result + len, capacity - len, "(1)/(0-v%d) + (v%d)",
                      v - 5, v - 7);
      break;
    }
    len += snprintf(result + len, capacity - len, "\n");
  }

  result[len] = '\0';
  return result;
}

void CalculatorAst_prepare(Benchmark *self) {
  CalculatorAstData *data = (CalculatorAstData *)self->data;

  data->operations = Helper_config_i64(self->name, "operations");
  if (data->operations <= 0) {
    data->operations = 1000;
  }

  data->text = calculator_ast_generate_random_program(data->operations);
  data->expressions = NULL;
  data->expressions_count = 0;
  data->expressions_capacity = 0;
  data->result_val = 0;
}

void CalculatorAst_run(Benchmark *self, int iteration_id) {
  CalculatorAstData *data = (CalculatorAstData *)self->data;

  if (data->expressions) {
    for (int64_t i = 0; i < data->expressions_count; i++) {
      ast_node_free(data->expressions[i]);
    }
    free(data->expressions);
    data->expressions = NULL;
    data->expressions_count = 0;
    data->expressions_capacity = 0;
  }

  CalculatorAstParser parser;
  calculator_ast_parser_init(&parser, data->text);

  if (data->expressions) {
    for (int64_t i = 0; i < data->expressions_count; i++) {
      ast_node_free(data->expressions[i]);
    }
    free(data->expressions);
    data->expressions = NULL;
    data->expressions_count = 0;
    data->expressions_capacity = 0;
  }

  calculator_ast_parser_parse_all(&parser, data);

  uint32_t iteration_result = (uint32_t)data->expressions_count;

  if (data->expressions_count > 0 &&
      data->expressions[data->expressions_count - 1]->type == AST_ASSIGNMENT) {
    AST_Node *last = data->expressions[data->expressions_count - 1];
    iteration_result += Helper_checksum_string(last->data.assignment->var_name);
  }

  data->result_val += iteration_result;
}

uint32_t CalculatorAst_checksum(Benchmark *self) {
  CalculatorAstData *data = (CalculatorAstData *)self->data;
  return data->result_val;
}

void CalculatorAst_cleanup(Benchmark *self) {
  CalculatorAstData *data = (CalculatorAstData *)self->data;

  if (data->text) {
    free(data->text);
    data->text = NULL;
  }

  if (data->expressions) {
    for (int64_t i = 0; i < data->expressions_count; i++) {
      ast_node_free(data->expressions[i]);
    }
    free(data->expressions);
    data->expressions = NULL;
  }
}

Benchmark *CalculatorAst_create(void) {
  Benchmark *bench = Benchmark_create("Calculator::Ast");

  CalculatorAstData *data = malloc(sizeof(CalculatorAstData));
  memset(data, 0, sizeof(CalculatorAstData));

  bench->data = data;

  bench->prepare = CalculatorAst_prepare;
  bench->run = CalculatorAst_run;
  bench->checksum = CalculatorAst_checksum;
  bench->cleanup = CalculatorAst_cleanup;

  return bench;
}

typedef struct {
  char *name;
  int64_t value;
  UT_hash_handle hh;
} VariableEntry;

typedef struct {
  VariableEntry *variables_hash;
} CalculatorInterpreterContext;

static CalculatorInterpreterContext *calculator_interpreter_context_new(void) {
  CalculatorInterpreterContext *ctx =
      malloc(sizeof(CalculatorInterpreterContext));
  ctx->variables_hash = NULL;
  return ctx;
}

static void
calculator_interpreter_context_free(CalculatorInterpreterContext *ctx) {
  VariableEntry *entry, *tmp;

  HASH_ITER(hh, ctx->variables_hash, entry, tmp) {
    free(entry->name);
    HASH_DEL(ctx->variables_hash, entry);
    free(entry);
  }

  free(ctx);
}

static int64_t *
calculator_interpreter_context_get(CalculatorInterpreterContext *ctx,
                                   const char *name) {
  VariableEntry *entry = NULL;
  HASH_FIND_STR(ctx->variables_hash, name, entry);
  return entry ? &entry->value : NULL;
}

static void
calculator_interpreter_context_set(CalculatorInterpreterContext *ctx,
                                   const char *name, int64_t value) {
  VariableEntry *entry = NULL;
  HASH_FIND_STR(ctx->variables_hash, name, entry);

  if (entry) {
    entry->value = value;
  } else {
    entry = malloc(sizeof(VariableEntry));
    entry->name = strdup(name);
    entry->value = value;
    HASH_ADD_KEYPTR(hh, ctx->variables_hash, entry->name, strlen(entry->name),
                    entry);
  }
}

static int64_t calculator_interpreter_simple_div(int64_t a, int64_t b) {
  if (b == 0)
    return 0;
  if ((a >= 0 && b > 0) || (a < 0 && b < 0)) {
    return a / b;
  } else {
    int64_t abs_a = a >= 0 ? a : -a;
    int64_t abs_b = b >= 0 ? b : -b;
    return -(abs_a / abs_b);
  }
}

static int64_t calculator_interpreter_simple_mod(int64_t a, int64_t b) {
  if (b == 0)
    return 0;
  return a - calculator_interpreter_simple_div(a, b) * b;
}

static int64_t
calculator_interpreter_evaluate(AST_Node *node,
                                CalculatorInterpreterContext *ctx) {
  switch (node->type) {
  case AST_NUMBER:
    return node->data.number_value;

  case AST_VARIABLE: {
    int64_t *value =
        calculator_interpreter_context_get(ctx, node->data.variable_name);
    return value ? *value : 0;
  }

  case AST_BINARY_OP: {
    AST_BinaryOp *binop = node->data.binary_op;
    int64_t left = calculator_interpreter_evaluate(binop->left, ctx);
    int64_t right = calculator_interpreter_evaluate(binop->right, ctx);

    switch (binop->op) {
    case '+':
      return left + right;
    case '-':
      return left - right;
    case '*':
      return left * right;
    case '/':
      return calculator_interpreter_simple_div(left, right);
    case '%':
      return calculator_interpreter_simple_mod(left, right);
    default:
      return 0;
    }
  }

  case AST_ASSIGNMENT: {
    AST_Assignment *assign = node->data.assignment;
    int64_t value = calculator_interpreter_evaluate(assign->expr, ctx);
    calculator_interpreter_context_set(ctx, assign->var_name, value);
    return value;
  }
  }
  return 0;
}

typedef struct {
  CalculatorAstData ast_data;
  uint32_t result_val;
} CalculatorInterpreterData;

void CalculatorInterpreter_prepare(Benchmark *self) {
  CalculatorInterpreterData *data = (CalculatorInterpreterData *)self->data;

  data->ast_data.operations = Helper_config_i64(self->name, "operations");
  if (data->ast_data.operations <= 0) {
    data->ast_data.operations = 1000;
  }

  data->ast_data.text =
      calculator_ast_generate_random_program(data->ast_data.operations);
  data->ast_data.expressions = NULL;
  data->ast_data.expressions_count = 0;
  data->ast_data.expressions_capacity = 0;

  CalculatorAstParser parser;
  calculator_ast_parser_init(&parser, data->ast_data.text);
  calculator_ast_parser_parse_all(&parser, &data->ast_data);

  data->result_val = 0;
}

void CalculatorInterpreter_run(Benchmark *self, int iteration_id) {
  CalculatorInterpreterData *data = (CalculatorInterpreterData *)self->data;

  CalculatorInterpreterContext *ctx = calculator_interpreter_context_new();
  int64_t iteration_result = 0;

  for (int64_t i = 0; i < data->ast_data.expressions_count; i++) {
    iteration_result =
        calculator_interpreter_evaluate(data->ast_data.expressions[i], ctx);
  }

  calculator_interpreter_context_free(ctx);

  data->result_val += iteration_result;
}

uint32_t CalculatorInterpreter_checksum(Benchmark *self) {
  CalculatorInterpreterData *data = (CalculatorInterpreterData *)self->data;
  return data->result_val;
}

void CalculatorInterpreter_cleanup(Benchmark *self) {
  CalculatorInterpreterData *data = (CalculatorInterpreterData *)self->data;

  if (data->ast_data.text) {
    free(data->ast_data.text);
    data->ast_data.text = NULL;
  }

  if (data->ast_data.expressions) {
    for (int64_t i = 0; i < data->ast_data.expressions_count; i++) {
      ast_node_free(data->ast_data.expressions[i]);
    }
    free(data->ast_data.expressions);
    data->ast_data.expressions = NULL;
  }
}

Benchmark *CalculatorInterpreter_create(void) {
  Benchmark *bench = Benchmark_create("Calculator::Interpreter");

  CalculatorInterpreterData *data = malloc(sizeof(CalculatorInterpreterData));
  memset(data, 0, sizeof(CalculatorInterpreterData));

  bench->data = data;

  bench->prepare = CalculatorInterpreter_prepare;
  bench->run = CalculatorInterpreter_run;
  bench->checksum = CalculatorInterpreter_checksum;
  bench->cleanup = CalculatorInterpreter_cleanup;

  return bench;
}

typedef struct Cell Cell;

struct Cell {
  bool alive;
  bool next_state;
  Cell **neighbors;
  int neighbor_count;
};

typedef struct {
  int width;
  int height;
  Cell ***cells;
} GameOfLifeGrid;

typedef struct {
  uint32_t result_val;
  int64_t width_val;
  int64_t height_val;
  GameOfLifeGrid grid;
} GameOfLifeData;

static uint32_t fnv1a_hash(uint32_t hash, uint32_t value) {
  const uint32_t FNV_OFFSET_BASIS = 2166136261UL;
  const uint32_t FNV_PRIME = 16777619UL;

  if (hash == 0)
    hash = FNV_OFFSET_BASIS;
  hash ^= value;
  hash *= FNV_PRIME;
  return hash;
}

static Cell *cell_create(void) {
  Cell *cell = malloc(sizeof(Cell));
  cell->alive = false;
  cell->next_state = false;
  cell->neighbors = malloc(8 * sizeof(Cell *));
  cell->neighbor_count = 0;
  return cell;
}

static void cell_destroy(Cell *cell) {
  free(cell->neighbors);
  free(cell);
}

static void cell_add_neighbor(Cell *cell, Cell *neighbor) {
  cell->neighbors[cell->neighbor_count++] = neighbor;
}

static void cell_compute_next_state(Cell *cell) {
  int alive_neighbors = 0;
  for (int i = 0; i < cell->neighbor_count; i++) {
    if (cell->neighbors[i]->alive) {
      alive_neighbors++;
    }
  }

  if (cell->alive) {
    cell->next_state = (alive_neighbors == 2 || alive_neighbors == 3);
  } else {
    cell->next_state = (alive_neighbors == 3);
  }
}

static void cell_update(Cell *cell) { cell->alive = cell->next_state; }

static void game_of_life_grid_init(GameOfLifeGrid *grid, int width,
                                   int height) {
  grid->width = width;
  grid->height = height;

  grid->cells = malloc(height * sizeof(Cell **));
  for (int y = 0; y < height; y++) {
    grid->cells[y] = malloc(width * sizeof(Cell *));
    for (int x = 0; x < width; x++) {
      grid->cells[y][x] = cell_create();
    }
  }

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      Cell *cell = grid->cells[y][x];

      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0)
            continue;

          int ny = (y + dy + height) % height;
          int nx = (x + dx + width) % width;

          cell_add_neighbor(cell, grid->cells[ny][nx]);
        }
      }
    }
  }
}

static void game_of_life_grid_free(GameOfLifeGrid *grid) {
  for (int y = 0; y < grid->height; y++) {
    for (int x = 0; x < grid->width; x++) {
      cell_destroy(grid->cells[y][x]);
    }
    free(grid->cells[y]);
  }
  free(grid->cells);
}

static void game_of_life_next_generation(GameOfLifeGrid *grid) {

  for (int y = 0; y < grid->height; y++) {
    for (int x = 0; x < grid->width; x++) {
      cell_compute_next_state(grid->cells[y][x]);
    }
  }

  for (int y = 0; y < grid->height; y++) {
    for (int x = 0; x < grid->width; x++) {
      cell_update(grid->cells[y][x]);
    }
  }
}

static int game_of_life_count_alive(GameOfLifeGrid *grid) {
  int count = 0;
  for (int y = 0; y < grid->height; y++) {
    for (int x = 0; x < grid->width; x++) {
      if (grid->cells[y][x]->alive)
        count++;
    }
  }
  return count;
}

static uint32_t game_of_life_grid_hash(GameOfLifeGrid *grid) {
  uint32_t hash = 0;

  for (int y = 0; y < grid->height; y++) {
    for (int x = 0; x < grid->width; x++) {
      uint32_t alive = (grid->cells[y][x]->alive) ? 1 : 0;
      hash = fnv1a_hash(hash, alive);
    }
  }

  return hash;
}

void GameOfLife_prepare(Benchmark *self) {
  GameOfLifeData *data = (GameOfLifeData *)self->data;

  data->width_val = Helper_config_i64(self->name, "w");
  data->height_val = Helper_config_i64(self->name, "h");

  if (data->width_val <= 0)
    data->width_val = 256;
  if (data->height_val <= 0)
    data->height_val = 256;

  game_of_life_grid_init(&data->grid, (int)data->width_val,
                         (int)data->height_val);

  for (int y = 0; y < data->grid.height; y++) {
    for (int x = 0; x < data->grid.width; x++) {
      if (Helper_next_float(1.0) < 0.1) {
        data->grid.cells[y][x]->alive = true;
      }
    }
  }

  data->result_val = 0;
}

void GameOfLife_run(Benchmark *self, int iteration_id) {
  GameOfLifeData *data = (GameOfLifeData *)self->data;
  game_of_life_next_generation(&data->grid);
}

uint32_t GameOfLife_checksum(Benchmark *self) {
  GameOfLifeData *data = (GameOfLifeData *)self->data;
  int alive = game_of_life_count_alive(&data->grid);
  return game_of_life_grid_hash(&data->grid) + (uint32_t)alive;
}

void GameOfLife_cleanup(Benchmark *self) {
  GameOfLifeData *data = (GameOfLifeData *)self->data;
  game_of_life_grid_free(&data->grid);
}

Benchmark *GameOfLife_create(void) {
  Benchmark *bench = Benchmark_create("Etc::GameOfLife");

  GameOfLifeData *data = malloc(sizeof(GameOfLifeData));
  memset(data, 0, sizeof(GameOfLifeData));

  bench->data = data;
  bench->prepare = GameOfLife_prepare;
  bench->run = GameOfLife_run;
  bench->checksum = GameOfLife_checksum;
  bench->cleanup = GameOfLife_cleanup;

  return bench;
}

typedef enum {
  MAZE_CELL_WALL = 0,
  MAZE_CELL_SPACE,
  MAZE_CELL_START,
  MAZE_CELL_FINISH,
  MAZE_CELL_BORDER,
  MAZE_CELL_PATH
} MazeCellKind;

typedef struct MazeCell {
  MazeCellKind kind;
  struct MazeCell *neighbors[4];
  int neighbor_count;
  int x;
  int y;
} MazeCell;

typedef struct {
  int width;
  int height;
  MazeCell **cells;
  MazeCell *start;
  MazeCell *finish;
} Maze;

static MazeCell *maze_cell_create(int x, int y) {
  MazeCell *cell = malloc(sizeof(MazeCell));
  cell->kind = MAZE_CELL_WALL;
  cell->x = x;
  cell->y = y;
  cell->neighbor_count = 0;
  return cell;
}

static void maze_cell_add_neighbor(MazeCell *cell, MazeCell *neighbor) {
  if (cell->neighbor_count < 4) {
    cell->neighbors[cell->neighbor_count++] = neighbor;
  }
}

static bool maze_cell_is_walkable(MazeCell *cell) {
  return cell->kind == MAZE_CELL_SPACE || cell->kind == MAZE_CELL_START ||
         cell->kind == MAZE_CELL_FINISH;
}

static void maze_cell_reset(MazeCell *cell) {
  if (cell->kind == MAZE_CELL_SPACE) {
    cell->kind = MAZE_CELL_WALL;
  }
}

static Maze *maze_create(int width, int height) {
  Maze *maze = malloc(sizeof(Maze));
  maze->width = width;
  maze->height = height;

  maze->cells = malloc(height * sizeof(MazeCell *));
  for (int y = 0; y < height; y++) {
    maze->cells[y] = malloc(width * sizeof(MazeCell));
    for (int x = 0; x < width; x++) {
      maze->cells[y][x] = *maze_cell_create(x, y);
    }
  }

  maze->start = &maze->cells[1][1];
  maze->finish = &maze->cells[height - 2][width - 2];
  maze->start->kind = MAZE_CELL_START;
  maze->finish->kind = MAZE_CELL_FINISH;

  return maze;
}

static void maze_update_neighbors(Maze *maze) {
  for (int y = 0; y < maze->height; y++) {
    for (int x = 0; x < maze->width; x++) {
      MazeCell *cell = &maze->cells[y][x];
      cell->neighbor_count = 0;

      if (x > 0 && y > 0 && x < maze->width - 1 && y < maze->height - 1) {
        maze_cell_add_neighbor(cell, &maze->cells[y - 1][x]);
        maze_cell_add_neighbor(cell, &maze->cells[y + 1][x]);
        maze_cell_add_neighbor(cell, &maze->cells[y][x + 1]);
        maze_cell_add_neighbor(cell, &maze->cells[y][x - 1]);

        for (int t = 0; t < 4; t++) {
          int i = Helper_next_int(4);
          int j = Helper_next_int(4);
          if (i != j) {
            MazeCell *temp = cell->neighbors[i];
            cell->neighbors[i] = cell->neighbors[j];
            cell->neighbors[j] = temp;
          }
        }
      } else {
        cell->kind = MAZE_CELL_BORDER;
      }
    }
  }
}

static void maze_reset(Maze *maze) {
  for (int y = 0; y < maze->height; y++) {
    for (int x = 0; x < maze->width; x++) {
      maze_cell_reset(&maze->cells[y][x]);
    }
  }
  maze->start->kind = MAZE_CELL_START;
  maze->finish->kind = MAZE_CELL_FINISH;
}

static void maze_dig(Maze *maze, MazeCell *start_cell) {
  size_t max_size = maze->width * maze->height;
  MazeCell **stack = malloc(max_size * sizeof(MazeCell *));

  if (!stack)
    return;

  size_t stack_size = 0;
  stack[stack_size++] = start_cell;

  while (stack_size > 0) {
    MazeCell *cell = stack[--stack_size];

    int walkable = 0;
    for (int i = 0; i < cell->neighbor_count; i++) {
      if (maze_cell_is_walkable(cell->neighbors[i]))
        walkable++;
    }

    if (walkable != 1)
      continue;

    cell->kind = MAZE_CELL_SPACE;

    for (int i = 0; i < cell->neighbor_count; i++) {
      MazeCell *n = cell->neighbors[i];
      if (n->kind == MAZE_CELL_WALL) {

        if (stack_size >= max_size) {

          max_size *= 2;
          MazeCell **new_stack = realloc(stack, max_size * sizeof(MazeCell *));
          if (!new_stack) {

            free(stack);
            return;
          }
          stack = new_stack;
        }
        stack[stack_size++] = n;
      }
    }
  }

  free(stack);
}
static void maze_ensure_open_finish(Maze *maze, MazeCell *start_cell) {
  MazeCell **stack = malloc(maze->width * maze->height * sizeof(MazeCell *));
  int stack_size = 0;
  stack[stack_size++] = start_cell;

  while (stack_size > 0) {
    MazeCell *cell = stack[--stack_size];

    cell->kind = MAZE_CELL_SPACE;

    int walkable = 0;
    for (int i = 0; i < cell->neighbor_count; i++) {
      if (maze_cell_is_walkable(cell->neighbors[i]))
        walkable++;
    }

    if (walkable > 1)
      continue;

    for (int i = 0; i < cell->neighbor_count; i++) {
      MazeCell *n = cell->neighbors[i];
      if (n->kind == MAZE_CELL_WALL) {
        stack[stack_size++] = n;
      }
    }
  }

  free(stack);
}

static void maze_generate(Maze *maze) {
  for (int i = 0; i < maze->start->neighbor_count; i++) {
    MazeCell *n = maze->start->neighbors[i];
    if (n->kind == MAZE_CELL_WALL) {
      maze_dig(maze, n);
    }
  }

  for (int i = 0; i < maze->finish->neighbor_count; i++) {
    MazeCell *n = maze->finish->neighbors[i];
    if (n->kind == MAZE_CELL_WALL) {
      maze_ensure_open_finish(maze, n);
    }
  }
}

static MazeCell *maze_middle_cell(Maze *maze) {
  return &maze->cells[maze->height / 2][maze->width / 2];
}

static uint32_t maze_checksum(Maze *maze) {
  uint32_t hasher = 2166136261UL;
  uint32_t prime = 16777619UL;

  for (int y = 0; y < maze->height; y++) {
    for (int x = 0; x < maze->width; x++) {
      if (maze->cells[y][x].kind == MAZE_CELL_SPACE) {
        uint32_t val = (uint32_t)(x * y);
        hasher = (hasher ^ val) * prime;
      }
    }
  }
  return hasher;
}

static void maze_free(Maze *maze) {
  if (!maze)
    return;
  for (int y = 0; y < maze->height; y++) {
    free(maze->cells[y]);
  }
  free(maze->cells);
  free(maze);
}

typedef struct {
  uint32_t result_val;
  int width;
  int height;
  Maze *maze;
} MazeGeneratorData;

void MazeGenerator_prepare(Benchmark *self) {
  MazeGeneratorData *data = (MazeGeneratorData *)self->data;

  data->width = (int)Helper_config_i64(self->name, "w");
  data->height = (int)Helper_config_i64(self->name, "h");

  if (data->width < 5)
    data->width = 5;
  if (data->height < 5)
    data->height = 5;

  data->maze = maze_create(data->width, data->height);
  maze_update_neighbors(data->maze);
  data->result_val = 0;
}

void MazeGenerator_run(Benchmark *self, int iteration_id) {
  (void)iteration_id;
  MazeGeneratorData *data = (MazeGeneratorData *)self->data;

  maze_reset(data->maze);
  maze_generate(data->maze);

  data->result_val += maze_middle_cell(data->maze)->kind;
}

uint32_t MazeGenerator_checksum(Benchmark *self) {
  MazeGeneratorData *data = (MazeGeneratorData *)self->data;
  return data->result_val + maze_checksum(data->maze);
}

void MazeGenerator_cleanup(Benchmark *self) {
  MazeGeneratorData *data = (MazeGeneratorData *)self->data;
  if (data->maze) {
    maze_free(data->maze);
    data->maze = NULL;
  }
}

Benchmark *MazeGenerator_create(void) {
  Benchmark *bench = Benchmark_create("Maze::Generator");
  MazeGeneratorData *data = calloc(1, sizeof(MazeGeneratorData));
  bench->data = data;
  bench->prepare = MazeGenerator_prepare;
  bench->run = MazeGenerator_run;
  bench->checksum = MazeGenerator_checksum;
  bench->cleanup = MazeGenerator_cleanup;
  return bench;
}

typedef struct PathNode {
  MazeCell *cell;
  int parent;
} PathNode;

typedef struct {
  uint32_t result_val;
  int width;
  int height;
  Maze *maze;
  MazeCell **path;
  int path_length;
} MazeBFSData;

void MazeBFS_prepare(Benchmark *self) {
  MazeBFSData *data = (MazeBFSData *)self->data;

  data->width = (int)Helper_config_i64(self->name, "w");
  data->height = (int)Helper_config_i64(self->name, "h");

  if (data->width < 5)
    data->width = 5;
  if (data->height < 5)
    data->height = 5;

  data->maze = maze_create(data->width, data->height);
  maze_update_neighbors(data->maze);
  maze_generate(data->maze);
  data->result_val = 0;
  data->path = NULL;
  data->path_length = 0;
}

static MazeCell **maze_bfs(Maze *maze, MazeCell *start, MazeCell *target,
                           int *out_length) {
  if (start == target) {
    *out_length = 1;
    MazeCell **result = malloc(sizeof(MazeCell *));
    result[0] = start;
    return result;
  }

  int width = maze->width;
  int height = maze->height;

  int *queue = malloc(width * height * sizeof(int));
  int queue_head = 0;
  int queue_tail = 0;

  bool **visited = malloc(height * sizeof(bool *));
  for (int y = 0; y < height; y++) {
    visited[y] = calloc(width, sizeof(bool));
  }

  PathNode *path_nodes = malloc(width * height * sizeof(PathNode));
  int path_count = 0;

  visited[start->y][start->x] = true;
  path_nodes[path_count].cell = start;
  path_nodes[path_count].parent = -1;
  path_count++;
  queue[queue_tail++] = 0;

  while (queue_head < queue_tail) {
    int path_id = queue[queue_head++];
    MazeCell *cell = path_nodes[path_id].cell;

    for (int i = 0; i < cell->neighbor_count; i++) {
      MazeCell *neighbor = cell->neighbors[i];

      if (neighbor == target) {

        int length = 1;
        int cur = path_id;
        while (cur >= 0) {
          length++;
          cur = path_nodes[cur].parent;
        }

        MazeCell **result = malloc(length * sizeof(MazeCell *));
        int idx = length - 1;
        result[idx--] = target;

        cur = path_id;
        while (cur >= 0) {
          result[idx--] = path_nodes[cur].cell;
          cur = path_nodes[cur].parent;
        }

        *out_length = length;

        free(queue);
        for (int y = 0; y < height; y++)
          free(visited[y]);
        free(visited);
        free(path_nodes);

        return result;
      }

      if (maze_cell_is_walkable(neighbor) &&
          !visited[neighbor->y][neighbor->x]) {
        visited[neighbor->y][neighbor->x] = true;
        path_nodes[path_count].cell = neighbor;
        path_nodes[path_count].parent = path_id;
        queue[queue_tail++] = path_count;
        path_count++;
      }
    }
  }

  *out_length = 0;

  free(queue);
  for (int y = 0; y < height; y++)
    free(visited[y]);
  free(visited);
  free(path_nodes);

  return NULL;
}

static uint32_t mid_cell_checksum(MazeCell **path, int length) {
  if (length == 0)
    return 0;
  int mid = length / 2;
  MazeCell *cell = path[mid];
  return (uint32_t)(cell->x * cell->y);
}

void MazeBFS_run(Benchmark *self, int iteration_id) {
  (void)iteration_id;
  MazeBFSData *data = (MazeBFSData *)self->data;

  if (data->path) {
    free(data->path);
    data->path = NULL;
  }

  data->path = maze_bfs(data->maze, data->maze->start, data->maze->finish,
                        &data->path_length);
  data->result_val += data->path_length;
}

uint32_t MazeBFS_checksum(Benchmark *self) {
  MazeBFSData *data = (MazeBFSData *)self->data;
  return data->result_val + mid_cell_checksum(data->path, data->path_length);
}

void MazeBFS_cleanup(Benchmark *self) {
  MazeBFSData *data = (MazeBFSData *)self->data;
  if (data->path)
    free(data->path);
  if (data->maze)
    maze_free(data->maze);
}

Benchmark *MazeBFS_create(void) {
  Benchmark *bench = Benchmark_create("Maze::BFS");
  MazeBFSData *data = calloc(1, sizeof(MazeBFSData));
  bench->data = data;
  bench->prepare = MazeBFS_prepare;
  bench->run = MazeBFS_run;
  bench->checksum = MazeBFS_checksum;
  bench->cleanup = MazeBFS_cleanup;
  return bench;
}

typedef struct {
  int priority;
  int vertex;
} AStarPriorityQueueEntry;

typedef struct {
  AStarPriorityQueueEntry *heap;
  int *best_priority;
  int size;
  int capacity;
} AStarPriorityQueue;

static AStarPriorityQueue *astar_pq_create(int capacity) {
  AStarPriorityQueue *pq = malloc(sizeof(AStarPriorityQueue));
  pq->heap = malloc(capacity * sizeof(AStarPriorityQueueEntry));
  pq->best_priority = malloc(capacity * sizeof(int));
  for (int i = 0; i < capacity; i++) {
    pq->best_priority[i] = INT_MAX;
  }
  pq->size = 0;
  pq->capacity = capacity;
  return pq;
}

static void astar_pq_push(AStarPriorityQueue *pq, int vertex, int priority) {
  if (priority >= pq->best_priority[vertex])
    return;
  pq->best_priority[vertex] = priority;

  if (pq->size >= pq->capacity) {
    pq->capacity *= 2;
    pq->heap =
        realloc(pq->heap, pq->capacity * sizeof(AStarPriorityQueueEntry));
  }

  int i = pq->size++;
  while (i > 0) {
    int parent = (i - 1) / 2;
    if (pq->heap[parent].priority <= priority)
      break;
    pq->heap[i] = pq->heap[parent];
    i = parent;
  }
  pq->heap[i].priority = priority;
  pq->heap[i].vertex = vertex;
}

static AStarPriorityQueueEntry astar_pq_pop(AStarPriorityQueue *pq) {
  AStarPriorityQueueEntry min = pq->heap[0];
  pq->size--;

  if (pq->size > 0) {
    AStarPriorityQueueEntry last = pq->heap[pq->size];
    int i = 0;
    while (1) {
      int left = 2 * i + 1;
      int right = 2 * i + 2;
      int smallest = i;

      if (left < pq->size &&
          pq->heap[left].priority < pq->heap[smallest].priority) {
        smallest = left;
      }
      if (right < pq->size &&
          pq->heap[right].priority < pq->heap[smallest].priority) {
        smallest = right;
      }

      if (smallest == i)
        break;

      pq->heap[i] = pq->heap[smallest];
      i = smallest;
    }
    pq->heap[i] = last;
  }

  return min;
}

static bool astar_pq_empty(AStarPriorityQueue *pq) { return pq->size == 0; }

static void astar_pq_free(AStarPriorityQueue *pq) {
  free(pq->heap);
  free(pq->best_priority);
  free(pq);
}

typedef struct {
  uint32_t result_val;
  int width;
  int height;
  Maze *maze;
  MazeCell **path;
  int path_length;
} MazeAStarData;

static int astar_heuristic(MazeCell *a, MazeCell *b) {
  return abs(a->x - b->x) + abs(a->y - b->y);
}

static int astar_idx(int y, int x, int width) { return y * width + x; }

static MazeCell **maze_astar(Maze *maze, MazeCell *start, MazeCell *target,
                             int *out_length) {
  if (start == target) {
    *out_length = 1;
    MazeCell **result = malloc(sizeof(MazeCell *));
    result[0] = start;
    return result;
  }

  int width = maze->width;
  int height = maze->height;
  int size = width * height;

  int *came_from = malloc(size * sizeof(int));
  int *g_score = malloc(size * sizeof(int));
  for (int i = 0; i < size; i++) {
    came_from[i] = -1;
    g_score[i] = INT_MAX;
  }

  int start_idx = astar_idx(start->y, start->x, width);
  int target_idx = astar_idx(target->y, target->x, width);

  AStarPriorityQueue *open_set = astar_pq_create(size);

  g_score[start_idx] = 0;
  astar_pq_push(open_set, start_idx, astar_heuristic(start, target));

  while (!astar_pq_empty(open_set)) {
    AStarPriorityQueueEntry entry = astar_pq_pop(open_set);
    int current_idx = entry.vertex;

    if (current_idx == target_idx) {

      int length = 0;
      int cur = current_idx;
      while (cur != -1) {
        length++;
        cur = came_from[cur];
      }

      MazeCell **result = malloc(length * sizeof(MazeCell *));
      cur = current_idx;
      for (int i = length - 1; i >= 0; i--) {
        int y = cur / width;
        int x = cur % width;
        result[i] = &maze->cells[y][x];
        cur = came_from[cur];
      }

      *out_length = length;

      free(came_from);
      free(g_score);
      astar_pq_free(open_set);

      return result;
    }

    int current_y = current_idx / width;
    int current_x = current_idx % width;
    MazeCell *current = &maze->cells[current_y][current_x];
    int current_g = g_score[current_idx];

    for (int i = 0; i < current->neighbor_count; i++) {
      MazeCell *neighbor = current->neighbors[i];
      if (!maze_cell_is_walkable(neighbor))
        continue;

      int neighbor_idx = astar_idx(neighbor->y, neighbor->x, width);
      int tentative_g = current_g + 1;

      if (tentative_g < g_score[neighbor_idx]) {
        came_from[neighbor_idx] = current_idx;
        g_score[neighbor_idx] = tentative_g;
        int f_new = tentative_g + astar_heuristic(neighbor, target);
        astar_pq_push(open_set, neighbor_idx, f_new);
      }
    }
  }

  *out_length = 0;

  free(came_from);
  free(g_score);
  astar_pq_free(open_set);

  return NULL;
}

void MazeAStar_prepare(Benchmark *self) {
  MazeAStarData *data = (MazeAStarData *)self->data;

  data->width = (int)Helper_config_i64(self->name, "w");
  data->height = (int)Helper_config_i64(self->name, "h");

  if (data->width < 5)
    data->width = 5;
  if (data->height < 5)
    data->height = 5;

  data->maze = maze_create(data->width, data->height);
  maze_update_neighbors(data->maze);
  maze_generate(data->maze);
  data->result_val = 0;
  data->path = NULL;
  data->path_length = 0;
}

void MazeAStar_run(Benchmark *self, int iteration_id) {
  (void)iteration_id;
  MazeAStarData *data = (MazeAStarData *)self->data;

  if (data->path) {
    free(data->path);
    data->path = NULL;
  }

  data->path = maze_astar(data->maze, data->maze->start, data->maze->finish,
                          &data->path_length);
  data->result_val += data->path_length;
}

uint32_t MazeAStar_checksum(Benchmark *self) {
  MazeAStarData *data = (MazeAStarData *)self->data;
  if (data->path_length == 0)
    return data->result_val;
  int mid = data->path_length / 2;
  MazeCell *cell = data->path[mid];
  return data->result_val + (uint32_t)(cell->x * cell->y);
}

void MazeAStar_cleanup(Benchmark *self) {
  MazeAStarData *data = (MazeAStarData *)self->data;
  if (data->path)
    free(data->path);
  if (data->maze)
    maze_free(data->maze);
}

Benchmark *MazeAStar_create(void) {
  Benchmark *bench = Benchmark_create("Maze::AStar");
  MazeAStarData *data = calloc(1, sizeof(MazeAStarData));
  bench->data = data;
  bench->prepare = MazeAStar_prepare;
  bench->run = MazeAStar_run;
  bench->checksum = MazeAStar_checksum;
  bench->cleanup = MazeAStar_cleanup;
  return bench;
}

static uint8_t *generate_test_data(int64_t size, size_t *data_size) {
  const char *pattern = "ABRACADABRA";
  size_t pattern_len = strlen(pattern);

  uint8_t *data = malloc(size);
  if (!data) {
    *data_size = 0;
    return NULL;
  }

  *data_size = size;
  for (int64_t i = 0; i < size; i++) {
    data[i] = pattern[i % pattern_len];
  }

  return data;
}

typedef struct {
  uint8_t *transformed;
  size_t transformed_size;
  size_t original_idx;
} BWTResult;

static BWTResult bwt_transform(uint8_t *input, size_t n) {
  BWTResult result = {0};

  if (n == 0 || !input) {
    return result;
  }

  uint8_t *doubled = malloc(n * 2);
  memcpy(doubled, input, n);
  memcpy(doubled + n, input, n);

  size_t *sa = malloc(sizeof(size_t) * n);

  for (size_t i = 0; i < n; i++) {
    sa[i] = i;
  }

  size_t *temp_buffer = malloc(sizeof(size_t) * n);
  size_t bucket_counts[256] = {0};

  for (size_t i = 0; i < n; i++) {
    bucket_counts[input[sa[i]]]++;
  }

  size_t bucket_starts[256];
  size_t sum = 0;
  for (int i = 0; i < 256; i++) {
    bucket_starts[i] = sum;
    sum += bucket_counts[i];
  }

  for (size_t i = 0; i < n; i++) {
    uint8_t c = input[sa[i]];
    temp_buffer[bucket_starts[c]++] = sa[i];
  }

  memcpy(sa, temp_buffer, sizeof(size_t) * n);

  if (n > 1) {
    int *rank = malloc(sizeof(int) * n);

    int current_rank = 0;
    uint8_t prev_char = input[sa[0]];

    for (size_t i = 0; i < n; i++) {
      size_t idx = sa[i];
      uint8_t curr_char = input[idx];
      if (curr_char != prev_char) {
        current_rank++;
        prev_char = curr_char;
      }
      rank[idx] = current_rank;
    }

    size_t k = 1;
    while (k < n) {
      struct Pair {
        int first, second;
      };
      struct Pair *pairs = malloc(sizeof(struct Pair) * n);

      for (size_t i = 0; i < n; i++) {
        pairs[i].first = rank[i];
        pairs[i].second = rank[(i + k) % n];
      }

      int *count = calloc(n + 1, sizeof(int));

      for (size_t i = 0; i < n; i++) {
        count[pairs[sa[i]].second]++;
      }

      for (int i = 1; i <= n; i++) {
        count[i] += count[i - 1];
      }

      memcpy(temp_buffer, sa, sizeof(size_t) * n);
      for (int i = n - 1; i >= 0; i--) {
        int key = pairs[temp_buffer[i]].second;
        sa[--count[key]] = temp_buffer[i];
      }

      memset(count, 0, (n + 1) * sizeof(int));

      for (size_t i = 0; i < n; i++) {
        count[pairs[sa[i]].first]++;
      }

      for (int i = 1; i <= n; i++) {
        count[i] += count[i - 1];
      }

      memcpy(temp_buffer, sa, sizeof(size_t) * n);
      for (int i = n - 1; i >= 0; i--) {
        int key = pairs[temp_buffer[i]].first;
        sa[--count[key]] = temp_buffer[i];
      }

      int *new_rank = malloc(sizeof(int) * n);

      new_rank[sa[0]] = 0;
      for (size_t i = 1; i < n; i++) {
        struct Pair prev_pair = pairs[sa[i - 1]];
        struct Pair curr_pair = pairs[sa[i]];
        new_rank[sa[i]] =
            new_rank[sa[i - 1]] + (prev_pair.first != curr_pair.first ||
                                           prev_pair.second != curr_pair.second
                                       ? 1
                                       : 0);
      }

      free(count);
      free(pairs);
      free(rank);
      rank = new_rank;
      k *= 2;
    }

    free(rank);
  }

  result.transformed = malloc(n);
  result.transformed_size = n;
  result.original_idx = 0;

  for (size_t i = 0; i < n; i++) {
    size_t suffix = sa[i];
    if (suffix == 0) {
      result.transformed[i] = input[n - 1];
      result.original_idx = i;
    } else {
      result.transformed[i] = input[suffix - 1];
    }
  }

  free(doubled);
  free(sa);
  free(temp_buffer);

  return result;
}

typedef struct {
  int64_t size_val;
  uint8_t *test_data;
  size_t test_data_size;
  uint32_t result_val;
} BWTEncodeData;

static void bwt_encode_prepare(Benchmark *self) {
  BWTEncodeData *data = (BWTEncodeData *)self->data;
  data->size_val = Helper_config_i64(self->name, "size");
  data->test_data = generate_test_data(data->size_val, &data->test_data_size);
  data->result_val = 0;
}

static void bwt_encode_run(Benchmark *self, int iteration_id) {
  BWTEncodeData *data = (BWTEncodeData *)self->data;
  BWTResult result = bwt_transform(data->test_data, data->test_data_size);

  if (result.transformed) {
    data->result_val =
        (data->result_val + (uint32_t)result.transformed_size) & 0xFFFFFFFFu;
    free(result.transformed);
  }
}

static uint32_t bwt_encode_checksum(Benchmark *self) {
  BWTEncodeData *data = (BWTEncodeData *)self->data;
  return data->result_val;
}

static void bwt_encode_cleanup(Benchmark *self) {
  BWTEncodeData *data = (BWTEncodeData *)self->data;
  if (data->test_data) {
    free(data->test_data);
    data->test_data = NULL;
  }
  free(data);
  self->data = NULL;
}

Benchmark *BWTEncode_create(void) {
  Benchmark *bench = Benchmark_create("Compress::BWTEncode");
  BWTEncodeData *data = malloc(sizeof(BWTEncodeData));
  memset(data, 0, sizeof(BWTEncodeData));

  bench->data = data;
  bench->prepare = bwt_encode_prepare;
  bench->run = bwt_encode_run;
  bench->checksum = bwt_encode_checksum;
  bench->cleanup = bwt_encode_cleanup;

  return bench;
}

static uint8_t *bwt_inverse(BWTResult *bwt_result, size_t *result_size) {
  uint8_t *bwt = bwt_result->transformed;
  size_t n = bwt_result->transformed_size;

  if (n == 0) {
    *result_size = 0;
    return NULL;
  }

  int counts[256] = {0};
  for (size_t i = 0; i < n; i++) {
    counts[bwt[i]]++;
  }

  int positions[256];
  int total = 0;
  for (int i = 0; i < 256; i++) {
    positions[i] = total;
    total += counts[i];
  }

  size_t *next = malloc(sizeof(size_t) * n);

  int temp_counts[256] = {0};

  for (size_t i = 0; i < n; i++) {
    int byte_idx = bwt[i];
    int pos = positions[byte_idx] + temp_counts[byte_idx];
    next[pos] = i;
    temp_counts[byte_idx]++;
  }

  uint8_t *result = malloc(n);

  size_t idx = bwt_result->original_idx;

  for (size_t i = 0; i < n; i++) {
    idx = next[idx];
    result[i] = bwt[idx];
  }

  free(next);
  *result_size = n;
  return result;
}

typedef struct {
  int64_t size_val;
  uint8_t *test_data;
  size_t test_data_size;
  uint8_t *inverted;
  size_t inverted_size;
  BWTResult bwt_result;
  uint32_t result_val;
} BWTDecodeData;

static void bwt_decode_prepare(Benchmark *self) {
  BWTDecodeData *data = (BWTDecodeData *)self->data;
  data->size_val = Helper_config_i64(self->name, "size");
  data->test_data = generate_test_data(data->size_val, &data->test_data_size);
  data->bwt_result = bwt_transform(data->test_data, data->test_data_size);
  data->inverted = NULL;
  data->inverted_size = 0;
  data->result_val = 0;
}

static void bwt_decode_run(Benchmark *self, int iteration_id) {
  BWTDecodeData *data = (BWTDecodeData *)self->data;

  if (data->inverted) {
    free(data->inverted);
    data->inverted = NULL;
  }

  data->inverted = bwt_inverse(&data->bwt_result, &data->inverted_size);

  if (data->inverted) {
    data->result_val =
        (data->result_val + (uint32_t)data->inverted_size) & 0xFFFFFFFFu;
  }
}

static uint32_t bwt_decode_checksum(Benchmark *self) {
  BWTDecodeData *data = (BWTDecodeData *)self->data;
  uint32_t res = data->result_val;

  if (data->inverted && data->test_data &&
      data->inverted_size == data->test_data_size) {
    if (memcmp(data->inverted, data->test_data, data->test_data_size) == 0) {
      res = (res + 100000) & 0xFFFFFFFFu;
    }
  }

  return res;
}

static void bwt_decode_cleanup(Benchmark *self) {
  BWTDecodeData *data = (BWTDecodeData *)self->data;

  if (data->test_data)
    free(data->test_data);
  if (data->inverted)
    free(data->inverted);
  if (data->bwt_result.transformed)
    free(data->bwt_result.transformed);

  free(data);
  self->data = NULL;
}

Benchmark *BWTDecode_create(void) {
  Benchmark *bench = Benchmark_create("Compress::BWTDecode");
  BWTDecodeData *data = malloc(sizeof(BWTDecodeData));
  memset(data, 0, sizeof(BWTDecodeData));

  bench->data = data;
  bench->prepare = bwt_decode_prepare;
  bench->run = bwt_decode_run;
  bench->checksum = bwt_decode_checksum;
  bench->cleanup = bwt_decode_cleanup;

  return bench;
}

typedef struct HuffmanNode {
  int frequency;
  uint8_t byte_val;
  bool is_leaf;
  struct HuffmanNode *left;
  struct HuffmanNode *right;
} HuffmanNode;

typedef struct {
  int code_lengths[256];
  int codes[256];
} HuffmanCodes;

typedef struct {
  uint8_t *data;
  size_t data_size;
  int bit_count;
  int frequencies[256];
} EncodedResult;

static int compare_huffman_nodes(const void *a, const void *b) {
  HuffmanNode *node_a = *(HuffmanNode **)a;
  HuffmanNode *node_b = *(HuffmanNode **)b;
  return node_a->frequency - node_b->frequency;
}

static HuffmanNode *build_huffman_tree(int frequencies[256]) {
  HuffmanNode **nodes = malloc(sizeof(HuffmanNode *) * 256);

  int node_count = 0;

  for (int i = 0; i < 256; i++) {
    if (frequencies[i] > 0) {
      HuffmanNode *node = malloc(sizeof(HuffmanNode));
      node->frequency = frequencies[i];
      node->byte_val = i;
      node->is_leaf = true;
      node->left = NULL;
      node->right = NULL;
      nodes[node_count++] = node;
    }
  }

  if (node_count == 0) {
    free(nodes);
    return NULL;
  }

  if (node_count == 1) {
    HuffmanNode *root = malloc(sizeof(HuffmanNode));
    root->frequency = nodes[0]->frequency;
    root->byte_val = 0;
    root->is_leaf = false;
    root->left = nodes[0];

    root->right = malloc(sizeof(HuffmanNode));
    root->right->frequency = 0;
    root->right->byte_val = 0;
    root->right->is_leaf = true;
    root->right->left = NULL;
    root->right->right = NULL;

    free(nodes);
    return root;
  }

  qsort(nodes, node_count, sizeof(HuffmanNode *), compare_huffman_nodes);

  while (node_count > 1) {
    HuffmanNode *left = nodes[0];
    HuffmanNode *right = nodes[1];

    HuffmanNode *parent = malloc(sizeof(HuffmanNode));

    parent->frequency = left->frequency + right->frequency;
    parent->byte_val = 0;
    parent->is_leaf = false;
    parent->left = left;
    parent->right = right;

    nodes[0] = parent;
    for (int i = 1; i < node_count - 1; i++) {
      nodes[i] = nodes[i + 1];
    }
    node_count--;

    qsort(nodes, node_count, sizeof(HuffmanNode *), compare_huffman_nodes);
  }

  HuffmanNode *root = nodes[0];
  free(nodes);
  return root;
}

static void build_huffman_codes(HuffmanNode *node, int code, int length,
                                HuffmanCodes *huffman_codes) {
  if (!node)
    return;

  if (node->is_leaf) {
    int idx = node->byte_val;
    huffman_codes->code_lengths[idx] = length;
    huffman_codes->codes[idx] = code;
  } else {
    if (node->left) {
      build_huffman_codes(node->left, code << 1, length + 1, huffman_codes);
    }
    if (node->right) {
      build_huffman_codes(node->right, (code << 1) | 1, length + 1,
                          huffman_codes);
    }
  }
}

static void free_huffman_tree(HuffmanNode *node) {
  if (!node)
    return;
  if (!node->is_leaf) {
    free_huffman_tree(node->left);
    free_huffman_tree(node->right);
  }
  free(node);
}

static EncodedResult huffman_encode(uint8_t *data, size_t data_size,
                                    HuffmanCodes *huffman_codes,
                                    int frequencies[256]) {
  EncodedResult result = {0};

  if (!data || data_size == 0 || !huffman_codes) {
    return result;
  }

  memcpy(result.frequencies, frequencies, sizeof(int) * 256);

  size_t max_size = data_size * 2;
  result.data = malloc(max_size);
  if (!result.data) {
    return result;
  }

  result.data_size = 0;
  result.bit_count = 0;

  uint8_t current_byte = 0;
  int bit_pos = 0;

  for (size_t i = 0; i < data_size; i++) {
    int idx = data[i];
    int code = huffman_codes->codes[idx];
    int length = huffman_codes->code_lengths[idx];

    if (length <= 0)
      continue;

    for (int j = length - 1; j >= 0; j--) {
      if ((code & (1 << j)) != 0) {
        current_byte |= (1 << (7 - bit_pos));
      }
      bit_pos++;
      result.bit_count++;

      if (bit_pos == 8) {

        if (result.data_size >= max_size) {
          max_size *= 2;
          uint8_t *new_data = realloc(result.data, max_size);
          if (!new_data) {
            free(result.data);
            result.data = NULL;
            return result;
          }
          result.data = new_data;
        }
        result.data[result.data_size++] = current_byte;
        current_byte = 0;
        bit_pos = 0;
      }
    }
  }

  if (bit_pos > 0) {
    if (result.data_size >= max_size) {
      max_size *= 2;
      uint8_t *new_data = realloc(result.data, max_size);
      if (!new_data) {
        free(result.data);
        result.data = NULL;
        return result;
      }
      result.data = new_data;
    }
    result.data[result.data_size++] = current_byte;
  }

  if (result.data_size < max_size) {
    uint8_t *new_data = realloc(result.data, result.data_size);
    if (new_data) {
      result.data = new_data;
    }
  }

  return result;
}

static uint8_t *huffman_decode(uint8_t *encoded, size_t encoded_size,
                               HuffmanNode *root, int bit_count,
                               size_t *result_size) {
  if (!root || bit_count <= 0 || !encoded) {
    *result_size = 0;
    return NULL;
  }

  size_t max_size = bit_count;
  uint8_t *result = malloc(max_size);
  if (!result) {
    *result_size = 0;
    return NULL;
  }

  size_t result_idx = 0;
  HuffmanNode *current_node = root;
  int bits_processed = 0;
  size_t byte_index = 0;

  while (bits_processed < bit_count && byte_index < encoded_size) {
    uint8_t byte_val = encoded[byte_index++];

    for (int bit_pos = 7; bit_pos >= 0 && bits_processed < bit_count;
         bit_pos--) {
      int bit = (byte_val >> bit_pos) & 1;
      bits_processed++;

      current_node = bit ? current_node->right : current_node->left;

      if (!current_node)
        break;

      if (current_node->is_leaf) {
        result[result_idx++] = current_node->byte_val;
        current_node = root;
      }
    }
  }

  *result_size = result_idx;
  return result;
}

typedef struct {
  int64_t size_val;
  uint8_t *test_data;
  size_t test_data_size;
  EncodedResult encoded;
  uint32_t result_val;
} HuffEncodeData;

static void huff_encode_prepare(Benchmark *self) {
  HuffEncodeData *data = (HuffEncodeData *)self->data;
  data->size_val = Helper_config_i64(self->name, "size");
  data->test_data = generate_test_data(data->size_val, &data->test_data_size);
  data->result_val = 0;
}

static void huff_encode_run(Benchmark *self, int iteration_id) {
  HuffEncodeData *data = (HuffEncodeData *)self->data;

  if (data->encoded.data) {
    free(data->encoded.data);
    data->encoded.data = NULL;
  }

  int frequencies[256] = {0};
  for (size_t i = 0; i < data->test_data_size; i++) {
    frequencies[data->test_data[i]]++;
  }

  HuffmanNode *tree = build_huffman_tree(frequencies);
  if (!tree)
    return;

  HuffmanCodes codes = {0};
  build_huffman_codes(tree, 0, 0, &codes);

  data->encoded = huffman_encode(data->test_data, data->test_data_size, &codes,
                                 frequencies);

  if (data->encoded.data) {
    data->result_val =
        (data->result_val + (uint32_t)data->encoded.data_size) & 0xFFFFFFFFu;
  }

  free_huffman_tree(tree);
}

static uint32_t huff_encode_checksum(Benchmark *self) {
  HuffEncodeData *data = (HuffEncodeData *)self->data;
  return data->result_val;
}

static void huff_encode_cleanup(Benchmark *self) {
  HuffEncodeData *data = (HuffEncodeData *)self->data;
  if (data->test_data) {
    free(data->test_data);
    data->test_data = NULL;
  }
  if (data->encoded.data) {
    free(data->encoded.data);
    data->encoded.data = NULL;
  }
  free(data);
  self->data = NULL;
}

Benchmark *HuffEncode_create(void) {
  Benchmark *bench = Benchmark_create("Compress::HuffEncode");
  HuffEncodeData *data = malloc(sizeof(HuffEncodeData));
  memset(data, 0, sizeof(HuffEncodeData));

  bench->data = data;
  bench->prepare = huff_encode_prepare;
  bench->run = huff_encode_run;
  bench->checksum = huff_encode_checksum;
  bench->cleanup = huff_encode_cleanup;

  return bench;
}

typedef struct {
  int64_t size_val;
  uint8_t *test_data;
  size_t test_data_size;
  uint8_t *decoded;
  size_t decoded_size;
  EncodedResult encoded;
  uint32_t result_val;
} HuffDecodeData;

static void huff_decode_prepare(Benchmark *self) {
  HuffDecodeData *data = (HuffDecodeData *)self->data;
  data->size_val = Helper_config_i64(self->name, "size");
  data->test_data = generate_test_data(data->size_val, &data->test_data_size);
  data->result_val = 0;
  data->decoded = NULL;
  data->decoded_size = 0;

  HuffEncodeData *encoder_data = malloc(sizeof(HuffEncodeData));
  encoder_data->size_val = data->size_val;
  encoder_data->test_data = data->test_data;
  encoder_data->test_data_size = data->test_data_size;

  int frequencies[256] = {0};
  for (size_t i = 0; i < data->test_data_size; i++) {
    frequencies[data->test_data[i]]++;
  }

  HuffmanNode *tree = build_huffman_tree(frequencies);
  if (tree) {
    HuffmanCodes codes = {0};
    build_huffman_codes(tree, 0, 0, &codes);
    data->encoded = huffman_encode(data->test_data, data->test_data_size,
                                   &codes, frequencies);
    free_huffman_tree(tree);
  }

  free(encoder_data);
}

static void huff_decode_run(Benchmark *self, int iteration_id) {
  HuffDecodeData *data = (HuffDecodeData *)self->data;

  HuffmanNode *tree = build_huffman_tree(data->encoded.frequencies);
  if (!tree)
    return;

  if (data->decoded)
    free(data->decoded);

  data->decoded =
      huffman_decode(data->encoded.data, data->encoded.data_size, tree,
                     data->encoded.bit_count, &data->decoded_size);

  if (data->decoded) {
    data->result_val =
        (data->result_val + (uint32_t)data->decoded_size) & 0xFFFFFFFFu;
  }

  free_huffman_tree(tree);
}

static uint32_t huff_decode_checksum(Benchmark *self) {
  HuffDecodeData *data = (HuffDecodeData *)self->data;
  uint32_t res = data->result_val;

  if (data->decoded && data->test_data &&
      data->decoded_size == data->test_data_size) {
    if (memcmp(data->decoded, data->test_data, data->test_data_size) == 0) {
      res = (res + 100000) & 0xFFFFFFFFu;
    }
  }

  return res;
}

static void huff_decode_cleanup(Benchmark *self) {
  HuffDecodeData *data = (HuffDecodeData *)self->data;

  if (data->test_data)
    free(data->test_data);
  if (data->decoded)
    free(data->decoded);
  if (data->encoded.data)
    free(data->encoded.data);

  free(data);
  self->data = NULL;
}

Benchmark *HuffDecode_create(void) {
  Benchmark *bench = Benchmark_create("Compress::HuffDecode");
  HuffDecodeData *data = malloc(sizeof(HuffDecodeData));
  memset(data, 0, sizeof(HuffDecodeData));

  bench->data = data;
  bench->prepare = huff_decode_prepare;
  bench->run = huff_decode_run;
  bench->checksum = huff_decode_checksum;
  bench->cleanup = huff_decode_cleanup;

  return bench;
}

typedef struct {
  int total;
  int low[256];
  int high[256];
} ArithFreqTable;

static ArithFreqTable *create_arith_freq_table(int frequencies[256]) {
  ArithFreqTable *ft = malloc(sizeof(ArithFreqTable));
  if (!ft)
    return NULL;

  ft->total = 0;
  for (int i = 0; i < 256; i++)
    ft->total += frequencies[i];

  int cum = 0;
  for (int i = 0; i < 256; i++) {
    ft->low[i] = cum;
    cum += frequencies[i];
    ft->high[i] = cum;
  }

  return ft;
}

typedef struct {
  int buffer;
  int bit_pos;
  uint8_t *bytes;
  size_t bytes_size;
  size_t bytes_capacity;
  int bits_written;
} BitOutputStream;

static BitOutputStream *bit_output_create(void) {
  BitOutputStream *out = malloc(sizeof(BitOutputStream));
  if (!out)
    return NULL;

  out->buffer = 0;
  out->bit_pos = 0;
  out->bytes_capacity = 1024;
  out->bytes = malloc(out->bytes_capacity);
  if (!out->bytes) {
    free(out);
    return NULL;
  }
  out->bytes_size = 0;
  out->bits_written = 0;

  return out;
}

static void bit_output_write_bit(BitOutputStream *out, int bit) {
  if (!out)
    return;

  out->buffer = (out->buffer << 1) | (bit & 1);
  out->bit_pos++;
  out->bits_written++;

  if (out->bit_pos == 8) {
    if (out->bytes_size >= out->bytes_capacity) {
      out->bytes_capacity *= 2;
      uint8_t *new_bytes = realloc(out->bytes, out->bytes_capacity);
      if (!new_bytes)
        return;
      out->bytes = new_bytes;
    }
    out->bytes[out->bytes_size++] = (uint8_t)out->buffer;
    out->buffer = 0;
    out->bit_pos = 0;
  }
}

static uint8_t *bit_output_flush(BitOutputStream *out, size_t *size) {
  if (!out) {
    *size = 0;
    return NULL;
  }

  if (out->bit_pos > 0) {
    out->buffer <<= (8 - out->bit_pos);
    if (out->bytes_size >= out->bytes_capacity) {
      out->bytes_capacity *= 2;
      uint8_t *new_bytes = realloc(out->bytes, out->bytes_capacity);
      if (!new_bytes) {
        *size = out->bytes_size;
        return out->bytes;
      }
      out->bytes = new_bytes;
    }
    out->bytes[out->bytes_size++] = (uint8_t)out->buffer;
    out->buffer = 0;
    out->bit_pos = 0;
  }

  *size = out->bytes_size;

  uint8_t *result = malloc(out->bytes_size);
  if (result) {
    memcpy(result, out->bytes, out->bytes_size);
  }
  return result;
}

static void bit_output_free(BitOutputStream *out) {
  if (out) {
    if (out->bytes) {
      free(out->bytes);
      out->bytes = NULL;
    }
    free(out);
  }
}

typedef struct {
  uint8_t *data;
  size_t data_size;
  int bit_count;
  int frequencies[256];
} ArithEncodedResult;

static ArithEncodedResult arith_encode(uint8_t *data, size_t data_size) {
  ArithEncodedResult result = {0};

  if (!data || data_size == 0)
    return result;

  int frequencies[256] = {0};
  for (size_t i = 0; i < data_size; i++) {
    frequencies[data[i]]++;
  }

  ArithFreqTable *freq_table = create_arith_freq_table(frequencies);
  if (!freq_table)
    return result;

  uint64_t low = 0;
  uint64_t high = 0xFFFFFFFF;
  int pending = 0;
  BitOutputStream *output = bit_output_create();
  if (!output) {
    free(freq_table);
    return result;
  }

  for (size_t i = 0; i < data_size; i++) {
    int idx = data[i];
    uint64_t range = high - low + 1;

    high = low +
           (range * (uint64_t)freq_table->high[idx] /
            (uint64_t)freq_table->total) -
           1;
    low = low + (range * (uint64_t)freq_table->low[idx] /
                 (uint64_t)freq_table->total);

    while (1) {
      if (high < 0x80000000) {
        bit_output_write_bit(output, 0);
        for (int i = 0; i < pending; i++)
          bit_output_write_bit(output, 1);
        pending = 0;
      } else if (low >= 0x80000000) {
        bit_output_write_bit(output, 1);
        for (int i = 0; i < pending; i++)
          bit_output_write_bit(output, 0);
        pending = 0;
        low -= 0x80000000;
        high -= 0x80000000;
      } else if (low >= 0x40000000 && high < 0xC0000000) {
        pending++;
        low -= 0x40000000;
        high -= 0x40000000;
      } else {
        break;
      }

      low <<= 1;
      high = (high << 1) | 1;
      high &= 0xFFFFFFFF;
    }
  }

  pending++;
  if (low < 0x40000000) {
    bit_output_write_bit(output, 0);
    for (int i = 0; i < pending; i++)
      bit_output_write_bit(output, 1);
  } else {
    bit_output_write_bit(output, 1);
    for (int i = 0; i < pending; i++)
      bit_output_write_bit(output, 0);
  }

  size_t data_size_out;
  uint8_t *encoded_data = bit_output_flush(output, &data_size_out);

  result.data = encoded_data;
  result.data_size = data_size_out;
  result.bit_count = output->bits_written;
  memcpy(result.frequencies, frequencies, sizeof(frequencies));

  if (output) {
    if (output->bytes) {
      free(output->bytes);
      output->bytes = NULL;
    }
    free(output);
  }
  free(freq_table);

  return result;
}

typedef struct {
  int64_t size_val;
  uint8_t *test_data;
  size_t test_data_size;
  uint32_t result_val;
} ArithEncodeData;

static void arith_encode_prepare(Benchmark *self) {
  ArithEncodeData *data = (ArithEncodeData *)self->data;
  if (!data)
    return;

  data->size_val = Helper_config_i64(self->name, "size");
  if (data->size_val == 0)
    data->size_val = 1000;

  if (data->test_data) {
    free(data->test_data);
    data->test_data = NULL;
  }

  data->test_data = generate_test_data(data->size_val, &data->test_data_size);
  data->result_val = 0;
}

static void arith_encode_run(Benchmark *self, int iteration_id) {
  ArithEncodeData *data = (ArithEncodeData *)self->data;
  if (!data || !data->test_data)
    return;

  ArithEncodedResult result =
      arith_encode(data->test_data, data->test_data_size);

  if (result.data) {
    data->result_val =
        (data->result_val + (uint32_t)result.data_size) & 0xFFFFFFFFu;
    free(result.data);
  }
}

static uint32_t arith_encode_checksum(Benchmark *self) {
  ArithEncodeData *data = (ArithEncodeData *)self->data;
  return data ? data->result_val : 0;
}

static void arith_encode_cleanup(Benchmark *self) {
  ArithEncodeData *data = (ArithEncodeData *)self->data;
  if (data) {
    if (data->test_data)
      free(data->test_data);
    free(data);
  }
  self->data = NULL;
}

Benchmark *ArithEncode_create(void) {
  Benchmark *bench = Benchmark_create("Compress::ArithEncode");
  if (!bench)
    return NULL;

  ArithEncodeData *data = malloc(sizeof(ArithEncodeData));
  if (!data) {
    free(bench);
    return NULL;
  }
  memset(data, 0, sizeof(ArithEncodeData));

  bench->data = data;
  bench->prepare = arith_encode_prepare;
  bench->run = arith_encode_run;
  bench->checksum = arith_encode_checksum;
  bench->cleanup = arith_encode_cleanup;

  return bench;
}

typedef struct {
  int64_t size_val;
  uint8_t *test_data;
  size_t test_data_size;
  uint8_t *decoded;
  size_t decoded_size;
  ArithEncodedResult encoded;
  uint32_t result_val;
} ArithDecodeData;

typedef struct {
  const uint8_t *bytes;
  size_t bytes_size;
  size_t byte_pos;
  int bit_pos;
  uint8_t current_byte;
} BitInputStream;

static void bit_input_init(BitInputStream *in, const uint8_t *bytes,
                           size_t size) {
  in->bytes = bytes;
  in->bytes_size = size;
  in->byte_pos = 0;
  in->bit_pos = 0;
  in->current_byte = size > 0 ? bytes[0] : 0;
}

static int bit_input_read_bit(BitInputStream *in) {
  if (in->bit_pos == 8) {
    in->byte_pos++;
    in->bit_pos = 0;
    in->current_byte =
        in->byte_pos < in->bytes_size ? in->bytes[in->byte_pos] : 0;
  }

  int bit = (in->current_byte >> (7 - in->bit_pos)) & 1;
  in->bit_pos++;
  return bit;
}

static uint8_t *arith_decode(ArithEncodedResult *encoded, size_t *result_size) {
  if (!encoded || !encoded->data || encoded->data_size == 0) {
    *result_size = 0;
    return NULL;
  }

  int total = 0;
  for (int i = 0; i < 256; i++)
    total += encoded->frequencies[i];
  int data_size = total;

  if (data_size == 0) {
    *result_size = 0;
    return NULL;
  }

  int low_table[256], high_table[256];
  int cum = 0;
  for (int i = 0; i < 256; i++) {
    low_table[i] = cum;
    cum += encoded->frequencies[i];
    high_table[i] = cum;
  }

  uint8_t *result = malloc(data_size);
  if (!result) {
    *result_size = 0;
    return NULL;
  }

  BitInputStream input;
  bit_input_init(&input, encoded->data, encoded->data_size);

  uint64_t value = 0;
  for (int i = 0; i < 32; i++) {
    value = (value << 1) | bit_input_read_bit(&input);
  }

  uint64_t low = 0;
  uint64_t high = 0xFFFFFFFF;

  for (int j = 0; j < data_size; j++) {
    uint64_t range = high - low + 1;
    uint64_t scaled = ((value - low + 1) * (uint64_t)total - 1) / range;

    int symbol = 0;
    while (symbol < 255 && (uint64_t)high_table[symbol] <= scaled) {
      symbol++;
    }

    result[j] = (uint8_t)symbol;

    high = low + (range * (uint64_t)high_table[symbol] / (uint64_t)total) - 1;
    low = low + (range * (uint64_t)low_table[symbol] / (uint64_t)total);

    while (1) {
      if (high < 0x80000000) {

      } else if (low >= 0x80000000) {
        value -= 0x80000000;
        low -= 0x80000000;
        high -= 0x80000000;
      } else if (low >= 0x40000000 && high < 0xC0000000) {
        value -= 0x40000000;
        low -= 0x40000000;
        high -= 0x40000000;
      } else {
        break;
      }

      low <<= 1;
      high = (high << 1) | 1;
      value = (value << 1) | bit_input_read_bit(&input);
    }
  }

  *result_size = data_size;
  return result;
}

static void arith_decode_prepare(Benchmark *self) {
  ArithDecodeData *data = (ArithDecodeData *)self->data;
  if (!data)
    return;

  data->size_val = Helper_config_i64(self->name, "size");
  if (data->size_val == 0)
    data->size_val = 1000;

  if (data->test_data) {
    free(data->test_data);
    data->test_data = NULL;
  }

  data->test_data = generate_test_data(data->size_val, &data->test_data_size);

  if (data->encoded.data) {
    free(data->encoded.data);
    memset(&data->encoded, 0, sizeof(ArithEncodedResult));
  }

  if (data->encoded.data) {
    free(data->encoded.data);
    memset(&data->encoded, 0, sizeof(ArithEncodedResult));
  }

  data->encoded = arith_encode(data->test_data, data->test_data_size);

  data->decoded = NULL;
  data->decoded_size = 0;
  data->result_val = 0;
}

static void arith_decode_run(Benchmark *self, int iteration_id) {
  ArithDecodeData *data = (ArithDecodeData *)self->data;
  if (data->decoded) {
    free(data->decoded);
    data->decoded = NULL;
  }

  data->decoded = arith_decode(&data->encoded, &data->decoded_size);

  if (data->decoded) {
    data->result_val =
        (data->result_val + (uint32_t)data->decoded_size) & 0xFFFFFFFFu;
  }
}

static uint32_t arith_decode_checksum(Benchmark *self) {
  ArithDecodeData *data = (ArithDecodeData *)self->data;
  if (!data)
    return 0;

  uint32_t res = data->result_val;

  if (data->decoded && data->test_data &&
      data->decoded_size == data->test_data_size) {
    if (memcmp(data->decoded, data->test_data, data->test_data_size) == 0) {
      res = (res + 100000) & 0xFFFFFFFFu;
    }
  }

  return res;
}

static void arith_decode_cleanup(Benchmark *self) {
  ArithDecodeData *data = (ArithDecodeData *)self->data;
  if (data) {
    if (data->test_data)
      free(data->test_data);
    if (data->decoded)
      free(data->decoded);
    if (data->encoded.data)
      free(data->encoded.data);
    free(data);
  }
  self->data = NULL;
}

Benchmark *ArithDecode_create(void) {
  Benchmark *bench = Benchmark_create("Compress::ArithDecode");
  if (!bench)
    return NULL;

  ArithDecodeData *data = malloc(sizeof(ArithDecodeData));
  if (!data) {
    free(bench);
    return NULL;
  }
  memset(data, 0, sizeof(ArithDecodeData));

  bench->data = data;
  bench->prepare = arith_decode_prepare;
  bench->run = arith_decode_run;
  bench->checksum = arith_decode_checksum;
  bench->cleanup = arith_decode_cleanup;

  return bench;
}

typedef struct {
  uint8_t *data;
  size_t data_size;
  int dict_size;
} LZWResult;

typedef struct {
  int64_t size_val;
  uint8_t *test_data;
  size_t test_data_size;
  uint32_t result_val;
} LZWEncodeData;

typedef struct {
  char *key;
  int32_t value;
  UT_hash_handle hh;
} DictEntry;

static LZWResult lzw_encode(uint8_t *input, size_t input_size) {
  LZWResult result = {0};
  result.dict_size = 256;

  if (input_size == 0) {
    result.data = NULL;
    result.data_size = 0;
    return result;
  }

  DictEntry *dict = NULL;

  for (int i = 0; i < 256; i++) {
    char *key = malloc(2);
    key[0] = (char)i;
    key[1] = '\0';

    DictEntry *entry = malloc(sizeof(DictEntry));
    entry->key = key;
    entry->value = i;
    HASH_ADD_KEYPTR(hh, dict, entry->key, strlen(entry->key), entry);
  }

  int32_t next_code = 256;

  result.data = malloc(input_size * 2);
  result.data_size = 0;

  char *current = malloc(2);
  current[0] = (char)input[0];
  current[1] = '\0';

  for (size_t i = 1; i < input_size; i++) {

    char next_char[2] = {(char)input[i], '\0'};

    char *new_str = malloc(strlen(current) + 2);
    strcpy(new_str, current);
    strcat(new_str, next_char);

    DictEntry *entry = NULL;
    HASH_FIND_STR(dict, new_str, entry);

    if (entry) {

      free(current);
      current = new_str;
    } else {

      DictEntry *current_entry = NULL;
      HASH_FIND_STR(dict, current, current_entry);
      int32_t code = current_entry->value;

      result.data[result.data_size++] = (code >> 8) & 0xFF;
      result.data[result.data_size++] = code & 0xFF;

      DictEntry *new_entry = malloc(sizeof(DictEntry));
      new_entry->key = new_str;
      new_entry->value = next_code++;
      HASH_ADD_KEYPTR(hh, dict, new_entry->key, strlen(new_entry->key),
                      new_entry);

      free(current);
      current = malloc(2);
      current[0] = (char)input[i];
      current[1] = '\0';
    }
  }

  DictEntry *last_entry = NULL;
  HASH_FIND_STR(dict, current, last_entry);
  int32_t last_code = last_entry->value;
  result.data[result.data_size++] = (last_code >> 8) & 0xFF;
  result.data[result.data_size++] = last_code & 0xFF;

  result.dict_size = next_code;

  free(current);

  DictEntry *entry, *tmp;
  HASH_ITER(hh, dict, entry, tmp) {
    HASH_DEL(dict, entry);
    free(entry->key);
    free(entry);
  }

  return result;
}

static void lzw_encode_prepare(Benchmark *self) {
  LZWEncodeData *data = (LZWEncodeData *)self->data;
  data->size_val = Helper_config_i64(self->name, "size");
  data->test_data = generate_test_data(data->size_val, &data->test_data_size);
  data->result_val = 0;
}

static void lzw_encode_run(Benchmark *self, int iteration_id) {
  LZWEncodeData *data = (LZWEncodeData *)self->data;
  LZWResult result = lzw_encode(data->test_data, data->test_data_size);

  if (result.data) {
    data->result_val =
        (data->result_val + (uint32_t)result.data_size) & 0xFFFFFFFFu;
    free(result.data);
  }
}

static uint32_t lzw_encode_checksum(Benchmark *self) {
  LZWEncodeData *data = (LZWEncodeData *)self->data;
  return data->result_val;
}

static void lzw_encode_cleanup(Benchmark *self) {
  LZWEncodeData *data = (LZWEncodeData *)self->data;
  if (data->test_data)
    free(data->test_data);
  free(data);
  self->data = NULL;
}

Benchmark *LZWEncode_create(void) {
  Benchmark *bench = Benchmark_create("Compress::LZWEncode");
  LZWEncodeData *data = malloc(sizeof(LZWEncodeData));
  memset(data, 0, sizeof(LZWEncodeData));

  bench->data = data;
  bench->prepare = lzw_encode_prepare;
  bench->run = lzw_encode_run;
  bench->checksum = lzw_encode_checksum;
  bench->cleanup = lzw_encode_cleanup;

  return bench;
}

typedef struct {
  int64_t size_val;
  uint8_t *test_data;
  size_t test_data_size;
  uint8_t *decoded;
  size_t decoded_size;
  LZWResult encoded;
  uint32_t result_val;
} LZWDecodeData;

static uint8_t *lzw_decode(LZWResult *encoded, size_t *result_size) {
  if (!encoded || encoded->data_size == 0) {
    *result_size = 0;
    return NULL;
  }

  size_t dict_capacity = 4096;
  char **dict = malloc(dict_capacity * sizeof(char *));
  if (!dict) {
    *result_size = 0;
    return NULL;
  }
  size_t dict_size = 256;

  for (int i = 0; i < 256; i++) {
    dict[i] = malloc(2);
    dict[i][0] = (char)i;
    dict[i][1] = '\0';
  }

  size_t result_capacity = encoded->data_size * 2;
  uint8_t *result = malloc(result_capacity);
  if (!result) {
    for (int i = 0; i < dict_size; i++)
      free(dict[i]);
    free(dict);
    *result_size = 0;
    return NULL;
  }
  size_t result_pos = 0;

  uint8_t *data = encoded->data;
  size_t pos = 0;

  if (pos + 1 >= encoded->data_size) {
    free(result);
    for (int i = 0; i < dict_size; i++)
      free(dict[i]);
    free(dict);
    *result_size = 0;
    return NULL;
  }

  uint16_t high = data[pos];
  uint16_t low = data[pos + 1];
  int32_t old_code = (high << 8) | low;
  pos += 2;

  if (old_code < 0 || old_code >= (int32_t)dict_size) {
    free(result);
    for (int i = 0; i < dict_size; i++)
      free(dict[i]);
    free(dict);
    *result_size = 0;
    return NULL;
  }

  char *old_str = dict[old_code];
  size_t old_len = strlen(old_str);

  if (result_pos + old_len >= result_capacity) {
    result_capacity *= 2;
    result = realloc(result, result_capacity);
  }
  for (size_t i = 0; i < old_len; i++) {
    result[result_pos++] = old_str[i];
  }

  int32_t next_code = 256;

  while (pos + 1 < encoded->data_size) {
    high = data[pos];
    low = data[pos + 1];
    int32_t new_code = (high << 8) | low;
    pos += 2;

    char *new_str;
    if (new_code >= 0 && new_code < (int32_t)dict_size) {
      new_str = dict[new_code];
    } else if (new_code == next_code) {
      size_t len = strlen(dict[old_code]);
      new_str = malloc(len + 2);
      strcpy(new_str, dict[old_code]);
      new_str[len] = dict[old_code][0];
      new_str[len + 1] = '\0';
    } else {
      free(result);
      for (int i = 0; i < dict_size; i++)
        free(dict[i]);
      free(dict);
      *result_size = 0;
      return NULL;
    }

    size_t new_len = strlen(new_str);

    if (result_pos + new_len >= result_capacity) {
      result_capacity *= 2;
      result = realloc(result, result_capacity);
    }
    for (size_t i = 0; i < new_len; i++) {
      result[result_pos++] = new_str[i];
    }

    if (new_code == next_code) {
      if (dict_size >= dict_capacity) {
        dict_capacity *= 2;
        dict = realloc(dict, dict_capacity * sizeof(char *));
      }
      dict[dict_size++] = new_str;
    } else {
      size_t len = strlen(dict[old_code]);
      char *entry = malloc(len + 2);
      strcpy(entry, dict[old_code]);
      entry[len] = new_str[0];
      entry[len + 1] = '\0';

      if (dict_size >= dict_capacity) {
        dict_capacity *= 2;
        dict = realloc(dict, dict_capacity * sizeof(char *));
      }
      dict[dict_size++] = entry;
    }

    next_code++;
    old_code = new_code;
  }

  *result_size = result_pos;

  for (int i = 0; i < dict_size; i++) {
    free(dict[i]);
  }
  free(dict);

  return result;
}

static void lzw_decode_prepare(Benchmark *self) {
  LZWDecodeData *data = (LZWDecodeData *)self->data;
  data->size_val = Helper_config_i64(self->name, "size");
  data->test_data = generate_test_data(data->size_val, &data->test_data_size);
  data->encoded = lzw_encode(data->test_data, data->test_data_size);
  data->decoded = NULL;
  data->decoded_size = 0;
  data->result_val = 0;
}

static void lzw_decode_run(Benchmark *self, int iteration_id) {
  LZWDecodeData *data = (LZWDecodeData *)self->data;

  if (data->decoded) {
    free(data->decoded);
    data->decoded = NULL;
  }

  data->decoded = lzw_decode(&data->encoded, &data->decoded_size);

  if (data->decoded) {
    data->result_val =
        (data->result_val + (uint32_t)data->decoded_size) & 0xFFFFFFFFu;
  }
}

static uint32_t lzw_decode_checksum(Benchmark *self) {
  LZWDecodeData *data = (LZWDecodeData *)self->data;
  uint32_t res = data->result_val;

  if (data->decoded && data->test_data &&
      data->decoded_size == data->test_data_size) {
    if (memcmp(data->decoded, data->test_data, data->test_data_size) == 0) {
      res = (res + 100000) & 0xFFFFFFFFu;
    }
  }

  return res;
}

static void lzw_decode_cleanup(Benchmark *self) {
  LZWDecodeData *data = (LZWDecodeData *)self->data;

  if (data->test_data)
    free(data->test_data);
  if (data->decoded)
    free(data->decoded);
  if (data->encoded.data)
    free(data->encoded.data);

  free(data);
  self->data = NULL;
}

Benchmark *LZWDecode_create(void) {
  Benchmark *bench = Benchmark_create("Compress::LZWDecode");
  LZWDecodeData *data = malloc(sizeof(LZWDecodeData));
  memset(data, 0, sizeof(LZWDecodeData));

  bench->data = data;
  bench->prepare = lzw_decode_prepare;
  bench->run = lzw_decode_run;
  bench->checksum = lzw_decode_checksum;
  bench->cleanup = lzw_decode_cleanup;

  return bench;
}

typedef struct {
  char **s1;
  char **s2;
  size_t pair_count;
} StringPairs;

StringPairs *generate_pair_strings(int64_t n, int64_t m) {
  StringPairs *pairs = malloc(sizeof(StringPairs));
  pairs->pair_count = n;
  pairs->s1 = malloc(n * sizeof(char *));
  pairs->s2 = malloc(n * sizeof(char *));

  for (int64_t i = 0; i < n; i++) {
    int len1 = Helper_next_int(m) + 4;
    int len2 = Helper_next_int(m) + 4;

    pairs->s1[i] = malloc(len1 + 1);
    pairs->s2[i] = malloc(len2 + 1);

    for (int j = 0; j < len1; j++) {
      pairs->s1[i][j] = 'a' + Helper_next_int(10);
    }
    pairs->s1[i][len1] = '\0';

    for (int j = 0; j < len2; j++) {
      pairs->s2[i][j] = 'a' + Helper_next_int(10);
    }
    pairs->s2[i][len2] = '\0';
  }

  return pairs;
}

void free_string_pairs(StringPairs *pairs) {
  if (!pairs)
    return;

  for (size_t i = 0; i < pairs->pair_count; i++) {
    if (pairs->s1[i])
      free(pairs->s1[i]);
    if (pairs->s2[i])
      free(pairs->s2[i]);
  }
  free(pairs->s1);
  free(pairs->s2);
  free(pairs);
}

typedef struct {
  StringPairs *pairs;
  uint32_t result;
  int64_t count;
  int64_t size;
} JaroData;

void Jaro_prepare(Benchmark *self) {
  JaroData *data = (JaroData *)self->data;

  data->count = Helper_config_i64(self->name, "count");
  data->size = Helper_config_i64(self->name, "size");

  data->pairs = generate_pair_strings(data->count, data->size);
  data->result = 0;
}

double Jaro_calc(const char *s1, const char *s2) {
  size_t len1 = strlen(s1);
  size_t len2 = strlen(s2);

  if (len1 == 0 || len2 == 0)
    return 0.0;

  int64_t match_dist = (len1 > len2 ? len1 : len2) / 2 - 1;
  if (match_dist < 0)
    match_dist = 0;

  bool *s1_matches = calloc(len1, sizeof(bool));
  bool *s2_matches = calloc(len2, sizeof(bool));

  int matches = 0;
  for (size_t i = 0; i < len1; i++) {
    size_t start = i > (size_t)match_dist ? i - match_dist : 0;
    size_t end = (len2 - 1 < i + match_dist) ? len2 - 1 : i + match_dist;

    for (size_t j = start; j <= end; j++) {
      if (!s2_matches[j] && s1[i] == s2[j]) {
        s1_matches[i] = true;
        s2_matches[j] = true;
        matches++;
        break;
      }
    }
  }

  double result = 0.0;

  if (matches > 0) {
    int transpositions = 0;
    size_t k = 0;

    for (size_t i = 0; i < len1; i++) {
      if (s1_matches[i]) {
        while (k < len2 && !s2_matches[k]) {
          k++;
        }
        if (k < len2) {
          if (s1[i] != s2[k]) {
            transpositions++;
          }
          k++;
        }
      }
    }
    transpositions /= 2;

    double m = (double)matches;
    result = (m / len1 + m / len2 + (m - transpositions) / m) / 3.0;
  }

  free(s1_matches);
  free(s2_matches);

  return result;
}

void Jaro_run(Benchmark *self, int iteration_id) {
  JaroData *data = (JaroData *)self->data;
  StringPairs *pairs = data->pairs;

  for (size_t i = 0; i < pairs->pair_count; i++) {
    double jaro = Jaro_calc(pairs->s1[i], pairs->s2[i]);
    data->result += (uint32_t)(jaro * 1000);
  }
}

uint32_t Jaro_checksum(Benchmark *self) {
  JaroData *data = (JaroData *)self->data;
  return data->result;
}

void Jaro_cleanup(Benchmark *self) {
  JaroData *data = (JaroData *)self->data;

  if (data->pairs) {
    free_string_pairs(data->pairs);
    data->pairs = NULL;
  }
}

Benchmark *Jaro_create(void) {
  Benchmark *bench = Benchmark_create("Distance::Jaro");

  JaroData *data = malloc(sizeof(JaroData));
  memset(data, 0, sizeof(JaroData));

  bench->data = data;
  bench->prepare = Jaro_prepare;
  bench->run = Jaro_run;
  bench->checksum = Jaro_checksum;
  bench->cleanup = Jaro_cleanup;

  return bench;
}

typedef struct {
  uint32_t gram;
  int count;
  UT_hash_handle hh;
} GramHash;

typedef struct {
  StringPairs *pairs;
  uint32_t result;
  int64_t count;
  int64_t size;
} NGramData;

void NGram_prepare(Benchmark *self) {
  NGramData *data = (NGramData *)self->data;

  data->count = Helper_config_i64(self->name, "count");
  data->size = Helper_config_i64(self->name, "size");

  data->pairs = generate_pair_strings(data->count, data->size);
  data->result = 0;
}

double NGram_calc(const char *s1, const char *s2) {
  size_t len1 = strlen(s1);
  size_t len2 = strlen(s2);

  if (len1 < 4 || len2 < 4)
    return 0.0;

  GramHash *grams1 = NULL;

  for (size_t i = 0; i <= len1 - 4; i++) {
    uint32_t gram = ((uint32_t)(uint8_t)s1[i] << 24) |
                    ((uint32_t)(uint8_t)s1[i + 1] << 16) |
                    ((uint32_t)(uint8_t)s1[i + 2] << 8) |
                    (uint32_t)(uint8_t)s1[i + 3];

    GramHash *g;
    HASH_FIND_INT(grams1, &gram, g);
    if (g) {
      g->count++;
    } else {
      g = (GramHash *)malloc(sizeof(GramHash));
      g->gram = gram;
      g->count = 1;
      HASH_ADD_INT(grams1, gram, g);
    }
  }

  GramHash *grams2 = NULL;
  int intersection = 0;

  for (size_t i = 0; i <= len2 - 4; i++) {
    uint32_t gram = ((uint32_t)(uint8_t)s2[i] << 24) |
                    ((uint32_t)(uint8_t)s2[i + 1] << 16) |
                    ((uint32_t)(uint8_t)s2[i + 2] << 8) |
                    (uint32_t)(uint8_t)s2[i + 3];

    GramHash *g2;
    HASH_FIND_INT(grams2, &gram, g2);
    if (g2) {
      g2->count++;
    } else {
      g2 = (GramHash *)malloc(sizeof(GramHash));
      g2->gram = gram;
      g2->count = 1;
      HASH_ADD_INT(grams2, gram, g2);
    }

    GramHash *g1;
    HASH_FIND_INT(grams1, &gram, g1);
    if (g1 && g2->count <= g1->count) {
      intersection++;
    }
  }

  int total = HASH_COUNT(grams1) + HASH_COUNT(grams2);

  GramHash *current, *tmp;
  HASH_ITER(hh, grams1, current, tmp) {
    HASH_DEL(grams1, current);
    free(current);
  }
  HASH_ITER(hh, grams2, current, tmp) {
    HASH_DEL(grams2, current);
    free(current);
  }

  return total > 0 ? (double)intersection / total : 0.0;
}

void NGram_run(Benchmark *self, int iteration_id) {
  NGramData *data = (NGramData *)self->data;
  StringPairs *pairs = data->pairs;

  for (size_t i = 0; i < pairs->pair_count; i++) {
    double sim = NGram_calc(pairs->s1[i], pairs->s2[i]);
    data->result += (uint32_t)(sim * 1000);
  }
}

uint32_t NGram_checksum(Benchmark *self) {
  NGramData *data = (NGramData *)self->data;
  return data->result;
}

void NGram_cleanup(Benchmark *self) {
  NGramData *data = (NGramData *)self->data;

  if (data->pairs) {
    free_string_pairs(data->pairs);
    data->pairs = NULL;
  }
}

Benchmark *NGram_create(void) {
  Benchmark *bench = Benchmark_create("Distance::NGram");

  NGramData *data = malloc(sizeof(NGramData));
  memset(data, 0, sizeof(NGramData));

  bench->data = data;
  bench->prepare = NGram_prepare;
  bench->run = NGram_run;
  bench->checksum = NGram_checksum;
  bench->cleanup = NGram_cleanup;

  return bench;
}

void register_all_benchmarks(void) {
  Benchmark_register("CLBG::Pidigits", Pidigits_create);
  Benchmark_register("Binarytrees::Obj", BinarytreesObj_create);
  Benchmark_register("Binarytrees::Arena", BinarytreesArena_create);
  Benchmark_register("Brainfuck::Array", BrainfuckArray_create);
  Benchmark_register("Brainfuck::Recursion", BrainfuckRecursion_create);
  Benchmark_register("CLBG::Fannkuchredux", Fannkuchredux_create);
  Benchmark_register("CLBG::Fasta", Fasta_create);
  Benchmark_register("CLBG::Knuckeotide", Knuckeotide_create);
  Benchmark_register("CLBG::Mandelbrot", Mandelbrot_create);
  Benchmark_register("Matmul::Single", Matmul_create);
  Benchmark_register("Matmul::T4", Matmul4T_create);
  Benchmark_register("Matmul::T8", Matmul8T_create);
  Benchmark_register("Matmul::T16", Matmul16T_create);
  Benchmark_register("CLBG::Nbody", Nbody_create);
  Benchmark_register("CLBG::RegexDna", RegexDna_create);
  Benchmark_register("CLBG::Revcomp", Revcomp_create);
  Benchmark_register("CLBG::Spectralnorm", Spectralnorm_create);
  Benchmark_register("Base64::Encode", Base64Encode_create);
  Benchmark_register("Base64::Decode", Base64Decode_create);
  Benchmark_register("Json::Generate", JsonGenerate_create);
  Benchmark_register("Json::ParseDom", JsonParseDom_create);
  Benchmark_register("Json::ParseMapping", JsonParseMapping_create);
  Benchmark_register("Etc::Sieve", Sieve_create);
  Benchmark_register("Etc::Noise", Noise_create);
  Benchmark_register("Etc::TextRaytracer", TextRaytracer_create);
  Benchmark_register("Etc::NeuralNet", NeuralNet_create);
  Benchmark_register("Sort::Quick", SortQuick_create);
  Benchmark_register("Sort::Merge", SortMerge_create);
  Benchmark_register("Sort::Self", SortSelf_create);
  Benchmark_register("Graph::BFS", GraphPathBFS_create);
  Benchmark_register("Graph::DFS", GraphPathDFS_create);
  Benchmark_register("Graph::AStar", GraphPathAStar_create);
  Benchmark_register("Hash::SHA256", BufferHashSHA256_create);
  Benchmark_register("Hash::CRC32", BufferHashCRC32_create);
  Benchmark_register("Etc::CacheSimulation", CacheSimulation_create);
  Benchmark_register("Calculator::Ast", CalculatorAst_create);
  Benchmark_register("Calculator::Interpreter", CalculatorInterpreter_create);
  Benchmark_register("Etc::GameOfLife", GameOfLife_create);
  Benchmark_register("Maze::Generator", MazeGenerator_create);
  Benchmark_register("Maze::BFS", MazeBFS_create);
  Benchmark_register("Maze::AStar", MazeAStar_create);
  Benchmark_register("Compress::BWTEncode", BWTEncode_create);
  Benchmark_register("Compress::BWTDecode", BWTDecode_create);
  Benchmark_register("Compress::HuffEncode", HuffEncode_create);
  Benchmark_register("Compress::HuffDecode", HuffDecode_create);
  Benchmark_register("Compress::ArithEncode", ArithEncode_create);
  Benchmark_register("Compress::ArithDecode", ArithDecode_create);
  Benchmark_register("Compress::LZWEncode", LZWEncode_create);
  Benchmark_register("Compress::LZWDecode", LZWDecode_create);
  Benchmark_register("Distance::Jaro", Jaro_create);
  Benchmark_register("Distance::NGram", NGram_create);
}

int main(int argc, char *argv[]) {

  struct timespec start_time;
  clock_gettime(CLOCK_REALTIME, &start_time);
  printf("start: %ld\n",
         start_time.tv_sec * 1000 + start_time.tv_nsec / 1000000);

  const char *config_file = argc > 1 ? argv[1] : "../test.js";
  Helper_load_config(config_file);

  register_all_benchmarks();

  const char *single_bench = argc > 2 ? argv[2] : NULL;
  Benchmark_all(single_bench);

  Helper_free_config();

  if (benchmark_factories) {
    free(benchmark_factories);
    benchmark_factories = NULL;
    benchmark_factories_count = 0;
    benchmark_factories_capacity = 0;
  }

  FILE *f = fopen("/tmp/recompile_marker", "w");
  if (f) {
    fprintf(f, "RECOMPILE_MARKER_0");
    fclose(f);
  }

  return 0;
}