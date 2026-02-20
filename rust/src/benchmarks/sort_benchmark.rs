use super::super::helper;
use crate::config_i64;

pub struct SortBenchmark {
    pub size_val: i64,
    pub data: Vec<i32>,
    pub result_val: u32,
}

impl SortBenchmark {
    pub fn new_base() -> Self {
        Self {
            size_val: 0,
            data: Vec::new(),
            result_val: 0,
        }
    }

    pub fn prepare(&mut self, class_name: &str) {
        if self.size_val == 0 {
            self.size_val = config_i64(class_name, "size");
            self.data.reserve(self.size_val as usize);
            for _ in 0..self.size_val {
                self.data.push(helper::next_int(1_000_000));
            }
        }
    }
}
