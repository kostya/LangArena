package benchmark

import "core:math"

INF :: 0x7FFFFFFF

GraphPathDijkstra :: struct {
    base: GraphPathBenchmark,
}

dijkstra_shortest_path :: proc(g: ^Graph, start, target: int) -> int {
    if start == target {
        return 0
    }

    dist := make([]int, g.vertices)
    visited := make([]bool, g.vertices)
    defer {
        delete(dist)
        delete(visited)
    }

    for i in 0..<g.vertices {
        dist[i] = INF
    }
    dist[start] = 0

    for iteration in 0..<g.vertices {
        u := -1
        min_dist := INF

        for v in 0..<g.vertices {
            if !visited[v] && dist[v] < min_dist {
                min_dist = dist[v]
                u = v
            }
        }

        if u == -1 || min_dist == INF || u == target {
            if u == target {
                return min_dist
            }
            return -1
        }

        visited[u] = true

        for v in g.adj[u][:] {
            if dist[u] + 1 < dist[v] {
                dist[v] = dist[u] + 1
            }
        }
    }

    return -1
}

graphdijkstra_test :: proc(bench: ^GraphPathBenchmark) -> i64 {
    total_length: i64 = 0

    for pair in bench.pairs {
        start := pair[0]
        target := pair[1]
        total_length += i64(dijkstra_shortest_path(bench.graph, start, target))
    }

    return total_length
}

create_graphdijkstra :: proc() -> ^Benchmark {
    gd := new(GraphPathDijkstra)

    gd.base.name = "GraphPathDijkstra"
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

    vtable.test = graphdijkstra_test

    gd.base.vtable = cast(^Benchmark_VTable)vtable

    return cast(^Benchmark)gd
}