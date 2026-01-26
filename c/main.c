#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include <stdbool.h>
#include <math.h>
#include <uthash.h> //sudo apt-get install uthash-dev
#include <ctype.h>
#include <gmp.h>
#include "cJSON.h"  // Нужно скачать cJSON: https://github.com/DaveGamble/cJSON
#include <limits.h>
#define PCRE2_CODE_UNIT_WIDTH 8
#include <pcre2.h>
#include <pthread.h>

// ============================================================================
// Константы и глобальное состояние
// ============================================================================
#define IM      139968
#define IA       3877
#define IC      29573
#define INIT       42

static uint32_t Helper_last = INIT;

// ============================================================================
// Вспомогательные функции (Helper модуль)
// ============================================================================
void Helper_reset(void) {
    Helper_last = INIT;
}

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

uint32_t Helper_checksum_string(const char* v) {
    uint32_t hash = 5381;
    while (*v) {
        hash = ((hash << 5) + hash) + (uint8_t)(*v);
        v++;
    }
    return hash;
}

uint32_t Helper_checksum_bytes(const uint8_t* data, size_t length) {
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

// Функции для эмуляции &+ и << из Crystal
static inline int64_t crystal_add(int64_t a, int64_t b) {
    uint64_t ua = (uint64_t)a;
    uint64_t ub = (uint64_t)b;
    uint64_t result = ua + ub;
    return (int64_t)result;
}

static inline int64_t crystal_shl(int64_t a, int shift) {
    uint64_t ua = (uint64_t)a;
    uint64_t result = ua << shift;
    return (int64_t)result;
}

// ============================================================================
// Конфигурация тестов
// ============================================================================
typedef struct {
    char* name;
    char* input;
    int64_t expected;
} BenchmarkConfig;

static BenchmarkConfig* Helper_configs = NULL;
static size_t Helper_config_count = 0;

void Helper_load_config(const char* filename) {
    FILE* file = fopen(filename, "r");
    if (!file) {
        fprintf(stderr, "Cannot open config file: %s\n", filename);
        exit(1);
    }
    
    char line[256];
    size_t count = 0;
    while (fgets(line, sizeof(line), file)) {
        if (strlen(line) > 1) count++;
    }
    rewind(file);
    
    Helper_configs = malloc(sizeof(BenchmarkConfig) * count);
    Helper_config_count = 0;
    
    while (fgets(line, sizeof(line), file)) {
        if (strlen(line) <= 1) continue;
        line[strcspn(line, "\n")] = 0;
        
        char* name = strtok(line, "|");
        char* input = strtok(NULL, "|");
        char* expected_str = strtok(NULL, "|");
        
        if (name && input && expected_str) {
            Helper_configs[Helper_config_count].name = strdup(name);
            Helper_configs[Helper_config_count].input = strdup(input);
            Helper_configs[Helper_config_count].expected = atoll(expected_str);
            Helper_config_count++;
        }
    }
    
    fclose(file);
}

void Helper_free_config(void) {
    for (size_t i = 0; i < Helper_config_count; i++) {
        free(Helper_configs[i].name);
        free(Helper_configs[i].input);
    }
    free(Helper_configs);
    Helper_configs = NULL;
    Helper_config_count = 0;
}

const char* Helper_get_input(const char* name) {
    for (size_t i = 0; i < Helper_config_count; i++) {
        if (strcmp(Helper_configs[i].name, name) == 0) {
            return Helper_configs[i].input;
        }
    }
    return NULL;
}

int64_t Helper_get_expected(const char* name) {
    for (size_t i = 0; i < Helper_config_count; i++) {
        if (strcmp(Helper_configs[i].name, name) == 0) {
            return Helper_configs[i].expected;
        }
    }
    return 0;
}

// ============================================================================
// Базовый класс Benchmark
// ============================================================================
typedef struct Benchmark {
    const char* name;
    int64_t (*run)(void* self);
    void (*prepare)(void* self);
    void (*cleanup)(void* self);
    void* instance;
} Benchmark;

typedef struct {
    Benchmark** benchmarks;
    size_t count;
    size_t capacity;
} BenchmarkRegistry;

BenchmarkRegistry* BenchmarkRegistry_create(void) {
    BenchmarkRegistry* registry = malloc(sizeof(BenchmarkRegistry));
    registry->capacity = 16;
    registry->count = 0;
    registry->benchmarks = malloc(sizeof(Benchmark*) * registry->capacity);
    return registry;
}

void BenchmarkRegistry_free(BenchmarkRegistry* registry) {
    for (size_t i = 0; i < registry->count; i++) {        
        Benchmark* bench = registry->benchmarks[i];
        free(bench);
        registry->benchmarks[i] = NULL;
    }
    
    free(registry->benchmarks);
    free(registry);
}

void BenchmarkRegistry_add(BenchmarkRegistry* registry, Benchmark* bench) {
    if (registry->count >= registry->capacity) {
        registry->capacity *= 2;
        registry->benchmarks = realloc(registry->benchmarks, 
                                      sizeof(Benchmark*) * registry->capacity);
    }
    registry->benchmarks[registry->count++] = bench;
}

void BenchmarkRegistry_run(BenchmarkRegistry* registry, const char* single_bench) {
    double summary_time = 0.0;
    int ok = 0;
    int fails = 0;
    
    for (size_t i = 0; i < registry->count; i++) {
        Benchmark* bench = registry->benchmarks[i];
        
        if (single_bench && strcmp(single_bench, bench->name) != 0) {
            continue;
        }
        
        printf("%s: ", bench->name);
        
        Helper_reset();
        
        if (bench->prepare) {
            bench->prepare(bench->instance);
        }
        
        struct timespec start, end;
        clock_gettime(CLOCK_MONOTONIC, &start);

        int64_t result = bench->run(bench->instance);

        clock_gettime(CLOCK_MONOTONIC, &end);
        double time_delta = (end.tv_sec - start.tv_sec) + 
                   (end.tv_nsec - start.tv_nsec) * 1e-9;

        summary_time += time_delta;
        
        if (result == Helper_get_expected(bench->name)) {
            printf("OK ");
            ok++;
        } else {
            printf("ERR[actual=%lld, expected=%lld] ", 
                   (long long)result,
                   (long long)Helper_get_expected(bench->name));
            fails++;
        }

        if (bench->cleanup) {
            bench->cleanup(bench->instance);
        }
        
        printf("in %.3fs\n", time_delta);
    }
    
    printf("Summary: %.4fs, %d, %d, %d\n", summary_time, ok+fails, ok, fails);
    
    if (fails > 0) {
        exit(1);
    }
}

// ============================================================================
// Класс BrainfuckRecursion - ИСПРАВЛЕННАЯ ВЕРСИЯ
// ============================================================================

// 1. Сначала объявляем ВСЕ структуры

// Внутренние типы
typedef enum {
    BrainfuckRecursion_OP_INC,
    BrainfuckRecursion_OP_MOVE,
    BrainfuckRecursion_OP_PRINT,
    BrainfuckRecursion_OP_LOOP
} BrainfuckRecursion_OpType;

// Предварительное объявление
typedef struct BrainfuckRecursion_Op BrainfuckRecursion_Op;

// Полное определение структуры Op
struct BrainfuckRecursion_Op {
    BrainfuckRecursion_OpType type;
    int value;
    BrainfuckRecursion_Op* loop_ops;
    int32_t loop_size;
};

// Класс Tape
typedef struct BrainfuckRecursion_Tape {
    uint8_t* tape;
    int32_t size;
    int32_t pos;
} BrainfuckRecursion_Tape;

// Класс Program
typedef struct BrainfuckRecursion_Program {
    BrainfuckRecursion_Op* ops;
    int32_t ops_size;
    int64_t result;
} BrainfuckRecursion_Program;

// Основной класс BrainfuckRecursion
typedef struct {
    BrainfuckRecursion_Program* program;
    const char* text;
    int64_t result;
} BrainfuckRecursion;

// 2. Объявляем функции парсинга и работы с операциями
static void BrainfuckRecursion_free_ops(BrainfuckRecursion_Op* ops, int32_t ops_size);
static BrainfuckRecursion_Op* BrainfuckRecursion_parse_ops(const char** code, int32_t* ops_count);
static void BrainfuckRecursion_run_ops(BrainfuckRecursion_Op* ops, int32_t ops_size, 
                                      BrainfuckRecursion_Tape* tape, int64_t* result);

// 3. Реализация функций Tape
BrainfuckRecursion_Tape* BrainfuckRecursion_Tape_new(void) {
    BrainfuckRecursion_Tape* self = malloc(sizeof(BrainfuckRecursion_Tape));
    self->size = 1024;
    self->tape = calloc(self->size, sizeof(uint8_t));
    self->pos = 0;
    return self;
}

uint8_t BrainfuckRecursion_Tape_get(BrainfuckRecursion_Tape* self) {
    return (self->pos < self->size) ? self->tape[self->pos] : 0;
}

void BrainfuckRecursion_Tape_inc(BrainfuckRecursion_Tape* self, int x) {
    if (self->pos < self->size) {
        self->tape[self->pos] += x;
    }
}

void BrainfuckRecursion_Tape_move(BrainfuckRecursion_Tape* self, int x) {
    if (x > 0) {
        // Движение вправо
        self->pos += x;
        while (self->pos >= self->size) {
            self->size *= 2;
            self->tape = realloc(self->tape, self->size);
            memset(self->tape + self->size / 2, 0, self->size / 2);
        }
    } else if (x < 0) {
        // Движение влево
        int64_t move_left = -x;
        if (move_left > self->pos) {
            // Нужно расширить массив в начале
            int32_t needed = move_left - self->pos;
            int32_t new_size = self->size + needed;
            uint8_t* new_tape = malloc(new_size);
            memset(new_tape, 0, needed);
            memcpy(new_tape + needed, self->tape, self->size);
            free(self->tape);
            self->tape = new_tape;
            self->size = new_size;
            self->pos += needed;
        }
        self->pos -= move_left;
    }
}

void BrainfuckRecursion_Tape_free(BrainfuckRecursion_Tape* self) {
    free(self->tape);
    free(self);
}

// 4. Парсинг операций - ИСПРАВЛЕННАЯ ВЕРСИЯ
static BrainfuckRecursion_Op* BrainfuckRecursion_parse_ops(const char** code, int32_t* ops_count) {
    int32_t capacity = 16;
    BrainfuckRecursion_Op* ops = malloc(sizeof(BrainfuckRecursion_Op) * capacity);
    int32_t count = 0;
    
    while (**code) {
        if (count >= capacity) {
            capacity *= 2;
            BrainfuckRecursion_Op* new_ops = realloc(ops, sizeof(BrainfuckRecursion_Op) * capacity);
            if (!new_ops) {
                free(ops);
                *ops_count = 0;
                return NULL;
            }
            ops = new_ops;
        }
        
        switch (**code) {
            case '+':
                ops[count].type = BrainfuckRecursion_OP_INC;
                ops[count].value = 1;
                ops[count].loop_ops = NULL;
                ops[count].loop_size = 0;
                count++;
                break;
            case '-':
                ops[count].type = BrainfuckRecursion_OP_INC;
                ops[count].value = -1;
                ops[count].loop_ops = NULL;
                ops[count].loop_size = 0;
                count++;
                break;
            case '>':
                ops[count].type = BrainfuckRecursion_OP_MOVE;
                ops[count].value = 1;
                ops[count].loop_ops = NULL;
                ops[count].loop_size = 0;
                count++;
                break;
            case '<':
                ops[count].type = BrainfuckRecursion_OP_MOVE;
                ops[count].value = -1;
                ops[count].loop_ops = NULL;
                ops[count].loop_size = 0;
                count++;
                break;
            case '.':
                ops[count].type = BrainfuckRecursion_OP_PRINT;
                ops[count].value = 0;
                ops[count].loop_ops = NULL;
                ops[count].loop_size = 0;
                count++;
                break;
            case '[':
                (*code)++;  // Пропускаем '['
                ops[count].type = BrainfuckRecursion_OP_LOOP;
                ops[count].value = 0;
                int32_t loop_ops_count = 0;
                ops[count].loop_ops = BrainfuckRecursion_parse_ops(code, &loop_ops_count);
                ops[count].loop_size = loop_ops_count;
                count++;
                // После парсинга loop мы уже стоим на символе после ']'
                continue;  // Важно: не увеличиваем code дальше
            case ']':
                *ops_count = count;
                (*code)++;  // Пропускаем ']'
                return ops;
            default:
                // Пропускаем неизвестные символы
                break;
        }
        (*code)++;
    }
    
    *ops_count = count;
    return ops;
}

// 5. Функция освобождения операций - ИСПРАВЛЕННАЯ ВЕРСИЯ
static void BrainfuckRecursion_free_ops(BrainfuckRecursion_Op* ops, int32_t ops_size) {
    if (!ops) return;
    
    for (int32_t i = 0; i < ops_size; i++) {
        if (ops[i].type == BrainfuckRecursion_OP_LOOP && ops[i].loop_ops) {
            // Рекурсивно освобождаем вложенные операции
            BrainfuckRecursion_free_ops(ops[i].loop_ops, ops[i].loop_size);
            // НЕ освобождаем ops[i].loop_ops здесь - это уже сделано рекурсивно
        }
    }
    // Освобождаем только сам массив операций
    free(ops);
}

// 6. Выполнение операций
static void BrainfuckRecursion_run_ops(BrainfuckRecursion_Op* ops, int32_t ops_size, 
                                      BrainfuckRecursion_Tape* tape, int64_t* result) {
    for (int32_t i = 0; i < ops_size; i++) {
        BrainfuckRecursion_Op* op = &ops[i];
        switch (op->type) {
            case BrainfuckRecursion_OP_INC:
                BrainfuckRecursion_Tape_inc(tape, op->value);
                break;
            case BrainfuckRecursion_OP_MOVE:
                BrainfuckRecursion_Tape_move(tape, op->value);
                break;
            case BrainfuckRecursion_OP_PRINT: {
                uint8_t value = BrainfuckRecursion_Tape_get(tape);
                int64_t shifted = crystal_shl(*result, 2);
                *result = crystal_add(shifted, value);
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

// 7. Класс Program - методы
BrainfuckRecursion_Program* BrainfuckRecursion_Program_new(const char* code) {
    if (!code || !code[0]) {
        return NULL;
    }
    
    BrainfuckRecursion_Program* self = malloc(sizeof(BrainfuckRecursion_Program));
    if (!self) {
        return NULL;
    }
    
    const char* code_ptr = code;
    int32_t ops_count = 0;
    self->ops = BrainfuckRecursion_parse_ops(&code_ptr, &ops_count);
    
    if (!self->ops) {
        free(self);
        return NULL;
    }
    
    self->ops_size = ops_count;
    self->result = 0;
    return self;
}

void BrainfuckRecursion_Program_run(BrainfuckRecursion_Program* self) {
    BrainfuckRecursion_Tape* tape = BrainfuckRecursion_Tape_new();
    self->result = 0;
    BrainfuckRecursion_run_ops(self->ops, self->ops_size, tape, &self->result);
    BrainfuckRecursion_Tape_free(tape);
}

void BrainfuckRecursion_Program_free(BrainfuckRecursion_Program* self) {
    if (!self) return;
    
    if (self->ops) {
        BrainfuckRecursion_free_ops(self->ops, self->ops_size);
        // НЕ free(self->ops) - уже освобождено в BrainfuckRecursion_free_ops
    }
    free(self);
}

// 8. Основной класс BrainfuckRecursion - методы бенчмарка
int64_t BrainfuckRecursion_run(void* self) {
    BrainfuckRecursion* bench = (BrainfuckRecursion*)self;
    
    if (!bench->text || !bench->text[0]) {
        return 0;
    }
    
    // Создаем и запускаем программу один раз (как в Crystal)
    BrainfuckRecursion_Program* program = BrainfuckRecursion_Program_new(bench->text);
    if (!program) {
        return 0;
    }
    
    BrainfuckRecursion_Program_run(program);
    int64_t result = program->result;
    
    // Освобождаем программу сразу
    BrainfuckRecursion_Program_free(program);
    
    bench->result = result;
    return result;
}

void BrainfuckRecursion_prepare(void* self) {
    BrainfuckRecursion* bench = (BrainfuckRecursion*)self;
    bench->text = Helper_get_input("BrainfuckRecursion");
    bench->program = NULL;  // Не создаем здесь программу
    bench->result = 0;
}

void BrainfuckRecursion_cleanup(void* self) {
    BrainfuckRecursion* bench = (BrainfuckRecursion*)self;
    
    // program освобождается в run(), так что здесь только освобождаем bench
    free(bench);
}

Benchmark* BrainfuckRecursion_new(void) {
    BrainfuckRecursion* instance = malloc(sizeof(BrainfuckRecursion));
    instance->text = NULL;
    instance->program = NULL;
    instance->result = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "BrainfuckRecursion";
    bench->run = BrainfuckRecursion_run;
    bench->prepare = BrainfuckRecursion_prepare;
    bench->cleanup = BrainfuckRecursion_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс Pidigits
// ============================================================================

typedef struct {
    int nn;
    char* result_str;
    size_t result_capacity;
    size_t result_length;
    uint32_t result_val;
} Pidigits;

static void Pidigits_grow_result(Pidigits* self, size_t needed) {
    size_t new_capacity = self->result_capacity;
    while (self->result_length + needed >= new_capacity) {
        new_capacity = new_capacity ? new_capacity * 2 : 1024;
    }
    if (new_capacity > self->result_capacity) {
        self->result_str = realloc(self->result_str, new_capacity);
        self->result_capacity = new_capacity;
    }
}

static void Pidigits_append(Pidigits* self, const char* str) {
    size_t len = strlen(str);
    Pidigits_grow_result(self, len + 1);
    memcpy(self->result_str + self->result_length, str, len);
    self->result_length += len;
    self->result_str[self->result_length] = '\0';
}

int64_t Pidigits_run(void* self) {
    Pidigits* bench = (Pidigits*)self;
    
    // Очищаем результат
    bench->result_length = 0;
    if (bench->result_str) {
        bench->result_str[0] = '\0';
    }
    
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
    
    while (1) {
        k += 1;
        mpz_mul_ui(t, n, 2);
        mpz_mul_ui(n, n, k);
        k1 += 2;
        
        // a = (a + t) * k1
        mpz_add(a, a, t);
        mpz_mul_ui(a, a, k1);
        
        // d *= k1
        mpz_mul_ui(d, d, k1);
        
        if (mpz_cmp(a, n) >= 0) {
            // temp = n * 3 + a
            mpz_mul_ui(temp, n, 3);
            mpz_add(temp, temp, a);
            
            // q = temp / d
            mpz_fdiv_q(q, temp, d);
            
            // u = temp % d
            mpz_fdiv_r(u, temp, d);
            
            // u += n
            mpz_add(u, u, n);
            
            if (mpz_cmp(d, u) > 0) {
                // ns = ns * 10 + q
                mpz_mul_ui(ns, ns, 10);
                mpz_add(ns, ns, q);
                i++;
                
                if (i % 10 == 0) {
                    char* ns_str = mpz_get_str(NULL, 10, ns);
                    size_t len = strlen(ns_str);
                    if (len < 10) {
                        char padded[11] = {0};
                        memset(padded, '0', 10 - len);
                        strcpy(padded + 10 - len, ns_str);
                        Pidigits_append(bench, padded);
                    } else {
                        Pidigits_append(bench, ns_str);
                    }
                    Pidigits_append(bench, "\t:");
                    
                    char i_str[32];
                    snprintf(i_str, sizeof(i_str), "%d\n", i);
                    Pidigits_append(bench, i_str);
                    
                    mpz_set_ui(ns, 0);
                    free(ns_str);
                }
                
                if (i >= bench->nn) break;
                
                // a = (a - (d * q)) * 10
                mpz_mul(temp, d, q);
                mpz_sub(a_minus_dq, a, temp);
                mpz_mul_ui(a, a_minus_dq, 10);
                
                // n *= 10
                mpz_mul_ui(n, n, 10);
            }
        }
    }
    
    // Добавляем оставшиеся цифры
    if (mpz_cmp_ui(ns, 0) > 0) {
        char* ns_str = mpz_get_str(NULL, 10, ns);
        size_t len = strlen(ns_str);
        if (len < 10) {
            char padded[11] = {0};
            memset(padded, '0', 10 - len);
            strcpy(padded + 10 - len, ns_str);
            Pidigits_append(bench, padded);
        } else {
            Pidigits_append(bench, ns_str);
        }
        Pidigits_append(bench, "\t:");
        
        char i_str[32];
        snprintf(i_str, sizeof(i_str), "%d\n", i);
        Pidigits_append(bench, i_str);
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
    
    bench->result_val = Helper_checksum_string(bench->result_str);
    return bench->result_val;
}

void Pidigits_prepare(void* self) {
    Pidigits* bench = (Pidigits*)self;
    const char* input = Helper_get_input("Pidigits");
    bench->nn = input ? atoi(input) : 100;
    bench->result_capacity = 0;
    bench->result_length = 0;
    bench->result_str = NULL;
    bench->result_val = 0;
}

void Pidigits_cleanup(void* self) {
    Pidigits* bench = (Pidigits*)self;
    free(bench->result_str);
    free(bench);
}

Benchmark* Pidigits_new(void) {
    Pidigits* instance = malloc(sizeof(Pidigits));
    instance->nn = 0;
    instance->result_str = NULL;
    instance->result_capacity = 0;
    instance->result_length = 0;
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "Pidigits";
    bench->run = Pidigits_run;
    bench->prepare = Pidigits_prepare;
    bench->cleanup = Pidigits_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс Binarytrees
// ============================================================================

typedef struct Binarytrees_TreeNode {
    struct Binarytrees_TreeNode* left;
    struct Binarytrees_TreeNode* right;
    int item;
} Binarytrees_TreeNode;

static Binarytrees_TreeNode* Binarytrees_TreeNode_new(int item, int depth) {
    Binarytrees_TreeNode* node = malloc(sizeof(Binarytrees_TreeNode));
    node->item = item;
    node->left = NULL;
    node->right = NULL;
    
    if (depth > 0) {
        node->left = Binarytrees_TreeNode_new(2 * item - 1, depth - 1);
        node->right = Binarytrees_TreeNode_new(2 * item, depth - 1);
    }
    
    return node;
}

static void Binarytrees_TreeNode_free(Binarytrees_TreeNode* node) {
    if (!node) return;
    Binarytrees_TreeNode_free(node->left);
    Binarytrees_TreeNode_free(node->right);
    free(node);
}

static int Binarytrees_TreeNode_check(Binarytrees_TreeNode* node) {
    if (!node->left || !node->right) {
        return node->item;
    }
    return Binarytrees_TreeNode_check(node->left) - 
           Binarytrees_TreeNode_check(node->right) + node->item;
}

typedef struct {
    int n;
    int result_val;
} Binarytrees;

int64_t Binarytrees_run(void* self) {
    Binarytrees* bench = (Binarytrees*)self;
    
    int min_depth = 4;
    int max_depth = bench->n > (min_depth + 2) ? bench->n : (min_depth + 2);
    int stretch_depth = max_depth + 1;
    
    // Stretch tree
    Binarytrees_TreeNode* stretch_tree = Binarytrees_TreeNode_new(0, stretch_depth);
    bench->result_val = Binarytrees_TreeNode_check(stretch_tree);
    Binarytrees_TreeNode_free(stretch_tree);
    
    for (int depth = min_depth; depth <= max_depth; depth += 2) {
        int iterations = 1 << (max_depth - depth + min_depth);
        for (int i = 1; i <= iterations; i++) {
            Binarytrees_TreeNode* tree1 = Binarytrees_TreeNode_new(i, depth);
            Binarytrees_TreeNode* tree2 = Binarytrees_TreeNode_new(-i, depth);
            bench->result_val += Binarytrees_TreeNode_check(tree1);
            bench->result_val += Binarytrees_TreeNode_check(tree2);
            Binarytrees_TreeNode_free(tree1);
            Binarytrees_TreeNode_free(tree2);
        }
    }
    
    return bench->result_val;
}

void Binarytrees_prepare(void* self) {
    Binarytrees* bench = (Binarytrees*)self;
    const char* input = Helper_get_input("Binarytrees");
    bench->n = input ? atoi(input) : 1;
    bench->result_val = 0;
}

void Binarytrees_cleanup(void* self) {
    free(self);
}

Benchmark* Binarytrees_new(void) {
    Binarytrees* instance = malloc(sizeof(Binarytrees));
    instance->n = 0;
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "Binarytrees";
    bench->run = Binarytrees_run;
    bench->prepare = Binarytrees_prepare;
    bench->cleanup = Binarytrees_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс BrainfuckHashMap
// ============================================================================

typedef struct {
    int key;
    int value;
    UT_hash_handle hh;
} BrainfuckHashMap_BracketPair;

typedef struct {
    uint8_t* tape;
    int32_t tape_size;
    int32_t pos;
} BrainfuckHashMap_Tape;

static BrainfuckHashMap_Tape* BrainfuckHashMap_Tape_new(void) {
    BrainfuckHashMap_Tape* tape = malloc(sizeof(BrainfuckHashMap_Tape));
    tape->tape_size = 1024;
    tape->tape = calloc(tape->tape_size, sizeof(uint8_t));
    tape->pos = 0;
    return tape;
}

static void BrainfuckHashMap_Tape_free(BrainfuckHashMap_Tape* tape) {
    free(tape->tape);
    free(tape);
}

static uint8_t BrainfuckHashMap_Tape_get(BrainfuckHashMap_Tape* tape) {
    return tape->pos < tape->tape_size ? tape->tape[tape->pos] : 0;
}

static void BrainfuckHashMap_Tape_inc(BrainfuckHashMap_Tape* tape) {
    if (tape->pos < tape->tape_size) {
        tape->tape[tape->pos]++;
    }
}

static void BrainfuckHashMap_Tape_dec(BrainfuckHashMap_Tape* tape) {
    if (tape->pos < tape->tape_size) {
        tape->tape[tape->pos]--;
    }
}

static void BrainfuckHashMap_Tape_advance(BrainfuckHashMap_Tape* tape) {
    tape->pos++;
    if (tape->pos >= tape->tape_size) {
        tape->tape_size *= 2;
        tape->tape = realloc(tape->tape, tape->tape_size);
        memset(tape->tape + tape->tape_size / 2, 0, tape->tape_size / 2);
    }
}

static void BrainfuckHashMap_Tape_devance(BrainfuckHashMap_Tape* tape) {
    if (tape->pos > 0) {
        tape->pos--;
    }
}

typedef struct {
    char* code;
    int32_t code_length;
    BrainfuckHashMap_BracketPair* bracket_map;
    int64_t result_val;
} BrainfuckHashMap;

int64_t BrainfuckHashMap_run(void* self) {
    BrainfuckHashMap* bench = (BrainfuckHashMap*)self;
    
    BrainfuckHashMap_Tape* tape = BrainfuckHashMap_Tape_new();
    int pc = 0;
    bench->result_val = 0;
    
    while (pc < bench->code_length) {
        char c = bench->code[pc];
        switch (c) {
            case '+':
                BrainfuckHashMap_Tape_inc(tape);
                break;
            case '-':
                BrainfuckHashMap_Tape_dec(tape);
                break;
            case '>':
                BrainfuckHashMap_Tape_advance(tape);
                break;
            case '<':
                BrainfuckHashMap_Tape_devance(tape);
                break;
            case '[': {
                if (BrainfuckHashMap_Tape_get(tape) == 0) {
                    BrainfuckHashMap_BracketPair* pair = NULL;
                    HASH_FIND_INT(bench->bracket_map, &pc, pair);
                    if (pair) pc = pair->value;
                }
                break;
            }
            case ']': {
                if (BrainfuckHashMap_Tape_get(tape) != 0) {
                    BrainfuckHashMap_BracketPair* pair = NULL;
                    HASH_FIND_INT(bench->bracket_map, &pc, pair);
                    if (pair) pc = pair->value;
                }
                break;
            }
            case '.': {
                uint8_t value = BrainfuckHashMap_Tape_get(tape);
                int64_t shifted = crystal_shl(bench->result_val, 2);
                bench->result_val = crystal_add(shifted, value);
                break;
            }
        }
        pc++;
    }
    
    BrainfuckHashMap_Tape_free(tape);
    return bench->result_val;
}

void BrainfuckHashMap_prepare(void* self) {
    BrainfuckHashMap* bench = (BrainfuckHashMap*)self;
    
    // Получаем код Brainfuck
    const char* input = Helper_get_input("BrainfuckHashMap");
    if (!input) {
        bench->code = NULL;
        bench->code_length = 0;
        bench->bracket_map = NULL;
        bench->result_val = 0;
        return;
    }
    
    // Фильтруем код, оставляя только нужные символы
    int32_t input_len = strlen(input);
    bench->code = malloc(input_len + 1);
    int32_t code_pos = 0;
    
    for (int32_t i = 0; i < input_len; i++) {
        char c = input[i];
        if (strchr("[]<>+-,.", c) != NULL) {
            bench->code[code_pos++] = c;
        }
    }
    bench->code[code_pos] = '\0';
    bench->code_length = code_pos;
    
    // Строим карту скобок
    bench->bracket_map = NULL;
    int* stack = malloc(sizeof(int) * (code_pos / 2 + 1));
    int stack_top = -1;
    
    for (int pc = 0; pc < code_pos; pc++) {
        char c = bench->code[pc];
        if (c == '[') {
            stack[++stack_top] = pc;
        } else if (c == ']' && stack_top >= 0) {
            int left = stack[stack_top--];
            int right = pc;
            
            // Добавляем пару [ -> ]
            BrainfuckHashMap_BracketPair* pair = malloc(sizeof(BrainfuckHashMap_BracketPair));
            pair->key = left;
            pair->value = right;
            HASH_ADD_INT(bench->bracket_map, key, pair);
            
            // Добавляем пару ] -> [
            pair = malloc(sizeof(BrainfuckHashMap_BracketPair));
            pair->key = right;
            pair->value = left;
            HASH_ADD_INT(bench->bracket_map, key, pair);
        }
    }
    
    free(stack);
    bench->result_val = 0;
}

void BrainfuckHashMap_cleanup(void* self) {
    BrainfuckHashMap* bench = (BrainfuckHashMap*)self;
    
    free(bench->code);
    
    // Освобождаем хеш-таблицу
    BrainfuckHashMap_BracketPair* pair, *tmp;
    HASH_ITER(hh, bench->bracket_map, pair, tmp) {
        HASH_DEL(bench->bracket_map, pair);
        free(pair);
    }
    
    free(bench);
}

Benchmark* BrainfuckHashMap_new(void) {
    BrainfuckHashMap* instance = malloc(sizeof(BrainfuckHashMap));
    instance->code = NULL;
    instance->code_length = 0;
    instance->bracket_map = NULL;
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "BrainfuckHashMap";
    bench->run = BrainfuckHashMap_run;
    bench->prepare = BrainfuckHashMap_prepare;
    bench->cleanup = BrainfuckHashMap_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ==================== Fasta ====================

typedef struct {
    char c;
    double prob;
} Fasta_Gene;

typedef struct {
    int n;
    char* result_str;
    size_t result_capacity;
    size_t result_length;
} Fasta;

static void Fasta_grow_result(Fasta* self, size_t needed) {
    size_t min_capacity = self->result_length + needed + 1;
    if (min_capacity <= self->result_capacity) return;
    
    size_t new_capacity = self->result_capacity ? self->result_capacity * 2 : 1024;
    while (new_capacity < min_capacity) new_capacity *= 2;
    
    self->result_str = realloc(self->result_str, new_capacity);
    self->result_capacity = new_capacity;
}

static void Fasta_append(Fasta* self, const char* str) {
    size_t len = strlen(str);
    Fasta_grow_result(self, len + 1);
    memcpy(self->result_str + self->result_length, str, len);
    self->result_length += len;
    self->result_str[self->result_length] = '\0';
}

static void Fasta_append_char(Fasta* self, char c) {
    Fasta_grow_result(self, 2);
    self->result_str[self->result_length++] = c;
    self->result_str[self->result_length] = '\0';
}

static void Fasta_append_substring(Fasta* self, const char* str, size_t len) {
    Fasta_grow_result(self, len + 1);
    memcpy(self->result_str + self->result_length, str, len);
    self->result_length += len;
    self->result_str[self->result_length] = '\0';
}

static char Fasta_select_random(Fasta_Gene* genelist, size_t size) {
    double r = Helper_next_float(1.0);
    if (r < genelist[0].prob) return genelist[0].c;
    
    int lo = 0, hi = size - 1;
    while (hi > lo + 1) {
        int i = (hi + lo) / 2;
        if (r < genelist[i].prob) hi = i;
        else lo = i;
    }
    return genelist[hi].c;
}

static void Fasta_make_random_fasta(Fasta* self, const char* id, const char* desc,
                                   Fasta_Gene* genelist, size_t genelist_size, int n_iter) {
    // Заголовок
    char header[256];
    snprintf(header, sizeof(header), ">%s %s\n", id, desc);
    Fasta_append(self, header);
    
    const int LINE_LENGTH = 60;
    int todo = n_iter;
    
    while (todo > 0) {
        int m = (todo < LINE_LENGTH) ? todo : LINE_LENGTH;
        
        // Создаем строку длиной m символов
        for (int i = 0; i < m; i++) {
            char c = Fasta_select_random(genelist, genelist_size);
            Fasta_append_char(self, c);
        }
        Fasta_append_char(self, '\n');
        todo -= LINE_LENGTH;
    }
}

static void Fasta_make_repeat_fasta(Fasta* self, const char* id, const char* desc,
                                   const char* s, int n_iter) {
    // Заголовок
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

int64_t Fasta_run(void* self) {
    Fasta* bench = (Fasta*)self;
    
    // Очищаем результат
    bench->result_length = 0;
    if (bench->result_str) {
        bench->result_str[0] = '\0';
    } else {
        bench->result_str = malloc(1024);
        bench->result_capacity = 1024;
        bench->result_str[0] = '\0';
    }
    
    // IUB
    Fasta_Gene IUB[] = {
        {'a', 0.27}, {'c', 0.39}, {'g', 0.51}, {'t', 0.78}, {'B', 0.8}, {'D', 0.8200000000000001},
        {'H', 0.8400000000000001}, {'K', 0.8600000000000001}, {'M', 0.8800000000000001},
        {'N', 0.9000000000000001}, {'R', 0.9200000000000002}, {'S', 0.9400000000000002},
        {'V', 0.9600000000000002}, {'W', 0.9800000000000002}, {'Y', 1.0000000000000002}
    };
    
    // HOMO
    Fasta_Gene HOMO[] = {
        {'a', 0.302954942668}, {'c', 0.5009432431601}, {'g', 0.6984905497992}, {'t', 1.0}
    };
    
    const char* ALU = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";
    
    Fasta_make_repeat_fasta(bench, "ONE", "Homo sapiens alu", ALU, bench->n * 2);
    Fasta_make_random_fasta(bench, "TWO", "IUB ambiguity codes", IUB, sizeof(IUB)/sizeof(IUB[0]), bench->n * 3);
    Fasta_make_random_fasta(bench, "THREE", "Homo sapiens frequency", HOMO, sizeof(HOMO)/sizeof(HOMO[0]), bench->n * 5);
    
    return Helper_checksum_string(bench->result_str);
}

void Fasta_prepare(void* self) {
    Fasta* bench = (Fasta*)self;
    // Используем стандартное значение для итераций
    const char* input = Helper_get_input("Fasta");
    bench->n = input ? atoi(input) : 1000;

    bench->result_str = NULL;
    bench->result_capacity = 0;
    bench->result_length = 0;
}

void Fasta_cleanup(void* self) {
    Fasta* bench = (Fasta*)self;
    free(bench->result_str);
    free(bench);
}

Benchmark* Fasta_new(void) {
    Fasta* instance = malloc(sizeof(Fasta));
    instance->n = 0;
    instance->result_str = NULL;
    instance->result_capacity = 0;
    instance->result_length = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "Fasta";
    bench->run = Fasta_run;
    bench->prepare = Fasta_prepare;
    bench->cleanup = Fasta_cleanup;
    bench->instance = instance;
    
    return bench;
}



// ============================================================================
// Класс Fannkuchredux
// ============================================================================

typedef struct {
    int n;
    int64_t result_val;
} Fannkuchredux;

static void fannkuchredux_swap(int* a, int* b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}

static int fannkuchredux_calculate(int n, int* checksum, int* max_flips) {
    int* perm1 = malloc(n * sizeof(int));
    int* perm = malloc(n * sizeof(int));
    int* count = malloc(n * sizeof(int));
    
    for (int i = 0; i < n; i++) perm1[i] = i;
    
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
        
        if (flipsCount > *max_flips) *max_flips = flipsCount;
        *checksum += (permCount % 2 == 0) ? flipsCount : -flipsCount;
        
        while (1) {
            if (r == n) {
                free(perm1);
                free(perm);
                free(count);
                return 0;
            }
            
            int perm0 = perm1[0];
            for (int i = 0; i < r; i++) {
                perm1[i] = perm1[i + 1];
            }
            perm1[r] = perm0;
            
            count[r]--;
            if (count[r] > 0) break;
            r++;
        }
        permCount++;
    }
}

int64_t Fannkuchredux_run(void* self) {
    Fannkuchredux* bench = (Fannkuchredux*)self;
    int checksum, max_flips;
    fannkuchredux_calculate(bench->n, &checksum, &max_flips);
    bench->result_val = checksum * 100 + max_flips;
    return bench->result_val;
}

void Fannkuchredux_prepare(void* self) {
    Fannkuchredux* bench = (Fannkuchredux*)self;
    const char* input = Helper_get_input("Fannkuchredux");
    bench->n = input ? atoi(input) : 12;
    bench->result_val = 0;
}

void Fannkuchredux_cleanup(void* self) {
    free(self);
}

Benchmark* Fannkuchredux_new(void) {
    Fannkuchredux* instance = malloc(sizeof(Fannkuchredux));
    instance->n = 0;
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "Fannkuchredux";
    bench->run = Fannkuchredux_run;
    bench->prepare = Fannkuchredux_prepare;
    bench->cleanup = Fannkuchredux_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс Knuckeotide (нуждается в Fasta для подготовки данных)
// ============================================================================

typedef struct {
    char* seq;
    size_t seq_length;
    char* result_str;
    size_t result_capacity;
    size_t result_length;
} Knuckeotide;

static void Knuckeotide_grow_result(Knuckeotide* self, size_t needed) {
    size_t new_capacity = self->result_capacity;
    while (self->result_length + needed >= new_capacity) {
        new_capacity = new_capacity ? new_capacity * 2 : 1024;
    }
    if (new_capacity > self->result_capacity) {
        self->result_str = realloc(self->result_str, new_capacity);
        self->result_capacity = new_capacity;
    }
}

static void Knuckeotide_append(Knuckeotide* self, const char* str) {
    size_t len = strlen(str);
    Knuckeotide_grow_result(self, len + 1);
    memcpy(self->result_str + self->result_length, str, len);
    self->result_length += len;
    self->result_str[self->result_length] = '\0';
}

static int Knuckeotide_frequency(const char* seq, size_t seq_len, int length, 
                                 char** keys, int* values, int* unique_count) {
    int n = seq_len - length + 1;
    *unique_count = 0;
    
    // Простая реализация для небольших длин
    if (length == 1) {
        int counts[256] = {0};
        for (int i = 0; i < n; i++) {
            counts[(unsigned char)seq[i]]++;
        }
        
        for (int i = 0; i < 256; i++) {
            if (counts[i] > 0) {
                keys[*unique_count] = malloc(2);
                keys[*unique_count][0] = (char)i;
                keys[*unique_count][1] = '\0';
                values[*unique_count] = counts[i];
                (*unique_count)++;
            }
        }
    } else if (length == 2) {
        // Для длины 2 используем простой массив
        int counts[256][256] = {0};
        for (int i = 0; i < n; i++) {
            unsigned char c1 = seq[i];
            unsigned char c2 = seq[i + 1];
            counts[c1][c2]++;
        }
        
        for (int i = 0; i < 256; i++) {
            for (int j = 0; j < 256; j++) {
                if (counts[i][j] > 0) {
                    keys[*unique_count] = malloc(3);
                    keys[*unique_count][0] = (char)i;
                    keys[*unique_count][1] = (char)j;
                    keys[*unique_count][2] = '\0';
                    values[*unique_count] = counts[i][j];
                    (*unique_count)++;
                }
            }
        }
    }
    
    return n;
}

static int Knuckeotide_compare(const void* a, const void* b, void* arg) {
    int* values = (int*)arg;
    int idx_a = *((int*)a);
    int idx_b = *((int*)b);
    
    if (values[idx_a] != values[idx_b]) {
        return values[idx_b] - values[idx_a]; // По убыванию частоты
    }
    // При равной частоте - лексикографически
    char** keys = (char**)arg;
    return strcmp(keys[idx_a], keys[idx_b]);
}

typedef struct {
    char* key;
    int count;
} FrequencyEntry;

static int compare_entries(const void* a, const void* b) {
    const FrequencyEntry* ea = (const FrequencyEntry*)a;
    const FrequencyEntry* eb = (const FrequencyEntry*)b;
    
    if (ea->count != eb->count) {
        return eb->count - ea->count; // По убыванию
    }
    return strcmp(ea->key, eb->key);
}

static void Knuckeotide_sort_by_freq(Knuckeotide* self, int length) {
    // Используем хеш-таблицу для подсчета
    #define TABLE_SIZE 8192
    FrequencyEntry* table = calloc(TABLE_SIZE, sizeof(FrequencyEntry));
    int* counts = calloc(TABLE_SIZE, sizeof(int));
    
    // Подсчет частот (упрощенно для length=1,2)
    int n = self->seq_length - length + 1;
    
    for (int i = 0; i < n; i++) {
        // Создаем ключ
        char key[length + 1];
        strncpy(key, self->seq + i, length);
        key[length] = '\0';
        
        // Простой хеш
        unsigned int hash = 0;
        for (int j = 0; j < length; j++) {
            hash = hash * 31 + key[j];
        }
        hash %= TABLE_SIZE;
        
        // Ищем или добавляем
        if (table[hash].key == NULL) {
            table[hash].key = strdup(key);
            table[hash].count = 1;
        } else if (strcmp(table[hash].key, key) == 0) {
            table[hash].count++;
        } else {
            // Коллизия - линейное пробирование
            int j = (hash + 1) % TABLE_SIZE;
            while (j != hash && table[j].key != NULL && strcmp(table[j].key, key) != 0) {
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
    
    // Собираем ненулевые записи
    FrequencyEntry* entries = malloc(TABLE_SIZE * sizeof(FrequencyEntry));
    int entry_count = 0;
    for (int i = 0; i < TABLE_SIZE; i++) {
        if (table[i].key != NULL) {
            entries[entry_count++] = table[i];
        }
    }
    
    // Сортируем
    qsort(entries, entry_count, sizeof(FrequencyEntry), compare_entries);
    
    // Вывод
    for (int i = 0; i < entry_count; i++) {
        double percent = (entries[i].count * 100.0) / n;
        
        // В верхний регистр
        for (char* p = entries[i].key; *p; p++) {
            if (*p >= 'a' && *p <= 'z') *p = *p - 'a' + 'A';
        }
        
        char line[256];
        snprintf(line, sizeof(line), "%s %.3f\n", entries[i].key, percent);
        Knuckeotide_append(self, line);
        free(entries[i].key);
    }
    Knuckeotide_append(self, "\n");
    
    free(table);
    free(counts);
    free(entries);
}

static void Knuckeotide_find_seq(Knuckeotide* self, const char* s) {
    size_t s_len = strlen(s);
    int count = 0;
    
    // Простой поиск подстроки
    for (size_t i = 0; i <= self->seq_length - s_len; i++) {
        if (strncasecmp(self->seq + i, s, s_len) == 0) {
            count++;
        }
    }
    
    char upper_s[32];
    strcpy(upper_s, s);
    for (char* p = upper_s; *p; p++) {
        if (*p >= 'a' && *p <= 'z') *p = *p - 'a' + 'A';
    }
    
    char line[256];
    snprintf(line, sizeof(line), "%d\t%s\n", count, upper_s);
    Knuckeotide_append(self, line);
}

int64_t Knuckeotide_run(void* self) {
    Knuckeotide* bench = (Knuckeotide*)self;
    
    bench->result_length = 0;
    if (bench->result_str) bench->result_str[0] = '\0';
    
    for (int i = 1; i <= 2; i++) {
        Knuckeotide_sort_by_freq(bench, i);
    }
    
    const char* searches[] = {"ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt"};
    for (int i = 0; i < 5; i++) {
        Knuckeotide_find_seq(bench, searches[i]);
    }
    
    return Helper_checksum_string(bench->result_str);
}

void Knuckeotide_prepare(void* self) {
    Knuckeotide* bench = (Knuckeotide*)self;
    
    // Создаем временный Fasta для получения данных
    Fasta fasta_instance;
    Fasta* fasta = &fasta_instance;
    const char* input = Helper_get_input("Knuckeotide");
    fasta->n = input ? atoi(input) : 1000;
    fasta->result_capacity = 0;
    fasta->result_length = 0;
    fasta->result_str = NULL;
    
    Fasta_run(fasta);
    
    // Извлекаем только часть "THREE" из результата Fasta
    const char* result = fasta->result_str;
    bool in_three = false;
    bench->seq_length = 0;
    
    if (bench->seq) free(bench->seq);
    bench->seq = malloc(strlen(result) + 1);
    
    const char* ptr = result;
    while (*ptr) {
        if (strncmp(ptr, ">THREE", 6) == 0) {
            in_three = true;
            // Пропускаем до конца строки
            while (*ptr && *ptr != '\n') ptr++;
            if (*ptr == '\n') ptr++;
            continue;
        }
        
        if (in_three) {
            if (*ptr == '>') break; // Начало следующей секции
            
            if (*ptr != '\n') {
                bench->seq[bench->seq_length++] = *ptr;
            }
        }
        
        if (*ptr == '\n') {
            // Пропускаем перевод строки
        }
        ptr++;
    }
    bench->seq[bench->seq_length] = '\0';
    
    free(fasta->result_str);
    
    bench->result_capacity = 0;
    bench->result_length = 0;
    bench->result_str = NULL;
}

void Knuckeotide_cleanup(void* self) {
    Knuckeotide* bench = (Knuckeotide*)self;
    free(bench->seq);
    free(bench->result_str);
    free(bench);
}

Benchmark* Knuckeotide_new(void) {
    Knuckeotide* instance = malloc(sizeof(Knuckeotide));
    instance->seq = NULL;
    instance->seq_length = 0;
    instance->result_str = NULL;
    instance->result_capacity = 0;
    instance->result_length = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "Knuckeotide";
    bench->run = Knuckeotide_run;
    bench->prepare = Knuckeotide_prepare;
    bench->cleanup = Knuckeotide_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ==================== RegexDna ====================

typedef struct {
    char* seq;
    int seq_len;
    int ilen;
    int clen;
    char* result_str;
    size_t result_capacity;
    size_t result_length;
    
    // Скомпилированные регулярочки с JIT
    pcre2_code* compiled_patterns[9];
    pcre2_match_data* match_data[9];
} RegexDna;

static void RegexDna_grow_result(RegexDna* self, size_t needed) {
    size_t min_capacity = self->result_length + needed + 1;
    if (min_capacity <= self->result_capacity) return;
    
    size_t new_capacity = self->result_capacity ? self->result_capacity * 2 : 1024;
    while (new_capacity < min_capacity) new_capacity *= 2;
    
    self->result_str = realloc(self->result_str, new_capacity);
    self->result_capacity = new_capacity;
}

static void RegexDna_append(RegexDna* self, const char* str) {
    size_t len = strlen(str);
    RegexDna_grow_result(self, len + 1);
    memcpy(self->result_str + self->result_length, str, len);
    self->result_length += len;
    self->result_str[self->result_length] = '\0';
}

// Lookup table для замен (быстрее чем switch)
static const struct {
    char from;
    const char* to;
    int len;
} REPLACEMENTS[] = {
    {'B', "(c|g|t)", 7},
    {'D', "(a|g|t)", 7},
    {'H', "(a|c|t)", 7},
    {'K', "(g|t)", 5},
    {'M', "(a|c)", 5},
    {'N', "(a|c|g|t)", 9},
    {'R', "(a|g)", 5},
    {'S', "(c|t)", 5},
    {'V', "(a|c|g)", 7},
    {'W', "(a|t)", 5},
    {'Y', "(c|t)", 5},
};
static const int REPLACEMENTS_COUNT = sizeof(REPLACEMENTS) / sizeof(REPLACEMENTS[0]);

static void RegexDna_prepare(void* self) {
    RegexDna* bench = (RegexDna*)self;
    
    // Создаем Fasta
    Fasta fasta;
    const char* input = Helper_get_input("RegexDna");
    fasta.n = input ? atoi(input) : 1000;
    fasta.result_str = NULL;
    fasta.result_capacity = 0;
    fasta.result_length = 0;
    
    Fasta_run(&fasta);
    
    if (!fasta.result_str || fasta.result_length == 0) {
        bench->seq = strdup("");
        bench->seq_len = 0;
        bench->ilen = 0;
        bench->clen = 0;
        free(fasta.result_str);
        return;
    }
    
    bench->ilen = 0;
    bench->clen = 0;
    
    char* seq = malloc(fasta.result_length + 1);
    if (!seq) {
        fprintf(stderr, "Failed to allocate memory for seq\n");
        free(fasta.result_str);
        return;
    }
    
    size_t seq_pos = 0;
    char* current = fasta.result_str;
    
    while (*current) {
        char* line_start = current;
        
        while (*current && *current != '\n') {
            current++;
        }
        
        int line_length = current - line_start;
        bench->ilen += line_length + 1;
        
        if (line_length > 0 && line_start[0] != '>') {
            memcpy(seq + seq_pos, line_start, line_length);
            seq_pos += line_length;
        }
        
        if (*current == '\n') {
            current++;
        }
    }
    
    seq[seq_pos] = '\0';
    bench->seq_len = seq_pos;
    bench->clen = seq_pos;
    bench->seq = seq;
    
    free(fasta.result_str);
    
    bench->result_str = NULL;
    bench->result_capacity = 0;
    bench->result_length = 0;
    
    // ============ КОМПИЛИРУЕМ ВСЕ РЕГУЛЯРОЧКИ С JIT ============
    const char* patterns[] = {
        "agggtaaa|tttaccct",
        "[cgt]gggtaaa|tttaccc[acg]",
        "a[act]ggtaaa|tttacc[agt]t",
        "ag[act]gtaaa|tttac[agt]ct",
        "agg[act]taaa|ttta[agt]cct",
        "aggg[acg]aaa|ttt[cgt]ccct",
        "agggt[cgt]aa|tt[acg]accct",
        "agggta[cgt]a|t[acg]taccct",
        "agggtaa[cgt]|[acg]ttaccct"
    };
    
    for (int i = 0; i < 9; i++) {
        int errornumber;
        PCRE2_SIZE erroroffset;
        
        bench->compiled_patterns[i] = pcre2_compile(
            (PCRE2_SPTR)patterns[i],
            PCRE2_ZERO_TERMINATED,
            PCRE2_UTF | PCRE2_NO_UTF_CHECK,
            &errornumber,
            &erroroffset,
            NULL
        );
        
        if (bench->compiled_patterns[i] == NULL) {
            PCRE2_UCHAR buffer[256];
            pcre2_get_error_message(errornumber, buffer, sizeof(buffer));
            fprintf(stderr, "PCRE2 compilation failed for pattern %d: %s\n", i, buffer);
            bench->compiled_patterns[i] = NULL;
            bench->match_data[i] = NULL;
        } else {
            // ВОТ ОНО! JIT КОМПИЛЯЦИЯ
            pcre2_jit_compile(bench->compiled_patterns[i], PCRE2_JIT_COMPLETE);
            
            bench->match_data[i] = pcre2_match_data_create_from_pattern(
                bench->compiled_patterns[i], 
                NULL
            );
        }
    }
}

static size_t RegexDna_count_pattern_optimized(RegexDna* self, int pattern_idx) {
    pcre2_code* re = self->compiled_patterns[pattern_idx];
    pcre2_match_data* match_data = self->match_data[pattern_idx];
    
    if (re == NULL || match_data == NULL) {
        return 0;
    }
    
    size_t count = 0;
    PCRE2_SIZE start_offset = 0;
    PCRE2_SPTR subject = (PCRE2_SPTR)self->seq;
    PCRE2_SIZE subject_length = self->seq_len;
    
    while (1) {
        // ИСПОЛЬЗУЕМ JIT MATCH!
        int rc = pcre2_jit_match(
            re,
            subject,
            subject_length,
            start_offset,
            0,
            match_data,
            NULL
        );
        
        if (rc < 0) {
            if (rc == PCRE2_ERROR_NOMATCH) break;
            break;
        }
        
        count++;
        
        PCRE2_SIZE* ovector = pcre2_get_ovector_pointer(match_data);
        start_offset = ovector[1];
        
        if (ovector[0] == ovector[1]) {
            start_offset++;
        }
        
        if (start_offset > subject_length) break;
    }
    
    return count;
}

static int64_t RegexDna_run(void* self) {
    RegexDna* bench = (RegexDna*)self;
    
    bench->result_length = 0;
    if (bench->result_str) {
        bench->result_str[0] = '\0';
    }
    
    const char* patterns[] = {
        "agggtaaa|tttaccct",
        "[cgt]gggtaaa|tttaccc[acg]",
        "a[act]ggtaaa|tttacc[agt]t",
        "ag[act]gtaaa|tttac[agt]ct",
        "agg[act]taaa|ttta[agt]cct",
        "aggg[acg]aaa|ttt[cgt]ccct",
        "agggt[cgt]aa|tt[acg]accct",
        "agggta[cgt]a|t[acg]taccct",
        "agggtaa[cgt]|[acg]ttaccct"
    };
    
    char buffer[256];
    for (int i = 0; i < 9; i++) {
        size_t count = RegexDna_count_pattern_optimized(bench, i);
        snprintf(buffer, sizeof(buffer), "%s %zu\n", patterns[i], count);
        RegexDna_append(bench, buffer);
    }
    
    // Оптимизированная замена через lookup table
    char* seq2 = malloc(bench->seq_len * 9 + 1);
    if (!seq2) {
        fprintf(stderr, "Failed to allocate memory for seq2\n");
        return 0;
    }
    
    int seq2_len = 0;
    for (int i = 0; i < bench->seq_len; i++) {
        char c = bench->seq[i];
        int found = 0;
        
        // Поиск в lookup table (маленький, быстрый)
        for (int j = 0; j < REPLACEMENTS_COUNT; j++) {
            if (c == REPLACEMENTS[j].from) {
                memcpy(seq2 + seq2_len, REPLACEMENTS[j].to, REPLACEMENTS[j].len);
                seq2_len += REPLACEMENTS[j].len;
                found = 1;
                break;
            }
        }
        
        if (!found) {
            seq2[seq2_len++] = c;
        }
    }
    seq2[seq2_len] = '\0';
    
    snprintf(buffer, sizeof(buffer), "\n%d\n%d\n%d\n", 
             bench->ilen, bench->clen, seq2_len);
    RegexDna_append(bench, buffer);
    
    int64_t checksum = Helper_checksum_string(bench->result_str);
    
    free(seq2);
    
    return checksum;
}

void RegexDna_cleanup(void* self) {
    RegexDna* bench = (RegexDna*)self;
    
    for (int i = 0; i < 9; i++) {
        if (bench->compiled_patterns[i]) {
            pcre2_code_free(bench->compiled_patterns[i]);
        }
        if (bench->match_data[i]) {
            pcre2_match_data_free(bench->match_data[i]);
        }
    }
    
    free(bench->seq);
    free(bench->result_str);
    free(bench);
}

Benchmark* RegexDna_new(void) {
    RegexDna* instance = calloc(1, sizeof(RegexDna));
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "RegexDna";
    bench->run = RegexDna_run;
    bench->prepare = RegexDna_prepare;
    bench->cleanup = RegexDna_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Revcomp
// ============================================================================

// ==================== Revcomp ====================

typedef struct {
    char* input;
    char* result_str;
    size_t result_capacity;
    size_t result_length;
} Revcomp;

static void Revcomp_grow_result(Revcomp* self, size_t needed) {
    size_t min_capacity = self->result_length + needed + 1;
    if (min_capacity <= self->result_capacity) return;
    
    size_t new_capacity = self->result_capacity ? self->result_capacity * 2 : 1024;
    while (new_capacity < min_capacity) new_capacity *= 2;
    
    self->result_str = realloc(self->result_str, new_capacity);
    self->result_capacity = new_capacity;
}

static void Revcomp_append(Revcomp* self, const char* str) {
    size_t len = strlen(str);
    Revcomp_grow_result(self, len + 1);
    memcpy(self->result_str + self->result_length, str, len);
    self->result_length += len;
    self->result_str[self->result_length] = '\0';
}

static void Revcomp_append_char(Revcomp* self, char c) {
    Revcomp_grow_result(self, 2);
    self->result_str[self->result_length++] = c;
    self->result_str[self->result_length] = '\0';
}

static void Revcomp_append_string(Revcomp* self, const char* str, size_t len) {
    Revcomp_grow_result(self, len + 1);
    memcpy(self->result_str + self->result_length, str, len);
    self->result_length += len;
    self->result_str[self->result_length] = '\0';
}

static char* Revcomp_revcomp(const char* seq, size_t seq_len) {
    if (seq_len == 0) return strdup("");
    
    // Таблица замен ТОЧНО как в C++ версии
    static char lookup[256];
    static int initialized = 0;
    
    if (!initialized) {
        // Инициализируем таблицу идентичными значениями
        for (int i = 0; i < 256; i++) {
            lookup[i] = (char)i;
        }
        
        // ТОЧНАЯ копия таблицы из C++ версии
        const char* from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
        const char* to   = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";
        
        for (size_t i = 0; from[i] != '\0' && to[i] != '\0'; i++) {
            unsigned char idx = (unsigned char)from[i];
            lookup[idx] = to[i];
        }
        
        initialized = 1;
    }
    
    // 1. Реверсируем строку
    char* reversed = malloc(seq_len + 1);
    if (!reversed) return NULL;
    
    for (size_t i = 0; i < seq_len; i++) {
        reversed[i] = seq[seq_len - 1 - i];
    }
    reversed[seq_len] = '\0';
    
    // 2. Применяем таблицу замен
    for (size_t i = 0; i < seq_len; i++) {
        unsigned char idx = (unsigned char)reversed[i];
        reversed[i] = lookup[idx];
    }
    
    // 3. Разбиваем на строки по 60 символов
    size_t num_lines = (seq_len + 59) / 60;  // ceil(seq_len / 60)
    size_t result_size = seq_len + num_lines + 1;  // +1 для null
    
    char* result = malloc(result_size);
    if (!result) {
        free(reversed);
        return NULL;
    }
    
    char* out = result;
    for (size_t i = 0; i < seq_len; i += 60) {
        size_t chunk_len = (seq_len - i < 60) ? (seq_len - i) : 60;
        memcpy(out, reversed + i, chunk_len);
        out += chunk_len;
        *out++ = '\n';
    }
    *out = '\0';
    
    free(reversed);
    return result;
}

static int64_t Revcomp_run(void* self) {
    Revcomp* bench = (Revcomp*)self;
    
    // Сбрасываем результат
    bench->result_length = 0;
    if (bench->result_str) {
        bench->result_str[0] = '\0';
    }
    
    const char* input = bench->input;
    if (!input) {
        fprintf(stderr, "Revcomp: input is NULL\n");
        return 0;
    }
    
    const char* ptr = input;
    char* seq = NULL;
    size_t seq_capacity = 0;
    size_t seq_len = 0;
    
    while (*ptr) {
        const char* line_start = ptr;
        
        // Читаем до конца строки
        while (*ptr && *ptr != '\n') ptr++;
        
        size_t line_len = ptr - line_start;
        
        if (line_len > 0) {
            if (line_start[0] == '>') {
                // Это заголовок
                if (seq_len > 0) {
                    // Обрабатываем накопленную последовательность
                    char* rev = Revcomp_revcomp(seq, seq_len);
                    if (rev) {
                        Revcomp_append(bench, rev);
                        free(rev);
                    }
                    seq_len = 0;
                }
                
                // Добавляем заголовок
                Revcomp_append_string(bench, line_start, line_len);
                Revcomp_append_char(bench, '\n');
            } else {
                // Это последовательность
                if (seq_len + line_len >= seq_capacity) {
                    seq_capacity = (seq_len + line_len + 1) * 2;
                    seq = realloc(seq, seq_capacity);
                }
                
                memcpy(seq + seq_len, line_start, line_len);
                seq_len += line_len;
                if (seq_len < seq_capacity) {
                    seq[seq_len] = '\0'; // Для безопасности
                }
            }
        }
        
        // Пропускаем \n если есть
        if (*ptr == '\n') ptr++;
    }
    
    // Обрабатываем последнюю последовательность
    if (seq_len > 0) {
        char* rev = Revcomp_revcomp(seq, seq_len);
        if (rev) {
            Revcomp_append(bench, rev);
            free(rev);
        }
    }
    
    free(seq);
    
    return Helper_checksum_string(bench->result_str);
}

void Revcomp_prepare(void* self) {
    Revcomp* bench = (Revcomp*)self;
    
    // Создаем Fasta данные
    Fasta fasta_instance;
    Fasta* fasta = &fasta_instance;
    const char* input = Helper_get_input("Revcomp");
    fasta->n = input ? atoi(input) : 1000;
    fasta->result_str = NULL;
    fasta->result_capacity = 0;
    fasta->result_length = 0;
    
    Fasta_run(fasta);
    
    // Сохраняем результат
    if (bench->input) free(bench->input);
    bench->input = strdup(fasta->result_str);
    
    free(fasta->result_str);
    
    bench->result_capacity = 0;
    bench->result_length = 0;
    bench->result_str = NULL;
}

void Revcomp_cleanup(void* self) {
    Revcomp* bench = (Revcomp*)self;
    free(bench->input);
    free(bench->result_str);
    free(bench);
}

Benchmark* Revcomp_new(void) {
    Revcomp* instance = malloc(sizeof(Revcomp));
    instance->input = NULL;
    instance->result_str = NULL;
    instance->result_capacity = 0;
    instance->result_length = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "Revcomp";
    bench->run = Revcomp_run;
    bench->prepare = Revcomp_prepare;
    bench->cleanup = Revcomp_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс Mandelbrot
// ============================================================================

typedef struct {
    int n;
    uint8_t* result_bin;
    size_t result_size;
    size_t result_capacity;
} Mandelbrot;

static void Mandelbrot_grow_result(Mandelbrot* self, size_t needed) {
    size_t new_capacity = self->result_capacity;
    while (self->result_size + needed >= new_capacity) {
        new_capacity = new_capacity ? new_capacity * 2 : 1024;
    }
    if (new_capacity > self->result_capacity) {
        self->result_bin = realloc(self->result_bin, new_capacity);
        self->result_capacity = new_capacity;
    }
}

static void Mandelbrot_append(Mandelbrot* self, const uint8_t* data, size_t size) {
    Mandelbrot_grow_result(self, size);
    memcpy(self->result_bin + self->result_size, data, size);
    self->result_size += size;
}

int64_t Mandelbrot_run(void* self) {
    Mandelbrot* bench = (Mandelbrot*)self;
    
    bench->result_size = 0;
    
    int w = bench->n, h = bench->n;
    char header[256];
    int header_len = snprintf(header, sizeof(header), "P4\n%d %d\n", w, h);
    Mandelbrot_append(bench, (uint8_t*)header, header_len);
    
    const int ITER = 50;
    const double LIMIT = 2.0;
    
    int bit_num = 0;
    uint8_t byte_acc = 0;
    
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            double tmp_x = x;
            double tmp_y = y;
            volatile double tmp_w = w;
            double tmp_h = h;

            double cr = 2.0 * tmp_x / tmp_w - 1.5;
            double ci = 2.0 * tmp_y / tmp_h - 1.0;
            double zr = 0.0, zi = 0.0, tr = 0.0, ti = 0.0;
            
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
                uint8_t byte = byte_acc;
                Mandelbrot_append(bench, &byte, 1);
                byte_acc = 0;
                bit_num = 0;
            } else if (x == w - 1) {
                byte_acc <<= (8 - (w % 8));
                uint8_t byte = byte_acc;
                Mandelbrot_append(bench, &byte, 1);
                byte_acc = 0;
                bit_num = 0;
            }
        }
    }
    
    return Helper_checksum_bytes(bench->result_bin, bench->result_size);
}

void Mandelbrot_prepare(void* self) {
    Mandelbrot* bench = (Mandelbrot*)self;
    const char* input = Helper_get_input("Mandelbrot");
    bench->n = input ? atoi(input) : 200;
    bench->result_bin = NULL;
    bench->result_size = 0;
    bench->result_capacity = 0;
}

void Mandelbrot_cleanup(void* self) {
    Mandelbrot* bench = (Mandelbrot*)self;
    free(bench->result_bin);
    free(bench);
}

Benchmark* Mandelbrot_new(void) {
    Mandelbrot* instance = malloc(sizeof(Mandelbrot));
    instance->n = 0;
    instance->result_bin = NULL;
    instance->result_size = 0;
    instance->result_capacity = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "Mandelbrot";
    bench->run = Mandelbrot_run;
    bench->prepare = Mandelbrot_prepare;
    bench->cleanup = Mandelbrot_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс Matmul (матричное умножение)
// ============================================================================

typedef struct {
    int n;
    uint32_t result_val;
} Matmul;

static double** Matmul_matgen(int n) {
    double tmp = 1.0 / n / n;
    double** a = malloc(n * sizeof(double*));
    
    for (int i = 0; i < n; i++) {
        a[i] = malloc(n * sizeof(double));
        for (int j = 0; j < n; j++) {
            a[i][j] = tmp * (i - j) * (i + j);
        }
    }
    return a;
}

static void Matmul_free_matrix(double** a, int n) {
    for (int i = 0; i < n; i++) {
        free(a[i]);
    }
    free(a);
}

static double** Matmul_matmul(double** a, double** b, int n) {
    // Транспонирование b
    double** b2 = malloc(n * sizeof(double*));
    for (int j = 0; j < n; j++) {
        b2[j] = malloc(n * sizeof(double));
        for (int i = 0; i < n; i++) {
            b2[j][i] = b[i][j];
        }
    }
    
    // Умножение
    double** c = malloc(n * sizeof(double*));
    for (int i = 0; i < n; i++) {
        c[i] = malloc(n * sizeof(double));
        double* ai = a[i];
        for (int j = 0; j < n; j++) {
            double s = 0.0;
            double* b2j = b2[j];
            for (int k = 0; k < n; k++) {
                s += ai[k] * b2j[k];
            }
            c[i][j] = s;
        }
    }
    
    // Освобождаем временную матрицу
    Matmul_free_matrix(b2, n);
    return c;
}

int64_t Matmul_run(void* self) {
    Matmul* bench = (Matmul*)self;
    
    double** a = Matmul_matgen(bench->n);
    double** b = Matmul_matgen(bench->n);
    double** c = Matmul_matmul(a, b, bench->n);
    
    double center_value = c[bench->n >> 1][bench->n >> 1];
    
    Matmul_free_matrix(a, bench->n);
    Matmul_free_matrix(b, bench->n);
    Matmul_free_matrix(c, bench->n);
    
    bench->result_val = Helper_checksum_f64(center_value);
    return bench->result_val;
}

void Matmul_prepare(void* self) {
    Matmul* bench = (Matmul*)self;
    const char* input = Helper_get_input("Matmul");
    bench->n = input ? atoi(input) : 100;
    bench->result_val = 0;
}

void Matmul_cleanup(void* self) {
    free(self);
}

Benchmark* Matmul_new(void) {
    Matmul* instance = malloc(sizeof(Matmul));
    instance->n = 0;
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "Matmul";
    bench->run = Matmul_run;
    bench->prepare = Matmul_prepare;
    bench->cleanup = Matmul_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ------------------------------- Matmul4T ------------------------------

typedef struct {
    int n;
    uint32_t result_val;
} Matmul4T;

typedef struct {
    double** a;
    double** b_t;
    double** c;
    int n;
    int start_row;
    int end_row;
} ThreadData;

static void* matmul_thread(void* arg) {
    ThreadData* data = (ThreadData*)arg;
    
    for (int i = data->start_row; i < data->end_row; i++) {
        double* ai = data->a[i];
        double* ci = data->c[i];
        
        for (int j = 0; j < data->n; j++) {
            double sum = 0.0;
            double* b_tj = data->b_t[j];
            
            for (int k = 0; k < data->n; k++) {
                sum += ai[k] * b_tj[k];
            }
            ci[j] = sum;
        }
    }
    
    return NULL;
}

static double** Matmul4T_matgen(int n) {
    double tmp = 1.0 / n / n;
    double** a = malloc(n * sizeof(double*));
    
    for (int i = 0; i < n; i++) {
        a[i] = malloc(n * sizeof(double));
        for (int j = 0; j < n; j++) {
            a[i][j] = tmp * (i - j) * (i + j);
        }
    }
    return a;
}

static void Matmul4T_free_matrix(double** a, int n) {
    for (int i = 0; i < n; i++) {
        free(a[i]);
    }
    free(a);
}

static double** Matmul4T_matmul_parallel(double** a, double** b, int n) {
    const int num_threads = 4;
    pthread_t threads[num_threads];
    ThreadData thread_data[num_threads];
    
    // Транспонируем b (последовательно)
    double** b_t = malloc(n * sizeof(double*));
    for (int j = 0; j < n; j++) {
        b_t[j] = malloc(n * sizeof(double));
        for (int i = 0; i < n; i++) {
            b_t[j][i] = b[i][j];
        }
    }
    
    // Создаем матрицу результата
    double** c = malloc(n * sizeof(double*));
    for (int i = 0; i < n; i++) {
        c[i] = calloc(n, sizeof(double)); // инициализируем нулями
    }
    
    // Разделяем работу между потоками
    int rows_per_thread = (n + num_threads - 1) / num_threads;
    
    // Создаем потоки
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
        
        int rc = pthread_create(&threads[t], NULL, matmul_thread, &thread_data[t]);
        if (rc != 0) {
            fprintf(stderr, "Failed to create thread %d, running sequentially\n", t);
            // Если не удалось создать поток, выполняем работу в текущем потоке
            matmul_thread(&thread_data[t]);
        }
    }
    
    // Ждем завершения всех потоков
    for (int t = 0; t < num_threads; t++) {
        if (threads[t] != 0) { // Проверяем что поток был создан
            pthread_join(threads[t], NULL);
        }
    }

    // Освобождаем временную матрицу
    Matmul4T_free_matrix(b_t, n);
    
    return c;
}

int64_t Matmul4T_run(void* self) {
    Matmul4T* bench = (Matmul4T*)self;
    
    double** a = Matmul4T_matgen(bench->n);
    double** b = Matmul4T_matgen(bench->n);
    double** c = Matmul4T_matmul_parallel(a, b, bench->n);
    
    double center_value = c[bench->n >> 1][bench->n >> 1];
    
    Matmul4T_free_matrix(a, bench->n);
    Matmul4T_free_matrix(b, bench->n);
    Matmul4T_free_matrix(c, bench->n);
    
    bench->result_val = Helper_checksum_f64(center_value);
    return bench->result_val;
}

void Matmul4T_prepare(void* self) {
    Matmul4T* bench = (Matmul4T*)self;
    const char* input = Helper_get_input("Matmul4T");
    bench->n = input ? atoi(input) : 100;
    bench->result_val = 0;
}

void Matmul4T_cleanup(void* self) {
    Matmul4T* bench = (Matmul4T*)self;
    free(bench);
}

Benchmark* Matmul4T_new(void) {
    Matmul4T* instance = malloc(sizeof(Matmul4T));
    if (!instance) return NULL;
    
    instance->n = 0;
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    if (!bench) {
        free(instance);
        return NULL;
    }
    
    bench->name = "Matmul4T";
    bench->run = Matmul4T_run;
    bench->prepare = Matmul4T_prepare;
    bench->cleanup = Matmul4T_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ------------------------------- Matmul8T ------------------------------

typedef struct {
    int n;
    uint32_t result_val;
} Matmul8T;

static void* matmul8_thread(void* arg) {
    ThreadData* data = (ThreadData*)arg;
    
    for (int i = data->start_row; i < data->end_row; i++) {
        double* ai = data->a[i];
        double* ci = data->c[i];
        
        for (int j = 0; j < data->n; j++) {
            double sum = 0.0;
            double* b_tj = data->b_t[j];
            
            for (int k = 0; k < data->n; k++) {
                sum += ai[k] * b_tj[k];
            }
            ci[j] = sum;
        }
    }
    
    return NULL;
}

static double** Matmul8T_matgen(int n) {
    double tmp = 1.0 / n / n;
    double** a = malloc(n * sizeof(double*));
    
    for (int i = 0; i < n; i++) {
        a[i] = malloc(n * sizeof(double));
        for (int j = 0; j < n; j++) {
            a[i][j] = tmp * (i - j) * (i + j);
        }
    }
    return a;
}

static void Matmul8T_free_matrix(double** a, int n) {
    for (int i = 0; i < n; i++) {
        free(a[i]);
    }
    free(a);
}

static double** Matmul8T_matmul_parallel(double** a, double** b, int n) {
    const int num_threads = 8;
    pthread_t threads[num_threads];
    ThreadData thread_data[num_threads];
    
    // Транспонируем b (последовательно)
    double** b_t = malloc(n * sizeof(double*));
    for (int j = 0; j < n; j++) {
        b_t[j] = malloc(n * sizeof(double));
        for (int i = 0; i < n; i++) {
            b_t[j][i] = b[i][j];
        }
    }
    
    // Создаем матрицу результата
    double** c = malloc(n * sizeof(double*));
    for (int i = 0; i < n; i++) {
        c[i] = calloc(n, sizeof(double)); // инициализируем нулями
    }
    
    // Разделяем работу между потоками
    int rows_per_thread = (n + num_threads - 1) / num_threads;
    
    // Создаем потоки
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
        
        int rc = pthread_create(&threads[t], NULL, matmul8_thread, &thread_data[t]);
        if (rc != 0) {
            fprintf(stderr, "Failed to create thread %d, running sequentially\n", t);
            // Если не удалось создать поток, выполняем работу в текущем потоке
            matmul_thread(&thread_data[t]);
        }
    }
    
    // Ждем завершения всех потоков
    for (int t = 0; t < num_threads; t++) {
        if (threads[t] != 0) { // Проверяем что поток был создан
            pthread_join(threads[t], NULL);
        }
    }

    // Освобождаем временную матрицу
    Matmul8T_free_matrix(b_t, n);
    
    return c;
}

int64_t Matmul8T_run(void* self) {
    Matmul8T* bench = (Matmul8T*)self;
    
    double** a = Matmul8T_matgen(bench->n);
    double** b = Matmul8T_matgen(bench->n);
    double** c = Matmul8T_matmul_parallel(a, b, bench->n);
    
    double center_value = c[bench->n >> 1][bench->n >> 1];
    
    Matmul8T_free_matrix(a, bench->n);
    Matmul8T_free_matrix(b, bench->n);
    Matmul8T_free_matrix(c, bench->n);
    
    bench->result_val = Helper_checksum_f64(center_value);
    return bench->result_val;
}

void Matmul8T_prepare(void* self) {
    Matmul8T* bench = (Matmul8T*)self;
    const char* input = Helper_get_input("Matmul8T");
    bench->n = input ? atoi(input) : 100;
    bench->result_val = 0;
}

void Matmul8T_cleanup(void* self) {
    Matmul8T* bench = (Matmul8T*)self;
    free(bench);
}

Benchmark* Matmul8T_new(void) {
    Matmul8T* instance = malloc(sizeof(Matmul8T));
    if (!instance) return NULL;
    
    instance->n = 0;
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    if (!bench) {
        free(instance);
        return NULL;
    }
    
    bench->name = "Matmul8T";
    bench->run = Matmul8T_run;
    bench->prepare = Matmul8T_prepare;
    bench->cleanup = Matmul8T_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ------------------------------- Matmul16T ------------------------------

typedef struct {
    int n;
    uint32_t result_val;
} Matmul16T;

static void* matmul16_thread(void* arg) {
    ThreadData* data = (ThreadData*)arg;
    
    for (int i = data->start_row; i < data->end_row; i++) {
        double* ai = data->a[i];
        double* ci = data->c[i];
        
        for (int j = 0; j < data->n; j++) {
            double sum = 0.0;
            double* b_tj = data->b_t[j];
            
            for (int k = 0; k < data->n; k++) {
                sum += ai[k] * b_tj[k];
            }
            ci[j] = sum;
        }
    }
    
    return NULL;
}

static double** Matmul16T_matgen(int n) {
    double tmp = 1.0 / n / n;
    double** a = malloc(n * sizeof(double*));
    
    for (int i = 0; i < n; i++) {
        a[i] = malloc(n * sizeof(double));
        for (int j = 0; j < n; j++) {
            a[i][j] = tmp * (i - j) * (i + j);
        }
    }
    return a;
}

static void Matmul16T_free_matrix(double** a, int n) {
    for (int i = 0; i < n; i++) {
        free(a[i]);
    }
    free(a);
}

static double** Matmul16T_matmul_parallel(double** a, double** b, int n) {
    const int num_threads = 16;
    pthread_t threads[num_threads];
    ThreadData thread_data[num_threads];
    
    // Транспонируем b (последовательно)
    double** b_t = malloc(n * sizeof(double*));
    for (int j = 0; j < n; j++) {
        b_t[j] = malloc(n * sizeof(double));
        for (int i = 0; i < n; i++) {
            b_t[j][i] = b[i][j];
        }
    }
    
    // Создаем матрицу результата
    double** c = malloc(n * sizeof(double*));
    for (int i = 0; i < n; i++) {
        c[i] = calloc(n, sizeof(double)); // инициализируем нулями
    }
    
    // Разделяем работу между потоками
    int rows_per_thread = (n + num_threads - 1) / num_threads;
    
    // Создаем потоки
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
        
        int rc = pthread_create(&threads[t], NULL, matmul16_thread, &thread_data[t]);
        if (rc != 0) {
            fprintf(stderr, "Failed to create thread %d, running sequentially\n", t);
            // Если не удалось создать поток, выполняем работу в текущем потоке
            matmul_thread(&thread_data[t]);
        }
    }
    
    // Ждем завершения всех потоков
    for (int t = 0; t < num_threads; t++) {
        if (threads[t] != 0) { // Проверяем что поток был создан
            pthread_join(threads[t], NULL);
        }
    }

    // Освобождаем временную матрицу
    Matmul16T_free_matrix(b_t, n);
    
    return c;
}

int64_t Matmul16T_run(void* self) {
    Matmul16T* bench = (Matmul16T*)self;
    
    double** a = Matmul16T_matgen(bench->n);
    double** b = Matmul16T_matgen(bench->n);
    double** c = Matmul16T_matmul_parallel(a, b, bench->n);
    
    double center_value = c[bench->n >> 1][bench->n >> 1];
    
    Matmul16T_free_matrix(a, bench->n);
    Matmul16T_free_matrix(b, bench->n);
    Matmul16T_free_matrix(c, bench->n);
    
    bench->result_val = Helper_checksum_f64(center_value);
    return bench->result_val;
}

void Matmul16T_prepare(void* self) {
    Matmul16T* bench = (Matmul16T*)self;
    const char* input = Helper_get_input("Matmul16T");
    bench->n = input ? atoi(input) : 100;
    bench->result_val = 0;
}

void Matmul16T_cleanup(void* self) {
    Matmul16T* bench = (Matmul16T*)self;
    free(bench);
}

Benchmark* Matmul16T_new(void) {
    Matmul16T* instance = malloc(sizeof(Matmul16T));
    if (!instance) return NULL;
    
    instance->n = 0;
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    if (!bench) {
        free(instance);
        return NULL;
    }
    
    bench->name = "Matmul16T";
    bench->run = Matmul16T_run;
    bench->prepare = Matmul16T_prepare;
    bench->cleanup = Matmul16T_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс Nbody
// ============================================================================

// #define M_PI 3.14159265358979323846
#define SOLAR_MASS (4 * M_PI * M_PI)
#define DAYS_PER_YEAR 365.24

typedef struct {
    double x, y, z;
    double vx, vy, vz;
    double mass;
} Nbody_Planet;

typedef struct {
    int n;
    Nbody_Planet* bodies;
    int nbodies;
    uint32_t result_val;
} Nbody;

static void Nbody_Planet_init(Nbody_Planet* p, double x, double y, double z,
                             double vx, double vy, double vz, double mass) {
    p->x = x;
    p->y = y;
    p->z = z;
    p->vx = vx * DAYS_PER_YEAR;
    p->vy = vy * DAYS_PER_YEAR;
    p->vz = vz * DAYS_PER_YEAR;
    p->mass = mass * SOLAR_MASS;
}

static void Nbody_Planet_move_from_i(Nbody_Planet* bodies, int nbodies, double dt, int idx) {
    Nbody_Planet* b1 = &bodies[idx];
    
    for (int i = idx + 1; i < nbodies; i++) {
        Nbody_Planet* b2 = &bodies[i];
        double dx = b1->x - b2->x;
        double dy = b1->y - b2->y;
        double dz = b1->z - b2->z;
        
        double distance = sqrt(dx * dx + dy * dy + dz * dz);
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

static double Nbody_energy(Nbody_Planet* bodies, int nbodies) {
    double e = 0.0;
    
    for (int i = 0; i < nbodies; i++) {
        Nbody_Planet* b = &bodies[i];
        e += 0.5 * b->mass * (b->vx * b->vx + b->vy * b->vy + b->vz * b->vz);
        for (int j = i + 1; j < nbodies; j++) {
            Nbody_Planet* b2 = &bodies[j];
            double dx = b->x - b2->x;
            double dy = b->y - b2->y;
            double dz = b->z - b2->z;
            double distance = sqrt(dx * dx + dy * dy + dz * dz);
            e -= (b->mass * b2->mass) / distance;
        }
    }
    return e;
}

static void Nbody_offset_momentum(Nbody_Planet* bodies, int nbodies) {
    double px = 0.0, py = 0.0, pz = 0.0;
    
    for (int i = 0; i < nbodies; i++) {
        Nbody_Planet* b = &bodies[i];
        px += b->vx * b->mass;
        py += b->vy * b->mass;
        pz += b->vz * b->mass;
    }
    
    Nbody_Planet* b = &bodies[0];
    b->vx = -px / SOLAR_MASS;
    b->vy = -py / SOLAR_MASS;
    b->vz = -pz / SOLAR_MASS;
}

int64_t Nbody_run(void* self) {
    Nbody* bench = (Nbody*)self;
    
    Nbody_offset_momentum(bench->bodies, bench->nbodies);
    double v1 = Nbody_energy(bench->bodies, bench->nbodies);
    
    double dt = 0.01;
    
    for (int iter = 0; iter < bench->n; iter++) {
        for (int i = 0; i < bench->nbodies; i++) {
            Nbody_Planet_move_from_i(bench->bodies, bench->nbodies, dt, i);
        }
    }
    
    double v2 = Nbody_energy(bench->bodies, bench->nbodies);
    bench->result_val = (Helper_checksum_f64(v1) << 5) & Helper_checksum_f64(v2);
    return bench->result_val;
}

void Nbody_prepare(void* self) {
    Nbody* bench = (Nbody*)self;
    const char* input = Helper_get_input("Nbody");
    bench->n = input ? atoi(input) : 1000;
    bench->result_val = 0;
    
    // Инициализируем планеты если еще не инициализированы
    if (!bench->bodies) {
        bench->nbodies = 5;
        bench->bodies = malloc(bench->nbodies * sizeof(Nbody_Planet));
        
        // sun
        Nbody_Planet_init(&bench->bodies[0], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);
        // jupiter
        Nbody_Planet_init(&bench->bodies[1], 
            4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
            1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05,
            9.54791938424326609e-04);
        // saturn
        Nbody_Planet_init(&bench->bodies[2],
            8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
            -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05,
            2.85885980666130812e-04);
        // uranus
        Nbody_Planet_init(&bench->bodies[3],
            1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
            2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05,
            4.36624404335156298e-05);
        // neptune
        Nbody_Planet_init(&bench->bodies[4],
            1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
            2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05,
            5.15138902046611451e-05);
    }
}

void Nbody_cleanup(void* self) {
    Nbody* bench = (Nbody*)self;
    free(bench->bodies);
    free(bench);
}

Benchmark* Nbody_new(void) {
    Nbody* instance = malloc(sizeof(Nbody));
    instance->n = 0;
    instance->bodies = NULL;
    instance->nbodies = 0;
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "Nbody";
    bench->run = Nbody_run;
    bench->prepare = Nbody_prepare;
    bench->cleanup = Nbody_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс Spectralnorm
// ============================================================================

typedef struct {
    int n;
    uint32_t result_val;
} Spectralnorm;

static double Spectralnorm_eval_A(int i, int j) {
    return 1.0 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0);
}

static void Spectralnorm_eval_A_times_u(double* u, double* v, int n) {
    for (int i = 0; i < n; i++) {
        double sum = 0.0;
        for (int j = 0; j < n; j++) {
            sum += Spectralnorm_eval_A(i, j) * u[j];
        }
        v[i] = sum;
    }
}

static void Spectralnorm_eval_At_times_u(double* u, double* v, int n) {
    for (int i = 0; i < n; i++) {
        double sum = 0.0;
        for (int j = 0; j < n; j++) {
            sum += Spectralnorm_eval_A(j, i) * u[j];
        }
        v[i] = sum;
    }
}

static void Spectralnorm_eval_AtA_times_u(double* u, double* v, double* w, int n) {
    Spectralnorm_eval_A_times_u(u, w, n);
    Spectralnorm_eval_At_times_u(w, v, n);
}

int64_t Spectralnorm_run(void* self) {
    Spectralnorm* bench = (Spectralnorm*)self;
    
    double* u = malloc(bench->n * sizeof(double));
    double* v = malloc(bench->n * sizeof(double));
    double* w = malloc(bench->n * sizeof(double));
    
    for (int i = 0; i < bench->n; i++) {
        u[i] = 1.0;
        v[i] = 1.0;
    }
    
    for (int i = 0; i < 10; i++) {
        Spectralnorm_eval_AtA_times_u(u, v, w, bench->n);
        Spectralnorm_eval_AtA_times_u(v, u, w, bench->n);
    }
    
    double vBv = 0.0, vv = 0.0;
    for (int i = 0; i < bench->n; i++) {
        vBv += u[i] * v[i];
        vv += v[i] * v[i];
    }
    
    free(u);
    free(v);
    free(w);
    
    bench->result_val = Helper_checksum_f64(sqrt(vBv / vv));
    return bench->result_val;
}

void Spectralnorm_prepare(void* self) {
    Spectralnorm* bench = (Spectralnorm*)self;
    const char* input = Helper_get_input("Spectralnorm");
    bench->n = input ? atoi(input) : 100;
    bench->result_val = 0;
}

void Spectralnorm_cleanup(void* self) {
    free(self);
}

Benchmark* Spectralnorm_new(void) {
    Spectralnorm* instance = malloc(sizeof(Spectralnorm));
    instance->n = 0;
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "Spectralnorm";
    bench->run = Spectralnorm_run;
    bench->prepare = Spectralnorm_prepare;
    bench->cleanup = Spectralnorm_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ----------------------------------- Base64Encode ----------------------------
#include "libbase64.h"

typedef struct {
    char* input_str;
    size_t input_len;
    char* encoded_str;
    size_t encoded_len;
    uint32_t result_val;
} Base64Encode;

static size_t encode_size(size_t size) { 
    return (size_t)(size * 4 / 3.0) + 6; 
}

static size_t b64_encode(char *dst, const char *src, size_t src_size) {
    size_t encoded_size;
    base64_encode(src, src_size, dst, &encoded_size, 0);
    return encoded_size;
}

static void Base64Encode_prepare(void* self) {
    Base64Encode* bench = (Base64Encode*)self;
    const char* input = Helper_get_input("Base64Encode");

    bench->input_len = input ? atoi(input) : 100;
    bench->input_str = malloc(bench->input_len + 1);
    memset(bench->input_str, 'a', bench->input_len);
    bench->input_str[bench->input_len] = '\0';
    
    // Предварительно вычисляем закодированную версию
    bench->encoded_len = encode_size(bench->input_len);
    bench->encoded_str = malloc(bench->encoded_len);
    bench->encoded_len = b64_encode(bench->encoded_str, bench->input_str, bench->input_len);
    
    bench->result_val = 0;
}

static int64_t Base64Encode_run(void* self) {
    Base64Encode* bench = (Base64Encode*)self;
    
    const int TRIES = 8192;
    int64_t s_encoded = 0;
    size_t encoded_size = encode_size(bench->input_len);
    
    // Горячий цикл - используем стек для избежания аллокаций
    char encoded_buf[encoded_size];
    
    for (int i = 0; i < TRIES; i++) {
        s_encoded += b64_encode(encoded_buf, bench->input_str, bench->input_len);
    }
    
    char result_str[256];
    snprintf(result_str, sizeof(result_str), 
             "encode %.*s... to %.*s...: %lld\n",
             4, bench->input_str,
             4, bench->encoded_str,
             (long long)s_encoded);
    
    bench->result_val = Helper_checksum_string(result_str);
    return bench->result_val;
}

static void Base64Encode_cleanup(void* self) {
    Base64Encode* bench = (Base64Encode*)self;
    free(bench->input_str);
    free(bench->encoded_str);
}

Benchmark* Base64Encode_new(void) {
    Base64Encode* instance = calloc(1, sizeof(Base64Encode));
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "Base64Encode";
    bench->run = Base64Encode_run;
    bench->prepare = Base64Encode_prepare;
    bench->cleanup = Base64Encode_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ----------------------------------- Base64Decode ----------------------------

typedef struct {
    char* encoded_str;
    size_t encoded_len;
    char* decoded_str;
    size_t decoded_len;
    uint32_t result_val;
} Base64Decode;

static size_t decode_size(size_t size) { 
    return (size_t)(size * 3 / 4.0) + 6; 
}

static size_t b64_decode(char *dst, const char *src, size_t src_size) {
    size_t decoded_size;
    if (base64_decode(src, src_size, dst, &decoded_size, 0) != 1) {
        return 0; // Ошибка декодирования
    }
    return decoded_size;
}

static void Base64Decode_prepare(void* self) {
    Base64Decode* bench = (Base64Decode*)self;
    const char* input = Helper_get_input("Base64Decode");
    
    const int len = input ? atoi(input) : 100;
    char* str = malloc(len + 1);
    memset(str, 'a', len);
    str[len] = '\0';

    // Кодируем строку
    size_t encoded_size = (size_t)(len * 4 / 3.0) + 6;
    char* encoded = malloc(encoded_size);
    size_t actual_encoded = 0;
    base64_encode(str, len, encoded, &actual_encoded, 0);
    
    bench->encoded_str = encoded;
    bench->encoded_len = actual_encoded;

    // Декодируем обратно для проверки
    size_t decoded_size = decode_size(bench->encoded_len);
    bench->decoded_str = malloc(decoded_size);
    bench->decoded_len = b64_decode(bench->decoded_str, bench->encoded_str, bench->encoded_len);

    bench->result_val = 0;
    
    free(str);
}

static int64_t Base64Decode_run(void* self) {
    Base64Decode* bench = (Base64Decode*)self;
    
    const int TRIES = 8192;
    int64_t s_decoded = 0;
    size_t decoded_buf_size = decode_size(bench->encoded_len);
    
    // Используем стек для избежания аллокаций в горячем цикле
    char decoded_buf[decoded_buf_size];
    
    for (int i = 0; i < TRIES; i++) {
        s_decoded += b64_decode(decoded_buf, bench->encoded_str, bench->encoded_len);
    }
    
    char result_str[256];
    snprintf(result_str, sizeof(result_str), 
             "decode %.*s... to %.*s...: %lld\n",
             4, bench->encoded_str,
             4, bench->decoded_str,
             (long long)s_decoded);
    
    bench->result_val = Helper_checksum_string(result_str);
    return bench->result_val;
}

static void Base64Decode_cleanup(void* self) {
    Base64Decode* bench = (Base64Decode*)self;
    free(bench->encoded_str);
    free(bench->decoded_str);
}

Benchmark* Base64Decode_new(void) {
    Base64Decode* instance = calloc(1, sizeof(Base64Decode));
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "Base64Decode";
    bench->run = Base64Decode_run;
    bench->prepare = Base64Decode_prepare;
    bench->cleanup = Base64Decode_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Primes
// ============================================================================

typedef struct PrimesNode PrimesNode;

struct PrimesNode {
    PrimesNode* children[10];
    bool terminal;
};

typedef struct {
    PrimesNode* root;
    PrimesNode** node_pool;     // Для эффективного освобождения
    size_t pool_size;
    size_t pool_capacity;
} Trie;

typedef struct {
    int n;
    uint32_t result_val;
} Primes;

// Создаем ноду, используя пул для эффективного освобождения
static PrimesNode* node_create(Trie* trie) {
    // Расширяем пул при необходимости
    if (trie->pool_size >= trie->pool_capacity) {
        size_t new_capacity = trie->pool_capacity * 2;
        if (new_capacity < 64) new_capacity = 64;
        
        PrimesNode** new_pool = realloc(trie->node_pool, new_capacity * sizeof(PrimesNode*));
        if (!new_pool) return NULL;
        
        trie->node_pool = new_pool;
        trie->pool_capacity = new_capacity;
    }
    
    PrimesNode* node = malloc(sizeof(PrimesNode));
    if (!node) return NULL;
    
    memset(node->children, 0, sizeof(node->children));
    node->terminal = false;
    
    // Сохраняем в пул для легкого освобождения
    trie->node_pool[trie->pool_size++] = node;
    return node;
}

// Создаем trie с пулом нод
static Trie* trie_create(void) {
    Trie* trie = malloc(sizeof(Trie));
    if (!trie) return NULL;
    
    trie->node_pool = NULL;
    trie->pool_size = 0;
    trie->pool_capacity = 0;
    
    trie->root = node_create(trie);
    if (!trie->root) {
        free(trie);
        return NULL;
    }
    
    return trie;
}

// Эффективное освобождение через пул
static void trie_free(Trie* trie) {
    if (!trie) return;
    
    // Освобождаем все ноды из пула
    for (size_t i = 0; i < trie->pool_size; i++) {
        free(trie->node_pool[i]);
    }
    
    free(trie->node_pool);
    free(trie);
}

// Вставка с предварительным вычислением длины строки
static bool trie_insert(Trie* trie, int number) {
    // Быстрое преобразование числа в строку
    char buffer[12];
    char* end = buffer + sizeof(buffer) - 1;
    *end = '\0';
    
    int n = number;
    do {
        *--end = '0' + (n % 10);
        n /= 10;
    } while (n > 0);
    
    PrimesNode* current = trie->root;
    const char* digit_ptr = end;
    
    while (*digit_ptr) {
        int digit = *digit_ptr - '0';
        
        if (!current->children[digit]) {
            current->children[digit] = node_create(trie);
            if (!current->children[digit]) return false;
        }
        current = current->children[digit];
        digit_ptr++;
    }
    
    current->terminal = true;
    return true;
}

// Решето с cache-friendly оптимизациями
static int* generate_primes(int limit, int* count) {
    if (limit < 2) {
        *count = 0;
        return NULL;
    }
    
    // Используем unsigned char для лучшей плотности
    unsigned char* is_prime = malloc((size_t)limit + 1);
    if (!is_prime) {
        *count = 0;
        return NULL;
    }
    
    // Инициализация
    memset(is_prime, 1, (size_t)limit + 1);
    is_prime[0] = is_prime[1] = 0;
    
    // Кэш-дружественная реализация
    const int sqrt_limit = (int)sqrt((double)limit);
    
    for (int p = 2; p <= sqrt_limit; p++) {
        if (is_prime[p]) {
            // Начинаем с p*p
            for (int multiple = p * p; multiple <= limit; multiple += p) {
                is_prime[multiple] = 0;
            }
        }
    }
    
    // Два прохода: сначала подсчет, потом выделение памяти
    int prime_count = 0;
    for (int i = 2; i <= limit; i++) {
        if (is_prime[i]) prime_count++;
    }
    
    int* primes = malloc(prime_count * sizeof(int));
    if (!primes) {
        free(is_prime);
        *count = 0;
        return NULL;
    }
    
    // Второй проход: сбор простых чисел
    int index = 0;
    // Оптимизация: обрабатываем 2 отдельно, потом только нечетные
    if (limit >= 2) {
        primes[index++] = 2;
    }
    
    for (int i = 3; i <= limit; i += 2) {
        if (is_prime[i]) {
            primes[index++] = i;
        }
    }
    
    free(is_prime);
    *count = prime_count;
    return primes;
}

// BFS с динамическим массивом вместо фиксированного
typedef struct {
    PrimesNode* node;
    int number;
} QueueItem;

static int* find_with_prefix(Trie* trie, int prefix, int* result_count) {
    // Быстрое преобразование префикса
    char prefix_str[12];
    char* end = prefix_str + sizeof(prefix_str) - 1;
    *end = '\0';
    
    int n = prefix;
    do {
        *--end = '0' + (n % 10);
        n /= 10;
    } while (n > 0);
    
    // Находим узел префикса
    PrimesNode* current = trie->root;
    const char* digit_ptr = end;
    
    int prefix_value = 0;
    while (*digit_ptr) {
        int digit = *digit_ptr - '0';
        prefix_value = prefix_value * 10 + digit;
        
        if (!current->children[digit]) {
            *result_count = 0;
            return NULL;
        }
        current = current->children[digit];
        digit_ptr++;
    }
    
    // Динамический BFS
    QueueItem* queue = malloc(65536 * sizeof(QueueItem));
    if (!queue) {
        *result_count = 0;
        return NULL;
    }
    
    int* results = malloc(65536 * sizeof(int));
    if (!results) {
        free(queue);
        *result_count = 0;
        return NULL;
    }
    
    int queue_front = 0, queue_back = 0;
    int found_count = 0;
    
    queue[queue_back++] = (QueueItem){current, prefix_value};
    
    while (queue_front < queue_back) {
        QueueItem current_item = queue[queue_front++];
        
        if (current_item.node->terminal) {
            results[found_count++] = current_item.number;
        }
        
        for (int digit = 0; digit < 10; digit++) {
            if (current_item.node->children[digit]) {
                if (queue_back >= 65536) {
                    // Увеличиваем очередь
                    size_t new_size = 65536 * 2;
                    QueueItem* new_queue = realloc(queue, new_size * sizeof(QueueItem));
                    if (!new_queue) goto cleanup;
                    queue = new_queue;
                }
                
                queue[queue_back++] = (QueueItem){
                    current_item.node->children[digit],
                    current_item.number * 10 + digit
                };
            }
        }
    }
    
    // Сортировка вставками (эффективна для небольших/частично отсортированных массивов)
    for (int i = 1; i < found_count; i++) {
        int key = results[i];
        int j = i - 1;
        
        while (j >= 0 && results[j] > key) {
            results[j + 1] = results[j];
            j--;
        }
        results[j + 1] = key;
    }
    
    // Освобождаем очередь
    free(queue);
    
    // Уменьшаем массив результатов до фактического размера
    if (found_count > 0) {
        int* resized = realloc(results, found_count * sizeof(int));
        if (resized) {
            results = resized;
        }
    }
    
    *result_count = found_count;
    return results;

cleanup:
    free(queue);
    free(results);
    *result_count = 0;
    return NULL;
}

int64_t Primes_run(void* self) {
    Primes* bench = (Primes*)self;
    const int PREFIX = 32338;
    
    int prime_count;
    int* primes = generate_primes(bench->n, &prime_count);
    if (!primes || prime_count == 0) {
        bench->result_val = 5432;
        return bench->result_val;
    }
    
    Trie* trie = trie_create();
    if (!trie) {
        free(primes);
        bench->result_val = 5432;
        return bench->result_val;
    }
    
    for (int i = 0; i < prime_count; i++) {
        if (!trie_insert(trie, primes[i])) {
            trie_free(trie);
            free(primes);
            bench->result_val = 5432;
            return bench->result_val;
        }
    }
    
    int result_count;
    int* results = find_with_prefix(trie, PREFIX, &result_count);
    
    bench->result_val = 5432;
    bench->result_val += (uint32_t)result_count;
    
    if (results) {
        for (int i = 0; i < result_count; i++) {
            bench->result_val += (uint32_t)results[i];
        }
        free(results);
    }
    
    trie_free(trie);
    free(primes);
    
    return bench->result_val;
}

void Primes_prepare(void* self) {
    Primes* bench = (Primes*)self;
    const char* input = Helper_get_input("Primes");
    bench->n = input ? atoi(input) : 5000000;
    bench->result_val = 0;
}

void Primes_cleanup(void* self) {
    free(self);
}

Benchmark* Primes_new(void) {
    Primes* instance = calloc(1, sizeof(Primes));
    if (!instance) return NULL;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    if (!bench) {
        free(instance);
        return NULL;
    }
    
    bench->name = "Primes";
    bench->run = Primes_run;
    bench->prepare = Primes_prepare;
    bench->cleanup = Primes_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Вспомогательные функции для JSON бенчмарков
// ============================================================================

static double custom_round(double value, int decimals) {
    double factor = pow(10.0, decimals);
    return round(value * factor) / factor;
}

// ============================================================================
// Класс JsonGenerate
// ============================================================================

// 1. Структура для координаты
typedef struct JsonGenerate_Coordinate {
    double x, y, z;
    char* name;
} JsonGenerate_Coordinate;

// 2. Forward declaration для JsonGenerate
typedef struct JsonGenerate JsonGenerate;

// 3. Объявления вспомогательных функций
static void JsonGenerate_grow_result(JsonGenerate* self, size_t needed);
static void JsonGenerate_append(JsonGenerate* self, const char* str);
static void JsonGenerate_append_double(JsonGenerate* self, double value);

// 4. Полное определение структуры JsonGenerate
struct JsonGenerate {
    int n;
    JsonGenerate_Coordinate* data;
    char* result_str;
    size_t result_capacity;
    size_t result_length;
};

// 5. Реализация вспомогательных функций
static void JsonGenerate_grow_result(JsonGenerate* self, size_t needed) {
    size_t new_capacity = self->result_capacity;
    while (self->result_length + needed >= new_capacity) {
        new_capacity = new_capacity ? new_capacity * 2 : 1024;
    }
    if (new_capacity > self->result_capacity) {
        self->result_str = realloc(self->result_str, new_capacity);
        self->result_capacity = new_capacity;
    }
}

static void JsonGenerate_append(JsonGenerate* self, const char* str) {
    size_t len = strlen(str);
    JsonGenerate_grow_result(self, len + 1);
    memcpy(self->result_str + self->result_length, str, len);
    self->result_length += len;
    self->result_str[self->result_length] = '\0';
}

static void JsonGenerate_append_double(JsonGenerate* self, double value) {
    char buffer[32];
    snprintf(buffer, sizeof(buffer), "%.8f", value);
    JsonGenerate_append(self, buffer);
}

// 6. Основные функции JsonGenerate
int64_t JsonGenerate_run(void* self) {
    JsonGenerate* bench = (JsonGenerate*)self;
    
    // Очищаем результат
    bench->result_length = 0;
    if (bench->result_str) bench->result_str[0] = '\0';
    
    // Начинаем JSON
    JsonGenerate_append(bench, "{\"coordinates\":[");
    
    // Добавляем координаты
    for (int i = 0; i < bench->n; i++) {
        if (i > 0) JsonGenerate_append(bench, ",");
        
        JsonGenerate_Coordinate* coord = &bench->data[i];
        
        JsonGenerate_append(bench, "{");
        JsonGenerate_append(bench, "\"x\":");
        JsonGenerate_append_double(bench, coord->x);
        JsonGenerate_append(bench, ",\"y\":");
        JsonGenerate_append_double(bench, coord->y);
        JsonGenerate_append(bench, ",\"z\":");
        JsonGenerate_append_double(bench, coord->z);
        JsonGenerate_append(bench, ",\"name\":\"");
        JsonGenerate_append(bench, coord->name);
        JsonGenerate_append(bench, "\",\"opts\":{\"1\":[1,true]}");
        JsonGenerate_append(bench, "}");
    }
    
    JsonGenerate_append(bench, "],\"info\":\"some info\"}");
    
    // В Crystal версии результат всегда 1 (true)
    return 1;
}

void JsonGenerate_prepare(void* self) {
    JsonGenerate* bench = (JsonGenerate*)self;
    const char* input = Helper_get_input("JsonGenerate");
    bench->n = input ? atoi(input) : 1000;
    
    // Выделяем память для данных
    bench->data = malloc(bench->n * sizeof(JsonGenerate_Coordinate));
    
    // Генерируем случайные данные
    for (int i = 0; i < bench->n; i++) {
        JsonGenerate_Coordinate* coord = &bench->data[i];
        
        coord->x = custom_round(Helper_next_float(1.0), 8);
        coord->y = custom_round(Helper_next_float(1.0), 8);
        coord->z = custom_round(Helper_next_float(1.0), 8);
        
        // Генерируем имя
        char name[64];
        snprintf(name, sizeof(name), "%.7f %d", 
                Helper_next_float(1.0), Helper_next_int(10000));
        coord->name = strdup(name);
    }
    
    bench->result_str = NULL;
    bench->result_capacity = 0;
    bench->result_length = 0;
}

void JsonGenerate_cleanup(void* self) {
    JsonGenerate* bench = (JsonGenerate*)self;
    
    // Освобождаем данные
    for (int i = 0; i < bench->n; i++) {
        free(bench->data[i].name);
    }
    free(bench->data);
    
    // Освобождаем результат
    free(bench->result_str);
    free(bench);
}

Benchmark* JsonGenerate_new(void) {
    JsonGenerate* instance = malloc(sizeof(JsonGenerate));
    instance->n = 0;
    instance->data = NULL;
    instance->result_str = NULL;
    instance->result_capacity = 0;
    instance->result_length = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "JsonGenerate";
    bench->run = JsonGenerate_run;
    bench->prepare = JsonGenerate_prepare;
    bench->cleanup = JsonGenerate_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс JsonParseDom
// ============================================================================

typedef struct {
    char* json_text;
    uint32_t result_val;
} JsonParseDom;

int64_t JsonParseDom_run(void* self) {
    JsonParseDom* bench = (JsonParseDom*)self;
    
    cJSON* root = cJSON_Parse(bench->json_text);
    if (!root) {
        bench->result_val = 0;
        return 0;
    }
    
    cJSON* coordinates = cJSON_GetObjectItem(root, "coordinates");
    if (!coordinates || !cJSON_IsArray(coordinates)) {
        cJSON_Delete(root);
        bench->result_val = 0;
        return 0;
    }
    
    double x_sum = 0.0, y_sum = 0.0, z_sum = 0.0;
    int len = 0;
    
    cJSON* coord_item = NULL;
    cJSON_ArrayForEach(coord_item, coordinates) {
        cJSON* x_item = cJSON_GetObjectItem(coord_item, "x");
        cJSON* y_item = cJSON_GetObjectItem(coord_item, "y");
        cJSON* z_item = cJSON_GetObjectItem(coord_item, "z");
        
        if (x_item && y_item && z_item && 
            cJSON_IsNumber(x_item) && 
            cJSON_IsNumber(y_item) && 
            cJSON_IsNumber(z_item)) {
            
            x_sum += x_item->valuedouble;
            y_sum += y_item->valuedouble;
            z_sum += z_item->valuedouble;
            len++;
        }
    }
    
    cJSON_Delete(root);
    
    if (len > 0) {
        double x_avg = x_sum / len;
        double y_avg = y_sum / len;
        double z_avg = z_sum / len;
        
        bench->result_val = Helper_checksum_f64(x_avg) + 
                           Helper_checksum_f64(y_avg) + 
                           Helper_checksum_f64(z_avg);
    } else {
        bench->result_val = 0;
    }
    
    return bench->result_val;
}

void JsonParseDom_prepare(void* self) {
    JsonParseDom* bench = (JsonParseDom*)self;
    
    // Создаем JsonGenerate для получения JSON
    JsonGenerate gen_instance;
    memset(&gen_instance, 0, sizeof(JsonGenerate));
    JsonGenerate* gen = &gen_instance;
    
    const char* input = Helper_get_input("JsonParseDom");
    gen->n = input ? atoi(input) : 1000;
    
    // Инициализируем генератор
    gen->data = malloc(gen->n * sizeof(JsonGenerate_Coordinate));
    for (int i = 0; i < gen->n; i++) {
        JsonGenerate_Coordinate* coord = &gen->data[i];
        coord->x = custom_round(Helper_next_float(1.0), 8);
        coord->y = custom_round(Helper_next_float(1.0), 8);
        coord->z = custom_round(Helper_next_float(1.0), 8);
        
        char name[64];
        snprintf(name, sizeof(name), "%.7f %d", 
                Helper_next_float(1.0), Helper_next_int(10000));
        coord->name = strdup(name);
    }
    
    gen->result_str = NULL;
    gen->result_capacity = 0;
    gen->result_length = 0;
    
    // Генерируем JSON
    JsonGenerate_run(gen);
    
    // Сохраняем JSON текст
    bench->json_text = strdup(gen->result_str);
    bench->result_val = 0;
    
    // Освобождаем память генератора
    for (int i = 0; i < gen->n; i++) {
        free(gen->data[i].name);
    }
    free(gen->data);
    free(gen->result_str);
}

void JsonParseDom_cleanup(void* self) {
    JsonParseDom* bench = (JsonParseDom*)self;
    free(bench->json_text);
    free(bench);
}

Benchmark* JsonParseDom_new(void) {
    JsonParseDom* instance = malloc(sizeof(JsonParseDom));
    instance->json_text = NULL;
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "JsonParseDom";
    bench->run = JsonParseDom_run;
    bench->prepare = JsonParseDom_prepare;
    bench->cleanup = JsonParseDom_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс JsonParseMapping
// ============================================================================

typedef struct {
    char* json_text;
    uint32_t result_val;
} JsonParseMapping;

int64_t JsonParseMapping_run(void* self) {
    JsonParseMapping* bench = (JsonParseMapping*)self;
    
    // Используем ту же реализацию, что и JsonParseDom
    cJSON* root = cJSON_Parse(bench->json_text);
    if (!root) {
        bench->result_val = 0;
        return 0;
    }
    
    cJSON* coordinates = cJSON_GetObjectItem(root, "coordinates");
    if (!coordinates || !cJSON_IsArray(coordinates)) {
        cJSON_Delete(root);
        bench->result_val = 0;
        return 0;
    }
    
    double x_sum = 0.0, y_sum = 0.0, z_sum = 0.0;
    int len = 0;
    
    cJSON* coord_item = NULL;
    cJSON_ArrayForEach(coord_item, coordinates) {
        cJSON* x_item = cJSON_GetObjectItem(coord_item, "x");
        cJSON* y_item = cJSON_GetObjectItem(coord_item, "y");
        cJSON* z_item = cJSON_GetObjectItem(coord_item, "z");
        
        if (x_item && y_item && z_item && 
            cJSON_IsNumber(x_item) && 
            cJSON_IsNumber(y_item) && 
            cJSON_IsNumber(z_item)) {
            
            x_sum += x_item->valuedouble;
            y_sum += y_item->valuedouble;
            z_sum += z_item->valuedouble;
            len++;
        }
    }
    
    cJSON_Delete(root);
    
    if (len > 0) {
        double x_avg = x_sum / len;
        double y_avg = y_sum / len;
        double z_avg = z_sum / len;
        
        bench->result_val = Helper_checksum_f64(x_avg) + 
                           Helper_checksum_f64(y_avg) + 
                           Helper_checksum_f64(z_avg);
    } else {
        bench->result_val = 0;
    }
    
    return bench->result_val;
}

void JsonParseMapping_prepare(void* self) {
    JsonParseMapping* bench = (JsonParseMapping*)self;
    
    // Создаем JsonGenerate для получения JSON
    JsonGenerate gen_instance;
    memset(&gen_instance, 0, sizeof(JsonGenerate));
    JsonGenerate* gen = &gen_instance;
    
    const char* input = Helper_get_input("JsonParseMapping");
    gen->n = input ? atoi(input) : 1000;
    
    // Инициализируем генератор
    gen->data = malloc(gen->n * sizeof(JsonGenerate_Coordinate));
    for (int i = 0; i < gen->n; i++) {
        JsonGenerate_Coordinate* coord = &gen->data[i];
        coord->x = custom_round(Helper_next_float(1.0), 8);
        coord->y = custom_round(Helper_next_float(1.0), 8);
        coord->z = custom_round(Helper_next_float(1.0), 8);
        
        char name[64];
        snprintf(name, sizeof(name), "%.7f %d", 
                Helper_next_float(1.0), Helper_next_int(10000));
        coord->name = strdup(name);
    }
    
    gen->result_str = NULL;
    gen->result_capacity = 0;
    gen->result_length = 0;
    
    // Генерируем JSON
    JsonGenerate_run(gen);
    
    // Сохраняем JSON текст
    bench->json_text = strdup(gen->result_str);
    bench->result_val = 0;
    
    // Освобождаем память генератора
    for (int i = 0; i < gen->n; i++) {
        free(gen->data[i].name);
    }
    free(gen->data);
    free(gen->result_str);
}

void JsonParseMapping_cleanup(void* self) {
    JsonParseMapping* bench = (JsonParseMapping*)self;
    free(bench->json_text);
    free(bench);
}

Benchmark* JsonParseMapping_new(void) {
    JsonParseMapping* instance = malloc(sizeof(JsonParseMapping));
    instance->json_text = NULL;
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "JsonParseMapping";
    bench->run = JsonParseMapping_run;
    bench->prepare = JsonParseMapping_prepare;
    bench->cleanup = JsonParseMapping_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс Noise (шум Перлина)
// ============================================================================

#define NOISE_SIZE 64
// #define M_PI 3.14159265358979323846

typedef struct {
    double x, y;
} Noise_Vec2;

typedef struct {
    Noise_Vec2 rgradients[NOISE_SIZE];
    int permutations[NOISE_SIZE];
} Noise2DContext;

static Noise_Vec2 Noise_random_gradient(void) {
    double v = Helper_next_float(1.0) * M_PI * 2.0;
    Noise_Vec2 result = {cos(v), sin(v)};
    return result;
}

static double Noise_lerp(double a, double b, double v) {
    return a * (1.0 - v) + b * v;
}

static double Noise_smooth(double v) {
    return v * v * (3.0 - 2.0 * v);
}

static double Noise_gradient(Noise_Vec2 orig, Noise_Vec2 grad, Noise_Vec2 p) {
    Noise_Vec2 sp = {p.x - orig.x, p.y - orig.y};
    return grad.x * sp.x + grad.y * sp.y;
}

static void Noise2DContext_init(Noise2DContext* ctx) {
    for (int i = 0; i < NOISE_SIZE; i++) {
        ctx->rgradients[i] = Noise_random_gradient();
        ctx->permutations[i] = i;
    }
    
    for (int i = 0; i < NOISE_SIZE; i++) {
        int a = Helper_next_int(NOISE_SIZE);
        int b = Helper_next_int(NOISE_SIZE);
        int temp = ctx->permutations[a];
        ctx->permutations[a] = ctx->permutations[b];
        ctx->permutations[b] = temp;
    }
}

static Noise_Vec2 Noise2DContext_get_gradient(Noise2DContext* ctx, int x, int y) {
    int idx = ctx->permutations[x & (NOISE_SIZE - 1)] + ctx->permutations[y & (NOISE_SIZE - 1)];
    return ctx->rgradients[idx & (NOISE_SIZE - 1)];
}

static double Noise2DContext_get(Noise2DContext* ctx, double x, double y) {
    double x0f = floor(x);
    double y0f = floor(y);
    int x0 = (int)x0f;
    int y0 = (int)y0f;
    int x1 = x0 + 1;
    int y1 = y0 + 1;
    
    Noise_Vec2 origins[4] = {
        {x0f + 0.0, y0f + 0.0},
        {x0f + 1.0, y0f + 0.0},
        {x0f + 0.0, y0f + 1.0},
        {x0f + 1.0, y0f + 1.0}
    };
    
    Noise_Vec2 gradients[4] = {
        Noise2DContext_get_gradient(ctx, x0, y0),
        Noise2DContext_get_gradient(ctx, x1, y0),
        Noise2DContext_get_gradient(ctx, x0, y1),
        Noise2DContext_get_gradient(ctx, x1, y1)
    };
    
    Noise_Vec2 p = {x, y};
    double v0 = Noise_gradient(origins[0], gradients[0], p);
    double v1 = Noise_gradient(origins[1], gradients[1], p);
    double v2 = Noise_gradient(origins[2], gradients[2], p);
    double v3 = Noise_gradient(origins[3], gradients[3], p);
    
    double fx = Noise_smooth(x - origins[0].x);
    double vx0 = Noise_lerp(v0, v1, fx);
    double vx1 = Noise_lerp(v2, v3, fx);
    
    double fy = Noise_smooth(y - origins[0].y);
    return Noise_lerp(vx0, vx1, fy);
}

typedef struct {
    int n_iter;
    uint64_t res_val;
} Noise;

static uint64_t Noise_noise_func(void) {
    double pixels[NOISE_SIZE][NOISE_SIZE];
    Noise2DContext ctx;
    Noise2DContext_init(&ctx);
    
    static const uint32_t SYM[6] = {' ', 0x2591, 0x2592, 0x2593, 0x2588, 0x2588};
    
    for (int i = 0; i < 100; i++) {
        for (int y = 0; y < NOISE_SIZE; y++) {
            for (int x = 0; x < NOISE_SIZE; x++) {
                double v = Noise2DContext_get(&ctx, x * 0.1, (y + (i * 128)) * 0.1) * 0.5 + 0.5;
                pixels[y][x] = v;
            }
        }
    }
    
    uint64_t res = 0;
    for (int y = 0; y < NOISE_SIZE; y++) {
        for (int x = 0; x < NOISE_SIZE; x++) {
            double v = pixels[y][x];
            int idx = (int)(v / 0.2);
            if (idx >= 6) idx = 5;
            res += (uint64_t)SYM[idx];
        }
    }
    return res;
}

int64_t Noise_run(void* self) {
    Noise* bench = (Noise*)self;
    bench->res_val = 0;
    
    for (int i = 0; i < bench->n_iter; i++) {
        uint64_t v = Noise_noise_func();
        bench->res_val += v;
    }
    
    return (int64_t)bench->res_val;
}

void Noise_prepare(void* self) {
    Noise* bench = (Noise*)self;
    const char* input = Helper_get_input("Noise");
    bench->n_iter = input ? atoi(input) : 100;
    bench->res_val = 0;
}

void Noise_cleanup(void* self) {
    free(self);
}

Benchmark* Noise_new(void) {
    Noise* instance = malloc(sizeof(Noise));
    instance->n_iter = 0;
    instance->res_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "Noise";
    bench->run = Noise_run;
    bench->prepare = Noise_prepare;
    bench->cleanup = Noise_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс TextRaytracer
// ============================================================================

typedef struct {
    double x, y, z;
} TextRaytracer_Vector;

typedef struct {
    TextRaytracer_Vector orig, dir;
} TextRaytracer_Ray;

typedef struct {
    double r, g, b;
} TextRaytracer_Color;

typedef struct {
    TextRaytracer_Vector center;
    double radius;
    TextRaytracer_Color color;
} TextRaytracer_Sphere;

typedef struct {
    TextRaytracer_Vector position;
    TextRaytracer_Color color;
} TextRaytracer_Light;

static TextRaytracer_Vector TextRaytracer_Vector_scale(TextRaytracer_Vector v, double s) {
    return (TextRaytracer_Vector){v.x * s, v.y * s, v.z * s};
}

static TextRaytracer_Vector TextRaytracer_Vector_add(TextRaytracer_Vector a, TextRaytracer_Vector b) {
    return (TextRaytracer_Vector){a.x + b.x, a.y + b.y, a.z + b.z};
}

static TextRaytracer_Vector TextRaytracer_Vector_sub(TextRaytracer_Vector a, TextRaytracer_Vector b) {
    return (TextRaytracer_Vector){a.x - b.x, a.y - b.y, a.z - b.z};
}

static double TextRaytracer_Vector_dot(TextRaytracer_Vector a, TextRaytracer_Vector b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

static double TextRaytracer_Vector_magnitude(TextRaytracer_Vector v) {
    return sqrt(TextRaytracer_Vector_dot(v, v));
}

static TextRaytracer_Vector TextRaytracer_Vector_normalize(TextRaytracer_Vector v) {
    double mag = TextRaytracer_Vector_magnitude(v);
    if (mag == 0.0) return (TextRaytracer_Vector){0, 0, 0};
    return TextRaytracer_Vector_scale(v, 1.0 / mag);
}

static TextRaytracer_Color TextRaytracer_Color_scale(TextRaytracer_Color c, double s) {
    return (TextRaytracer_Color){c.r * s, c.g * s, c.b * s};
}

static TextRaytracer_Color TextRaytracer_Color_add(TextRaytracer_Color a, TextRaytracer_Color b) {
    return (TextRaytracer_Color){a.r + b.r, a.g + b.g, a.b + b.b};
}

static TextRaytracer_Vector TextRaytracer_Sphere_get_normal(TextRaytracer_Sphere* sphere, TextRaytracer_Vector pt) {
    return TextRaytracer_Vector_normalize(TextRaytracer_Vector_sub(pt, sphere->center));
}

static double TextRaytracer_clamp(double x, double a, double b) {
    if (x < a) return a;
    if (x > b) return b;
    return x;
}

static double TextRaytracer_intersect_sphere(TextRaytracer_Ray ray, TextRaytracer_Vector center, double radius) {
    TextRaytracer_Vector l = TextRaytracer_Vector_sub(center, ray.orig);
    double tca = TextRaytracer_Vector_dot(l, ray.dir);
    if (tca < 0.0) return -1.0;
    
    double d2 = TextRaytracer_Vector_dot(l, l) - tca * tca;
    double r2 = radius * radius;
    if (d2 > r2) return -1.0;
    
    double thc = sqrt(r2 - d2);
    double t0 = tca - thc;
    if (t0 > 10000.0) return -1.0;
    
    return t0;
}

static TextRaytracer_Color TextRaytracer_diffuse_shading(TextRaytracer_Vector pi, TextRaytracer_Sphere* obj, TextRaytracer_Light light) {
    TextRaytracer_Vector n = TextRaytracer_Sphere_get_normal(obj, pi);
    TextRaytracer_Vector light_dir = TextRaytracer_Vector_normalize(TextRaytracer_Vector_sub(light.position, pi));
    double lam1 = TextRaytracer_Vector_dot(light_dir, n);
    double lam2 = TextRaytracer_clamp(lam1, 0.0, 1.0);
    
    TextRaytracer_Color light_color = TextRaytracer_Color_scale(light.color, lam2 * 0.5);
    TextRaytracer_Color obj_color = TextRaytracer_Color_scale(obj->color, 0.3);
    return TextRaytracer_Color_add(light_color, obj_color);
}

static const char LUT[6] = {'.', '-', '+', '*', 'X', 'M'};

typedef struct {
    int w, h;
    uint64_t res;
} TextRaytracer;

int64_t TextRaytracer_run(void* self) {
    TextRaytracer* bench = (TextRaytracer*)self;
    bench->res = 0;
    
    // Определяем цвета как локальные константы
    TextRaytracer_Color red = {1.0, 0.0, 0.0};
    TextRaytracer_Color green = {0.0, 1.0, 0.0};
    TextRaytracer_Color blue = {0.0, 0.0, 1.0};
    TextRaytracer_Color white = {1.0, 1.0, 1.0};
    
    TextRaytracer_Sphere scene[3] = {
        {{-1.0, 0.0, 3.0}, 0.3, red},
        {{0.0, 0.0, 3.0}, 0.8, green},
        {{1.0, 0.0, 3.0}, 0.4, blue}
    };
    
    TextRaytracer_Light light1 = {{0.7, -1.0, 1.7}, white};
    static const char LUT[6] = {'.', '-', '+', '*', 'X', 'M'};
    
    for (int j = 0; j < bench->h; j++) {
        for (int i = 0; i < bench->w; i++) {
            double fw = bench->w;
            double fh = bench->h;
            double fi = i;
            double fj = j;
            
            TextRaytracer_Ray ray;
            ray.orig = (TextRaytracer_Vector){0.0, 0.0, 0.0};
            
            TextRaytracer_Vector dir = {
                (fi - fw/2.0)/fw,
                (fj - fh/2.0)/fh,
                1.0
            };
            ray.dir = TextRaytracer_Vector_normalize(dir);
            
            double tval = -1.0;
            TextRaytracer_Sphere* hit_obj = NULL;
            
            for (int k = 0; k < 3; k++) {
                double intersect = TextRaytracer_intersect_sphere(ray, scene[k].center, scene[k].radius);
                if (intersect >= 0.0) {
                    tval = intersect;
                    hit_obj = &scene[k];
                    break;
                }
            }
            
            char pixel = ' ';
            if (hit_obj && tval >= 0.0) {
                TextRaytracer_Vector pi = TextRaytracer_Vector_add(ray.orig, TextRaytracer_Vector_scale(ray.dir, tval));
                TextRaytracer_Color color = TextRaytracer_diffuse_shading(pi, hit_obj, light1);
                double col = (color.r + color.g + color.b) / 3.0;
                int idx = (int)(col * 6.0);
                if (idx < 0) idx = 0;
                if (idx >= 6) idx = 5;
                pixel = LUT[idx];
            }
            
            bench->res += (uint8_t)pixel;
        }
    }
    
    return (int64_t)bench->res;
}

void TextRaytracer_prepare(void* self) {
    TextRaytracer* bench = (TextRaytracer*)self;
    const char* input = Helper_get_input("TextRaytracer");
    int size = input ? atoi(input) : 10;
    bench->w = size;
    bench->h = size;
    bench->res = 0;
}

void TextRaytracer_cleanup(void* self) {
    free(self);
}

Benchmark* TextRaytracer_new(void) {
    TextRaytracer* instance = malloc(sizeof(TextRaytracer));
    instance->w = 0;
    instance->h = 0;
    instance->res = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "TextRaytracer";
    bench->run = TextRaytracer_run;
    bench->prepare = TextRaytracer_prepare;
    bench->cleanup = TextRaytracer_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс NeuralNet (нейронная сеть)
// ============================================================================

typedef struct NeuralNet_Neuron NeuralNet_Neuron;
typedef struct NeuralNet_Synapse NeuralNet_Synapse;
typedef struct NeuralNet_Network NeuralNet_Network;

#define NEURAL_NET_LEARNING_RATE 1.0
#define NEURAL_NET_MOMENTUM 0.3

struct NeuralNet_Synapse {
    double weight;
    double prev_weight;
    NeuralNet_Neuron* source_neuron;
    NeuralNet_Neuron* dest_neuron;
};

struct NeuralNet_Neuron {
    NeuralNet_Synapse** synapses_in;
    int synapses_in_count;
    int synapses_in_capacity;
    
    NeuralNet_Synapse** synapses_out;
    int synapses_out_count;
    int synapses_out_capacity;
    
    double threshold;
    double prev_threshold;
    double error;
    double output;
};

static void NeuralNet_Neuron_init(NeuralNet_Neuron* neuron) {
    neuron->threshold = neuron->prev_threshold = Helper_next_float(1.0) * 2 - 1;
    neuron->output = 0.0;
    neuron->error = 0.0;
    neuron->synapses_in_count = 0;
    neuron->synapses_in_capacity = 4;
    neuron->synapses_in = malloc(neuron->synapses_in_capacity * sizeof(NeuralNet_Synapse*));
    
    neuron->synapses_out_count = 0;
    neuron->synapses_out_capacity = 4;
    neuron->synapses_out = malloc(neuron->synapses_out_capacity * sizeof(NeuralNet_Synapse*));
}

static void NeuralNet_Neuron_add_synapse_in(NeuralNet_Neuron* neuron, NeuralNet_Synapse* synapse) {
    if (neuron->synapses_in_count >= neuron->synapses_in_capacity) {
        neuron->synapses_in_capacity *= 2;
        neuron->synapses_in = realloc(neuron->synapses_in, neuron->synapses_in_capacity * sizeof(NeuralNet_Synapse*));
    }
    neuron->synapses_in[neuron->synapses_in_count++] = synapse;
}

static void NeuralNet_Neuron_add_synapse_out(NeuralNet_Neuron* neuron, NeuralNet_Synapse* synapse) {
    if (neuron->synapses_out_count >= neuron->synapses_out_capacity) {
        neuron->synapses_out_capacity *= 2;
        neuron->synapses_out = realloc(neuron->synapses_out, neuron->synapses_out_capacity * sizeof(NeuralNet_Synapse*));
    }
    neuron->synapses_out[neuron->synapses_out_count++] = synapse;
}

static void NeuralNet_Neuron_calculate_output(NeuralNet_Neuron* neuron) {
    double activation = 0.0;
    for (int i = 0; i < neuron->synapses_in_count; i++) {
        NeuralNet_Synapse* synapse = neuron->synapses_in[i];
        activation += synapse->weight * synapse->source_neuron->output;
    }
    activation -= neuron->threshold;
    neuron->output = 1.0 / (1.0 + exp(-activation));
}

static double NeuralNet_Neuron_derivative(NeuralNet_Neuron* neuron) {
    return neuron->output * (1 - neuron->output);
}

static void NeuralNet_Neuron_output_train(NeuralNet_Neuron* neuron, double rate, double target) {
    neuron->error = (target - neuron->output) * NeuralNet_Neuron_derivative(neuron);
    
    for (int i = 0; i < neuron->synapses_in_count; i++) {
        NeuralNet_Synapse* synapse = neuron->synapses_in[i];
        double temp_weight = synapse->weight;
        synapse->weight += (rate * NEURAL_NET_LEARNING_RATE * neuron->error * synapse->source_neuron->output) +
                         (NEURAL_NET_MOMENTUM * (synapse->weight - synapse->prev_weight));
        synapse->prev_weight = temp_weight;
    }
    
    double temp_threshold = neuron->threshold;
    neuron->threshold += (rate * NEURAL_NET_LEARNING_RATE * neuron->error * -1) +
                       (NEURAL_NET_MOMENTUM * (neuron->threshold - neuron->prev_threshold));
    neuron->prev_threshold = temp_threshold;
}

static void NeuralNet_Neuron_hidden_train(NeuralNet_Neuron* neuron, double rate) {
    double sum = 0.0;
    for (int i = 0; i < neuron->synapses_out_count; i++) {
        NeuralNet_Synapse* synapse = neuron->synapses_out[i];
        sum += synapse->prev_weight * synapse->dest_neuron->error;
    }
    neuron->error = sum * NeuralNet_Neuron_derivative(neuron);
    
    for (int i = 0; i < neuron->synapses_in_count; i++) {
        NeuralNet_Synapse* synapse = neuron->synapses_in[i];
        double temp_weight = synapse->weight;
        synapse->weight += (rate * NEURAL_NET_LEARNING_RATE * neuron->error * synapse->source_neuron->output) +
                         (NEURAL_NET_MOMENTUM * (synapse->weight - synapse->prev_weight));
        synapse->prev_weight = temp_weight;
    }
    
    double temp_threshold = neuron->threshold;
    neuron->threshold += (rate * NEURAL_NET_LEARNING_RATE * neuron->error * -1) +
                       (NEURAL_NET_MOMENTUM * (neuron->threshold - neuron->prev_threshold));
    neuron->prev_threshold = temp_threshold;
}

struct NeuralNet_Network {
    NeuralNet_Neuron* input_layer;
    int input_count;
    NeuralNet_Neuron* hidden_layer;
    int hidden_count;
    NeuralNet_Neuron* output_layer;
    int output_count;
    NeuralNet_Synapse* synapses;
    int synapse_count;
    int synapse_capacity;
};

static NeuralNet_Network* NeuralNet_Network_new(int inputs, int hidden, int outputs) {
    NeuralNet_Network* net = malloc(sizeof(NeuralNet_Network));
    net->input_count = inputs;
    net->hidden_count = hidden;
    net->output_count = outputs;
    
    net->input_layer = malloc(inputs * sizeof(NeuralNet_Neuron));
    net->hidden_layer = malloc(hidden * sizeof(NeuralNet_Neuron));
    net->output_layer = malloc(outputs * sizeof(NeuralNet_Neuron));
    
    for (int i = 0; i < inputs; i++) {
        NeuralNet_Neuron_init(&net->input_layer[i]);
    }
    for (int i = 0; i < hidden; i++) {
        NeuralNet_Neuron_init(&net->hidden_layer[i]);
    }
    for (int i = 0; i < outputs; i++) {
        NeuralNet_Neuron_init(&net->output_layer[i]);
    }
    
    net->synapse_count = 0;
    net->synapse_capacity = (inputs * hidden) + (hidden * outputs);
    net->synapses = malloc(net->synapse_capacity * sizeof(NeuralNet_Synapse));
    
    // Input -> Hidden connections
    for (int i = 0; i < inputs; i++) {
        for (int j = 0; j < hidden; j++) {
            NeuralNet_Synapse* synapse = &net->synapses[net->synapse_count++];
            synapse->source_neuron = &net->input_layer[i];
            synapse->dest_neuron = &net->hidden_layer[j];
            synapse->weight = synapse->prev_weight = Helper_next_float(1.0) * 2 - 1;
            
            NeuralNet_Neuron_add_synapse_out(&net->input_layer[i], synapse);
            NeuralNet_Neuron_add_synapse_in(&net->hidden_layer[j], synapse);
        }
    }
    
    // Hidden -> Output connections
    for (int i = 0; i < hidden; i++) {
        for (int j = 0; j < outputs; j++) {
            NeuralNet_Synapse* synapse = &net->synapses[net->synapse_count++];
            synapse->source_neuron = &net->hidden_layer[i];
            synapse->dest_neuron = &net->output_layer[j];
            synapse->weight = synapse->prev_weight = Helper_next_float(1.0) * 2 - 1;
            
            NeuralNet_Neuron_add_synapse_out(&net->hidden_layer[i], synapse);
            NeuralNet_Neuron_add_synapse_in(&net->output_layer[j], synapse);
        }
    }
    
    return net;
}

static void NeuralNet_Network_free(NeuralNet_Network* net) {
    for (int i = 0; i < net->input_count; i++) {
        free(net->input_layer[i].synapses_in);
        free(net->input_layer[i].synapses_out);
    }
    for (int i = 0; i < net->hidden_count; i++) {
        free(net->hidden_layer[i].synapses_in);
        free(net->hidden_layer[i].synapses_out);
    }
    for (int i = 0; i < net->output_count; i++) {
        free(net->output_layer[i].synapses_in);
        free(net->output_layer[i].synapses_out);
    }
    
    free(net->input_layer);
    free(net->hidden_layer);
    free(net->output_layer);
    free(net->synapses);
    free(net);
}

static void NeuralNet_Network_feed_forward(NeuralNet_Network* net, double* inputs) {
    for (int i = 0; i < net->input_count; i++) {
        net->input_layer[i].output = inputs[i];
    }
    
    for (int i = 0; i < net->hidden_count; i++) {
        NeuralNet_Neuron_calculate_output(&net->hidden_layer[i]);
    }
    
    for (int i = 0; i < net->output_count; i++) {
        NeuralNet_Neuron_calculate_output(&net->output_layer[i]);
    }
}

static void NeuralNet_Network_train(NeuralNet_Network* net, double* inputs, double* targets) {
    NeuralNet_Network_feed_forward(net, inputs);
    
    for (int i = 0; i < net->output_count; i++) {
        NeuralNet_Neuron_output_train(&net->output_layer[i], 0.3, targets[i]);
    }
    
    for (int i = 0; i < net->hidden_count; i++) {
        NeuralNet_Neuron_hidden_train(&net->hidden_layer[i], 0.3);
    }
}

typedef struct {
    int n;
    double sum_result;
} NeuralNet;

int64_t NeuralNet_run(void* self) {
    NeuralNet* bench = (NeuralNet*)self;
    bench->sum_result = 0.0;
    
    NeuralNet_Network* xor_net = NeuralNet_Network_new(2, 10, 1);
    
    double inputs_00[2] = {0, 0};
    double targets_0[1] = {0};
    
    double inputs_10[2] = {1, 0};
    double inputs_01[2] = {0, 1};
    double targets_1[1] = {1};
    
    double inputs_11[2] = {1, 1};
    
    for (int i = 0; i < bench->n; i++) {
        NeuralNet_Network_train(xor_net, inputs_00, targets_0);
        NeuralNet_Network_train(xor_net, inputs_10, targets_1);
        NeuralNet_Network_train(xor_net, inputs_01, targets_1);
        NeuralNet_Network_train(xor_net, inputs_11, targets_0);
    }
    
    NeuralNet_Network_feed_forward(xor_net, inputs_00);
    bench->sum_result += xor_net->output_layer[0].output;
    
    NeuralNet_Network_feed_forward(xor_net, inputs_01);
    bench->sum_result += xor_net->output_layer[0].output;
    
    NeuralNet_Network_feed_forward(xor_net, inputs_10);
    bench->sum_result += xor_net->output_layer[0].output;
    
    NeuralNet_Network_feed_forward(xor_net, inputs_11);
    bench->sum_result += xor_net->output_layer[0].output;
    
    NeuralNet_Network_free(xor_net);
    
    return Helper_checksum_f64(bench->sum_result);
}

void NeuralNet_prepare(void* self) {
    NeuralNet* bench = (NeuralNet*)self;
    const char* input = Helper_get_input("NeuralNet");
    bench->n = input ? atoi(input) : 100;
    bench->sum_result = 0.0;
}

void NeuralNet_cleanup(void* self) {
    free(self);
}

Benchmark* NeuralNet_new(void) {
    NeuralNet* instance = malloc(sizeof(NeuralNet));
    instance->n = 0;
    instance->sum_result = 0.0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "NeuralNet";
    bench->run = NeuralNet_run;
    bench->prepare = NeuralNet_prepare;
    bench->cleanup = NeuralNet_cleanup;
    bench->instance = instance;
    
    return bench;
}
// ============================================================================
// Базовые структуры данных для сортировки и графов
// ============================================================================

// ============================================================================
// Класс SortBenchmark (базовый класс)
// ============================================================================

#define SORT_ARR_SIZE 100000

typedef struct {
    int32_t* data;
    size_t data_size;
    int n;
    uint32_t result_val;
} SortBenchmark;

static char* SortBenchmark_check_n_elements(int32_t* arr, size_t arr_size, int n_check) {
    size_t result_capacity = 1024;
    char* result = malloc(result_capacity);
    size_t result_len = 0;
    
    result[result_len++] = '[';
    
    int step = arr_size / n_check;
    if (step == 0) step = 1;
    
    for (size_t index = 0; index < arr_size; index += step) {
        if (index >= arr_size) break;
        int written = snprintf(result + result_len, result_capacity - result_len,
                              "%zu:%d,", index, arr[index]);
        if (written > 0) result_len += written;
        
        if (result_len + 100 >= result_capacity) {
            result_capacity *= 2;
            result = realloc(result, result_capacity);
        }
    }
    
    result[result_len++] = ']';
    result[result_len++] = '\n';
    result[result_len] = '\0';
    
    return result;
}

// ============================================================================
// Класс SortQuick
// ============================================================================

typedef struct {
    SortBenchmark base;
} SortQuick;

static void SortQuick_quick_sort(int32_t* arr, int low, int high) {
    if (low >= high) return;
    
    int pivot = arr[(low + high) / 2];
    int i = low, j = high;
    
    while (i <= j) {
        while (arr[i] < pivot) i++;
        while (arr[j] > pivot) j--;
        if (i <= j) {
            int32_t temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
            i++;
            j--;
        }
    }
    
    SortQuick_quick_sort(arr, low, j);
    SortQuick_quick_sort(arr, i, high);
}

static int32_t* SortQuick_test(void* self) {
    SortQuick* bench = (SortQuick*)self;
    size_t arr_size = bench->base.data_size;
    int32_t* arr = malloc(arr_size * sizeof(int32_t));
    memcpy(arr, bench->base.data, arr_size * sizeof(int32_t));
    
    SortQuick_quick_sort(arr, 0, arr_size - 1);
    return arr;
}

int64_t SortQuick_run(void* self) {
    SortQuick* bench = (SortQuick*)self;
    
    char* verify1 = SortBenchmark_check_n_elements(bench->base.data, bench->base.data_size, 10);
    
    bench->base.result_val = 0;
    for (int i = 0; i < bench->base.n - 1; i++) {
        int32_t* arr = SortQuick_test(self);
        bench->base.result_val += arr[bench->base.data_size / 2];
        free(arr);
    }
    
    int32_t* arr = SortQuick_test(self);
    
    char* verify2 = SortBenchmark_check_n_elements(bench->base.data, bench->base.data_size, 10);
    char* verify3 = SortBenchmark_check_n_elements(arr, bench->base.data_size, 10);
    
    size_t verify_len = strlen(verify1) + strlen(verify2) + strlen(verify3) + 1;
    char* verify = malloc(verify_len);
    snprintf(verify, verify_len, "%s%s%s", verify1, verify2, verify3);
    
    bench->base.result_val += Helper_checksum_string(verify);
    
    free(verify1);
    free(verify2);
    free(verify3);
    free(verify);
    free(arr);
    
    return bench->base.result_val;
}

void SortQuick_prepare(void* self) {
    SortQuick* bench = (SortQuick*)self;
    const char* input = Helper_get_input("SortQuick");
    bench->base.n = input ? atoi(input) : 100;
    bench->base.data_size = SORT_ARR_SIZE;
    bench->base.data = malloc(bench->base.data_size * sizeof(int32_t));
    
    for (size_t i = 0; i < bench->base.data_size; i++) {
        bench->base.data[i] = Helper_next_int(1000000);
    }
    bench->base.result_val = 0;
}

void SortQuick_cleanup(void* self) {
    SortQuick* bench = (SortQuick*)self;
    free(bench->base.data);
    free(bench);
}

Benchmark* SortQuick_new(void) {
    SortQuick* instance = malloc(sizeof(SortQuick));
    instance->base.data = NULL;
    instance->base.data_size = 0;
    instance->base.n = 0;
    instance->base.result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "SortQuick";
    bench->run = SortQuick_run;
    bench->prepare = SortQuick_prepare;
    bench->cleanup = SortQuick_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс SortMerge
// ============================================================================

typedef struct {
    SortBenchmark base;
} SortMerge;

static void SortMerge_merge(int32_t* arr, int32_t* temp, int left, int mid, int right) {
    for (int i = left; i <= right; i++) {
        temp[i] = arr[i];
    }
    
    int i = left, j = mid + 1, k = left;
    
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

static void SortMerge_merge_sort_helper(int32_t* arr, int32_t* temp, int left, int right) {
    if (left >= right) return;
    
    int mid = (left + right) / 2;
    SortMerge_merge_sort_helper(arr, temp, left, mid);
    SortMerge_merge_sort_helper(arr, temp, mid + 1, right);
    SortMerge_merge(arr, temp, left, mid, right);
}

static void SortMerge_merge_sort_inplace(int32_t* arr, size_t size) {
    int32_t* temp = malloc(size * sizeof(int32_t));
    SortMerge_merge_sort_helper(arr, temp, 0, size - 1);
    free(temp);
}

static int32_t* SortMerge_test(void* self) {
    SortMerge* bench = (SortMerge*)self;
    size_t arr_size = bench->base.data_size;
    int32_t* arr = malloc(arr_size * sizeof(int32_t));
    memcpy(arr, bench->base.data, arr_size * sizeof(int32_t));
    
    SortMerge_merge_sort_inplace(arr, arr_size);
    return arr;
}

int64_t SortMerge_run(void* self) {
    SortMerge* bench = (SortMerge*)self;
    
    char* verify1 = SortBenchmark_check_n_elements(bench->base.data, bench->base.data_size, 10);
    
    bench->base.result_val = 0;
    for (int i = 0; i < bench->base.n - 1; i++) {
        int32_t* arr = SortMerge_test(self);
        bench->base.result_val += arr[bench->base.data_size / 2];
        free(arr);
    }
    
    int32_t* arr = SortMerge_test(self);
    
    char* verify2 = SortBenchmark_check_n_elements(bench->base.data, bench->base.data_size, 10);
    char* verify3 = SortBenchmark_check_n_elements(arr, bench->base.data_size, 10);
    
    size_t verify_len = strlen(verify1) + strlen(verify2) + strlen(verify3) + 1;
    char* verify = malloc(verify_len);
    snprintf(verify, verify_len, "%s%s%s", verify1, verify2, verify3);
    
    bench->base.result_val += Helper_checksum_string(verify);
    
    free(verify1);
    free(verify2);
    free(verify3);
    free(verify);
    free(arr);
    
    return bench->base.result_val;
}

void SortMerge_prepare(void* self) {
    SortMerge* bench = (SortMerge*)self;
    const char* input = Helper_get_input("SortMerge");
    bench->base.n = input ? atoi(input) : 100;
    bench->base.data_size = SORT_ARR_SIZE;
    bench->base.data = malloc(bench->base.data_size * sizeof(int32_t));
    
    for (size_t i = 0; i < bench->base.data_size; i++) {
        bench->base.data[i] = Helper_next_int(1000000);
    }
    bench->base.result_val = 0;
}

void SortMerge_cleanup(void* self) {
    SortMerge* bench = (SortMerge*)self;
    free(bench->base.data);
    free(bench);
}

Benchmark* SortMerge_new(void) {
    SortMerge* instance = malloc(sizeof(SortMerge));
    instance->base.data = NULL;
    instance->base.data_size = 0;
    instance->base.n = 0;
    instance->base.result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "SortMerge";
    bench->run = SortMerge_run;
    bench->prepare = SortMerge_prepare;
    bench->cleanup = SortMerge_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс SortSelf (использует qsort)
// ============================================================================

typedef struct {
    SortBenchmark base;
} SortSelf;

static int SortSelf_compare(const void* a, const void* b) {
    int32_t ia = *(const int32_t*)a;
    int32_t ib = *(const int32_t*)b;
    return (ia > ib) - (ia < ib);
}

static int32_t* SortSelf_test(void* self) {
    SortSelf* bench = (SortSelf*)self;
    size_t arr_size = bench->base.data_size;
    int32_t* arr = malloc(arr_size * sizeof(int32_t));
    memcpy(arr, bench->base.data, arr_size * sizeof(int32_t));
    
    qsort(arr, arr_size, sizeof(int32_t), SortSelf_compare);
    return arr;
}

int64_t SortSelf_run(void* self) {
    SortSelf* bench = (SortSelf*)self;
    
    char* verify1 = SortBenchmark_check_n_elements(bench->base.data, bench->base.data_size, 10);
    
    bench->base.result_val = 0;
    for (int i = 0; i < bench->base.n - 1; i++) {
        int32_t* arr = SortSelf_test(self);
        bench->base.result_val += arr[bench->base.data_size / 2];
        free(arr);
    }
    
    int32_t* arr = SortSelf_test(self);
    
    char* verify2 = SortBenchmark_check_n_elements(bench->base.data, bench->base.data_size, 10);
    char* verify3 = SortBenchmark_check_n_elements(arr, bench->base.data_size, 10);
    
    size_t verify_len = strlen(verify1) + strlen(verify2) + strlen(verify3) + 1;
    char* verify = malloc(verify_len);
    snprintf(verify, verify_len, "%s%s%s", verify1, verify2, verify3);
    
    bench->base.result_val += Helper_checksum_string(verify);
    
    free(verify1);
    free(verify2);
    free(verify3);
    free(verify);
    free(arr);
    
    return bench->base.result_val;
}

void SortSelf_prepare(void* self) {
    SortSelf* bench = (SortSelf*)self;
    const char* input = Helper_get_input("SortSelf");
    bench->base.n = input ? atoi(input) : 100;
    bench->base.data_size = SORT_ARR_SIZE;
    bench->base.data = malloc(bench->base.data_size * sizeof(int32_t));
    
    for (size_t i = 0; i < bench->base.data_size; i++) {
        bench->base.data[i] = Helper_next_int(1000000);
    }
    bench->base.result_val = 0;
}

void SortSelf_cleanup(void* self) {
    SortSelf* bench = (SortSelf*)self;
    free(bench->base.data);
    free(bench);
}

Benchmark* SortSelf_new(void) {
    SortSelf* instance = malloc(sizeof(SortSelf));
    instance->base.data = NULL;
    instance->base.data_size = 0;
    instance->base.n = 0;
    instance->base.result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "SortSelf";
    bench->run = SortSelf_run;
    bench->prepare = SortSelf_prepare;
    bench->cleanup = SortSelf_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Структуры для GraphPathBenchmark
// ============================================================================

typedef struct {
    int vertices;
    int components;
    int** adj;
    int* adj_count;
    int* adj_capacity;
} GraphPathBenchmark_Graph;

typedef struct {
    GraphPathBenchmark_Graph* graph;
    int* pairs_start;
    int* pairs_end;
    int n_pairs;
    int64_t result_val;
} GraphPathBenchmark;

static GraphPathBenchmark_Graph* GraphPathBenchmark_Graph_new(int vertices, int components) {
    GraphPathBenchmark_Graph* graph = malloc(sizeof(GraphPathBenchmark_Graph));
    graph->vertices = vertices;
    graph->components = components;
    
    graph->adj = malloc(vertices * sizeof(int*));
    graph->adj_count = malloc(vertices * sizeof(int));
    graph->adj_capacity = malloc(vertices * sizeof(int));
    
    for (int i = 0; i < vertices; i++) {
        graph->adj_capacity[i] = 4;
        graph->adj[i] = malloc(graph->adj_capacity[i] * sizeof(int));
        graph->adj_count[i] = 0;
    }
    
    return graph;
}

static void GraphPathBenchmark_Graph_free(GraphPathBenchmark_Graph* graph) {
    if (!graph) return;
    
    if (graph->adj) {
        for (int i = 0; i < graph->vertices; i++) {
            if (graph->adj[i]) {
                free(graph->adj[i]);
                graph->adj[i] = NULL;
            }
        }
        free(graph->adj);
        graph->adj = NULL;
    }
    
    if (graph->adj_count) {
        free(graph->adj_count);
        graph->adj_count = NULL;
    }
    
    if (graph->adj_capacity) {
        free(graph->adj_capacity);
        graph->adj_capacity = NULL;
    }
    
    free(graph);
}

static void GraphPathBenchmark_Graph_add_edge(GraphPathBenchmark_Graph* graph, int u, int v) {
    if (graph->adj_count[u] >= graph->adj_capacity[u]) {
        graph->adj_capacity[u] *= 2;
        graph->adj[u] = realloc(graph->adj[u], graph->adj_capacity[u] * sizeof(int));
    }
    graph->adj[u][graph->adj_count[u]++] = v;
    
    if (graph->adj_count[v] >= graph->adj_capacity[v]) {
        graph->adj_capacity[v] *= 2;
        graph->adj[v] = realloc(graph->adj[v], graph->adj_capacity[v] * sizeof(int));
    }
    graph->adj[v][graph->adj_count[v]++] = u;
}

static void GraphPathBenchmark_Graph_generate_random(GraphPathBenchmark_Graph* graph) {
    int component_size = graph->vertices / graph->components;
    
    for (int c = 0; c < graph->components; c++) {
        int start_idx = c * component_size;
        int end_idx = (c == graph->components - 1) ? graph->vertices : (c + 1) * component_size;
        
        for (int i = start_idx + 1; i < end_idx; i++) {
            int parent = start_idx + Helper_next_int(i - start_idx);
            GraphPathBenchmark_Graph_add_edge(graph, i, parent);
        }
        
        int extra_edges = component_size * 2;
        for (int e = 0; e < extra_edges; e++) {
            int u = start_idx + Helper_next_int(end_idx - start_idx);
            int v = start_idx + Helper_next_int(end_idx - start_idx);
            if (u != v) GraphPathBenchmark_Graph_add_edge(graph, u, v);
        }
    }
}

// ============================================================================
// Класс GraphPathBFS
// ============================================================================

typedef struct {
    GraphPathBenchmark base;
} GraphPathBFS;

static int GraphPathBFS_bfs_shortest_path(GraphPathBenchmark_Graph* graph, int start, int target) {
    if (start == target) return 0;
    
    int* queue = malloc(graph->vertices * 2 * sizeof(int));
    int* distances = malloc(graph->vertices * sizeof(int));
    uint8_t* visited = calloc(graph->vertices, sizeof(uint8_t));
    
    int front = 0, rear = 0;
    
    visited[start] = 1;
    distances[start] = 0;
    queue[rear++] = start;
    queue[rear++] = 0;
    
    while (front < rear) {
        int v = queue[front++];
        int dist = queue[front++];
        
        for (int i = 0; i < graph->adj_count[v]; i++) {
            int neighbor = graph->adj[v][i];
            
            if (neighbor == target) {
                free(queue);
                free(distances);
                free(visited);
                return dist + 1;
            }
            
            if (!visited[neighbor]) {
                visited[neighbor] = 1;
                distances[neighbor] = dist + 1;
                queue[rear++] = neighbor;
                queue[rear++] = dist + 1;
            }
        }
    }
    
    free(queue);
    free(distances);
    free(visited);
    return -1;
}

int64_t GraphPathBFS_run(void* self) {
    GraphPathBFS* bench = (GraphPathBFS*)self;
    
    bench->base.result_val = 0;
    for (int i = 0; i < bench->base.n_pairs; i++) {
        int path_len = GraphPathBFS_bfs_shortest_path(bench->base.graph, 
                                                     bench->base.pairs_start[i], 
                                                     bench->base.pairs_end[i]);
        bench->base.result_val += path_len;
    }
    
    return bench->base.result_val;
}

void GraphPathBFS_prepare(void* self) {
    GraphPathBFS* bench = (GraphPathBFS*)self;
    const char* input = Helper_get_input("GraphPathBFS");
    bench->base.n_pairs = input ? atoi(input) : 100;
    
    int vertices = bench->base.n_pairs * 10;
    int comps = (vertices / 10000 > 10) ? vertices / 10000 : 10;
    bench->base.graph = GraphPathBenchmark_Graph_new(vertices, comps);
    
    GraphPathBenchmark_Graph_generate_random(bench->base.graph);
    
    bench->base.pairs_start = malloc(bench->base.n_pairs * sizeof(int));
    bench->base.pairs_end = malloc(bench->base.n_pairs * sizeof(int));
    
    int component_size = vertices / 10;
    for (int i = 0; i < bench->base.n_pairs; i++) {
        if (Helper_next_int(100) < 70) {
            int component = Helper_next_int(10);
            int start = component * component_size + Helper_next_int(component_size);
            int end;
            do {
                end = component * component_size + Helper_next_int(component_size);
            } while (end == start);
            bench->base.pairs_start[i] = start;
            bench->base.pairs_end[i] = end;
        } else {
            int c1 = Helper_next_int(10);
            int c2;
            do {
                c2 = Helper_next_int(10);
            } while (c2 == c1);
            int start = c1 * component_size + Helper_next_int(component_size);
            int end = c2 * component_size + Helper_next_int(component_size);
            bench->base.pairs_start[i] = start;
            bench->base.pairs_end[i] = end;
        }
    }
    
    bench->base.result_val = 0;
}

void GraphPathBFS_cleanup(void* self) {
    if (!self) return;
    
    GraphPathBFS* bench = (GraphPathBFS*)self;
    
    if (bench->base.graph) {
        GraphPathBenchmark_Graph_free(bench->base.graph);
        bench->base.graph = NULL;
    }
    
    if (bench->base.pairs_start) {
        free(bench->base.pairs_start);
        bench->base.pairs_start = NULL;
    }
    
    if (bench->base.pairs_end) {
        free(bench->base.pairs_end);
        bench->base.pairs_end = NULL;
    }
    
    free(bench);
}

Benchmark* GraphPathBFS_new(void) {
    GraphPathBFS* instance = malloc(sizeof(GraphPathBFS));
    instance->base.graph = NULL;
    instance->base.pairs_start = NULL;
    instance->base.pairs_end = NULL;
    instance->base.n_pairs = 0;
    instance->base.result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "GraphPathBFS";
    bench->run = GraphPathBFS_run;
    bench->prepare = GraphPathBFS_prepare;
    bench->cleanup = GraphPathBFS_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс BufferHashBenchmark (базовый класс)
// ============================================================================

#define BUFFERHASH_DATA_SIZE 1000000

typedef struct {
    uint8_t* data;
    size_t data_size;
    int n;
    uint32_t result_val;
} BufferHashBenchmark;

// ============================================================================
// Класс BufferHashSHA256
// ============================================================================

typedef struct {
    BufferHashBenchmark base;
} BufferHashSHA256;

static uint32_t BufferHashSHA256_digest(uint8_t* data, size_t data_size) {
    uint32_t hashes[8] = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    };
    
    for (size_t i = 0; i < data_size; i++) {
        uint32_t hash_idx = i % 8;
        uint32_t* hash = &hashes[hash_idx];
        *hash = ((*hash << 5) + *hash) + data[i];
        *hash = (*hash + (*hash << 10)) ^ (*hash >> 6);
    }
    
    // Конвертируем в big-endian как в C++
    uint32_t result = hashes[0];
    
    // Преобразуем в big-endian (сетевой порядок)
    result = ((result & 0xFF000000) >> 24) |
             ((result & 0x00FF0000) >> 8) |
             ((result & 0x0000FF00) << 8) |
             ((result & 0x000000FF) << 24);
    
    return result;
}

int64_t BufferHashSHA256_run(void* self) {
    BufferHashSHA256* bench = (BufferHashSHA256*)self;
    
    bench->base.result_val = 0;
    for (int i = 0; i < bench->base.n; i++) {
        bench->base.result_val += BufferHashSHA256_digest(bench->base.data, bench->base.data_size);
    }
    
    return bench->base.result_val;
}

void BufferHashSHA256_prepare(void* self) {
    BufferHashSHA256* bench = (BufferHashSHA256*)self;
    const char* input = Helper_get_input("BufferHashSHA256");
    bench->base.n = input ? atoi(input) : 100;
    bench->base.data_size = BUFFERHASH_DATA_SIZE;
    bench->base.data = malloc(bench->base.data_size);
    
    for (size_t i = 0; i < bench->base.data_size; i++) {
        bench->base.data[i] = Helper_next_int(256);
    }
    bench->base.result_val = 0;
}

void BufferHashSHA256_cleanup(void* self) {
    BufferHashSHA256* bench = (BufferHashSHA256*)self;
    free(bench->base.data);
    free(bench);
}

Benchmark* BufferHashSHA256_new(void) {
    BufferHashSHA256* instance = malloc(sizeof(BufferHashSHA256));
    instance->base.data = NULL;
    instance->base.data_size = 0;
    instance->base.n = 0;
    instance->base.result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "BufferHashSHA256";
    bench->run = BufferHashSHA256_run;
    bench->prepare = BufferHashSHA256_prepare;
    bench->cleanup = BufferHashSHA256_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Класс BufferHashCRC32
// ============================================================================

typedef struct {
    BufferHashBenchmark base;
} BufferHashCRC32;

static uint32_t BufferHashCRC32_crc32(uint8_t* data, size_t data_size) {
    uint32_t crc = 0xFFFFFFFFu;
    
    for (size_t i = 0; i < data_size; i++) {
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

int64_t BufferHashCRC32_run(void* self) {
    BufferHashCRC32* bench = (BufferHashCRC32*)self;
    
    bench->base.result_val = 0;
    for (int i = 0; i < bench->base.n; i++) {
        bench->base.result_val += BufferHashCRC32_crc32(bench->base.data, bench->base.data_size);
    }
    
    return bench->base.result_val;
}

void BufferHashCRC32_prepare(void* self) {
    BufferHashCRC32* bench = (BufferHashCRC32*)self;
    const char* input = Helper_get_input("BufferHashCRC32");
    bench->base.n = input ? atoi(input) : 100;
    bench->base.data_size = BUFFERHASH_DATA_SIZE;
    bench->base.data = malloc(bench->base.data_size);
    
    for (size_t i = 0; i < bench->base.data_size; i++) {
        bench->base.data[i] = Helper_next_int(256);
    }
    bench->base.result_val = 0;
}

void BufferHashCRC32_cleanup(void* self) {
    BufferHashCRC32* bench = (BufferHashCRC32*)self;
    free(bench->base.data);
    free(bench);
}

Benchmark* BufferHashCRC32_new(void) {
    BufferHashCRC32* instance = malloc(sizeof(BufferHashCRC32));
    instance->base.data = NULL;
    instance->base.data_size = 0;
    instance->base.n = 0;
    instance->base.result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "BufferHashCRC32";
    bench->run = BufferHashCRC32_run;
    bench->prepare = BufferHashCRC32_prepare;
    bench->cleanup = BufferHashCRC32_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Исправленная версия CacheSimulation
// ============================================================================

#define CACHE_CAPACITY 1000
#define CACHE_OPERATIONS 100000

typedef struct CacheSimulation_Node CacheSimulation_Node;

struct CacheSimulation_Node {
    char* key;
    char* value;
    int64_t timestamp;
    CacheSimulation_Node* prev;
    CacheSimulation_Node* next;
    CacheSimulation_Node* hash_next;  // Для цепочки в хеш-таблице
};

typedef struct {
    CacheSimulation_Node** hash_table;  // Изменил имя для ясности
    size_t hash_size;  // Размер хеш-таблицы (лучше степень двойки)
    CacheSimulation_Node* head;
    CacheSimulation_Node* tail;
    int64_t time;
    size_t size;
    size_t capacity;
} CacheSimulation_LRUCache;

static CacheSimulation_LRUCache* CacheSimulation_LRUCache_new(size_t capacity) {
    CacheSimulation_LRUCache* cache = malloc(sizeof(CacheSimulation_LRUCache));
    cache->capacity = capacity;
    cache->hash_size = 2048;  // Фиксированный размер, степень двойки
    cache->hash_table = calloc(cache->hash_size, sizeof(CacheSimulation_Node*));
    cache->head = NULL;
    cache->tail = NULL;
    cache->time = 0;
    cache->size = 0;
    return cache;
}

static uint32_t CacheSimulation_hash(const char* key) {
    uint32_t hash = 5381;
    while (*key) {
        hash = ((hash << 5) + hash) + (uint8_t)(*key);
        key++;
    }
    return hash;
}

static CacheSimulation_Node* CacheSimulation_LRUCache_find_in_hash(CacheSimulation_LRUCache* cache, const char* key, uint32_t hash) {
    CacheSimulation_Node* node = cache->hash_table[hash];
    while (node) {
        if (strcmp(node->key, key) == 0) {
            return node;
        }
        node = node->hash_next;
    }
    return NULL;
}

static void CacheSimulation_LRUCache_move_to_front(CacheSimulation_LRUCache* cache, CacheSimulation_Node* node) {
    if (node == cache->head) return;
    
    // Удаляем из текущей позиции в двусвязном списке
    if (node->prev) node->prev->next = node->next;
    if (node->next) node->next->prev = node->prev;
    
    // Обновляем tail если нужно
    if (node == cache->tail) cache->tail = node->prev;
    
    // Вставляем в начало
    node->prev = NULL;
    node->next = cache->head;
    if (cache->head) cache->head->prev = node;
    cache->head = node;
    if (!cache->tail) cache->tail = node;
}

static CacheSimulation_Node* CacheSimulation_LRUCache_get(CacheSimulation_LRUCache* cache, const char* key) {
    uint32_t hash = CacheSimulation_hash(key) % cache->hash_size;
    CacheSimulation_Node* node = CacheSimulation_LRUCache_find_in_hash(cache, key, hash);
    
    if (node) {
        CacheSimulation_LRUCache_move_to_front(cache, node);
        node->timestamp = ++cache->time;
        return node;
    }
    return NULL;
}

static void CacheSimulation_LRUCache_remove_oldest(CacheSimulation_LRUCache* cache) {
    if (!cache->tail) return;
    
    CacheSimulation_Node* oldest = cache->tail;
    
    // Удаляем из хеш-таблицы
    uint32_t hash = CacheSimulation_hash(oldest->key) % cache->hash_size;
    CacheSimulation_Node** prev_ptr = &cache->hash_table[hash];
    CacheSimulation_Node* curr = cache->hash_table[hash];
    
    while (curr) {
        if (curr == oldest) {
            *prev_ptr = curr->hash_next;
            break;
        }
        prev_ptr = &curr->hash_next;
        curr = curr->hash_next;
    }
    
    // Удаляем из двусвязного списка
    if (oldest->prev) oldest->prev->next = oldest->next;
    if (oldest->next) oldest->next->prev = oldest->prev;
    
    if (cache->head == oldest) cache->head = oldest->next;
    if (cache->tail == oldest) cache->tail = oldest->prev;
    
    // Освобождаем память
    free(oldest->key);
    free(oldest->value);
    free(oldest);
    
    cache->size--;
}

static void CacheSimulation_LRUCache_put(CacheSimulation_LRUCache* cache, const char* key, const char* value) {
    uint32_t hash = CacheSimulation_hash(key) % cache->hash_size;
    
    CacheSimulation_Node* existing = CacheSimulation_LRUCache_find_in_hash(cache, key, hash);
    if (existing) {
        // Обновляем существующий
        free(existing->value);
        existing->value = strdup(value);
        CacheSimulation_LRUCache_move_to_front(cache, existing);
        existing->timestamp = ++cache->time;
        return;
    }
    
    // Удаляем самый старый если достигли capacity
    if (cache->size >= cache->capacity) {
        CacheSimulation_LRUCache_remove_oldest(cache);
    }
    
    // Создаем новый узел
    CacheSimulation_Node* node = malloc(sizeof(CacheSimulation_Node));
    node->key = strdup(key);
    node->value = strdup(value);
    node->timestamp = ++cache->time;
    node->prev = NULL;
    node->hash_next = cache->hash_table[hash];
    
    // Добавляем в хеш-таблицу
    cache->hash_table[hash] = node;
    
    // Добавляем в начало двусвязного списка
    node->next = cache->head;
    if (cache->head) cache->head->prev = node;
    cache->head = node;
    if (!cache->tail) cache->tail = node;
    
    cache->size++;
}

static void CacheSimulation_LRUCache_free(CacheSimulation_LRUCache* cache) {
    // Очищаем все узлы через двусвязный список (проще, чем через хеш-таблицу)
    CacheSimulation_Node* node = cache->head;
    while (node) {
        CacheSimulation_Node* next = node->next;
        free(node->key);
        free(node->value);
        free(node);
        node = next;
    }
    free(cache->hash_table);
    free(cache);
}

typedef struct {
    int operations;
    uint32_t result_val;
} CacheSimulation;

int64_t CacheSimulation_run(void* self) {
    CacheSimulation* bench = (CacheSimulation*)self;
    CacheSimulation_LRUCache* cache = CacheSimulation_LRUCache_new(CACHE_CAPACITY);
    
    int hits = 0;
    int misses = 0;
    
    for (int i = 0; i < bench->operations; i++) {
        char key[32];
        snprintf(key, sizeof(key), "item_%d", Helper_next_int(2000));
        
        if (CacheSimulation_LRUCache_get(cache, key)) {
            hits++;
            char value[32];
            snprintf(value, sizeof(value), "updated_%d", i);
            CacheSimulation_LRUCache_put(cache, key, value);
        } else {
            misses++;
            char value[32];
            snprintf(value, sizeof(value), "new_%d", i);
            CacheSimulation_LRUCache_put(cache, key, value);
        }
    }
    
    char result_str[256];
    snprintf(result_str, sizeof(result_str), "hits:%d|misses:%d|size:%zu", 
             hits, misses, cache->size);
    
    bench->result_val = Helper_checksum_string(result_str);
    
    CacheSimulation_LRUCache_free(cache);
    return bench->result_val;
}

void CacheSimulation_prepare(void* self) {
    CacheSimulation* bench = (CacheSimulation*)self;
    const char* input = Helper_get_input("CacheSimulation");
    int iterations = input ? atoi(input) : 100;
    bench->operations = iterations * 1000;
    bench->result_val = 0;
}

void CacheSimulation_cleanup(void* self) {
    free(self);
}

Benchmark* CacheSimulation_new(void) {
    CacheSimulation* instance = malloc(sizeof(CacheSimulation));
    instance->operations = 0;
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "CacheSimulation";
    bench->run = CacheSimulation_run;
    bench->prepare = CacheSimulation_prepare;
    bench->cleanup = CacheSimulation_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// GraphPathDFS (поиск в глубину)
// ============================================================================

typedef struct {
    GraphPathBenchmark base;
} GraphPathDFS;

typedef struct {
    int vertex;
    int distance;
} GraphPathDFS_StackItem;

static int GraphPathDFS_dfs_find_path(GraphPathBenchmark_Graph* graph, int start, int target) {
    if (start == target) return 0;
    
    uint8_t* visited = calloc(graph->vertices, sizeof(uint8_t));
    GraphPathDFS_StackItem* stack = malloc(graph->vertices * 2 * sizeof(GraphPathDFS_StackItem));
    int stack_top = -1;
    int best_path = INT_MAX;
    
    stack[++stack_top] = (GraphPathDFS_StackItem){start, 0};
    
    while (stack_top >= 0) {
        GraphPathDFS_StackItem current = stack[stack_top--];
        int v = current.vertex;
        int dist = current.distance;
        
        if (visited[v] || dist >= best_path) continue;
        visited[v] = 1;
        
        for (int i = 0; i < graph->adj_count[v]; i++) {
            int neighbor = graph->adj[v][i];
            if (neighbor == target) {
                if (dist + 1 < best_path) {
                    best_path = dist + 1;
                }
            } else if (!visited[neighbor]) {
                stack[++stack_top] = (GraphPathDFS_StackItem){neighbor, dist + 1};
            }
        }
    }
    
    free(visited);
    free(stack);
    return (best_path == INT_MAX) ? -1 : best_path;
}

int64_t GraphPathDFS_run(void* self) {
    GraphPathDFS* bench = (GraphPathDFS*)self;
    
    bench->base.result_val = 0;
    for (int i = 0; i < bench->base.n_pairs; i++) {
        int path_len = GraphPathDFS_dfs_find_path(bench->base.graph, 
                                                 bench->base.pairs_start[i], 
                                                 bench->base.pairs_end[i]);
        bench->base.result_val += path_len;
    }
    
    return bench->base.result_val;
}

void GraphPathDFS_prepare(void* self) {
    GraphPathDFS* bench = (GraphPathDFS*)self;
    const char* input = Helper_get_input("GraphPathDFS");
    bench->base.n_pairs = input ? atoi(input) : 100;
    
    int vertices = bench->base.n_pairs * 10;
    int comps = (vertices / 10000 > 10) ? vertices / 10000 : 10;
    bench->base.graph = GraphPathBenchmark_Graph_new(vertices, comps);
    
    GraphPathBenchmark_Graph_generate_random(bench->base.graph);
    
    bench->base.pairs_start = malloc(bench->base.n_pairs * sizeof(int));
    bench->base.pairs_end = malloc(bench->base.n_pairs * sizeof(int));
    
    int component_size = vertices / 10;
    for (int i = 0; i < bench->base.n_pairs; i++) {
        if (Helper_next_int(100) < 70) {
            int component = Helper_next_int(10);
            int start = component * component_size + Helper_next_int(component_size);
            int end;
            do {
                end = component * component_size + Helper_next_int(component_size);
            } while (end == start);
            bench->base.pairs_start[i] = start;
            bench->base.pairs_end[i] = end;
        } else {
            int c1 = Helper_next_int(10);
            int c2;
            do {
                c2 = Helper_next_int(10);
            } while (c2 == c1);
            int start = c1 * component_size + Helper_next_int(component_size);
            int end = c2 * component_size + Helper_next_int(component_size);
            bench->base.pairs_start[i] = start;
            bench->base.pairs_end[i] = end;
        }
    }
    
    bench->base.result_val = 0;
}

void GraphPathDFS_cleanup(void* self) {
    GraphPathDFS* bench = (GraphPathDFS*)self;
    GraphPathBenchmark_Graph_free(bench->base.graph);
    free(bench->base.pairs_start);
    free(bench->base.pairs_end);
    free(bench);
}

Benchmark* GraphPathDFS_new(void) {
    GraphPathDFS* instance = malloc(sizeof(GraphPathDFS));
    instance->base.graph = NULL;
    instance->base.pairs_start = NULL;
    instance->base.pairs_end = NULL;
    instance->base.n_pairs = 0;
    instance->base.result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "GraphPathDFS";
    bench->run = GraphPathDFS_run;
    bench->prepare = GraphPathDFS_prepare;
    bench->cleanup = GraphPathDFS_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// GraphPathDijkstra (алгоритм Дейкстры)
// ============================================================================

typedef struct {
    GraphPathBenchmark base;
} GraphPathDijkstra;

static int GraphPathDijkstra_dijkstra_shortest_path(GraphPathBenchmark_Graph* graph, int start, int target) {
    if (start == target) return 0;
    
    int* dist = malloc(graph->vertices * sizeof(int));
    uint8_t* visited = calloc(graph->vertices, sizeof(uint8_t));
    
    for (int i = 0; i < graph->vertices; i++) {
        dist[i] = INT_MAX / 2;
    }
    dist[start] = 0;
    
    for (int iteration = 0; iteration < graph->vertices; iteration++) {
        int u = -1;
        int min_dist = INT_MAX / 2;
        
        for (int v = 0; v < graph->vertices; v++) {
            if (!visited[v] && dist[v] < min_dist) {
                min_dist = dist[v];
                u = v;
            }
        }
        
        if (u == -1 || min_dist == INT_MAX / 2 || u == target) {
            int result = (u == target) ? min_dist : -1;
            free(dist);
            free(visited);
            return result;
        }
        
        visited[u] = 1;
        
        for (int i = 0; i < graph->adj_count[u]; i++) {
            int v = graph->adj[u][i];
            if (dist[u] + 1 < dist[v]) {
                dist[v] = dist[u] + 1;
            }
        }
    }
    
    free(dist);
    free(visited);
    return -1;
}

int64_t GraphPathDijkstra_run(void* self) {
    GraphPathDijkstra* bench = (GraphPathDijkstra*)self;
    
    bench->base.result_val = 0;
    for (int i = 0; i < bench->base.n_pairs; i++) {
        int path_len = GraphPathDijkstra_dijkstra_shortest_path(bench->base.graph, 
                                                               bench->base.pairs_start[i], 
                                                               bench->base.pairs_end[i]);
        bench->base.result_val += path_len;
    }
    
    return bench->base.result_val;
}

void GraphPathDijkstra_prepare(void* self) {
    GraphPathDijkstra* bench = (GraphPathDijkstra*)self;
    const char* input = Helper_get_input("GraphPathDijkstra");
    bench->base.n_pairs = input ? atoi(input) : 100;
    
    int vertices = bench->base.n_pairs * 10;
    int comps = (vertices / 10000 > 10) ? vertices / 10000 : 10;
    bench->base.graph = GraphPathBenchmark_Graph_new(vertices, comps);
    
    GraphPathBenchmark_Graph_generate_random(bench->base.graph);
    
    bench->base.pairs_start = malloc(bench->base.n_pairs * sizeof(int));
    bench->base.pairs_end = malloc(bench->base.n_pairs * sizeof(int));
    
    int component_size = vertices / 10;
    for (int i = 0; i < bench->base.n_pairs; i++) {
        if (Helper_next_int(100) < 70) {
            int component = Helper_next_int(10);
            int start = component * component_size + Helper_next_int(component_size);
            int end;
            do {
                end = component * component_size + Helper_next_int(component_size);
            } while (end == start);
            bench->base.pairs_start[i] = start;
            bench->base.pairs_end[i] = end;
        } else {
            int c1 = Helper_next_int(10);
            int c2;
            do {
                c2 = Helper_next_int(10);
            } while (c2 == c1);
            int start = c1 * component_size + Helper_next_int(component_size);
            int end = c2 * component_size + Helper_next_int(component_size);
            bench->base.pairs_start[i] = start;
            bench->base.pairs_end[i] = end;
        }
    }
    
    bench->base.result_val = 0;
}

void GraphPathDijkstra_cleanup(void* self) {
    GraphPathDijkstra* bench = (GraphPathDijkstra*)self;
    GraphPathBenchmark_Graph_free(bench->base.graph);
    free(bench->base.pairs_start);
    free(bench->base.pairs_end);
    free(bench);
}

Benchmark* GraphPathDijkstra_new(void) {
    GraphPathDijkstra* instance = malloc(sizeof(GraphPathDijkstra));
    instance->base.graph = NULL;
    instance->base.pairs_start = NULL;
    instance->base.pairs_end = NULL;
    instance->base.n_pairs = 0;
    instance->base.result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "GraphPathDijkstra";
    bench->run = GraphPathDijkstra_run;
    bench->prepare = GraphPathDijkstra_prepare;
    bench->cleanup = GraphPathDijkstra_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// CalculatorAST (AST парсер и интерпретатор)
// ============================================================================

// Типы узлов AST
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
    AST_Node* left;
    AST_Node* right;
};

struct AST_Assignment {
    char* var_name;
    AST_Node* expr;
};

struct AST_Number {
    int64_t value;
};

struct AST_Variable {
    char* name;
};

struct AST_Node {
    AST_NodeType type;
    union {
        struct AST_Number number;
        struct AST_Variable variable;
        AST_BinaryOp* binary_op;
        AST_Assignment* assignment;
    } data;
};

typedef struct {
    AST_Node** expressions;
    int expressions_count;
    int expressions_capacity;
    uint64_t result_val;
    char* text;
    int n;
} CalculatorAST;

static AST_Node* AST_Node_new_number(int64_t value) {
    AST_Node* node = malloc(sizeof(AST_Node));
    node->type = AST_NUMBER;
    node->data.number.value = value;
    return node;
}

static AST_Node* AST_Node_new_variable(const char* name) {
    AST_Node* node = malloc(sizeof(AST_Node));
    node->type = AST_VARIABLE;
    node->data.variable.name = strdup(name);
    return node;
}

static AST_Node* AST_Node_new_binary_op(char op, AST_Node* left, AST_Node* right) {
    AST_BinaryOp* binary_op = malloc(sizeof(AST_BinaryOp));
    binary_op->op = op;
    binary_op->left = left;
    binary_op->right = right;
    
    AST_Node* node = malloc(sizeof(AST_Node));
    node->type = AST_BINARY_OP;
    node->data.binary_op = binary_op;
    return node;
}

static AST_Node* AST_Node_new_assignment(const char* var_name, AST_Node* expr) {
    AST_Assignment* assignment = malloc(sizeof(AST_Assignment));
    assignment->var_name = strdup(var_name);
    assignment->expr = expr;
    
    AST_Node* node = malloc(sizeof(AST_Node));
    node->type = AST_ASSIGNMENT;
    node->data.assignment = assignment;
    return node;
}

static void AST_Node_free(AST_Node* node) {
    if (!node) return;
    
    switch (node->type) {
        case AST_VARIABLE:
            free(node->data.variable.name);
            break;
        case AST_BINARY_OP:
            AST_Node_free(node->data.binary_op->left);
            AST_Node_free(node->data.binary_op->right);
            free(node->data.binary_op);
            break;
        case AST_ASSIGNMENT:
            free(node->data.assignment->var_name);
            AST_Node_free(node->data.assignment->expr);
            free(node->data.assignment);
            break;
        default:
            break;
    }
    free(node);
}

// Парсер
typedef struct {
    const char* input;
    size_t pos;
    char current_char;
} CalculatorAST_Parser;

static AST_Node* CalculatorAST_Parser_parse_expression(CalculatorAST_Parser* parser);

static void CalculatorAST_Parser_init(CalculatorAST_Parser* parser, const char* input) {
    parser->input = input;
    parser->pos = 0;
    parser->current_char = input[0];
}

static void CalculatorAST_Parser_advance(CalculatorAST_Parser* parser) {
    parser->pos++;
    parser->current_char = parser->input[parser->pos];
}

static void CalculatorAST_Parser_skip_whitespace(CalculatorAST_Parser* parser) {
    while (parser->current_char && isspace((unsigned char)parser->current_char)) {
        CalculatorAST_Parser_advance(parser);
    }
}

static AST_Node* CalculatorAST_Parser_parse_number(CalculatorAST_Parser* parser) {
    int64_t value = 0;
    while (parser->current_char && isdigit((unsigned char)parser->current_char)) {
        value = value * 10 + (parser->current_char - '0');
        CalculatorAST_Parser_advance(parser);
    }
    return AST_Node_new_number(value);
}

static AST_Node* CalculatorAST_Parser_parse_variable(CalculatorAST_Parser* parser) {
    size_t start = parser->pos;
    while (parser->current_char && 
           (isalpha((unsigned char)parser->current_char) || 
            isdigit((unsigned char)parser->current_char))) {
        CalculatorAST_Parser_advance(parser);
    }
    
    size_t len = parser->pos - start;
    char* var_name = malloc(len + 1);
    strncpy(var_name, parser->input + start, len);
    var_name[len] = '\0';
    
    CalculatorAST_Parser_skip_whitespace(parser);
    
    if (parser->current_char == '=') {
        CalculatorAST_Parser_advance(parser);
        AST_Node* expr = CalculatorAST_Parser_parse_expression(parser);
        AST_Node* node = AST_Node_new_assignment(var_name, expr);
        free(var_name);
        return node;
    }
    
    AST_Node* node = AST_Node_new_variable(var_name);
    free(var_name);
    return node;
}

static AST_Node* CalculatorAST_Parser_parse_factor(CalculatorAST_Parser* parser) {
    CalculatorAST_Parser_skip_whitespace(parser);
    
    if (!parser->current_char) {
        return AST_Node_new_number(0);
    }
    
    if (isdigit((unsigned char)parser->current_char)) {
        return CalculatorAST_Parser_parse_number(parser);
    }
    
    if (isalpha((unsigned char)parser->current_char)) {
        return CalculatorAST_Parser_parse_variable(parser);
    }
    
    if (parser->current_char == '(') {
        CalculatorAST_Parser_advance(parser);
        AST_Node* node = CalculatorAST_Parser_parse_expression(parser);
        CalculatorAST_Parser_skip_whitespace(parser);
        if (parser->current_char == ')') {
            CalculatorAST_Parser_advance(parser);
        }
        return node;
    }
    
    return AST_Node_new_number(0);
}

static AST_Node* CalculatorAST_Parser_parse_term(CalculatorAST_Parser* parser) {
    AST_Node* node = CalculatorAST_Parser_parse_factor(parser);
    
    while (1) {
        CalculatorAST_Parser_skip_whitespace(parser);
        if (!parser->current_char) break;
        
        if (parser->current_char == '*' || parser->current_char == '/' || parser->current_char == '%') {
            char op = parser->current_char;
            CalculatorAST_Parser_advance(parser);
            AST_Node* right = CalculatorAST_Parser_parse_factor(parser);
            node = AST_Node_new_binary_op(op, node, right);
        } else {
            break;
        }
    }
    
    return node;
}

static AST_Node* CalculatorAST_Parser_parse_expression(CalculatorAST_Parser* parser) {
    AST_Node* node = CalculatorAST_Parser_parse_term(parser);
    
    while (1) {
        CalculatorAST_Parser_skip_whitespace(parser);
        if (!parser->current_char) break;
        
        if (parser->current_char == '+' || parser->current_char == '-') {
            char op = parser->current_char;
            CalculatorAST_Parser_advance(parser);
            AST_Node* right = CalculatorAST_Parser_parse_term(parser);
            node = AST_Node_new_binary_op(op, node, right);
        } else {
            break;
        }
    }
    
    return node;
}

static void CalculatorAST_Parser_parse_all(CalculatorAST_Parser* parser, CalculatorAST* ast) {
    ast->expressions_count = 0;
    
    while (parser->current_char) {
        CalculatorAST_Parser_skip_whitespace(parser);
        if (!parser->current_char) break;
        
        if (ast->expressions_count >= ast->expressions_capacity) {
            ast->expressions_capacity = ast->expressions_capacity ? ast->expressions_capacity * 2 : 16;
            ast->expressions = realloc(ast->expressions, ast->expressions_capacity * sizeof(AST_Node*));
        }
        
        ast->expressions[ast->expressions_count++] = CalculatorAST_Parser_parse_expression(parser);
    }
}

static char* CalculatorAST_generate_random_program(int n) {
    size_t capacity = n * 100;
    char* result = malloc(capacity);
    size_t len = 0;
    
    len += snprintf(result + len, capacity - len, "v0 = 1\n");
    for (int i = 0; i < 10; i++) {
        len += snprintf(result + len, capacity - len, "v%d = v%d + %d\n", i + 1, i, i + 1);
    }
    
    for (int i = 0; i < n; i++) {
        int v = i + 10;
        
        len += snprintf(result + len, capacity - len, "v%d = v%d + ", v, v - 1);
        
        switch (Helper_next_int(10)) {
            case 0:
                len += snprintf(result + len, capacity - len, 
                               "(v%d / 3) * 4 - %d / (3 + (18 - v%d)) %% v%d + 2 * ((9 - v%d) * (v%d + 7))",
                               v - 1, i, v - 2, v - 3, v - 6, v - 5);
                break;
            case 1:
                len += snprintf(result + len, capacity - len,
                               "v%d + (v%d + v%d) * v%d - (v%d / v%d)",
                               v - 1, v - 2, v - 3, v - 4, v - 5, v - 6);
                break;
            case 2:
                len += snprintf(result + len, capacity - len, "(3789 - (((v%d)))) + 1", v - 7);
                break;
            case 3:
                len += snprintf(result + len, capacity - len, "4/2 * (1-3) + v%d/v%d", v - 9, v - 5);
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
                len += snprintf(result + len, capacity - len, "((((((((((v%d)))))))))) * 2", v - 6);
                break;
            case 8:
                len += snprintf(result + len, capacity - len, "%d * (v%d%%6)%%7", i, v - 1);
                break;
            case 9:
                len += snprintf(result + len, capacity - len, "(1)/(0-v%d) + (v%d)", v - 5, v - 7);
                break;
        }
        len += snprintf(result + len, capacity - len, "\n");
    }
    
    return result;
}

int64_t CalculatorAST_run(void* self) {
    CalculatorAST* bench = (CalculatorAST*)self;
    
    CalculatorAST_Parser parser;
    CalculatorAST_Parser_init(&parser, bench->text);
    CalculatorAST_Parser_parse_all(&parser, bench);
    
    bench->result_val = bench->expressions_count;
    return (int64_t)bench->result_val;
}

void CalculatorAST_prepare(void* self) {
    CalculatorAST* bench = (CalculatorAST*)self;
    bench->text = CalculatorAST_generate_random_program(bench->n);
    bench->expressions = NULL;
    bench->expressions_count = 0;
    bench->expressions_capacity = 0;
    bench->result_val = 0;
}

void CalculatorAST_cleanup(void* self) {
    CalculatorAST* bench = (CalculatorAST*)self;
        
    if (bench->text) {
        free(bench->text);
        bench->text = NULL;
    }
    
    if (bench->expressions) {
        for (int i = 0; i < bench->expressions_count; i++) {
            if (bench->expressions[i]) {
                AST_Node_free(bench->expressions[i]);
                bench->expressions[i] = NULL;
            }
        }
        free(bench->expressions);
        bench->expressions = NULL;
    }
    
    free(bench);
}

Benchmark* CalculatorAST_new(void) {
    CalculatorAST* instance = malloc(sizeof(CalculatorAST));
    instance->text = NULL;
    instance->expressions = NULL;
    instance->expressions_count = 0;
    instance->expressions_capacity = 0;
    instance->result_val = 0;
    const char* input = Helper_get_input("CalculatorAst");
    instance->n = input ? atoi(input) : 100;

    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "CalculatorAst";
    bench->run = CalculatorAST_run;
    bench->prepare = CalculatorAST_prepare;
    bench->cleanup = CalculatorAST_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// CalculatorInterpreter (интерпретатор AST)
// ============================================================================

// Структура для элемента хеш-таблицы
typedef struct VariableEntry {
    char* name;                // ключ
    int64_t value;             // значение
    UT_hash_handle hh;         // для uthash
} VariableEntry;

typedef struct {
    VariableEntry* variables_hash;  // хеш-таблица переменных
} CalculatorInterpreter_Context;

static CalculatorInterpreter_Context* CalculatorInterpreter_Context_new(void) {
    CalculatorInterpreter_Context* ctx = malloc(sizeof(CalculatorInterpreter_Context));
    ctx->variables_hash = NULL;
    return ctx;
}

static void CalculatorInterpreter_Context_free(CalculatorInterpreter_Context* ctx) {
    VariableEntry *entry, *tmp;
    
    // Освобождаем все элементы хеш-таблицы
    HASH_ITER(hh, ctx->variables_hash, entry, tmp) {
        free(entry->name);
        HASH_DEL(ctx->variables_hash, entry);
        free(entry);
    }
    
    free(ctx);
}

static int64_t* CalculatorInterpreter_Context_get(CalculatorInterpreter_Context* ctx, const char* name) {
    VariableEntry* entry = NULL;
    
    // Быстрый поиск O(1) в среднем
    HASH_FIND_STR(ctx->variables_hash, name, entry);
    
    return entry ? &entry->value : NULL;
}

static void CalculatorInterpreter_Context_set(CalculatorInterpreter_Context* ctx, const char* name, int64_t value) {
    VariableEntry* entry = NULL;
    
    // Ищем существующую переменную
    HASH_FIND_STR(ctx->variables_hash, name, entry);
    
    if (entry) {
        // Переменная существует - обновляем значение
        entry->value = value;
    } else {
        // Создаем новую запись
        entry = malloc(sizeof(VariableEntry));
        entry->name = strdup(name);
        entry->value = value;
        
        // Добавляем в хеш-таблицу
        HASH_ADD_KEYPTR(hh, ctx->variables_hash, entry->name, strlen(entry->name), entry);
    }
}

// Функции CalculatorInterpreter_simple_div и CalculatorInterpreter_simple_mod остаются без изменений

static int64_t CalculatorInterpreter_simple_div(int64_t a, int64_t b) {
    if (b == 0) return 0;
    if ((a >= 0 && b > 0) || (a < 0 && b < 0)) {
        return a / b;
    } else {
        return -(llabs(a) / llabs(b));
    }
}

static int64_t CalculatorInterpreter_simple_mod(int64_t a, int64_t b) {
    if (b == 0) return 0;
    return a - CalculatorInterpreter_simple_div(a, b) * b;
}

static int64_t CalculatorInterpreter_evaluate(AST_Node* node, CalculatorInterpreter_Context* ctx) {
    switch (node->type) {
        case AST_NUMBER:
            return node->data.number.value;
            
        case AST_VARIABLE: {
            int64_t* value = CalculatorInterpreter_Context_get(ctx, node->data.variable.name);
            return value ? *value : 0;
        }
            
        case AST_BINARY_OP: {
            int64_t left = CalculatorInterpreter_evaluate(node->data.binary_op->left, ctx);
            int64_t right = CalculatorInterpreter_evaluate(node->data.binary_op->right, ctx);
            
            switch (node->data.binary_op->op) {
                case '+': return left + right;
                case '-': return left - right;
                case '*': return left * right;
                case '/': return CalculatorInterpreter_simple_div(left, right);
                case '%': return CalculatorInterpreter_simple_mod(left, right);
                default: return 0;
            }
        }
            
        case AST_ASSIGNMENT: {
            int64_t value = CalculatorInterpreter_evaluate(node->data.assignment->expr, ctx);
            CalculatorInterpreter_Context_set(ctx, node->data.assignment->var_name, value);
            return value;
        }
    }
    return 0;
}

typedef struct {
    CalculatorAST ast;
    int64_t result_val;
} CalculatorInterpreter;

int64_t CalculatorInterpreter_run(void* self) {
    CalculatorInterpreter* bench = (CalculatorInterpreter*)self;
    
    int64_t total = 0;
    for (int i = 0; i < 100; i++) {
        CalculatorInterpreter_Context* ctx = CalculatorInterpreter_Context_new();
        int64_t result = 0;
        
        for (int j = 0; j < bench->ast.expressions_count; j++) {
            result = CalculatorInterpreter_evaluate(bench->ast.expressions[j], ctx);
        }
        
        total += result;
        CalculatorInterpreter_Context_free(ctx);
    }
    
    bench->result_val = total;
    return bench->result_val;
}

// Остальной код остался без изменений
void CalculatorInterpreter_prepare(void* self) {
    CalculatorInterpreter* bench = (CalculatorInterpreter*)self;
    const char* input = Helper_get_input("CalculatorInterpreter");
    int n = input ? atoi(input) : 100;
    
    CalculatorAST *ast = &bench->ast;
    ast->n = n;
    CalculatorAST_prepare(&bench->ast);
    CalculatorAST_run(&bench->ast);
    
    bench->result_val = 0;
}

void CalculatorInterpreter_cleanup(void* self) {
    CalculatorInterpreter* bench = (CalculatorInterpreter*)self;
    CalculatorAST_cleanup(&bench->ast);
}

Benchmark* CalculatorInterpreter_new(void) {
    CalculatorInterpreter* instance = malloc(sizeof(CalculatorInterpreter));
    memset(&instance->ast, 0, sizeof(CalculatorAST));
    instance->result_val = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "CalculatorInterpreter";
    bench->run = CalculatorInterpreter_run;
    bench->prepare = CalculatorInterpreter_prepare;
    bench->cleanup = CalculatorInterpreter_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Игра "Жизнь" (Game of Life)
// ============================================================================

typedef enum {
    CELL_DEAD,
    CELL_ALIVE
} Cell1;

typedef struct {
    int width;
    int height;
    Cell1** cells;
} Grid;

static Grid* Grid_new(int width, int height) {
    Grid* grid = malloc(sizeof(Grid));
    grid->width = width;
    grid->height = height;
    
    grid->cells = malloc(height * sizeof(Cell1*));
    for (int i = 0; i < height; i++) {
        grid->cells[i] = malloc(width * sizeof(Cell1));
        for (int j = 0; j < width; j++) {
            grid->cells[i][j] = CELL_DEAD;
        }
    }
    
    return grid;
}

static void Grid_free(Grid* grid) {
    for (int i = 0; i < grid->height; i++) {
        free(grid->cells[i]);
    }
    free(grid->cells);
    free(grid);
}

static Cell1 Grid_get(Grid* grid, int x, int y) {
    return grid->cells[y][x];
}

static void Grid_set(Grid* grid, int x, int y, Cell1 cell) {
    grid->cells[y][x] = cell;
}

static int Grid_count_neighbors(Grid* grid, int x, int y) {
    int count = 0;
    
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            
            // Тороидальные координаты - правильная обработка
            int nx = (x + dx + grid->width) % grid->width;
            int ny = (y + dy + grid->height) % grid->height;
            
            if (grid->cells[ny][nx] == CELL_ALIVE) {
                count++;
            }
        }
    }
    
    return count;
}

static Grid* Grid_next_generation(Grid* grid) {
    Grid* next_grid = Grid_new(grid->width, grid->height);
    
    for (int y = 0; y < grid->height; y++) {
        for (int x = 0; x < grid->width; x++) {
            int neighbors = Grid_count_neighbors(grid, x, y);
            Cell1 current = grid->cells[y][x];
            
            Cell1 next_state;
            if (current == CELL_ALIVE && (neighbors == 2 || neighbors == 3)) {
                next_state = CELL_ALIVE;
            } else if (current == CELL_ALIVE) {
                next_state = CELL_DEAD;
            } else if (current == CELL_DEAD && neighbors == 3) {
                next_state = CELL_ALIVE;
            } else {
                next_state = CELL_DEAD;
            }
            
            next_grid->cells[y][x] = next_state;
        }
    }
    
    return next_grid;
}

static int Grid_alive_count(Grid* grid) {
    int count = 0;
    for (int y = 0; y < grid->height; y++) {
        for (int x = 0; x < grid->width; x++) {
            if (grid->cells[y][x] == CELL_ALIVE) {
                count++;
            }
        }
    }
    return count;
}

typedef struct {
    int64_t result;
    int width;
    int height;
    Grid* grid;
} GameOfLife;

static int64_t GameOfLife_run(void* self) {
    GameOfLife* bench = (GameOfLife*)self;
    
    // Инициализация случайными клетками
    for (int y = 0; y < bench->height; y++) {
        for (int x = 0; x < bench->width; x++) {
            if (Helper_next_float(1.0) < 0.1) {
                Grid_set(bench->grid, x, y, CELL_ALIVE);
            }
        }
    }
    
    const char* input = Helper_get_input("GameOfLife");
    int iterations = input ? atoi(input) : 100;

    for (int i = 0; i < iterations; i++) {
        Grid* next_grid = Grid_next_generation(bench->grid);
        Grid_free(bench->grid);
        bench->grid = next_grid;
    }
    
    bench->result = Grid_alive_count(bench->grid);
    return bench->result;
}

static void GameOfLife_prepare(void* self) {
    GameOfLife* bench = (GameOfLife*)self;
    bench->result = 0;
    bench->width = 256;
    bench->height = 256;
    bench->grid = Grid_new(bench->width, bench->height);
}

static void GameOfLife_cleanup(void* self) {
    GameOfLife* bench = (GameOfLife*)self;
    Grid_free(bench->grid);
    free(bench);
}

Benchmark* GameOfLife_new(void) {
    GameOfLife* instance = malloc(sizeof(GameOfLife));
    instance->result = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "GameOfLife";
    bench->run = GameOfLife_run;
    bench->prepare = GameOfLife_prepare;
    bench->cleanup = GameOfLife_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// Генератор лабиринта (MazeGenerator)
// ============================================================================

typedef enum {
    MAZE_WALL,
    MAZE_PATH
} MazeCell;

typedef struct {
    int width;
    int height;
    MazeCell** cells;
} Maze;

static Maze* Maze_new(int width, int height) {
    if (width < 5) width = 5;
    if (height < 5) height = 5;
    
    Maze* maze = malloc(sizeof(Maze));
    maze->width = width;
    maze->height = height;
    
    maze->cells = malloc(height * sizeof(MazeCell*));
    for (int i = 0; i < height; i++) {
        maze->cells[i] = malloc(width * sizeof(MazeCell));
        for (int j = 0; j < width; j++) {
            maze->cells[i][j] = MAZE_WALL;
        }
    }
    
    return maze;
}

static void Maze_free(Maze* maze) {
    for (int i = 0; i < maze->height; i++) {
        free(maze->cells[i]);
    }
    free(maze->cells);
    free(maze);
}

static MazeCell Maze_get(Maze* maze, int x, int y) {
    return maze->cells[y][x];
}

static void Maze_set(Maze* maze, int x, int y, MazeCell value) {
    maze->cells[y][x] = value;
}

static void Maze_divide(Maze* maze, int x1, int y1, int x2, int y2);

static void Maze_generate(Maze* maze) {
    if (maze->width < 5 || maze->height < 5) {
        for (int x = 0; x < maze->width; x++) {
            Maze_set(maze, x, maze->height / 2, MAZE_PATH);
        }
        return;
    }
    
    Maze_divide(maze, 0, 0, maze->width - 1, maze->height - 1);
}

static void Maze_divide(Maze* maze, int x1, int y1, int x2, int y2) {
    int width = x2 - x1;
    int height = y2 - y1;
    
    if (width < 2 || height < 2) return;
    
    int width_for_wall = width - 2;
    int height_for_wall = height - 2;
    int width_for_hole = width - 1;
    int height_for_hole = height - 1;
    
    if (width_for_wall <= 0 || height_for_wall <= 0 ||
        width_for_hole <= 0 || height_for_hole <= 0) {
        return;
    }
    
    if (width > height) {
        // Вертикальная стена
        int wall_range = width_for_wall / 2;
        if (wall_range < 1) wall_range = 1;
        
        // Исправление: правильная генерация случайных чисел
        int wall_offset = (wall_range > 0) ? (Helper_next_int(wall_range)) * 2 : 0;
        int wall_x = x1 + 2 + wall_offset;
        
        int hole_range = height_for_hole / 2;
        if (hole_range < 1) hole_range = 1;
        
        int hole_offset = (hole_range > 0) ? (Helper_next_int(hole_range)) * 2 : 0;
        int hole_y = y1 + 1 + hole_offset;
        
        if (wall_x > x2 || hole_y > y2) return;
        
        for (int y = y1; y <= y2; y++) {
            if (y != hole_y) {
                Maze_set(maze, wall_x, y, MAZE_WALL);
            }
        }
        
        if (wall_x > x1 + 1) {
            Maze_divide(maze, x1, y1, wall_x - 1, y2);
        }
        if (wall_x + 1 < x2) {
            Maze_divide(maze, wall_x + 1, y1, x2, y2);
        }
    } else {
        // Горизонтальная стена
        int wall_range = height_for_wall / 2;
        if (wall_range < 1) wall_range = 1;
        
        int wall_offset = (wall_range > 0) ? (Helper_next_int(wall_range)) * 2 : 0;
        int wall_y = y1 + 2 + wall_offset;
        
        int hole_range = width_for_hole / 2;
        if (hole_range < 1) hole_range = 1;
        
        int hole_offset = (hole_range > 0) ? (Helper_next_int(hole_range)) * 2 : 0;
        int hole_x = x1 + 1 + hole_offset;
        
        if (wall_y > y2 || hole_x > x2) return;
        
        for (int x = x1; x <= x2; x++) {
            if (x != hole_x) {
                Maze_set(maze, x, wall_y, MAZE_WALL);
            }
        }
        
        if (wall_y > y1 + 1) {
            Maze_divide(maze, x1, y1, x2, wall_y - 1);
        }
        if (wall_y + 1 < y2) {
            Maze_divide(maze, x1, wall_y + 1, x2, y2);
        }
    }
}

static bool** Maze_to_bool_grid(Maze* maze) {
    bool** result = malloc(maze->height * sizeof(bool*));
    for (int y = 0; y < maze->height; y++) {
        result[y] = malloc(maze->width * sizeof(bool));
        for (int x = 0; x < maze->width; x++) {
            result[y][x] = (Maze_get(maze, x, y) == MAZE_PATH);
        }
    }
    return result;
}

static void free_bool_grid(bool** grid, int height) {
    for (int i = 0; i < height; i++) {
        free(grid[i]);
    }
    free(grid);
}

typedef struct {
    int64_t result;
    int width;
    int height;
} MazeGenerator;

static bool** MazeGenerator_generate_walkable_maze(int width, int height);

static int64_t MazeGenerator_run(void* self) {
    MazeGenerator* bench = (MazeGenerator*)self;
    uint64_t checksum = 0;

    const char* input = Helper_get_input("MazeGenerator");
    int iterations = input ? atoi(input) : 100;
    
    for (int i = 0; i < iterations; i++) {
        bool** bool_grid = MazeGenerator_generate_walkable_maze(bench->width, bench->height);
        
        // Простая checksum для сравнения
        for (int y = 0; y < bench->height; y++) {
            for (int x = 0; x < bench->width; x++) {
                if (!bool_grid[y][x]) {
                    checksum = checksum + (x * y);
                }
            }
        }
        
        free_bool_grid(bool_grid, bench->height);
    }
    
    bench->result = (int64_t)checksum;
    return bench->result;
}

static void MazeGenerator_prepare(void* self) {
    MazeGenerator* bench = (MazeGenerator*)self;
    bench->result = 0;
    bench->width = 1001;
    bench->height = 1001;
}

static void MazeGenerator_cleanup(void* self) {
    free(self);
}

Benchmark* MazeGenerator_new(void) {
    MazeGenerator* instance = malloc(sizeof(MazeGenerator));
    instance->result = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "MazeGenerator";
    bench->run = MazeGenerator_run;
    bench->prepare = MazeGenerator_prepare;
    bench->cleanup = MazeGenerator_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ============================================================================
// A* поиск пути (AStarPathfinder)
// ============================================================================

typedef struct {
    int64_t result;
    int width;
    int height;
    int start_x;
    int start_y;
    int goal_x;
    int goal_y;
    bool** maze_grid;
} AStarPathfinder;

// Эвристики
typedef struct {
    int (*distance)(int a_x, int a_y, int b_x, int b_y);
} Heuristic;

static int Manhattan_distance(int a_x, int a_y, int b_x, int b_y) {
    return (abs(a_x - b_x) + abs(a_y - b_y)) * 1000;
}

static int Euclidean_distance(int a_x, int a_y, int b_x, int b_y) {
    double dx = abs(a_x - b_x);
    double dy = abs(a_y - b_y);
    return (int)(hypot(dx, dy) * 1000.0);
}

static int Chebyshev_distance(int a_x, int a_y, int b_x, int b_y) {
    int dx = abs(a_x - b_x);
    int dy = abs(a_y - b_y);
    return (dx > dy ? dx : dy) * 1000;
}

static Heuristic ManhattanHeuristic = {Manhattan_distance};
static Heuristic EuclideanHeuristic = {Euclidean_distance};
static Heuristic ChebyshevHeuristic = {Chebyshev_distance};

// Узел для A*
typedef struct {
    int x;
    int y;
    int f_score;
} Node;

// Бинарная куча (минимальная)
typedef struct {
    Node* data;
    int size;
    int capacity;
} BinaryHeap;

static BinaryHeap* BinaryHeap_new(int capacity) {
    BinaryHeap* heap = malloc(sizeof(BinaryHeap));
    heap->data = malloc(capacity * sizeof(Node));
    heap->size = 0;
    heap->capacity = capacity;
    return heap;
}

static void BinaryHeap_free(BinaryHeap* heap) {
    free(heap->data);
    free(heap);
}

static void BinaryHeap_swap(BinaryHeap* heap, int i, int j) {
    Node temp = heap->data[i];
    heap->data[i] = heap->data[j];
    heap->data[j] = temp;
}

static void BinaryHeap_sift_up(BinaryHeap* heap, int index) {
    while (index > 0) {
        int parent = (index - 1) / 2;
        if (heap->data[index].f_score >= heap->data[parent].f_score) break;
        BinaryHeap_swap(heap, index, parent);
        index = parent;
    }
}

static void BinaryHeap_sift_down(BinaryHeap* heap, int index) {
    while (1) {
        int left = index * 2 + 1;
        int right = left + 1;
        int smallest = index;
        
        if (left < heap->size && heap->data[left].f_score < heap->data[smallest].f_score) {
            smallest = left;
        }
        
        if (right < heap->size && heap->data[right].f_score < heap->data[smallest].f_score) {
            smallest = right;
        }
        
        if (smallest == index) break;
        
        BinaryHeap_swap(heap, index, smallest);
        index = smallest;
    }
}

static void BinaryHeap_push(BinaryHeap* heap, Node node) {
    if (heap->size >= heap->capacity) {
        heap->capacity *= 2;
        heap->data = realloc(heap->data, heap->capacity * sizeof(Node));
    }
    
    heap->data[heap->size] = node;
    BinaryHeap_sift_up(heap, heap->size);
    heap->size++;
}

static Node BinaryHeap_pop(BinaryHeap* heap) {
    if (heap->size == 0) {
        Node null_node = {0, 0, 0};
        return null_node;
    }
    
    Node result = heap->data[0];
    heap->size--;
    
    if (heap->size > 0) {
        heap->data[0] = heap->data[heap->size];
        BinaryHeap_sift_down(heap, 0);
    }
    
    return result;
}

static bool BinaryHeap_empty(BinaryHeap* heap) {
    return heap->size == 0;
}

static bool** MazeGenerator_generate_walkable_maze(int width, int height) {
    Maze* maze = Maze_new(width, height);
    Maze_generate(maze);
    
    // Проверка связности (упрощенная версия)
    // Или добавление путей по краям как в C#
    
    // Просто добавляем пути по краям как в C#/Java
    for (int x = 0; x < width; x++) {
        for (int y = 0; y < height; y++) {
            if (x == 1 || y == 1 || x == width - 2 || y == height - 2) {
                Maze_set(maze, x, y, MAZE_PATH);
            }
        }
    }
    
    bool** result = Maze_to_bool_grid(maze);
    Maze_free(maze);
    return result;
}

static int64_t AStarPathfinder_run(void* self) {
    AStarPathfinder* bench = (AStarPathfinder*)self;
    
    int total_paths_found = 0;
    int total_path_length = 0;
    int total_nodes_explored = 0;
    
    Heuristic heuristics[] = {ManhattanHeuristic, EuclideanHeuristic, ChebyshevHeuristic};
    int heuristic_count = 3;
    
    for (int iter = 0; iter < 10; iter++) {
        for (int h = 0; h < heuristic_count; h++) {
            Heuristic heuristic = heuristics[h];
            
            // 1. Ищем путь (ПЕРВЫЙ запуск A*)
            int path_found = 0;
            int path_length = 0;
            
            int** g_scores = malloc(bench->height * sizeof(int*));
            int** came_from_x = malloc(bench->height * sizeof(int*));
            int** came_from_y = malloc(bench->height * sizeof(int*));
            
            for (int i = 0; i < bench->height; i++) {
                g_scores[i] = malloc(bench->width * sizeof(int));
                came_from_x[i] = malloc(bench->width * sizeof(int));
                came_from_y[i] = malloc(bench->width * sizeof(int));
                
                for (int j = 0; j < bench->width; j++) {
                    g_scores[i][j] = INT_MAX;
                    came_from_x[i][j] = -1;
                    came_from_y[i][j] = -1;
                }
            }
            
            BinaryHeap* open_set = BinaryHeap_new(bench->width * bench->height);
            
            g_scores[bench->start_y][bench->start_x] = 0;
            Node start_node = {bench->start_x, bench->start_y, 
                              heuristic.distance(bench->start_x, bench->start_y, 
                                              bench->goal_x, bench->goal_y)};
            BinaryHeap_push(open_set, start_node);
            
            // Поиск пути (без closed массива, как в C++ find_path)
            while (!BinaryHeap_empty(open_set)) {
                Node current = BinaryHeap_pop(open_set);
                
                if (current.x == bench->goal_x && current.y == bench->goal_y) {
                    path_found = 1;
                    int x = current.x;
                    int y = current.y;
                    
                    while (x != bench->start_x || y != bench->start_y) {
                        path_length++;
                        int prev_x = came_from_x[y][x];
                        int prev_y = came_from_y[y][x];
                        x = prev_x;
                        y = prev_y;
                    }
                    path_length++; // добавляем стартовую точку
                    break;
                }
                
                int directions[4][2] = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}};
                
                for (int d = 0; d < 4; d++) {
                    int nx = current.x + directions[d][0];
                    int ny = current.y + directions[d][1];
                    
                    if (nx < 0 || nx >= bench->width || ny < 0 || ny >= bench->height) 
                        continue;
                    if (!bench->maze_grid[ny][nx]) 
                        continue;
                    
                    int tentative_g = g_scores[current.y][current.x] + 1000;
                    
                    if (tentative_g < g_scores[ny][nx]) {
                        came_from_x[ny][nx] = current.x;
                        came_from_y[ny][nx] = current.y;
                        g_scores[ny][nx] = tentative_g;
                        
                        int f_score = tentative_g + heuristic.distance(nx, ny, bench->goal_x, bench->goal_y);
                        Node next_node = {nx, ny, f_score};
                        BinaryHeap_push(open_set, next_node);
                    }
                }
            }
            
            // Освобождаем память после первого запуска
            BinaryHeap_free(open_set);
            for (int i = 0; i < bench->height; i++) {
                free(g_scores[i]);
                free(came_from_x[i]);
                free(came_from_y[i]);
            }
            free(g_scores);
            free(came_from_x);
            free(came_from_y);
            
            // 2. Если путь найден, ВТОРОЙ запуск A* для подсчета узлов
            if (path_found) {
                total_paths_found++;
                total_path_length += path_length;
                
                // ВТОРОЙ независимый запуск A* (как estimate_nodes_explored в C++)
                int nodes_explored = 0;
                
                // Создаем ВСЕ С НУЛЯ (как в C++)
                int** g_scores2 = malloc(bench->height * sizeof(int*));
                bool** closed = malloc(bench->height * sizeof(bool*));
                
                for (int i = 0; i < bench->height; i++) {
                    g_scores2[i] = malloc(bench->width * sizeof(int));
                    closed[i] = calloc(bench->width, sizeof(bool));
                    for (int j = 0; j < bench->width; j++) {
                        g_scores2[i][j] = INT_MAX;
                    }
                }
                
                BinaryHeap* open_set2 = BinaryHeap_new(bench->width * bench->height);
                
                g_scores2[bench->start_y][bench->start_x] = 0;
                Node start_node2 = {bench->start_x, bench->start_y, 
                                   heuristic.distance(bench->start_x, bench->start_y, 
                                                   bench->goal_x, bench->goal_y)};
                BinaryHeap_push(open_set2, start_node2);
                
                // Подсчет узлов (с closed массивом, как в C++)
                while (!BinaryHeap_empty(open_set2)) {
                    Node current = BinaryHeap_pop(open_set2);
                    
                    if (current.x == bench->goal_x && current.y == bench->goal_y) {
                        break;
                    }
                    
                    if (closed[current.y][current.x]) continue;
                    closed[current.y][current.x] = true;
                    nodes_explored++;
                    
                    int current_g = g_scores2[current.y][current.x];
                    
                    int directions[4][2] = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}};
                    
                    for (int d = 0; d < 4; d++) {
                        int nx = current.x + directions[d][0];
                        int ny = current.y + directions[d][1];
                        
                        if (nx < 0 || nx >= bench->width || ny < 0 || ny >= bench->height) 
                            continue;
                        if (!bench->maze_grid[ny][nx]) 
                            continue;
                        
                        int tentative_g = current_g + 1000;
                        
                        if (tentative_g < g_scores2[ny][nx]) {
                            g_scores2[ny][nx] = tentative_g;
                            
                            int f_score = tentative_g + heuristic.distance(nx, ny, bench->goal_x, bench->goal_y);
                            Node next_node = {nx, ny, f_score};
                            BinaryHeap_push(open_set2, next_node);
                        }
                    }
                }
                
                total_nodes_explored += nodes_explored;
                
                // Освобождаем память после второго запуска
                BinaryHeap_free(open_set2);
                for (int i = 0; i < bench->height; i++) {
                    free(g_scores2[i]);
                    free(closed[i]);
                }
                free(g_scores2);
                free(closed);
            }
        }
    }
    
    // Освобождаем лабиринт
    if (bench->maze_grid) {
        free_bool_grid(bench->maze_grid, bench->height);
        bench->maze_grid = NULL;
    }
    
    int64_t paths_checksum = Helper_checksum_f64(total_paths_found);
    int64_t length_checksum = Helper_checksum_f64(total_path_length);
    int64_t nodes_checksum = Helper_checksum_f64(total_nodes_explored);
    
    // Проверяем типы! В C++ checksum_f64 возвращает int64_t
    // Но сдвигаем на 16 и 32 бита - могут быть проблемы!
    bench->result = paths_checksum ^
                   (length_checksum << 16) ^
                   (nodes_checksum << 32);
    
    return bench->result;
}
static void AStarPathfinder_prepare(void* self) {
    AStarPathfinder* bench = (AStarPathfinder*)self;
    bench->result = 0;

    const char* input = Helper_get_input("AStarPathfinder");
    int n = input ? atoi(input) : 100;

    bench->width = n;
    bench->height = n;
    bench->start_x = 1;
    bench->start_y = 1;
    bench->goal_x = bench->width - 2;
    bench->goal_y = bench->height - 2;
    bench->maze_grid = MazeGenerator_generate_walkable_maze(bench->width, bench->height);            
}

static void AStarPathfinder_cleanup(void* self) {
    AStarPathfinder* bench = (AStarPathfinder*)self;
    if (bench->maze_grid) {
        free_bool_grid(bench->maze_grid, bench->height);
    }
    free(bench);
}

Benchmark* AStarPathfinder_new(void) {
    AStarPathfinder* instance = malloc(sizeof(AStarPathfinder));
    instance->result = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    bench->name = "AStarPathfinder";
    bench->run = AStarPathfinder_run;
    bench->prepare = AStarPathfinder_prepare;
    bench->cleanup = AStarPathfinder_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ==================== Compression Benchmark ====================

typedef struct {
    uint8_t* transformed;
    size_t transformed_size;
    size_t original_idx;
} BWTResult;

typedef struct HuffmanNode {
    int frequency;
    uint8_t byte_val;
    bool is_leaf;
    struct HuffmanNode* left;
    struct HuffmanNode* right;
} HuffmanNode;

typedef struct {
    int code_lengths[256];
    int codes[256];
} HuffmanCodes;

typedef struct {
    uint8_t* data;
    size_t data_size;
    int bit_count;
} EncodedResult;

typedef struct {
    BWTResult bwt_result;
    int frequencies[256];
    uint8_t* encoded_bits;
    size_t encoded_bits_size;
    int original_bit_count;
} CompressedData;

typedef struct {
    int iterations;
    uint32_t result;
    uint8_t* test_data;
    size_t test_data_size;
} Compression;

static BWTResult bwt_transform(uint8_t* input, size_t n) {
    BWTResult result = {0};
    
    if (n == 0 || !input) {
        return result;
    }
    
    // 1. Создаём удвоенную строку
    uint8_t* doubled = malloc(n * 2);
    if (!doubled) return result;
    memcpy(doubled, input, n);
    memcpy(doubled + n, input, n);
    
    // 2. Создаём суффиксный массив
    size_t* sa = malloc(sizeof(size_t) * n);
    if (!sa) {
        free(doubled);
        return result;
    }
    
    for (size_t i = 0; i < n; i++) {
        sa[i] = i;
    }
    
    // 3. Фаза 0: сортировка по первому символу (Radix sort)
    // Временные массивы для bucket sort
    size_t* temp_buffer = malloc(sizeof(size_t) * n);
    size_t bucket_counts[256] = {0};
    
    if (!temp_buffer) {
        free(doubled);
        free(sa);
        return result;
    }
    
    // Подсчитываем частоты
    for (size_t i = 0; i < n; i++) {
        bucket_counts[input[sa[i]]]++;
    }
    
    // Префиксные суммы
    size_t bucket_starts[256];
    size_t sum = 0;
    for (int i = 0; i < 256; i++) {
        bucket_starts[i] = sum;
        sum += bucket_counts[i];
    }
    
    // Распределяем
    for (size_t i = 0; i < n; i++) {
        uint8_t c = input[sa[i]];
        temp_buffer[bucket_starts[c]++] = sa[i];
    }
    
    // Копируем обратно
    memcpy(sa, temp_buffer, sizeof(size_t) * n);
    
    // 4. Фаза 1: сортировка по парам символов
    if (n > 1) {
        // Присваиваем ранги
        int* rank = malloc(sizeof(int) * n);
        if (!rank) {
            free(doubled);
            free(sa);
            free(temp_buffer);
            return result;
        }
        
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
        
        // Сортируем по парам (rank[i], rank[i+1])
        size_t k = 1;
        while (k < n) {
            // Создаём пары
            struct Pair { int first, second; };
            struct Pair* pairs = malloc(sizeof(struct Pair) * n);
            if (!pairs) {
                free(rank);
                free(doubled);
                free(sa);
                free(temp_buffer);
                return result;
            }
            
            for (size_t i = 0; i < n; i++) {
                pairs[i].first = rank[i];
                pairs[i].second = rank[(i + k) % n];
            }
            
            // Counting sort по второму элементу
            int* count = calloc(n + 1, sizeof(int)); // Выделяем n+1 элементов
            if (!count) {
                free(pairs);
                free(rank);
                free(doubled);
                free(sa);
                free(temp_buffer);
                return result;
            }
            
            // Считаем частоты (сдвиг на 1 для counting sort)
            for (size_t i = 0; i < n; i++) {
                count[pairs[sa[i]].second]++;
            }
            
            // Префиксные суммы
            for (int i = 1; i <= n; i++) {
                count[i] += count[i - 1];
            }
            
            // Сортировка по второму ключу
            memcpy(temp_buffer, sa, sizeof(size_t) * n);
            for (int i = n - 1; i >= 0; i--) {
                int key = pairs[temp_buffer[i]].second;
                sa[--count[key]] = temp_buffer[i];
            }
            
            // Counting sort по первому элементу
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
            
            // Обновляем ранги
            int* new_rank = malloc(sizeof(int) * n);
            if (!new_rank) {
                free(count);
                free(pairs);
                free(rank);
                free(doubled);
                free(sa);
                free(temp_buffer);
                return result;
            }
            
            new_rank[sa[0]] = 0;
            for (size_t i = 1; i < n; i++) {
                struct Pair prev_pair = pairs[sa[i - 1]];
                struct Pair curr_pair = pairs[sa[i]];
                new_rank[sa[i]] = new_rank[sa[i - 1]] + 
                    (prev_pair.first != curr_pair.first || prev_pair.second != curr_pair.second ? 1 : 0);
            }
            
            free(count);
            free(pairs);
            free(rank);
            rank = new_rank;
            k *= 2;
        }
        
        free(rank);
    }
    
    // 5. Собираем BWT результат
    result.transformed = malloc(n);
    result.transformed_size = n;
    result.original_idx = 0;
    
    if (!result.transformed) {
        free(doubled);
        free(sa);
        free(temp_buffer);
        return result;
    }
    
    for (size_t i = 0; i < n; i++) {
        size_t suffix = sa[i];
        if (suffix == 0) {
            result.transformed[i] = input[n - 1];
            result.original_idx = i;
        } else {
            result.transformed[i] = input[suffix - 1];
        }
    }
    
    // Очистка
    free(doubled);
    free(sa);
    free(temp_buffer);
    
    return result;
}

static uint8_t* bwt_inverse(BWTResult* bwt_result, size_t* result_size) {
    uint8_t* bwt = bwt_result->transformed;
    size_t n = bwt_result->transformed_size;
    
    if (n == 0) {
        *result_size = 0;
        return NULL;
    }
    
    // 1. Подсчитываем частоты символов
    int counts[256] = {0};
    for (size_t i = 0; i < n; i++) {
        counts[bwt[i]]++;
    }
    
    // 2. Вычисляем стартовые позиции
    int positions[256];
    int total = 0;
    for (int i = 0; i < 256; i++) {
        positions[i] = total;
        total += counts[i];
    }
    
    // 3. Строим массив next
    size_t* next = malloc(sizeof(size_t) * n);
    if (!next) {
        *result_size = 0;
        return NULL;
    }
    
    int temp_counts[256] = {0};
    
    for (size_t i = 0; i < n; i++) {
        int byte_idx = bwt[i];
        int pos = positions[byte_idx] + temp_counts[byte_idx];
        next[pos] = i;
        temp_counts[byte_idx]++;
    }
    
    // 4. Восстанавливаем строку
    uint8_t* result = malloc(n);
    if (!result) {
        free(next);
        *result_size = 0;
        return NULL;
    }
    
    size_t idx = bwt_result->original_idx;
    
    for (size_t i = 0; i < n; i++) {
        idx = next[idx];
        result[i] = bwt[idx];
    }
    
    free(next);
    *result_size = n;
    return result;
}

// ==================== Huffman функции ====================

static int compare_huffman_nodes(const void* a, const void* b) {
    HuffmanNode* node_a = *(HuffmanNode**)a;
    HuffmanNode* node_b = *(HuffmanNode**)b;
    return node_a->frequency - node_b->frequency;
}

static HuffmanNode* build_huffman_tree(int frequencies[256]) {
    // Создаём массив узлов
    HuffmanNode** nodes = malloc(sizeof(HuffmanNode*) * 256);
    if (!nodes) return NULL;
    
    int node_count = 0;
    
    for (int i = 0; i < 256; i++) {
        if (frequencies[i] > 0) {
            HuffmanNode* node = malloc(sizeof(HuffmanNode));
            if (!node) {
                for (int j = 0; j < node_count; j++) free(nodes[j]);
                free(nodes);
                return NULL;
            }
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
    
    // Если только один символ
    if (node_count == 1) {
        HuffmanNode* root = malloc(sizeof(HuffmanNode));
        if (!root) {
            free(nodes[0]);
            free(nodes);
            return NULL;
        }
        root->frequency = nodes[0]->frequency;
        root->byte_val = 0;
        root->is_leaf = false;
        root->left = nodes[0];
        
        root->right = malloc(sizeof(HuffmanNode));
        if (!root->right) {
            free(root);
            free(nodes[0]);
            free(nodes);
            return NULL;
        }
        root->right->frequency = 0;
        root->right->byte_val = 0;
        root->right->is_leaf = true;
        root->right->left = NULL;
        root->right->right = NULL;
        
        free(nodes);
        return root;
    }
    
    // Сортируем по частоте
    qsort(nodes, node_count, sizeof(HuffmanNode*), compare_huffman_nodes);
    
    // Строим дерево
    while (node_count > 1) {
        // Берём два наименьших узла
        HuffmanNode* left = nodes[0];
        HuffmanNode* right = nodes[1];
        
        // Создаём родительский узел
        HuffmanNode* parent = malloc(sizeof(HuffmanNode));
        if (!parent) {
            for (int i = 0; i < node_count; i++) free(nodes[i]);
            free(nodes);
            return NULL;
        }
        
        parent->frequency = left->frequency + right->frequency;
        parent->byte_val = 0;
        parent->is_leaf = false;
        parent->left = left;
        parent->right = right;
        
        // Убираем два узла, добавляем родителя
        nodes[0] = parent;
        for (int i = 1; i < node_count - 1; i++) {
            nodes[i] = nodes[i + 1];
        }
        node_count--;
        
        // Сортируем снова
        qsort(nodes, node_count, sizeof(HuffmanNode*), compare_huffman_nodes);
    }
    
    HuffmanNode* root = nodes[0];
    free(nodes);
    return root;
}

static void build_huffman_codes(HuffmanNode* node, int code, int length, HuffmanCodes* huffman_codes) {
    if (!node) return;
    
    if (node->is_leaf) {
        int idx = node->byte_val;
        huffman_codes->code_lengths[idx] = length;
        huffman_codes->codes[idx] = code;
    } else {
        if (node->left) {
            build_huffman_codes(node->left, code << 1, length + 1, huffman_codes);
        }
        if (node->right) {
            build_huffman_codes(node->right, (code << 1) | 1, length + 1, huffman_codes);
        }
    }
}

static void free_huffman_tree(HuffmanNode* node) {
    if (!node) return;
    if (!node->is_leaf) {
        free_huffman_tree(node->left);
        free_huffman_tree(node->right);
    }
    free(node);
}

static EncodedResult huffman_encode(uint8_t* data, size_t data_size, HuffmanCodes* huffman_codes) {
    EncodedResult result = {0};
    
    if (!data || data_size == 0 || !huffman_codes) {
        return result;
    }
    
    // Выделяем с запасом
    size_t max_size = data_size * 4;
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
        
        if (length <= 0) continue;
        
        for (int j = length - 1; j >= 0; j--) {
            if ((code & (1 << j)) != 0) {
                current_byte |= (1 << (7 - bit_pos));
            }
            bit_pos++;
            result.bit_count++;
            
            if (bit_pos == 8) {
                result.data[result.data_size++] = current_byte;
                current_byte = 0;
                bit_pos = 0;
            }
        }
    }
    
    if (bit_pos > 0) {
        result.data[result.data_size++] = current_byte;
    }
    
    return result;
}

static uint8_t* huffman_decode(uint8_t* encoded, size_t encoded_size, HuffmanNode* root, int bit_count, size_t* result_size) {
    if (!root || bit_count <= 0 || !encoded) {
        *result_size = 0;
        return NULL;
    }
    
    size_t max_size = bit_count;
    uint8_t* result = malloc(max_size);
    if (!result) {
        *result_size = 0;
        return NULL;
    }
    
    size_t result_idx = 0;
    HuffmanNode* current_node = root;
    int bits_processed = 0;
    size_t byte_index = 0;
    
    while (bits_processed < bit_count && byte_index < encoded_size) {
        uint8_t byte_val = encoded[byte_index++];
        
        for (int bit_pos = 7; bit_pos >= 0 && bits_processed < bit_count; bit_pos--) {
            int bit = (byte_val >> bit_pos) & 1;
            bits_processed++;
            
            current_node = bit ? current_node->right : current_node->left;
            
            if (!current_node) break;
            
            if (current_node->is_leaf) {
                result[result_idx++] = current_node->byte_val;
                current_node = root;
            }
        }
    }
    
    *result_size = result_idx;
    return result;
}

// ==================== Компрессор ====================

static CompressedData compress_data(uint8_t* data, size_t data_size) {
    CompressedData result = {0};
    
    if (!data || data_size == 0) {
        return result;
    }
    
    // Инициализируем frequencies нулями
    memset(result.frequencies, 0, sizeof(result.frequencies));
    
    // 1. BWT преобразование
    result.bwt_result = bwt_transform(data, data_size);
    if (!result.bwt_result.transformed) {
        return result;
    }

    // 2. Подсчёт частот
    for (size_t i = 0; i < result.bwt_result.transformed_size; i++) {
        result.frequencies[result.bwt_result.transformed[i]]++;
    }

    // 3. Построение дерева Huffman
    HuffmanNode* huffman_tree = build_huffman_tree(result.frequencies);
    if (!huffman_tree) {
        free(result.bwt_result.transformed);
        result.bwt_result.transformed = NULL;
        return result;
    }
    
    // 4. Построение кодов
    HuffmanCodes huffman_codes = {0};
    build_huffman_codes(huffman_tree, 0, 0, &huffman_codes);
    
    // 5. Кодирование
    EncodedResult encoded = huffman_encode(
        result.bwt_result.transformed,
        result.bwt_result.transformed_size,
        &huffman_codes
    );
    
    result.encoded_bits = encoded.data;
    result.encoded_bits_size = encoded.data_size;
    result.original_bit_count = encoded.bit_count;
    
    free_huffman_tree(huffman_tree);
    return result;
}

static uint8_t* decompress_data(CompressedData* compressed, size_t* result_size) {
    if (!compressed || !compressed->encoded_bits) {
        *result_size = 0;
        return NULL;
    }
    
    // 1. Восстанавливаем дерево Huffman
    HuffmanNode* huffman_tree = build_huffman_tree(compressed->frequencies);
    if (!huffman_tree) {
        *result_size = 0;
        return NULL;
    }
    
    // 2. Декодирование Huffman
    uint8_t* decoded = huffman_decode(
        compressed->encoded_bits,
        compressed->encoded_bits_size,
        huffman_tree,
        compressed->original_bit_count,
        result_size
    );
    
    if (!decoded) {
        free_huffman_tree(huffman_tree);
        *result_size = 0;
        return NULL;
    }
    
    // 3. Обратное BWT
    BWTResult bwt_result;
    bwt_result.transformed = decoded;
    bwt_result.transformed_size = *result_size;
    bwt_result.original_idx = compressed->bwt_result.original_idx;
    
    uint8_t* final_result = bwt_inverse(&bwt_result, result_size);
    
    free_huffman_tree(huffman_tree);
    free(decoded);
    return final_result;
}

static void free_compressed_data(CompressedData* compressed) {
    if (compressed) {
        free(compressed->bwt_result.transformed);
        free(compressed->encoded_bits);
    }
}

static uint8_t* generate_test_data(int size, size_t* data_size) {
    const char* pattern = "ABRACADABRA";
    size_t pattern_len = strlen(pattern);
    
    uint8_t* data = malloc(size);
    if (!data) {
        *data_size = 0;
        return NULL;
    }
    
    *data_size = size;
    
    for (int i = 0; i < size; i++) {
        data[i] = pattern[i % pattern_len];
    }
    
    return data;
}

static int64_t Compression_run(void* self) {
    Compression* bench = (Compression*)self;
    uint32_t total_checksum = 0;

    for (int i = 0; i < 5; i++) {
        // Компрессия
        CompressedData compressed = compress_data(bench->test_data, bench->test_data_size);

        if (!compressed.encoded_bits) {
            continue;
        }

        // Декомпрессия
        size_t decompressed_size;
        uint8_t* decompressed = decompress_data(&compressed, &decompressed_size);
        
        if (!decompressed) {
            free_compressed_data(&compressed);
            continue;
        }
        
        // Подсчёт checksum
        uint32_t checksum = Helper_checksum_bytes(decompressed, decompressed_size);
        
        total_checksum = (total_checksum + compressed.encoded_bits_size) & 0xFFFFFFFFu;
        total_checksum = (total_checksum + checksum) & 0xFFFFFFFFu;
        
        // Освобождаем память
        free_compressed_data(&compressed);
        free(decompressed);
    }

    bench->result = total_checksum;
    return total_checksum;
}

static void Compression_prepare(void* self) {
    Compression* bench = (Compression*)self;
    const char* input = Helper_get_input("Compression");
    bench->iterations = input ? atoi(input) : 1000;
    
    free(bench->test_data);
    bench->test_data = generate_test_data(bench->iterations, &bench->test_data_size);
}

static void Compression_cleanup(void* self) {
    Compression* bench = (Compression*)self;
    free(bench->test_data);
    free(bench);
}

static Benchmark* Compression_new(void) {
    Compression* instance = malloc(sizeof(Compression));
    if (!instance) return NULL;
    
    instance->iterations = 0;
    instance->result = 0;
    instance->test_data = NULL;
    instance->test_data_size = 0;
    
    Benchmark* bench = malloc(sizeof(Benchmark));
    if (!bench) {
        free(instance);
        return NULL;
    }
    
    bench->name = "Compression";
    bench->run = Compression_run;
    bench->prepare = Compression_prepare;
    bench->cleanup = Compression_cleanup;
    bench->instance = instance;
    
    return bench;
}

// ==================== Main для тестирования ====================
int main(int argc, char* argv[]) {
    const char* config_file = argc > 1 ? argv[1] : "../test.txt";
    const char* single_bench = argc > 2 ? argv[2] : NULL;
    
    Helper_load_config(config_file);
    
    BenchmarkRegistry* registry = BenchmarkRegistry_create();
    
    BenchmarkRegistry_add(registry, Pidigits_new());
    BenchmarkRegistry_add(registry, Binarytrees_new());
    BenchmarkRegistry_add(registry, BrainfuckHashMap_new());
    BenchmarkRegistry_add(registry, BrainfuckRecursion_new());            
    BenchmarkRegistry_add(registry, Fannkuchredux_new());
    BenchmarkRegistry_add(registry, Fasta_new());
    BenchmarkRegistry_add(registry, Knuckeotide_new());
    BenchmarkRegistry_add(registry, Mandelbrot_new());
    BenchmarkRegistry_add(registry, Matmul_new());
    BenchmarkRegistry_add(registry, Matmul4T_new());
    BenchmarkRegistry_add(registry, Matmul8T_new());
    BenchmarkRegistry_add(registry, Matmul16T_new());
    BenchmarkRegistry_add(registry, Nbody_new());
    BenchmarkRegistry_add(registry, RegexDna_new());
    BenchmarkRegistry_add(registry, Revcomp_new());            
    BenchmarkRegistry_add(registry, Spectralnorm_new());
    BenchmarkRegistry_add(registry, Base64Encode_new());
    BenchmarkRegistry_add(registry, Base64Decode_new());    
    BenchmarkRegistry_add(registry, JsonGenerate_new());
    BenchmarkRegistry_add(registry, JsonParseDom_new());
    BenchmarkRegistry_add(registry, JsonParseMapping_new());
    BenchmarkRegistry_add(registry, Primes_new());
    BenchmarkRegistry_add(registry, Noise_new());
    BenchmarkRegistry_add(registry, TextRaytracer_new());
    BenchmarkRegistry_add(registry, NeuralNet_new());
    BenchmarkRegistry_add(registry, SortQuick_new());
    BenchmarkRegistry_add(registry, SortMerge_new());
    BenchmarkRegistry_add(registry, SortSelf_new());
    BenchmarkRegistry_add(registry, GraphPathBFS_new());
    BenchmarkRegistry_add(registry, GraphPathDFS_new());
    BenchmarkRegistry_add(registry, GraphPathDijkstra_new());
    BenchmarkRegistry_add(registry, BufferHashSHA256_new());
    BenchmarkRegistry_add(registry, BufferHashCRC32_new());
    BenchmarkRegistry_add(registry, CacheSimulation_new());
    BenchmarkRegistry_add(registry, CalculatorAST_new());
    BenchmarkRegistry_add(registry, CalculatorInterpreter_new());
    BenchmarkRegistry_add(registry, MazeGenerator_new());
    BenchmarkRegistry_add(registry, GameOfLife_new());
    BenchmarkRegistry_add(registry, AStarPathfinder_new());
    BenchmarkRegistry_add(registry, Compression_new());
    
    BenchmarkRegistry_run(registry, single_bench);
    
    BenchmarkRegistry_free(registry);
    Helper_free_config();

    FILE *f = fopen("/tmp/recompile_marker", "w");
    if (f) {
        fprintf(f, "RECOMPILE_MARKER_011111111");
        fclose(f);
    }    
    
    return 0;
}
