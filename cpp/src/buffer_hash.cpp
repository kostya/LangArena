#include "buffer_hash.hpp"

BufferHashBenchmark::BufferHashBenchmark() : size_val(0), result_val(0) {}

void BufferHashBenchmark::prepare() {
  if (size_val == 0) {
    size_val = config_val("size");
    data.resize(static_cast<size_t>(size_val));
    for (size_t i = 0; i < static_cast<size_t>(size_val); i++) {
      data[i] = static_cast<uint8_t>(Helper::next_int(256));
    }
  }
}

void BufferHashBenchmark::run(int iteration_id) {
  (void)iteration_id;
  uint8_t ch = static_cast<uint8_t>(Helper::next_int(256));
  data[static_cast<size_t>(Helper::next_int(size_val))] = ch;
  result_val += test();
}

uint32_t BufferHashBenchmark::checksum() { return result_val; }

std::string BufferHashSHA256::name() const { return "Hash::SHA256"; }

std::vector<uint8_t>
BufferHashSHA256::SimpleSHA256::digest(const std::vector<uint8_t> &data) {
  std::vector<uint8_t> result(32);

  uint32_t hashes[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};

  for (size_t i = 0; i < data.size(); i++) {
    uint32_t hash_idx = i % 8;
    uint32_t &hash = hashes[hash_idx];
    hash = ((hash << 5) + hash) + data[i];
    hash = (hash + (hash << 10)) ^ (hash >> 6);
  }

  for (int i = 0; i < 8; i++) {
    result[i * 4] = static_cast<uint8_t>(hashes[i] >> 24);
    result[i * 4 + 1] = static_cast<uint8_t>(hashes[i] >> 16);
    result[i * 4 + 2] = static_cast<uint8_t>(hashes[i] >> 8);
    result[i * 4 + 3] = static_cast<uint8_t>(hashes[i]);
  }

  return result;
}

uint32_t BufferHashSHA256::test() {
  auto bytes = SimpleSHA256::digest(data);
  return *reinterpret_cast<uint32_t *>(bytes.data());
}

std::string BufferHashCRC32::name() const { return "Hash::CRC32"; }

uint32_t BufferHashCRC32::crc32(const std::vector<uint8_t> &data) {
  uint32_t crc = 0xFFFFFFFFu;

  for (uint8_t byte : data) {
    crc = crc ^ byte;
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

uint32_t BufferHashCRC32::test() { return crc32(data); }