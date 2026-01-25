use super::super::{helper};

const BUFFER_SIZE: usize = 1_000_000;

// Абстрактный бенчмарк хэширования буферов
pub struct BufferHashBenchmark {
    pub data: Vec<u8>,
    pub n: i32,
    pub result: u32,
}

impl BufferHashBenchmark {
    pub fn new_base(iterations: i32) -> Self {
        Self {
            data: vec![0; BUFFER_SIZE],
            n: iterations,
            result: 0,
        }
    }
    
    pub fn prepare_common(&mut self) {
        // Генерируем случайные данные для хэширования
        for i in 0..self.data.len() {
            self.data[i] = helper::next_int(256) as u8;
        }
    }
    
    pub fn run_common(&mut self, test_fn: impl Fn(&[u8]) -> u32) {
        for _ in 0..self.n {
            self.result = self.result.wrapping_add(test_fn(&self.data));
        }
    }
}