module cache_simulation

import benchmark
import helper

struct LRUNode {
mut:
	key   string
	value string
	prev  &LRUNode = unsafe { nil }
	next  &LRUNode = unsafe { nil }
}

struct FastLRUCache {
pub:
	capacity int
pub mut:
	cache map[string]&LRUNode
mut:
	head &LRUNode = unsafe { nil }
	tail &LRUNode = unsafe { nil }
	size int
}

fn new_fast_lru_cache(capacity int) FastLRUCache {
	return FastLRUCache{
		capacity: capacity
		cache:    map[string]&LRUNode{}
		size:     0
	}
}

fn (mut cache FastLRUCache) remove_node(mut node LRUNode) {
	if node.prev != unsafe { nil } {
		mut prev_node := node.prev
		prev_node.next = node.next
	} else {
		cache.head = node.next
	}

	if node.next != unsafe { nil } {
		mut next_node := node.next
		next_node.prev = node.prev
	} else {
		cache.tail = node.prev
	}
}

fn (mut cache FastLRUCache) add_to_front(mut node LRUNode) {
	node.next = cache.head
	node.prev = unsafe { nil }

	if cache.head != unsafe { nil } {
		mut head_node := cache.head
		head_node.prev = node
	}

	cache.head = node

	if cache.tail == unsafe { nil } {
		cache.tail = node
	}
}

fn (mut cache FastLRUCache) move_to_front(mut node LRUNode) {
	if unsafe { cache.head == node } {
		return
	}

	cache.remove_node(mut node)
	cache.add_to_front(mut node)
}

fn (mut cache FastLRUCache) get(key string) ?string {
	if key in cache.cache {
		mut node := cache.cache[key] or { return none }
		cache.move_to_front(mut node)
		return node.value
	}
	return none
}

fn (mut cache FastLRUCache) put(key string, value string) {
	if key in cache.cache {
		mut node := cache.cache[key] or { return }
		node.value = value
		cache.move_to_front(mut node)
		return
	}

	mut new_node := &LRUNode{
		key:   key
		value: value
	}

	if cache.size >= cache.capacity {
		if cache.tail != unsafe { nil } {
			mut oldest_node := cache.tail
			oldest_key := oldest_node.key
			cache.remove_node(mut oldest_node)
			cache.cache.delete(oldest_key)
			cache.size--
		}
	}

	cache.add_to_front(mut new_node)
	cache.cache[key] = new_node
	cache.size++
}

fn (cache FastLRUCache) size() int {
	return cache.size
}

pub struct CacheSimulation {
	benchmark.BaseBenchmark
mut:
	result_val  u32
	values_size int
	cache_size  int
	cache       FastLRUCache
	hits        int
	misses      int
}

pub fn new_cachesimulation() &benchmark.IBenchmark {
	mut bench := &CacheSimulation{
		BaseBenchmark: benchmark.new_base_benchmark('Etc::CacheSimulation')
		result_val:    5432
		values_size:   0
		cache_size:    0
		hits:          0
		misses:        0
	}
	return bench
}

pub fn (b CacheSimulation) name() string {
	return 'Etc::CacheSimulation'
}

pub fn (mut b CacheSimulation) prepare() {
	b.values_size = int(helper.config_i64('Etc::CacheSimulation', 'values'))
	b.cache_size = int(helper.config_i64('Etc::CacheSimulation', 'size'))

	b.cache = new_fast_lru_cache(b.cache_size)
	b.hits = 0
	b.misses = 0
}

pub fn (mut b CacheSimulation) run(iteration_id int) {
	key_idx := helper.next_int(b.values_size)
	key := 'item_${key_idx}'

	value := b.cache.get(key)

	if value != none {
		b.hits++
		b.cache.put(key, 'updated_${iteration_id}')
	} else {
		b.misses++
		b.cache.put(key, 'new_${iteration_id}')
	}
}

pub fn (b CacheSimulation) checksum() u32 {
	mut final_result := b.result_val
	final_result = (final_result << 5) + u32(b.hits)
	final_result = (final_result << 5) + u32(b.misses)
	final_result = (final_result << 5) + u32(b.cache.size())
	return final_result
}
