package benchmark

import "core:container/queue"
import "core:math"
import "core:mem"
import "core:container/priority_queue"

Graph :: struct {
    vertices: int,
    jumps: int,
    jump_len: int,
    adj: [][dynamic]int,
}

create_graph :: proc(vertices: int, jumps: int = 3, jump_len: int = 100) -> ^Graph {
    g := new(Graph)
    g.vertices = vertices
    g.jumps = jumps
    g.jump_len = jump_len
    g.adj = make([][dynamic]int, vertices)
    return g
}

destroy_graph :: proc(g: ^Graph) {
    for neighbors in g.adj {
        delete(neighbors)
    }
    delete(g.adj)
    free(g)
}

graph_add_edge :: proc(g: ^Graph, u, v: int) {
    append(&g.adj[u], v)
    append(&g.adj[v], u)
}

graph_generate_random :: proc(g: ^Graph) {

    for i in 1..<g.vertices {
        graph_add_edge(g, i, i-1)
    }

    for v in 0..<g.vertices {
        num_jumps := next_int(g.jumps)
        for _ in 0..<num_jumps {
            offset := next_int(g.jump_len) - g.jump_len / 2
            u := v + offset

            if u >= 0 && u < g.vertices && u != v {
                graph_add_edge(g, v, u)
            }
        }
    }
}

GraphPathBenchmark :: struct {
    using base: Benchmark,
    graph: ^Graph,
    vertices: int,
    result_val: i64,
}

GraphPathVTable :: struct {
    using base_vtable: Benchmark_VTable,
    test: proc(bench: ^GraphPathBenchmark) -> i64,
}

graphpath_prepare :: proc(bench: ^Benchmark) {
    gb := cast(^GraphPathBenchmark)bench

    gb.vertices = int(config_i64(gb.name, "vertices"))
    jumps := int(config_i64(gb.name, "jumps"))
    jump_len := int(config_i64(gb.name, "jump_len"))

    gb.graph = create_graph(gb.vertices, jumps, jump_len)
    graph_generate_random(gb.graph)
}

graphpath_run :: proc(bench: ^Benchmark, iteration_id: int) {
    gb := cast(^GraphPathBenchmark)bench
    vtable := cast(^GraphPathVTable)bench.vtable

    gb.result_val += vtable.test(gb)
}

graphpath_checksum :: proc(bench: ^Benchmark) -> u32 {
    gb := cast(^GraphPathBenchmark)bench
    return u32(gb.result_val)
}

graphpath_cleanup :: proc(bench: ^Benchmark) {
    gb := cast(^GraphPathBenchmark)bench
    if gb.graph != nil {
        destroy_graph(gb.graph)
    }
}

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
    return i64(bfs_shortest_path(bench.graph, 0, bench.graph.vertices - 1))
}

create_graphbfs :: proc() -> ^Benchmark {
    gb := new(GraphPathBFS)

    gb.base.name = "Graph::BFS"
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
    return i64(dfs_find_path(bench.graph, 0, bench.graph.vertices - 1))
}

create_graphdfs :: proc() -> ^Benchmark {
    gd := new(GraphPathDFS)

    gd.base.name = "Graph::DFS"
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

GraphPathAStar :: struct {
    base: GraphPathBenchmark,
}

GPANode :: struct {
    vertex: int,
    f_score: int,
}

gpa_node_less :: proc(a, b: GPANode) -> bool {
    return a.f_score < b.f_score
}

gpa_node_swap :: proc(nodes: []GPANode, i, j: int) {
    nodes[i], nodes[j] = nodes[j], nodes[i]
}

heuristic :: proc(v, target: int) -> int {
    return target - v
}

astar_shortest_path :: proc(g: ^Graph, start, target: int) -> int {
    if start == target {
        return 0
    }

    INF := max(int)
    g_score := make([]int, g.vertices)
    f_score := make([]int, g.vertices)
    in_open_set := make([]bool, g.vertices)
    closed := make([]bool, g.vertices)
    defer {
        delete(g_score)
        delete(f_score)
        delete(in_open_set)
        delete(closed)
    }

    for i in 0..<g.vertices {
        g_score[i] = INF
        f_score[i] = INF
        closed[i] = false
        in_open_set[i] = false
    }

    g_score[start] = 0
    f_score[start] = heuristic(start, target)

    open_set: priority_queue.Priority_Queue(GPANode)
    err := priority_queue.init(&open_set, gpa_node_less, gpa_node_swap, 16)
    if err != nil {
        return -1
    }
    defer priority_queue.destroy(&open_set)

    priority_queue.push(&open_set, GPANode{start, f_score[start]})
    in_open_set[start] = true

    for priority_queue.len(open_set) > 0 {
        current := priority_queue.pop(&open_set)

        if closed[current.vertex] {
            continue
        }
        closed[current.vertex] = true
        in_open_set[current.vertex] = false

        if current.vertex == target {
            return g_score[current.vertex]
        }

        for neighbor in g.adj[current.vertex] {
            if closed[neighbor] {
                continue
            }

            tentative_g := g_score[current.vertex] + 1

            if tentative_g < g_score[neighbor] {
                g_score[neighbor] = tentative_g
                f_score[neighbor] = tentative_g + heuristic(neighbor, target)

                if !in_open_set[neighbor] {
                    priority_queue.push(&open_set, GPANode{neighbor, f_score[neighbor]})
                    in_open_set[neighbor] = true
                }
            }
        }
    }

    return -1
}

graphastar_test :: proc(bench: ^GraphPathBenchmark) -> i64 {
    return i64(astar_shortest_path(bench.graph, 0, bench.graph.vertices - 1))
}

create_graphastar :: proc() -> ^Benchmark {
    ga := new(GraphPathAStar)

    ga.base.name = "Graph::AStar"
    ga.base.vertices = 0
    ga.base.result_val = 0

    vtable := new(GraphPathVTable)
    base_vtable := default_vtable()
    vtable.base_vtable = base_vtable^

    vtable.base_vtable.prepare = graphpath_prepare
    vtable.base_vtable.run = graphpath_run
    vtable.base_vtable.checksum = graphpath_checksum
    vtable.base_vtable.cleanup = graphpath_cleanup
    vtable.base_vtable.warmup = default_warmup

    vtable.test = graphastar_test

    ga.base.vtable = cast(^Benchmark_VTable)vtable

    return cast(^Benchmark)ga
}