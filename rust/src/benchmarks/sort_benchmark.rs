use super::super::helper; // Benchmark не используется в этом файле

const ARR_SIZE: usize = 100_000;

// Абстрактный бенчмарк сортировки - не должен вызываться напрямую
pub struct SortBenchmark {
    pub n: i32,
    pub data: Vec<i32>,
    pub result: u32,
}

impl SortBenchmark {
    pub fn new_base(iterations: i32) -> Self {
        Self {
            n: iterations,
            data: Vec::new(),
            result: 0,
        }
    }
    
    pub fn check_n_elements(&self, arr: &[i32], n: usize) -> String {
        if arr.is_empty() {
            return "[empty]\n".to_string();
        }
        
        let step = arr.len() / n;
        let mut result = String::new();
        result.push('[');
        
        for i in (0..arr.len()).step_by(step.max(1)) {
            result.push_str(&format!("{}:{},", i, arr[i]));
        }
        
        result.push(']');
        result.push('\n');
        result
    }
    
    pub fn prepare_common(&mut self) {
        self.data.clear();
        for _ in 0..ARR_SIZE {
            self.data.push(helper::next_int(1_000_000));
        }
    }
    
    pub fn run_common(&mut self, test_fn: impl FnMut() -> Vec<i32>) {
        let verify = self.check_n_elements(&self.data, 10);
        
        let mut verify_sum = verify.clone();
        
        // Выполняем сортировку n-1 раз
        let mut test_fn = test_fn;
        for _ in 0..(self.n - 1) {
            let arr = test_fn();
            self.result += arr[arr.len() / 2] as u32;
        }
        
        // Последняя сортировка - сохраняем результат
        let arr = test_fn();
        
        // Проверяем, что исходный массив не изменился
        verify_sum.push_str(&self.check_n_elements(&self.data, 10));
        verify_sum.push_str(&self.check_n_elements(&arr, 10));
        
        self.result += helper::checksum_str(&verify_sum);
    }
}