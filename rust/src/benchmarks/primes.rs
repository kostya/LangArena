use super::super::{Benchmark, INPUT};
use std::collections::VecDeque;

const PREFIX: i32 = 32_338;

struct Node {
    children: [Option<Box<Node>>; 10],
    terminal: bool,
}

impl Node {
    fn new() -> Self {
        Self {
            children: Default::default(),
            terminal: false,
        }
    }
}

fn generate_primes(limit: i32) -> Vec<i32> {
    if limit < 2 {
        return Vec::new();
    }
    
    let limit_usize = limit as usize;
    let mut is_prime = vec![true; limit_usize + 1];
    is_prime[0] = false;
    is_prime[1] = false;
    
    let sqrt_limit = (limit as f64).sqrt() as i32;
    
    for p in 2..=sqrt_limit {
        if is_prime[p as usize] {
            let mut multiple = p * p;
            while multiple <= limit {
                is_prime[multiple as usize] = false;
                multiple += p;
            }
        }
    }
    
    // Разумная оценка количества простых чисел
    let estimated_size = (limit as f64 / (limit as f64).ln()) as usize + 100;
    let mut primes = Vec::with_capacity(estimated_size);
    
    for i in 2..=limit {
        if is_prime[i as usize] {
            primes.push(i);
        }
    }
    
    primes
}

fn build_trie(primes: &[i32]) -> Box<Node> {
    let mut root = Box::new(Node::new());
    
    for &prime in primes {
        let mut current = &mut *root;
        let digits = prime.to_string();
        
        for ch in digits.chars() {
            let digit = ch.to_digit(10).unwrap() as usize;
            
            if current.children[digit].is_none() {
                current.children[digit] = Some(Box::new(Node::new()));
            }
            current = current.children[digit].as_mut().unwrap();
        }
        current.terminal = true;
    }
    
    root
}

fn find_primes_with_prefix(trie_root: &Node, prefix: i32) -> Vec<i32> {
    let prefix_str = prefix.to_string();
    let mut current = trie_root;
    
    // Находим узел префикса
    for ch in prefix_str.chars() {
        let digit = ch.to_digit(10).unwrap() as usize;
        match &current.children[digit] {
            Some(node) => current = node,
            None => return Vec::new(),
        }
    }
    
    // BFS обход как в C++ версии
    let mut results = Vec::new();
    let mut queue = VecDeque::new();
    queue.push_back((current, prefix));
    
    while let Some((node, number)) = queue.pop_front() {
        if node.terminal {
            results.push(number);
        }
        
        // Перебираем все возможные цифры
        for digit in 0..10 {
            if let Some(child) = &node.children[digit] {
                queue.push_back((child, number * 10 + digit as i32));
            }
        }
    }
    
    // Сортируем результаты как в C++
    results.sort_unstable();
    results
}

pub struct Primes {
    n: i32,
    result: u32,
}

impl Primes {
    pub fn new() -> Self {
        let name = "Primes".to_string();
        let iterations = INPUT.get()
            .and_then(|input| input.get(&name))
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n: iterations,
            result: 5432,
        }
    }
}

impl Benchmark for Primes {
    fn name(&self) -> String {
        "Primes".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn run(&mut self) {
        // 1. Генерация простых чисел (как в C++)
        let primes = generate_primes(self.n);
        
        // 2. Построение префиксного дерева (как в C++)
        let trie = build_trie(&primes);
        
        // 3. Поиск по префиксу (как в C++)
        let results = find_primes_with_prefix(&trie, PREFIX);
        
        // 4. Вычисление результата в том же порядке
        let mut temp = self.result;
        
        // Сначала добавляем размер (как в C++)
        temp = temp.wrapping_add(results.len() as u32);
        
        // Затем добавляем все числа (как в C++)
        for prime in results {
            temp = temp.wrapping_add(prime as u32);
        }
        
        self.result = temp;
    }
    
    fn result(&self) -> i64 {
        self.result as i64
    }
}