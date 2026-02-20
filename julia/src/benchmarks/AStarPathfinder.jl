mutable struct AStarPathfinder <: AbstractBenchmark
    width::Int64
    height::Int64
    start_x::Int64
    start_y::Int64
    goal_x::Int64
    goal_y::Int64
    maze_grid::Vector{Vector{Bool}}
    g_scores_cache::Vector{Int64}
    came_from_cache::Vector{Int64}
    result::UInt32
end

struct Node
    x::Int64
    y::Int64
    f_score::Int64
end

function Base.isless(a::Node, b::Node)::Bool
    if a.f_score != b.f_score
        return a.f_score < b.f_score
    end
    if a.y != b.y
        return a.y < b.y
    end
    return a.x < b.x
end

mutable struct BinaryHeap{T}
    data::Vector{T}

    function BinaryHeap{T}() where {T}
        new{T}(Vector{T}())
    end
end

function heap_push!(heap::BinaryHeap{T}, item::T) where {T}
    Base.push!(heap.data, item)
    sift_up!(heap, length(heap.data))
end

function heap_pop!(heap::BinaryHeap{T})::Union{T,Nothing} where {T}
    if Base.isempty(heap.data)
        return nothing
    end
    if length(heap.data) == 1
        return Base.pop!(heap.data)
    end

    result = heap.data[1]
    heap.data[1] = Base.pop!(heap.data)
    sift_down!(heap, 1)
    return result
end

function heap_isempty(heap::BinaryHeap)::Bool
    return Base.isempty(heap.data)
end

function sift_up!(heap::BinaryHeap{T}, index::Int64) where {T}
    while index > 1
        parent = index ÷ 2
        if Base.isless(heap.data[index], heap.data[parent])
            heap.data[index], heap.data[parent] = heap.data[parent], heap.data[index]
            index = parent
        else
            break
        end
    end
end

function sift_down!(heap::BinaryHeap{T}, index::Int64) where {T}
    n = length(heap.data)
    while true
        left = 2 * index
        right = left + 1
        smallest = index

        if left <= n && Base.isless(heap.data[left], heap.data[smallest])
            smallest = left
        end
        if right <= n && Base.isless(heap.data[right], heap.data[smallest])
            smallest = right
        end

        if smallest == index
            break
        end

        heap.data[index], heap.data[smallest] = heap.data[smallest], heap.data[index]
        index = smallest
    end
end

function manhattan_distance(ax::Int64, ay::Int64, bx::Int64, by::Int64)::Int64
    return abs(ax - bx) + abs(ay - by)
end

function pack_coords(width::Int64, x::Int64, y::Int64)::Int64
    return (y - 1) * width + x
end

function unpack_coords(width::Int64, packed::Int64)::Tuple{Int64,Int64}
    packed -= 1
    y = packed ÷ width
    x = packed - y * width
    return (x + 1, y + 1)
end

function find_path(
    astar::AStarPathfinder,
)::Tuple{Union{Vector{Tuple{Int64,Int64}},Nothing},Int64}
    grid = astar.maze_grid
    width = astar.width
    height = astar.height

    size_val = width * height
    g_scores = astar.g_scores_cache
    came_from = astar.came_from_cache

    Base.fill!(g_scores, typemax(Int64))
    Base.fill!(came_from, -1)

    open_set = BinaryHeap{Node}()
    nodes_explored = 0

    start_idx = pack_coords(width, astar.start_x, astar.start_y)
    g_scores[start_idx] = 0

    start_f = manhattan_distance(astar.start_x, astar.start_y, astar.goal_x, astar.goal_y)
    heap_push!(open_set, Node(astar.start_x, astar.start_y, start_f))

    directions = [(0, -1), (1, 0), (0, 1), (-1, 0)]

    while !heap_isempty(open_set)
        current = heap_pop!(open_set)
        nodes_explored += 1

        if current.x == astar.goal_x && current.y == astar.goal_y

            path = Vector{Tuple{Int64,Int64}}()
            x = current.x
            y = current.y

            while x != astar.start_x || y != astar.start_y
                Base.push!(path, (x, y))
                idx = pack_coords(width, x, y)
                packed = came_from[idx]
                if packed == -1
                    break
                end
                x, y = unpack_coords(width, packed)
            end

            Base.push!(path, (astar.start_x, astar.start_y))
            Base.reverse!(path)
            return (path, nodes_explored)
        end

        current_idx = pack_coords(width, current.x, current.y)
        current_g = g_scores[current_idx]

        for (dx, dy) in directions
            nx = current.x + dx
            ny = current.y + dy

            if nx < 1 || nx > width || ny < 1 || ny > height
                continue
            end
            if !grid[ny][nx]
                continue
            end

            tentative_g = current_g + 1000
            neighbor_idx = pack_coords(width, nx, ny)

            if tentative_g < g_scores[neighbor_idx]
                came_from[neighbor_idx] = current_idx
                g_scores[neighbor_idx] = tentative_g

                f_score =
                    tentative_g + manhattan_distance(nx, ny, astar.goal_x, astar.goal_y)
                heap_push!(open_set, Node(nx, ny, f_score))
            end
        end
    end

    return (nothing, nodes_explored)
end

function AStarPathfinder()
    width = Helper.config_i64("AStarPathfinder", "w")
    height = Helper.config_i64("AStarPathfinder", "h")
    start_x = Int64(2)
    start_y = Int64(2)
    goal_x = width - 1
    goal_y = height - 1
    maze_grid = Vector{Vector{Bool}}()

    size_val = width * height
    g_scores_cache = Base.fill(typemax(Int64), size_val)
    came_from_cache = Base.fill(-1, size_val)

    return AStarPathfinder(
        width,
        height,
        start_x,
        start_y,
        goal_x,
        goal_y,
        maze_grid,
        g_scores_cache,
        came_from_cache,
        UInt32(0),
    )
end

name(b::AStarPathfinder)::String = "AStarPathfinder"

function prepare(b::AStarPathfinder)

    b.maze_grid = generate_walkable_maze(b.width, b.height)
end

function run(b::AStarPathfinder, iteration_id::Int64)
    path, nodes_explored = find_path(b)

    local_result = UInt32(0)

    path_length = path === nothing ? 0 : length(path)
    local_result = UInt32(path_length)

    local_result = (local_result << 5) + UInt32(nodes_explored)

    b.result += local_result
end

function checksum(b::AStarPathfinder)::UInt32
    return b.result
end
