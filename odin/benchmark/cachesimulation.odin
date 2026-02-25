package benchmark

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:container/small_array"

LRUNode :: struct($K, $V: typeid) {
    key: K,
    value: V,
    prev: ^LRUNode(K, V),
    next: ^LRUNode(K, V),
}

LRUCache :: struct($K, $V: typeid) {
    capacity: int,
    cache: map[K]^LRUNode(K, V),
    head: ^LRUNode(K, V),
    tail: ^LRUNode(K, V),
    size: int,
}

lru_cache_init :: proc(cache: ^LRUCache($K, $V), capacity: int) {
    cache.capacity = capacity
    cache.cache = make(map[K]^LRUNode(K, V))
    cache.head = nil
    cache.tail = nil
    cache.size = 0
}

lru_cache_destroy :: proc(cache: ^LRUCache($K, $V)) {
    node := cache.head
    for node != nil {
        next := node.next

        when K == string {
            delete(node.key)
        }
        when V == string {
            delete(node.value)
        }

        free(node)
        node = next
    }
    delete(cache.cache)
}

lru_cache_move_to_front :: proc(cache: ^LRUCache($K, $V), node: ^LRUNode(K, V)) {
    if node == cache.head {
        return
    }

    if node.prev != nil {
        node.prev.next = node.next
    }
    if node.next != nil {
        node.next.prev = node.prev
    }

    if node == cache.tail {
        cache.tail = node.prev
    }

    node.prev = nil
    node.next = cache.head
    if cache.head != nil {
        cache.head.prev = node
    }
    cache.head = node

    if cache.tail == nil {
        cache.tail = node
    }
}

lru_cache_add_to_front :: proc(cache: ^LRUCache($K, $V), node: ^LRUNode(K, V)) {
    node.next = cache.head
    if cache.head != nil {
        cache.head.prev = node
    }
    cache.head = node
    if cache.tail == nil {
        cache.tail = node
    }
}

lru_cache_remove_oldest :: proc(cache: ^LRUCache($K, $V)) {
    if cache.tail == nil {
        return
    }

    oldest := cache.tail
    delete_key(&cache.cache, oldest.key)

    if oldest.prev != nil {
        oldest.prev.next = nil
    }
    cache.tail = oldest.prev

    if cache.head == oldest {
        cache.head = nil
    }

    when K == string {
        delete(oldest.key)
    }
    when V == string {
        delete(oldest.value)
    }

    free(oldest)
    cache.size -= 1
}

lru_cache_get :: proc(cache: ^LRUCache($K, $V), key: K) -> (V, bool) {
    node_ptr, ok := cache.cache[key]
    if !ok {
        return {}, false
    }

    lru_cache_move_to_front(cache, node_ptr)
    return node_ptr.value, true
}

lru_cache_put :: proc(cache: ^LRUCache($K, $V), key: K, value: V) {
    node_ptr, ok := cache.cache[key]
    if ok {
        when V == string {
            delete(node_ptr.value)
        }
        node_ptr.value = value
        lru_cache_move_to_front(cache, node_ptr)
        return
    }

    if cache.size >= cache.capacity {
        lru_cache_remove_oldest(cache)
    }

    new_node := new(LRUNode(K, V))
    new_node.key = key
    new_node.value = value
    new_node.prev = nil
    new_node.next = nil

    cache.cache[key] = new_node
    lru_cache_add_to_front(cache, new_node)
    cache.size += 1
}

lru_cache_size :: proc(cache: ^LRUCache($K, $V)) -> int {
    return cache.size
}

CacheSimulation :: struct {
    using base: Benchmark,
    result_val: u32,
    values_size: int,
    cache_size: int,
    cache: LRUCache(string, string),
    hits: int,
    misses: int,

}

cachesimulation_run :: proc(bench: ^Benchmark, iteration_id: int) {
    cs := cast(^CacheSimulation)bench

    for i in 0..<1000 {
        key_idx := next_int(cs.values_size)

        key_buf: [32]byte
        val_buf: [32]byte

        key := fmt.bprintf(key_buf[:], "item_%d", key_idx)

        _, found := lru_cache_get(&cs.cache, key)

        if found {
            cs.hits += 1

            new_value := fmt.bprintf(val_buf[:], "updated_%d", iteration_id)

            lru_cache_put(&cs.cache, key, strings.clone(new_value))
        } else {
            cs.misses += 1

            stored_key := strings.clone(fmt.bprintf(key_buf[:], "item_%d", key_idx))
            stored_value := strings.clone(fmt.bprintf(val_buf[:], "new_%d", iteration_id))

            lru_cache_put(&cs.cache, stored_key, stored_value)
        }
    }
}

cachesimulation_checksum :: proc(bench: ^Benchmark) -> u32 {
    cs := cast(^CacheSimulation)bench
    final_result := cs.result_val
    final_result = (final_result << 5) + u32(cs.hits)
    final_result = (final_result << 5) + u32(cs.misses)
    final_result = (final_result << 5) + u32(lru_cache_size(&cs.cache))
    return final_result
}

cachesimulation_prepare :: proc(bench: ^Benchmark) {
    cs := cast(^CacheSimulation)bench

    cs.result_val = 5432
    cs.values_size = int(config_i64("Etc::CacheSimulation", "values"))
    cs.cache_size = int(config_i64("Etc::CacheSimulation", "size"))

    lru_cache_init(&cs.cache, cs.cache_size)

    cs.hits = 0
    cs.misses = 0
}

cachesimulation_cleanup :: proc(bench: ^Benchmark) {
    cs := cast(^CacheSimulation)bench
    lru_cache_destroy(&cs.cache)
}

create_cachesimulation :: proc() -> ^Benchmark {
    bench := new(CacheSimulation)
    bench.name = "Etc::CacheSimulation"
    bench.vtable = default_vtable()

    bench.vtable.run = cachesimulation_run
    bench.vtable.checksum = cachesimulation_checksum
    bench.vtable.prepare = cachesimulation_prepare
    bench.vtable.cleanup = cachesimulation_cleanup

    return cast(^Benchmark)bench
}