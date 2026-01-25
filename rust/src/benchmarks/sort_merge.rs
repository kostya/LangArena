use super::super::{Benchmark, INPUT};
use crate::benchmarks::sort_benchmark::SortBenchmark;

pub struct SortMerge {
    base: SortBenchmark,
}

impl SortMerge {
    fn merge_sort_inplace(arr: &mut [i32]) {
        let mut temp = vec![0; arr.len()];
        Self::merge_sort_helper(arr, &mut temp, 0, arr.len() as isize - 1);
    }

    fn merge_sort_helper(arr: &mut [i32], temp: &mut [i32], left: isize, right: isize) {
        if left >= right {
            return;
        }

        let mid = (left + right) / 2;
        Self::merge_sort_helper(arr, temp, left, mid);
        Self::merge_sort_helper(arr, temp, mid + 1, right);
        Self::merge(arr, temp, left, mid, right);
    }

    fn merge(arr: &mut [i32], temp: &mut [i32], left: isize, mid: isize, right: isize) {
        // Копируем обе половины во временный массив
        for i in left..=right {
            temp[i as usize] = arr[i as usize];
        }

        let mut i = left;    // Индекс левой половины
        let mut j = mid + 1; // Индекс правой половины
        let mut k = left;    // Индекс в исходном массиве

        while i <= mid && j <= right {
            if temp[i as usize] <= temp[j as usize] {
                arr[k as usize] = temp[i as usize];
                i += 1;
            } else {
                arr[k as usize] = temp[j as usize];
                j += 1;
            }
            k += 1;
        }

        // Копируем оставшиеся элементы левой половины
        while i <= mid {
            arr[k as usize] = temp[i as usize];
            i += 1;
            k += 1;
        }
    }
    
    pub fn new() -> Self {
        let name = "SortMerge".to_string();
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

impl Benchmark for SortMerge {
    fn name(&self) -> String {
        "SortMerge".to_string()
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
            Self::merge_sort_inplace(&mut arr);
            arr
        });
    }
    
    fn result(&self) -> i64 {
        self.base.result as i64
    }
}