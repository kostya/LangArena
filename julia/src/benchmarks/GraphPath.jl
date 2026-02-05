using ..BenchmarkFramework
using DataStructures  

mutable struct Graph
    vertices::Int32
    components::Int32
    adj::Vector{Vector{Int32}}

    function Graph(vertices::Int32, components::Int32=10)
        adj = [Int32[] for _ in 1:vertices]
        new(vertices, components, adj)
    end
end

function add_edge(g::Graph, u::Int64, v::Int64)
    push!(g.adj[u+1], Int32(v))  
    push!(g.adj[v+1], Int32(u))  
end

function generate_random(g::Graph)
    component_size = div(g.vertices, g.components)

    for c in 0:g.components-1
        start_idx = c * component_size
        end_idx = (c == g.components-1) ? g.vertices : (c + 1) * component_size

        for i in start_idx+1:end_idx-1
            parent = start_idx + Helper.next_int(i - start_idx)
            add_edge(g, i, parent)
        end

        for _ in 1:component_size*2
            u = start_idx + Helper.next_int(end_idx - start_idx)
            v = start_idx + Helper.next_int(end_idx - start_idx)
            if u != v
                add_edge(g, u, v)
            end
        end
    end
end

function same_component(g::Graph, u::Int32, v::Int32)
    component_size = div(g.vertices, g.components)
    return div(u, component_size) == div(v, component_size)
end

abstract type AbstractGraphPathBenchmark <: AbstractBenchmark end

mutable struct GraphPathBenchmark <: AbstractGraphPathBenchmark
    n_pairs::Int64
    graph::Graph
    pairs::Vector{Tuple{Int32, Int32}}
    result::UInt32

    function GraphPathBenchmark()
        n_pairs_val = Helper.config_i64("GraphPathBenchmark", "pairs")
        vertices_val = Helper.config_i64("GraphPathBenchmark", "vertices")
        components_val = max(10, div(vertices_val, 10000))

        graph = Graph(Int32(vertices_val), Int32(components_val))
        new(n_pairs_val, graph, Tuple{Int32, Int32}[], UInt32(0))
    end
end

name(b::GraphPathBenchmark)::String = "GraphPathBenchmark"

function generate_pairs_common(graph::Graph, n_pairs::Int64)
    pairs = Vector{Tuple{Int32, Int32}}()
    sizehint!(pairs, n_pairs)

    component_size = div(graph.vertices, graph.components)

    for _ in 1:n_pairs

        if Helper.next_int(100) < 70

            component = Helper.next_int(graph.components)
            start = component * component_size + Helper.next_int(component_size)

            while true
                _end = component * component_size + Helper.next_int(component_size)
                if _end != start
                    push!(pairs, (start, _end))
                    break
                end
            end
        else

            c1 = Helper.next_int(graph.components)
            c2 = Helper.next_int(graph.components)
            while c2 == c1
                c2 = Helper.next_int(graph.components)
            end

            start = c1 * component_size + Helper.next_int(component_size)
            _end = c2 * component_size + Helper.next_int(component_size)
            push!(pairs, (start, _end))
        end
    end

    return pairs
end

function prepare_graph_path(b)
    generate_random(b.graph)
    b.pairs = generate_pairs_common(b.graph, b.n_pairs)
end

function prepare(b::GraphPathBenchmark)
    prepare_graph_path(b)
end

function test(b::GraphPathBenchmark)::Int64

    error("Abstract method 'test' not implemented")
end

function run(b::GraphPathBenchmark, iteration_id::Int64)
    total_length = test(b)
    b.result = (b.result + UInt32(total_length)) & 0xffffffff
end

function checksum(b::GraphPathBenchmark)::UInt32
    return b.result
end

mutable struct GraphPathBFS <: AbstractGraphPathBenchmark
    n_pairs::Int64
    graph::Graph
    pairs::Vector{Tuple{Int32, Int32}}
    result::UInt32

    function GraphPathBFS()
        n_pairs_val = Helper.config_i64("GraphPathBFS", "pairs")
        vertices_val = Helper.config_i64("GraphPathBFS", "vertices")
        components_val = max(10, div(vertices_val, 10000))

        graph = Graph(Int32(vertices_val), Int32(components_val))
        new(n_pairs_val, graph, Tuple{Int32, Int32}[], UInt32(0))
    end
end

name(b::GraphPathBFS)::String = "GraphPathBFS"

function prepare(b::GraphPathBFS)
    prepare_graph_path(b)
end

function bfs_shortest_path(b::GraphPathBFS, start::Int32, target::Int32)::Int32
    if start == target
        return 0
    end

    visited = falses(b.graph.vertices)
    queue = Vector{Tuple{Int32, Int32}}()

    visited[start+1] = true  
    push!(queue, (start, 0))

    idx = 1
    while idx <= length(queue)
        v, dist = queue[idx]
        idx += 1

        for neighbor in b.graph.adj[v+1]  
            if neighbor == target
                return dist + 1
            end

            if !visited[neighbor+1]  
                visited[neighbor+1] = true
                push!(queue, (neighbor, dist + 1))
            end
        end
    end

    return -1  
end

function test(b::GraphPathBFS)::Int64
    total_length = Int64(0)

    for (start, _end) in b.pairs
        length_val = bfs_shortest_path(b, start, _end)
        total_length += length_val
    end

    return total_length
end

function run(b::GraphPathBFS, iteration_id::Int64)
    total_length = test(b)
    b.result = (b.result + UInt32(total_length)) & 0xffffffff
end

function checksum(b::GraphPathBFS)::UInt32
    return b.result
end

mutable struct GraphPathDFS <: AbstractGraphPathBenchmark
    n_pairs::Int64
    graph::Graph
    pairs::Vector{Tuple{Int32, Int32}}
    result::UInt32

    function GraphPathDFS()
        n_pairs_val = Helper.config_i64("GraphPathDFS", "pairs")
        vertices_val = Helper.config_i64("GraphPathDFS", "vertices")
        components_val = max(10, div(vertices_val, 10000))

        graph = Graph(Int32(vertices_val), Int32(components_val))
        new(n_pairs_val, graph, Tuple{Int32, Int32}[], UInt32(0))
    end
end

name(b::GraphPathDFS)::String = "GraphPathDFS"

function prepare(b::GraphPathDFS)
    prepare_graph_path(b)
end

function dfs_find_path(b::GraphPathDFS, start::Int32, target::Int32)::Int32
    if start == target
        return 0
    end

    visited = falses(b.graph.vertices)
    stack = Vector{Tuple{Int32, Int32}}()
    best_path = typemax(Int32)

    push!(stack, (start, 0))

    while !isempty(stack)
        v, dist = pop!(stack)

        if visited[v+1] || dist >= best_path
            continue
        end
        visited[v+1] = true

        for neighbor in b.graph.adj[v+1]  
            if neighbor == target
                if dist + 1 < best_path
                    best_path = dist + 1
                end
            elseif !visited[neighbor+1]  
                push!(stack, (neighbor, dist + 1))
            end
        end
    end

    return best_path == typemax(Int32) ? -1 : best_path
end

function test(b::GraphPathDFS)::Int64
    total_length = Int64(0)

    for (start, _end) in b.pairs
        length_val = dfs_find_path(b, start, _end)
        total_length += length_val
    end

    return total_length
end

function run(b::GraphPathDFS, iteration_id::Int64)
    total_length = test(b)
    b.result = (b.result + UInt32(total_length)) & 0xffffffff
end

function checksum(b::GraphPathDFS)::UInt32
    return b.result
end

mutable struct GraphPathDijkstra <: AbstractGraphPathBenchmark
    n_pairs::Int64
    graph::Graph
    pairs::Vector{Tuple{Int32, Int32}}
    result::UInt32

    function GraphPathDijkstra()
        n_pairs_val = Helper.config_i64("GraphPathDijkstra", "pairs")
        vertices_val = Helper.config_i64("GraphPathDijkstra", "vertices")
        components_val = max(10, div(vertices_val, 10000))

        graph = Graph(Int32(vertices_val), Int32(components_val))
        new(n_pairs_val, graph, Tuple{Int32, Int32}[], UInt32(0))
    end
end

name(b::GraphPathDijkstra)::String = "GraphPathDijkstra"

function prepare(b::GraphPathDijkstra)
    prepare_graph_path(b)
end

const INF = typemax(Int32) ÷ 2

function dijkstra_shortest_path(b::GraphPathDijkstra, start::Int32, target::Int32)::Int32
    if start == target
        return 0
    end

    dist = fill(INF, b.graph.vertices)
    visited = falses(b.graph.vertices)

    dist[start+1] = 0  

    max_iterations = b.graph.vertices

    for iteration in 1:max_iterations

        u = -1
        min_dist = INF

        for v in 0:b.graph.vertices-1
            if !visited[v+1] && dist[v+1] < min_dist
                min_dist = dist[v+1]
                u = v
            end
        end

        if u == -1 || min_dist == INF || u == target
            return (u == target) ? min_dist : -1
        end

        visited[u+1] = true

        for neighbor in b.graph.adj[u+1]  
            new_dist = dist[u+1] + 1  
            if new_dist < dist[neighbor+1]  
                dist[neighbor+1] = new_dist
            end
        end
    end

    return -1
end

function test(b::GraphPathDijkstra)::Int64
    total_length = Int64(0)

    for (start, _end) in b.pairs
        length_val = dijkstra_shortest_path(b, start, _end)
        total_length += length_val
    end

    return total_length
end

function run(b::GraphPathDijkstra, iteration_id::Int64)
    total_length = test(b)
    b.result = (b.result + UInt32(total_length)) & 0xffffffff
end

function checksum(b::GraphPathDijkstra)::UInt32
    return b.result
end