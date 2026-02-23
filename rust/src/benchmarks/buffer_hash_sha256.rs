use super::super::Benchmark;
use crate::benchmarks::buffer_hash_benchmark::BufferHashBenchmark;

struct SimpleSHA256;

impl SimpleSHA256 {
    fn digest(data: &[u8]) -> [u8; 32] {
        let mut result = [0u8; 32];

        let mut hashes = [
            0x6a09e667u32,
            0xbb67ae85u32,
            0x3c6ef372u32,
            0xa54ff53au32,
            0x510e527fu32,
            0x9b05688cu32,
            0x1f83d9abu32,
            0x5be0cd19u32,
        ];

        for (i, &byte) in data.iter().enumerate() {
            let hash_idx = i % 8;
            let mut hash = hashes[hash_idx];
            hash = hash
                .wrapping_shl(5)
                .wrapping_add(hash)
                .wrapping_add(byte as u32);
            hash = hash.wrapping_add(hash.wrapping_shl(10)) ^ hash.wrapping_shr(6);
            hashes[hash_idx] = hash;
        }

        for i in 0..8 {
            let hash = hashes[i];
            result[i * 4] = (hash >> 24) as u8;
            result[i * 4 + 1] = (hash >> 16) as u8;
            result[i * 4 + 2] = (hash >> 8) as u8;
            result[i * 4 + 3] = hash as u8;
        }

        result
    }
}

pub struct BufferHashSHA256 {
    base: BufferHashBenchmark,
}

impl BufferHashSHA256 {
    pub fn new() -> Self {
        Self {
            base: BufferHashBenchmark::new_base(),
        }
    }
}

impl Benchmark for BufferHashSHA256 {
    fn name(&self) -> String {
        "Hash::SHA256".to_string()
    }

    fn prepare(&mut self) {
        self.base.prepare("Hash::SHA256");
    }

    fn run(&mut self, _iteration_id: i64) {
        let digest = SimpleSHA256::digest(&self.base.data);

        let hash = u32::from_le_bytes([digest[0], digest[1], digest[2], digest[3]]);
        self.base.result_val = self.base.result_val.wrapping_add(hash);
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}
