package benchmark

import "core:fmt"
import "core:container/lru"

CacheSimulation :: struct {
    using base: Benchmark,
    result_val: u32,
    values_size: int,
    cache_size: int,
    cache: lru.Cache(string, string),
    hits: int,
    misses: int,
    current_size: int,  
}

cachesimulation_run :: proc(bench: ^Benchmark, iteration_id: int) {
    cs := cast(^CacheSimulation)bench

    key_idx := next_int(cs.values_size)
    key := fmt.tprintf("item_%d", key_idx)

    exists := lru.exists(&cs.cache, key)

    if exists {
        cs.hits += 1

        new_value := fmt.tprintf("updated_%d", iteration_id)
        lru.set(&cs.cache, key, new_value)
    } else {
        cs.misses += 1

        if cs.current_size >= cs.cache_size {

        } else {
            cs.current_size += 1
        }

        new_value := fmt.tprintf("new_%d", iteration_id)
        lru.set(&cs.cache, key, new_value)
    }
}

cachesimulation_checksum :: proc(bench: ^Benchmark) -> u32 {
    cs := cast(^CacheSimulation)bench

    final_result := cs.result_val
    final_result = (final_result << 5) + u32(cs.hits)
    final_result = (final_result << 5) + u32(cs.misses)
    final_result = (final_result << 5) + u32(cs.current_size)

    return final_result
}

cachesimulation_prepare :: proc(bench: ^Benchmark) {
    cs := cast(^CacheSimulation)bench

    cs.result_val = 5432
    cs.values_size = int(config_i64("Etc::CacheSimulation", "values"))
    cs.cache_size = int(config_i64("Etc::CacheSimulation", "size"))

    lru.init(&cs.cache, cs.cache_size)

    cs.hits = 0
    cs.misses = 0
    cs.current_size = 0
}

cachesimulation_cleanup :: proc(bench: ^Benchmark) {
    cs := cast(^CacheSimulation)bench

    lru.destroy(&cs.cache, false)
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