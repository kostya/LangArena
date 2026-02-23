using ..BenchmarkFramework
using DataStructures: BinaryMinHeap

mutable struct Graph
    vertices::Int32
    jumps::Int32
    jump_len::Int32
    adj::Vector{Vector{Int32}}

    function Graph(vertices::Int32, jumps::Int32 = 3, jump_len::Int32 = 100)
        adj = [Int32[] for _ = 1:vertices]
        new(vertices, jumps, jump_len, adj)
    end
end

function add_edge(g::Graph, u::Int64, v::Int64)
    push!(g.adj[u+1], Int32(v))
    push!(g.adj[v+1], Int32(u))
end

function generate_random(g::Graph)

    for i = 1:(g.vertices-1)
        add_edge(g, i, i-1)
    end

    for v = 0:(g.vertices-1)
        num_jumps = Helper.next_int(g.jumps)
        for _ = 1:num_jumps
            offset = Helper.next_int(g.jump_len) - g.jump_len ÷ 2
            u = v + offset

            if u >= 0 && u < g.vertices && u != v
                add_edge(g, v, u)
            end
        end
    end
end

abstract type AbstractGraphPathBenchmark <: AbstractBenchmark end

mutable struct GraphPathBFS <: AbstractGraphPathBenchmark
    graph::Graph
    result::UInt32

    function GraphPathBFS()
        vertices_val = Helper.config_i64("Graph::BFS", "vertices")
        jumps_val = Helper.config_i64("Graph::BFS", "jumps")
        jump_len_val = Helper.config_i64("Graph::BFS", "jump_len")

        graph = Graph(Int32(vertices_val), Int32(jumps_val), Int32(jump_len_val))
        new(graph, UInt32(0))
    end
end

name(b::GraphPathBFS)::String = "Graph::BFS"

function prepare(b::GraphPathBFS)
    generate_random(b.graph)
end

function bfs_shortest_path(graph::Graph, start::Int64, target::Int64)::Int32
    if start == target
        return 0
    end

    visited = falses(graph.vertices)
    queue = Vector{Tuple{Int64,Int32}}()

    visited[start+1] = true
    push!(queue, (start, Int32(0)))

    idx = 1
    while idx <= length(queue)
        v, dist = queue[idx]
        idx += 1

        for neighbor in graph.adj[v+1]
            if neighbor == target
                return dist + 1
            end

            if !visited[neighbor+1]
                visited[neighbor+1] = true
                push!(queue, (Int64(neighbor), dist + 1))
            end
        end
    end

    return -1
end

function test(b::GraphPathBFS)::Int64
    return Int64(bfs_shortest_path(b.graph, Int64(0), Int64(b.graph.vertices - 1)))
end

function run(b::GraphPathBFS, iteration_id::Int64)
    total_length = test(b)
    b.result = (b.result + UInt32(total_length)) & 0xffffffff
end

function checksum(b::GraphPathBFS)::UInt32
    return b.result
end

mutable struct GraphPathDFS <: AbstractGraphPathBenchmark
    graph::Graph
    result::UInt32

    function GraphPathDFS()
        vertices_val = Helper.config_i64("Graph::DFS", "vertices")
        jumps_val = Helper.config_i64("Graph::DFS", "jumps")
        jump_len_val = Helper.config_i64("Graph::DFS", "jump_len")

        graph = Graph(Int32(vertices_val), Int32(jumps_val), Int32(jump_len_val))
        new(graph, UInt32(0))
    end
end

name(b::GraphPathDFS)::String = "Graph::DFS"

function prepare(b::GraphPathDFS)
    generate_random(b.graph)
end

function dfs_find_path(graph::Graph, start::Int64, target::Int64)::Int32
    if start == target
        return 0
    end

    visited = falses(graph.vertices)
    stack = Vector{Tuple{Int64,Int32}}()
    best_path = typemax(Int32)

    push!(stack, (start, Int32(0)))

    while !isempty(stack)
        v, dist = pop!(stack)

        if visited[v+1] || dist >= best_path
            continue
        end
        visited[v+1] = true

        for neighbor in graph.adj[v+1]
            if neighbor == target
                if dist + 1 < best_path
                    best_path = dist + 1
                end
            elseif !visited[neighbor+1]
                push!(stack, (Int64(neighbor), dist + 1))
            end
        end
    end

    return best_path == typemax(Int32) ? -1 : best_path
end

function test(b::GraphPathDFS)::Int64
    return Int64(dfs_find_path(b.graph, Int64(0), Int64(b.graph.vertices - 1)))
end

function run(b::GraphPathDFS, iteration_id::Int64)
    total_length = test(b)
    b.result = (b.result + UInt32(total_length)) & 0xffffffff
end

function checksum(b::GraphPathDFS)::UInt32
    return b.result
end

mutable struct GraphPathAStar <: AbstractGraphPathBenchmark
    graph::Graph
    result::UInt32

    function GraphPathAStar()
        vertices_val = Helper.config_i64("Graph::AStar", "vertices")
        jumps_val = Helper.config_i64("Graph::AStar", "jumps")
        jump_len_val = Helper.config_i64("Graph::AStar", "jump_len")

        graph = Graph(Int32(vertices_val), Int32(jumps_val), Int32(jump_len_val))
        new(graph, UInt32(0))
    end
end

name(b::GraphPathAStar)::String = "Graph::AStar"

function prepare(b::GraphPathAStar)
    generate_random(b.graph)
end

function heuristic(v::Int64, target::Int64)::Int32
    return Int32(target - v)
end

function a_star_shortest_path(graph::Graph, start::Int64, target::Int64)::Int32
    if start == target
        return 0
    end

    INF = typemax(Int32)
    g_score = fill(INF, graph.vertices)
    f_score = fill(INF, graph.vertices)
    closed = falses(graph.vertices)

    g_score[start+1] = 0
    f_score[start+1] = heuristic(start, target)

    open_set = BinaryMinHeap{Tuple{Int32,Int64}}()
    in_open_set = falses(graph.vertices)

    push!(open_set, (f_score[start+1], start))
    in_open_set[start+1] = true

    while !isempty(open_set)
        f, current = pop!(open_set)
        in_open_set[current+1] = false

        if current == target
            return g_score[current+1]
        end

        closed[current+1] = true

        for neighbor in graph.adj[current+1]
            if closed[neighbor+1]
                continue
            end

            tentative_g = g_score[current+1] + 1

            if tentative_g < g_score[neighbor+1]
                g_score[neighbor+1] = tentative_g
                new_f = tentative_g + heuristic(Int64(neighbor), target)
                f_score[neighbor+1] = new_f

                if !in_open_set[neighbor+1]
                    push!(open_set, (new_f, Int64(neighbor)))
                    in_open_set[neighbor+1] = true
                end
            end
        end
    end

    return -1
end

function test(b::GraphPathAStar)::Int64
    return Int64(a_star_shortest_path(b.graph, Int64(0), Int64(b.graph.vertices - 1)))
end

function run(b::GraphPathAStar, iteration_id::Int64)
    total_length = test(b)
    b.result = (b.result + UInt32(total_length)) & 0xffffffff
end

function checksum(b::GraphPathAStar)::UInt32
    return b.result
end
