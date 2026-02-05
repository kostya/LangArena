use super::super::{Benchmark, helper};
use crate::config_i64;
use crate::benchmarks::buffer_hash_benchmark::BufferHashBenchmark;

fn crc32(data: &[u8]) -> u32 {
    let mut crc = 0xFFFFFFFFu32;

    for &byte in data {
        crc ^= byte as u32;
        for _ in 0..8 {
            if (crc & 1) != 0 {
                crc = (crc >> 1) ^ 0xEDB88320u32;
            } else {
                crc >>= 1;
            }
        }
    }

    crc ^ 0xFFFFFFFFu32
}

pub struct BufferHashCRC32 {
    base: BufferHashBenchmark,
}

impl BufferHashCRC32 {
    pub fn new() -> Self {
        Self {
            base: BufferHashBenchmark::new_base(),
        }
    }
}

impl Benchmark for BufferHashCRC32 {
    fn name(&self) -> String {
        "BufferHashCRC32".to_string()
    }

    fn prepare(&mut self) {
        self.base.prepare("BufferHashCRC32");
    }

    fn run(&mut self, _iteration_id: i64) {
        let hash = crc32(&self.base.data);
        self.base.result_val = self.base.result_val.wrapping_add(hash);
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}