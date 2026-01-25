use super::super::{Benchmark, INPUT, helper};
use lru::LruCache;
use std::num::NonZeroUsize;

pub struct CacheSimulation {
    operations: i32,
    result: u32,
}

impl CacheSimulation {
    pub fn new() -> Self {
        let name = "CacheSimulation".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(100);
        
        Self {
            operations: iterations * 1000,
            result: 0,
        }
    }
}

impl Benchmark for CacheSimulation {
    fn name(&self) -> String {
        "CacheSimulation".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.operations / 1000
    }
    
    fn run(&mut self) {
        // Создаем LRU кэш с capacity 1000
        let capacity = NonZeroUsize::new(1000).unwrap();
        let mut cache = LruCache::new(capacity);
        
        let mut hits = 0;
        let mut misses = 0;

        // Оптимизация: используем буферы для уменьшения аллокаций
        let mut key_buf = String::with_capacity(32);
        let mut val_buf = String::with_capacity(32);
        
        for i in 0..self.operations {
            // Формируем ключ
            key_buf.clear();
            key_buf.push_str("item_");
            key_buf.push_str(&helper::next_int(2000).to_string());
            
            // Проверяем наличие в кэше
            if cache.contains(&key_buf) {
                hits += 1;
                // Обновляем значение
                val_buf.clear();
                val_buf.push_str("updated_");
                val_buf.push_str(&i.to_string());
                
                // Вставляем обратно (обновит порядок)
                cache.put(key_buf.clone(), val_buf.clone());
            } else {
                misses += 1;
                // Добавляем новое значение
                val_buf.clear();
                val_buf.push_str("new_");
                val_buf.push_str(&i.to_string());
                
                cache.put(key_buf.clone(), val_buf.clone());
            }
        }
        
        let message = format!("hits:{}|misses:{}|size:{}", hits, misses, cache.len());
        self.result = helper::checksum_str(&message);
    }
    
    fn result(&self) -> i64 {
        self.result as i64
    }
}