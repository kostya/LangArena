use super::super::{Benchmark, INPUT};
use crate::benchmarks::sort_benchmark::SortBenchmark;

pub struct SortQuick {
    base: SortBenchmark,
}

impl SortQuick {
    fn quick_sort(arr: &mut [i32]) {
        if arr.len() <= 1 {
            return;
        }
        
        let pivot = arr[arr.len() / 2];
        let mut i = 0;
        let mut j = arr.len() - 1;
        
        while i <= j {
            while arr[i] < pivot {
                i += 1;
            }
            while arr[j] > pivot {
                j -= 1;
            }
            if i <= j {
                arr.swap(i, j);
                i += 1;
                if j > 0 {
                    j -= 1;
                }
            }
        }
        
        if j > 0 {
            Self::quick_sort(&mut arr[0..=j]);
        }
        if i < arr.len() {
            Self::quick_sort(&mut arr[i..]);
        }
    }
    
    pub fn new() -> Self {
        let name = "SortQuick".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            base: SortBenchmark::new_base(iterations),
        }
    }
}

impl Benchmark for SortQuick {
    fn name(&self) -> String {
        "SortQuick".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.base.n
    }
    
    fn prepare(&mut self) {
        self.base.prepare_common();
    }
    
    fn run(&mut self) {
        let data = self.base.data.clone();
        self.base.run_common(|| {
            let mut arr = data.clone();
            Self::quick_sort(&mut arr);
            arr
        });
    }
    
    fn result(&self) -> i64 {
        self.base.result as i64
    }
}