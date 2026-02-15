using ..BenchmarkFramework

mutable struct Graph
    vertices::Int32
    jumps::Int32
    jump_len::Int32
    adj::Vector{Vector{Int32}}

    function Graph(vertices::Int32, jumps::Int32=3, jump_len::Int32=100)
        adj = [Int32[] for _ in 1:vertices]
        new(vertices, jumps, jump_len, adj)
    end
end

function add_edge(g::Graph, u::Int64, v::Int64)
    push!(g.adj[u+1], Int32(v))
    push!(g.adj[v+1], Int32(u))
end

function generate_random(g::Graph)

    for i in 1:g.vertices-1
        add_edge(g, i, i-1)
    end

    for v in 0:g.vertices-1
        num_jumps = Helper.next_int(g.jumps)
        for _ in 1:num_jumps
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
        vertices_val = Helper.config_i64("GraphPathBFS", "vertices")
        jumps_val = Helper.config_i64("GraphPathBFS", "jumps")
        jump_len_val = Helper.config_i64("GraphPathBFS", "jump_len")

        graph = Graph(Int32(vertices_val), Int32(jumps_val), Int32(jump_len_val))
        new(graph, UInt32(0))
    end
end

name(b::GraphPathBFS)::String = "GraphPathBFS"

function prepare(b::GraphPathBFS)
    generate_random(b.graph)
end

function bfs_shortest_path(graph::Graph, start::Int64, target::Int64)::Int32
    if start == target
        return 0
    end

    visited = falses(graph.vertices)
    queue = Vector{Tuple{Int64, Int32}}()

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
        vertices_val = Helper.config_i64("GraphPathDFS", "vertices")
        jumps_val = Helper.config_i64("GraphPathDFS", "jumps")
        jump_len_val = Helper.config_i64("GraphPathDFS", "jump_len")

        graph = Graph(Int32(vertices_val), Int32(jumps_val), Int32(jump_len_val))
        new(graph, UInt32(0))
    end
end

name(b::GraphPathDFS)::String = "GraphPathDFS"

function prepare(b::GraphPathDFS)
    generate_random(b.graph)
end

function dfs_find_path(graph::Graph, start::Int64, target::Int64)::Int32
    if start == target
        return 0
    end

    visited = falses(graph.vertices)
    stack = Vector{Tuple{Int64, Int32}}()
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

mutable struct PriorityQueue
    vertices::Vector{Int64}
    priorities::Vector{Int32}
    size::Int32

    function PriorityQueue(initial_capacity::Int64=16)
        vertices = Vector{Int64}(undef, initial_capacity)
        priorities = Vector{Int32}(undef, initial_capacity)
        new(vertices, priorities, 0)
    end
end

function pq_push!(pq::PriorityQueue, vertex::Int64, priority::Int32)
    if pq.size >= length(pq.vertices)
        new_capacity = length(pq.vertices) * 2
        resize!(pq.vertices, new_capacity)
        resize!(pq.priorities, new_capacity)
    end

    pq.size += 1
    i = pq.size
    pq.vertices[i] = vertex
    pq.priorities[i] = priority

    while i > 1
        parent = i ÷ 2
        if pq.priorities[parent] <= pq.priorities[i]
            break
        end
        pq.vertices[i], pq.vertices[parent] = pq.vertices[parent], pq.vertices[i]
        pq.priorities[i], pq.priorities[parent] = pq.priorities[parent], pq.priorities[i]
        i = parent
    end
end

function pq_pop!(pq::PriorityQueue)
    vertex = pq.vertices[1]
    pq.vertices[1] = pq.vertices[pq.size]
    pq.priorities[1] = pq.priorities[pq.size]
    pq.size -= 1

    i = 1
    while true
        left = 2 * i
        right = left + 1
        smallest = i

        if left <= pq.size && pq.priorities[left] < pq.priorities[smallest]
            smallest = left
        end
        if right <= pq.size && pq.priorities[right] < pq.priorities[smallest]
            smallest = right
        end
        if smallest == i
            break
        end

        pq.vertices[i], pq.vertices[smallest] = pq.vertices[smallest], pq.vertices[i]
        pq.priorities[i], pq.priorities[smallest] = pq.priorities[smallest], pq.priorities[i]
        i = smallest
    end

    return vertex
end

function pq_isempty(pq::PriorityQueue)
    return pq.size == 0
end

mutable struct GraphPathAStar <: AbstractGraphPathBenchmark
    graph::Graph
    result::UInt32

    function GraphPathAStar()
        vertices_val = Helper.config_i64("GraphPathAStar", "vertices")
        jumps_val = Helper.config_i64("GraphPathAStar", "jumps")
        jump_len_val = Helper.config_i64("GraphPathAStar", "jump_len")

        graph = Graph(Int32(vertices_val), Int32(jumps_val), Int32(jump_len_val))
        new(graph, UInt32(0))
    end
end

name(b::GraphPathAStar)::String = "GraphPathAStar"

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

    open_set = PriorityQueue()
    in_open_set = falses(graph.vertices)

    pq_push!(open_set, start, f_score[start+1])
    in_open_set[start+1] = true

    while !pq_isempty(open_set)
        current = pq_pop!(open_set)
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
                f_score[neighbor+1] = tentative_g + heuristic(Int64(neighbor), target)

                if !in_open_set[neighbor+1]
                    pq_push!(open_set, Int64(neighbor), f_score[neighbor+1])
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