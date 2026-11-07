#include "benchmark.h"
#include "libbase64.h"

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
  (void)iteration_id;
  Base64EncodeData *data = (Base64EncodeData *)self->data;
  free(data->encoded_str);
  data->encoded_str = malloc(b64_encode_size(data->input_len));
  data->encoded_len =
      b64_encode(data->encoded_str, data->input_str, data->input_len);
  data->result_val += (uint32_t)data->encoded_len;
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
  (void)iteration_id;
  Base64DecodeData *data = (Base64DecodeData *)self->data;
  free(data->decoded_str);
  data->decoded_str = malloc(b64_decode_size(data->encoded_len));
  data->decoded_len =
      b64_decode(data->decoded_str, data->encoded_str, data->encoded_len);
  data->result_val += (uint32_t)data->decoded_len;
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
