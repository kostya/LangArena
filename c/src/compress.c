#include "benchmark.h"

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

      for (size_t i = 1; i <= n; i++) {
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

      for (size_t i = 1; i <= n; i++) {
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
  (void)iteration_id;
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
  (void)iteration_id;
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
  (void)iteration_id;
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
  (void)iteration_id;
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

  bit_output_free(output);
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
  (void)iteration_id;
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

    int left = 0;
    int right = 256;
    while (left < right) {
      int mid = (left + right) / 2;
      if ((uint64_t)high_table[mid] <= scaled) {
        left = mid + 1;
      } else {
        right = mid;
      }
    }
    int symbol = left;

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
  (void)iteration_id;
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
  (void)iteration_id;
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
    for (size_t i = 0; i < dict_size; i++)
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
    for (size_t i = 0; i < dict_size; i++)
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
    for (size_t i = 0; i < dict_size; i++)
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
      for (size_t i = 0; i < dict_size; i++)
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

  for (size_t i = 0; i < dict_size; i++) {
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
  (void)iteration_id;
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
