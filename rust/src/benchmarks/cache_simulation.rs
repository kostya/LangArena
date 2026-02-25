use super::super::{helper, Benchmark};
use crate::config_i64;
use std::collections::HashMap;
use std::hash::Hash;
use std::marker::PhantomData;
use std::ptr::NonNull;

struct LRUCache<K, V>
where
    K: Eq + Hash + Clone,
    V: Clone,
{
    capacity: usize,
    cache: HashMap<K, NonNull<Node<K, V>>>,
    head: Option<NonNull<Node<K, V>>>,
    tail: Option<NonNull<Node<K, V>>>,
    size: usize,

    _k: PhantomData<K>,
    _v: PhantomData<V>,
}

struct Node<K, V> {
    key: K,
    value: V,
    prev: Option<NonNull<Node<K, V>>>,
    next: Option<NonNull<Node<K, V>>>,
}

impl<K, V> Node<K, V> {
    fn new(key: K, value: V) -> Self {
        Node {
            key,
            value,
            prev: None,
            next: None,
        }
    }
}

unsafe impl<K, V> Send for LRUCache<K, V>
where
    K: Send + Eq + Hash + Clone,
    V: Send + Clone,
{
}

unsafe impl<K, V> Sync for LRUCache<K, V>
where
    K: Sync + Eq + Hash + Clone,
    V: Sync + Clone,
{
}

impl<K, V> LRUCache<K, V>
where
    K: Eq + Hash + Clone,
    V: Clone,
{
    fn new(capacity: usize) -> Self {
        LRUCache {
            capacity,
            cache: HashMap::with_capacity(capacity),
            head: None,
            tail: None,
            size: 0,
            _k: PhantomData,
            _v: PhantomData,
        }
    }

    fn get(&mut self, key: &K) -> Option<V> {
        let node_ptr = *self.cache.get(key)?;

        unsafe {
            self.move_to_front(node_ptr);
            Some((*node_ptr.as_ptr()).value.clone())
        }
    }

    fn put(&mut self, key: K, value: V) {
        if let Some(&node_ptr) = self.cache.get(&key) {
            unsafe {
                (*node_ptr.as_ptr()).value = value;
                self.move_to_front(node_ptr);
            }
            return;
        }

        if self.size >= self.capacity {
            unsafe {
                self.remove_oldest();
            }
        }

        let node_ptr = unsafe {
            let node = Box::new(Node::new(key.clone(), value));
            NonNull::new_unchecked(Box::into_raw(node))
        };

        self.cache.insert(key, node_ptr);

        unsafe {
            self.add_to_front(node_ptr);
        }
        self.size += 1;
    }

    fn len(&self) -> usize {
        self.size
    }

    unsafe fn move_to_front(&mut self, node_ptr: NonNull<Node<K, V>>) {
        if Some(node_ptr) == self.head {
            return;
        }

        let node = node_ptr.as_ptr();

        if let Some(prev_ptr) = (*node).prev {
            (*prev_ptr.as_ptr()).next = (*node).next;
        }
        if let Some(next_ptr) = (*node).next {
            (*next_ptr.as_ptr()).prev = (*node).prev;
        }

        if Some(node_ptr) == self.tail {
            self.tail = (*node).prev;
        }

        (*node).prev = None;
        (*node).next = self.head;

        if let Some(head_ptr) = self.head {
            (*head_ptr.as_ptr()).prev = Some(node_ptr);
        }

        self.head = Some(node_ptr);

        if self.tail.is_none() {
            self.tail = Some(node_ptr);
        }
    }

    unsafe fn add_to_front(&mut self, node_ptr: NonNull<Node<K, V>>) {
        let node = node_ptr.as_ptr();
        (*node).next = self.head;

        if let Some(head_ptr) = self.head {
            (*head_ptr.as_ptr()).prev = Some(node_ptr);
        }

        self.head = Some(node_ptr);

        if self.tail.is_none() {
            self.tail = Some(node_ptr);
        }
    }

    unsafe fn remove_oldest(&mut self) {
        if let Some(tail_ptr) = self.tail {
            let tail = tail_ptr.as_ptr();

            self.cache.remove(&(*tail).key);

            if let Some(prev_ptr) = (*tail).prev {
                (*prev_ptr.as_ptr()).next = None;
            }

            self.tail = (*tail).prev;

            if Some(tail_ptr) == self.head {
                self.head = None;
            }

            let _ = Box::from_raw(tail);
            self.size -= 1;
        }
    }
}

impl<K, V> Drop for LRUCache<K, V>
where
    K: Eq + Hash + Clone,
    V: Clone,
{
    fn drop(&mut self) {
        while let Some(head_ptr) = self.head {
            unsafe {
                self.head = (*head_ptr.as_ptr()).next;
                let _ = Box::from_raw(head_ptr.as_ptr());
            }
        }
    }
}

pub struct CacheSimulation {
    operations: i32,
    result_val: u32,
    values_size: i32,
    cache_size: i32,
    cache: LRUCache<String, String>,
    hits: i32,
    misses: i32,
}

impl CacheSimulation {
    pub fn new() -> Self {
        let values_size = config_i64("Etc::CacheSimulation", "values") as i32;
        let cache_size = config_i64("Etc::CacheSimulation", "size") as i32;

        Self {
            operations: 0,
            result_val: 5432,
            values_size,
            cache_size,
            cache: LRUCache::new(cache_size as usize),
            hits: 0,
            misses: 0,
        }
    }
}

impl Benchmark for CacheSimulation {
    fn name(&self) -> String {
        "Etc::CacheSimulation".to_string()
    }

    fn prepare(&mut self) {
        self.cache = LRUCache::new(self.cache_size as usize);
        self.hits = 0;
        self.misses = 0;
    }

    fn run(&mut self, iteration_id: i64) {
        for _ in 0..1000 {
            let key_idx = helper::next_int(self.values_size);
            let key = format!("item_{}", key_idx);

            if let Some(_) = self.cache.get(&key) {
                self.hits += 1;
                let val = format!("updated_{}", iteration_id);
                self.cache.put(key, val);
            } else {
                self.misses += 1;
                let val = format!("new_{}", iteration_id);
                self.cache.put(key, val);
            }
        }
    }

    fn checksum(&self) -> u32 {
        let mut result = self.result_val;
        result = (result << 5) + self.hits as u32;
        result = (result << 5) + self.misses as u32;
        result = (result << 5) + self.cache.len() as u32;
        result
    }
}
