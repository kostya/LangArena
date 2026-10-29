#include "benchmark.h"

typedef struct {
  uint8_t *data;
  int64_t size_val;
  uint32_t result_val;
} BufferHashBaseData;

static void buffer_hash_base_prepare(Benchmark *self, const char *bench_name,
                                     BufferHashBaseData *data) {
  (void)self;
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
    uint32_t hash_idx = i % 8;
    uint32_t hash = hashes[hash_idx];

    uint32_t temp = (hash << 5) + hash;
    temp = temp + data[i];
    hash = temp;

    temp = hash + (hash << 10);
    hashes[hash_idx] = temp ^ (hash >> 6);
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
  (void)iteration_id;
  BufferHashSHA256Data *data = (BufferHashSHA256Data *)self->data;

  uint8_t ch = (uint8_t)Helper_next_int(256);
  data->base.data[Helper_next_int(data->base.size_val)] = ch;

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
  (void)iteration_id;
  BufferHashCRC32Data *data = (BufferHashCRC32Data *)self->data;

  uint8_t ch = (uint8_t)Helper_next_int(256);
  data->base.data[Helper_next_int(data->base.size_val)] = ch;

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
