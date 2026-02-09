package benchmark

import "core:container/queue"

GraphPathBFS :: struct {
    base: GraphPathBenchmark,
}

bfs_shortest_path :: proc(g: ^Graph, start, target: int) -> int {
    if start == target {
        return 0
    }

    visited := make([]bool, g.vertices)
    defer delete(visited)

    q: queue.Queue([2]int)  
    queue.init(&q)
    defer queue.destroy(&q)

    visited[start] = true
    queue.push_back(&q, [2]int{start, 0})

    for queue.len(q) > 0 {
        item := queue.pop_front(&q)
        v := item[0]
        dist := item[1]

        for neighbor in g.adj[v] {
            if neighbor == target {
                return dist + 1
            }

            if !visited[neighbor] {
                visited[neighbor] = true
                queue.push_back(&q, [2]int{neighbor, dist + 1})
            }
        }
    }

    return -1
}

graphbfs_test :: proc(bench: ^GraphPathBenchmark) -> i64 {
    total_length: i64 = 0

    for pair in bench.pairs {
        start := pair[0]
        target := pair[1]
        total_length += i64(bfs_shortest_path(bench.graph, start, target))
    }

    return total_length
}

create_graphbfs :: proc() -> ^Benchmark {
    gb := new(GraphPathBFS)

    gb.base.name = "GraphPathBFS"
    gb.base.n_pairs = 0
    gb.base.vertices = 0
    gb.base.result_val = 0

    vtable := new(GraphPathVTable)
    base_vtable := default_vtable()
    vtable.base_vtable = base_vtable^

    vtable.base_vtable.prepare = graphpath_prepare
    vtable.base_vtable.run = graphpath_run
    vtable.base_vtable.checksum = graphpath_checksum
    vtable.base_vtable.cleanup = graphpath_cleanup
    vtable.base_vtable.warmup = default_warmup

    vtable.test = graphbfs_test

    gb.base.vtable = cast(^Benchmark_VTable)vtable

    return cast(^Benchmark)gb
}