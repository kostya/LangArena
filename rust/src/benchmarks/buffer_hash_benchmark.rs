use super::super::helper;
use crate::config_i64;

pub struct BufferHashBenchmark {
    pub data: Vec<u8>,
    pub size_val: i64,
    pub result_val: u32,
    pub prepared: bool,
}

impl BufferHashBenchmark {
    pub fn new_base() -> Self {
        Self {
            data: Vec::new(),
            size_val: 0,
            result_val: 0,
            prepared: false,
        }
    }

    pub fn prepare(&mut self, class_name: &str) {
        if !self.prepared {
            self.size_val = config_i64(class_name, "size");
            self.data = vec![0; self.size_val as usize];

            for i in 0..self.data.len() {
                self.data[i] = helper::next_int(256) as u8;
            }

            self.prepared = true;
        }
    }
}