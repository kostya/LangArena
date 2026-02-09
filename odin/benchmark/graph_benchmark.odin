package benchmark

import "core:container/queue"

Graph :: struct {
    vertices: int,
    components: int,
    adj: [][dynamic]int,  
}

create_graph :: proc(vertices: int, components: int = 10) -> ^Graph {
    g := new(Graph)
    g.vertices = vertices
    g.components = components
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
    component_size := g.vertices / g.components

    for c in 0..<g.components {
        start_idx := c * component_size
        end_idx := (c == g.components - 1) ? g.vertices : (c + 1) * component_size

        for i in start_idx + 1..<end_idx {
            parent := start_idx + next_int(i - start_idx)
            graph_add_edge(g, i, parent)
        }

        extra_edges := component_size * 2
        for e in 0..<extra_edges {
            u := start_idx + next_int(end_idx - start_idx)
            v := start_idx + next_int(end_idx - start_idx)
            if u != v {
                graph_add_edge(g, u, v)
            }
        }
    }
}

generate_pairs :: proc(g: ^Graph, n: int) -> [][2]int {
    result := make([][2]int, n)
    component_size := g.vertices / 10

    for i in 0..<n {
        if next_int(100) < 70 {

            component := next_int(10)
            start := component * component_size + next_int(component_size)
            end: int
            for {
                end = component * component_size + next_int(component_size)
                if end != start {
                    break
                }
            }
            result[i] = [2]int{start, end}
        } else {

            c1 := next_int(10)
            c2: int
            for {
                c2 = next_int(10)
                if c2 != c1 {
                    break
                }
            }
            start := c1 * component_size + next_int(component_size)
            end := c2 * component_size + next_int(component_size)
            result[i] = [2]int{start, end}
        }
    }

    return result
}

GraphPathBenchmark :: struct {
    using base: Benchmark,
    graph: ^Graph,
    pairs: [][2]int,
    n_pairs: int,
    vertices: int,
    result_val: i64,
}

GraphPathVTable :: struct {
    using base_vtable: Benchmark_VTable,
    test: proc(bench: ^GraphPathBenchmark) -> i64,
}

graphpath_prepare :: proc(bench: ^Benchmark) {
    gb := cast(^GraphPathBenchmark)bench

    if gb.n_pairs == 0 {
        gb.n_pairs = int(config_i64(gb.name, "pairs"))
        gb.vertices = int(config_i64(gb.name, "vertices"))

        comps := max(10, gb.vertices / 10000)
        gb.graph = create_graph(gb.vertices, comps)
        graph_generate_random(gb.graph)

        gb.pairs = generate_pairs(gb.graph, gb.n_pairs)
    }
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
    delete(gb.pairs)
}