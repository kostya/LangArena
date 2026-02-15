package benchmark

import "core:container/queue"
import "core:math"
import "core:mem"

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

    gb.base.name = "GraphPathBFS"
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

    gd.base.name = "GraphPathDFS"
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

PriorityQueue :: struct {
    vertices: [dynamic]int,
    priorities: [dynamic]int,
}

priority_queue_init :: proc(capacity: int = 16) -> PriorityQueue {
    return PriorityQueue{
        vertices = make([dynamic]int, 0, capacity),
        priorities = make([dynamic]int, 0, capacity),
    }
}

priority_queue_destroy :: proc(pq: ^PriorityQueue) {
    delete(pq.vertices)
    delete(pq.priorities)
}

priority_queue_push :: proc(pq: ^PriorityQueue, vertex: int, priority: int) {
    append(&pq.vertices, vertex)
    append(&pq.priorities, priority)

    i := len(pq.vertices) - 1
    for i > 0 {
        parent := (i - 1) / 2
        if pq.priorities[parent] <= pq.priorities[i] {
            break
        }
        pq.vertices[i], pq.vertices[parent] = pq.vertices[parent], pq.vertices[i]
        pq.priorities[i], pq.priorities[parent] = pq.priorities[parent], pq.priorities[i]
        i = parent
    }
}

priority_queue_pop :: proc(pq: ^PriorityQueue) -> (int, bool) {
    if len(pq.vertices) == 0 {
        return 0, false
    }

    result := pq.vertices[0]

    last_idx := len(pq.vertices) - 1
    pq.vertices[0] = pq.vertices[last_idx]
    pq.priorities[0] = pq.priorities[last_idx]

    pop(&pq.vertices)
    pop(&pq.priorities)

    i := 0
    n := len(pq.vertices)
    for {
        left := 2 * i + 1
        right := 2 * i + 2
        smallest := i

        if left < n && pq.priorities[left] < pq.priorities[smallest] {
            smallest = left
        }
        if right < n && pq.priorities[right] < pq.priorities[smallest] {
            smallest = right
        }
        if smallest == i {
            break
        }

        pq.vertices[i], pq.vertices[smallest] = pq.vertices[smallest], pq.vertices[i]
        pq.priorities[i], pq.priorities[smallest] = pq.priorities[smallest], pq.priorities[i]
        i = smallest
    }

    return result, true
}

priority_queue_empty :: proc(pq: ^PriorityQueue) -> bool {
    return len(pq.vertices) == 0
}

heuristic :: proc(v, target: int) -> int {
    return target - v
}

a_star_shortest_path :: proc(g: ^Graph, start, target: int) -> int {
    if start == target {
        return 0
    }

    INF := max(int)
    g_score := make([]int, g.vertices)
    f_score := make([]int, g.vertices)
    closed := make([]bool, g.vertices)
    defer {
        delete(g_score)
        delete(f_score)
        delete(closed)
    }

    for i in 0..<g.vertices {
        g_score[i] = INF
        f_score[i] = INF
    }
    g_score[start] = 0
    f_score[start] = heuristic(start, target)

    open_set := priority_queue_init()
    defer priority_queue_destroy(&open_set)

    in_open_set := make([]bool, g.vertices)
    defer delete(in_open_set)

    priority_queue_push(&open_set, start, f_score[start])
    in_open_set[start] = true

    for !priority_queue_empty(&open_set) {
        current, ok := priority_queue_pop(&open_set)
        if !ok { break }

        in_open_set[current] = false

        if current == target {
            return g_score[current]
        }

        closed[current] = true

        for neighbor in g.adj[current] {
            if closed[neighbor] {
                continue
            }

            tentative_g := g_score[current] + 1

            if tentative_g < g_score[neighbor] {
                g_score[neighbor] = tentative_g
                f_score[neighbor] = tentative_g + heuristic(neighbor, target)

                if !in_open_set[neighbor] {
                    priority_queue_push(&open_set, neighbor, f_score[neighbor])
                    in_open_set[neighbor] = true
                }
            }
        }
    }

    return -1
}

graphastar_test :: proc(bench: ^GraphPathBenchmark) -> i64 {
    return i64(a_star_shortest_path(bench.graph, 0, bench.graph.vertices - 1))
}

create_graphastar :: proc() -> ^Benchmark {
    ga := new(GraphPathAStar)

    ga.base.name = "GraphPathAStar"
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