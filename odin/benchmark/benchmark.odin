package benchmark

import "core:fmt"
import "core:time"
import "core:strings"  

Benchmark_VTable :: struct {
    run:      proc(bench: ^Benchmark, iteration_id: int),
    checksum: proc(bench: ^Benchmark) -> u32,
    prepare:  proc(bench: ^Benchmark),
    cleanup:  proc(bench: ^Benchmark),
    warmup:  proc(bench: ^Benchmark),
}

Benchmark :: struct {
    vtable: ^Benchmark_VTable,

    name: string,
    iterations:      int,
    expected_checksum: i64,
}

Benchmark_Factory :: proc() -> ^Benchmark

Benchmark_Registry :: struct {
    factory: Benchmark_Factory,
}

benchmark_registry: [dynamic]Benchmark_Registry

register_benchmark_factory :: proc(factory: Benchmark_Factory) {
    append(&benchmark_registry, Benchmark_Registry{factory})
}

run_all_benchmarks :: proc(single_bench: string = "") {
    summary_time := 0.0
    ok := 0
    fails := 0

    for registry_item in benchmark_registry {
        bench_name := registry_item.factory().name

        if len(single_bench) > 0 && !strings.contains(strings.to_lower(bench_name), strings.to_lower(single_bench)) {
            continue
        }

        fmt.printf("%s: ", bench_name)

        bench := registry_item.factory()
        defer destroy_bench(bench)

        bench.iterations = int(config_i64(bench_name, "iterations"))
        bench.expected_checksum = config_i64(bench_name, "checksum")

        reset()
        bench.vtable.prepare(bench)
        bench.vtable.warmup(bench)
        reset()

        start := time.now()
        run_all(bench)
        duration := time.since(start)
        seconds := f64(duration) / f64(time.Second)
        summary_time += seconds

        actual := bench.vtable.checksum(bench)
        expected := u32(bench.expected_checksum)

        if actual == expected {
            fmt.print("OK ")
            ok += 1
        } else {
            fmt.printf("ERR[actual=%u, expected=%u] ", actual, expected)
            fails += 1
        }

        fmt.printf("in %.3fs\n", seconds)
    }

    fmt.printf("Summary: %.4fs, %d, %d, %d\n", summary_time, ok + fails, ok, fails)
}

run_all :: proc(bench: ^Benchmark) {
    for i in 0..<bench.iterations {
        bench.vtable.run(bench, i)
    }
}

default_vtable :: proc() -> ^Benchmark_VTable {
    vtable := new(Benchmark_VTable)

    vtable.run = default_run
    vtable.checksum = default_checksum
    vtable.prepare = default_prepare
    vtable.cleanup = default_cleanup
    vtable.warmup = default_warmup
    return vtable
}

default_run :: proc(bench: ^Benchmark, iteration_id: int) {
}

default_checksum :: proc(bench: ^Benchmark) -> u32 {
    return 0
}

default_prepare :: proc(bench: ^Benchmark) {
}

default_cleanup :: proc(bench: ^Benchmark) {
}

default_warmup :: proc(bench: ^Benchmark) {
    wi := warmup_iterations(bench)
    for i in 0..<wi {
        bench.vtable.run(bench, i)
    }
}

warmup_iterations :: proc(bench: ^Benchmark) -> int {
    warmup_iterations := int(0)

    if bench.name in _state.config {
        class_obj := _state.config[bench.name]

        val, exists := class_obj["warmup_iterations"]
        if exists {
            warmup_iterations = int(config_i64(bench.name, "warmup_iterations"))
        }
    }

    if warmup_iterations == 0 {
        warmup_iterations = int(f64(bench.iterations) * 0.2)
        if warmup_iterations == 0 {
            warmup_iterations = 1
        }
    }
    return warmup_iterations
}

destroy_bench :: proc(bench: ^Benchmark) {
     if bench.vtable.cleanup != nil {
        bench.vtable.cleanup(bench)
    }
    free(bench.vtable)
    free(bench)
}