package benchmark

import "core:math"

GraphPathDFS :: struct {
    base: GraphPathBenchmark,
}

dfs_find_path :: proc(g: ^Graph, start, target: int) -> int {
    if start == target {
        return 0
    }

    visited := make([]bool, g.vertices)
    defer delete(visited)

    stack: [dynamic][2]int  
    defer delete(stack)

    best_path := max(int)

    append(&stack, [2]int{start, 0})

    for len(stack) > 0 {
        item := pop(&stack)
        v := item[0]
        dist := item[1]

        if visited[v] || dist >= best_path {
            continue
        }
        visited[v] = true

        for neighbor in g.adj[v][:] {  
            if neighbor == target {
                if dist + 1 < best_path {
                    best_path = dist + 1
                }
            } else if !visited[neighbor] {
                append(&stack, [2]int{neighbor, dist + 1})
            }
        }
    }

    if best_path == max(int) {
        return -1
    }
    return best_path
}

graphdfs_test :: proc(bench: ^GraphPathBenchmark) -> i64 {
    total_length: i64 = 0

    for pair in bench.pairs {
        start := pair[0]
        target := pair[1]
        total_length += i64(dfs_find_path(bench.graph, start, target))
    }

    return total_length
}

create_graphdfs :: proc() -> ^Benchmark {
    gd := new(GraphPathDFS)

    gd.base.name = "GraphPathDFS"
    gd.base.n_pairs = 0
    gd.base.vertices = 0
    gd.base.result_val = 0

    vtable := new(GraphPathVTable)
    base_vtable := default_vtable()
    vtable.base_vtable = base_vtable^

    vtable.base_vtable.prepare = graphpath_prepare
    vtable.base_vtable.run = graphpath_run
    vtable.base_vtable.checksum = graphpath_checksum
    vtable.base_vtable.cleanup = graphpath_cleanup
    vtable.base_vtable.warmup = default_warmup

    vtable.test = graphdfs_test

    gd.base.vtable = cast(^Benchmark_VTable)vtable

    return cast(^Benchmark)gd
}