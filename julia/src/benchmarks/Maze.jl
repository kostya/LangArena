@enum CellKind begin
    WALL = 0
    SPACE = 1
    START = 2
    FINISH = 3
    BORDER = 4
    PATH = 5
end

is_walkable(kind::CellKind) = kind in (SPACE, START, FINISH)

mutable struct Cell
    kind::CellKind
    neighbors::Vector{Cell}
    x::Int
    y::Int
end

function Cell(x::Int, y::Int)
    return Cell(WALL, Cell[], x, y)
end

function add_neighbor(cell::Cell, neighbor::Cell)
    push!(cell.neighbors, neighbor)
end

function reset(cell::Cell)
    if cell.kind == SPACE
        cell.kind = WALL
    end
end

mutable struct Maze
    width::Int
    height::Int
    cells::Matrix{Cell}
    start::Cell
    finish::Cell
end

function Maze(width::Int, height::Int)
    w = max(width, 5)
    h = max(height, 5)

    cells = Matrix{Cell}(undef, h, w)
    for y = 1:h
        for x = 1:w
            cells[y, x] = Cell(x-1, y-1)
        end
    end

    start_cell = cells[2, 2]
    finish_cell = cells[h-1, w-1]
    start_cell.kind = START
    finish_cell.kind = FINISH

    maze = Maze(w, h, cells, start_cell, finish_cell)
    update_neighbors(maze)
    return maze
end

function update_neighbors(maze::Maze)

    for y = 1:maze.height
        for x = 1:maze.width
            empty!(maze.cells[y, x].neighbors)
        end
    end

    for y = 1:maze.height
        for x = 1:maze.width
            cell = maze.cells[y, x]

            if x > 1 && y > 1 && x < maze.width && y < maze.height
                add_neighbor(cell, maze.cells[y-1, x])
                add_neighbor(cell, maze.cells[y+1, x])
                add_neighbor(cell, maze.cells[y, x+1])
                add_neighbor(cell, maze.cells[y, x-1])

                for _ = 1:4
                    i = Helper.next_int(4) + 1
                    j = Helper.next_int(4) + 1
                    if i != j && i <= length(cell.neighbors) && j <= length(cell.neighbors)
                        cell.neighbors[i], cell.neighbors[j] =
                            cell.neighbors[j], cell.neighbors[i]
                    end
                end
            else
                cell.kind = BORDER
            end
        end
    end
end

function reset(maze::Maze)
    for y = 1:maze.height
        for x = 1:maze.width
            reset(maze.cells[y, x])
        end
    end
    maze.start.kind = START
    maze.finish.kind = FINISH
end

function dig(maze::Maze, start_cell::Cell)
    stack = Cell[]
    push!(stack, start_cell)

    while !isempty(stack)
        cell = pop!(stack)

        walkable = 0
        for n in cell.neighbors
            if is_walkable(n.kind)
                walkable += 1
            end
        end

        if walkable != 1
            continue
        end

        cell.kind = SPACE

        for n in cell.neighbors
            if n.kind == WALL
                push!(stack, n)
            end
        end
    end
end

function ensure_open_finish(maze::Maze, start_cell::Cell)
    stack = Cell[]
    push!(stack, start_cell)

    while !isempty(stack)
        cell = pop!(stack)

        cell.kind = SPACE

        walkable = 0
        for n in cell.neighbors
            if is_walkable(n.kind)
                walkable += 1
            end
        end

        if walkable > 1
            continue
        end

        for n in cell.neighbors
            if n.kind == WALL
                push!(stack, n)
            end
        end
    end
end

function generate(maze::Maze)
    for n in maze.start.neighbors
        if n.kind == WALL
            dig(maze, n)
        end
    end

    for n in maze.finish.neighbors
        if n.kind == WALL
            ensure_open_finish(maze, n)
        end
    end
end

function middle_cell(maze::Maze)::Cell
    return maze.cells[div(maze.height, 2)+1, div(maze.width, 2)+1]
end

function checksum(maze::Maze)::UInt32
    hasher = UInt32(2166136261)
    prime = UInt32(16777619)

    for y = 1:maze.height
        for x = 1:maze.width
            if maze.cells[y, x].kind == SPACE
                val = UInt32((x-1) * (y-1))
                hasher = (hasher ⊻ val) * prime
            end
        end
    end
    return hasher
end

function print_to_console(maze::Maze)
    for y = 1:maze.height
        for x = 1:maze.width
            cell = maze.cells[y, x]
            if cell.kind == SPACE
                print(" ")
            elseif cell.kind == WALL
                print("\u001B[34m#\u001B[0m")
            elseif cell.kind == BORDER
                print("\u001B[31mO\u001B[0m")
            elseif cell.kind == START
                print("\u001B[32m>\u001B[0m")
            elseif cell.kind == FINISH
                print("\u001B[32m<\u001B[0m")
            elseif cell.kind == PATH
                print("\u001B[33m.\u001B[0m")
            end
        end
        println()
    end
    println()
end

mutable struct MazeGenerator <: AbstractBenchmark
    width::Int64
    height::Int64
    maze::Union{Nothing,Maze}
    result_val::UInt32
end

function MazeGenerator()
    width = Helper.config_i64("Maze::Generator", "w")
    height = Helper.config_i64("Maze::Generator", "h")
    return MazeGenerator(width, height, nothing, UInt32(0))
end

name(b::MazeGenerator)::String = "Maze::Generator"

function prepare(b::MazeGenerator)
    b.maze = Maze(b.width, b.height)
    b.result_val = UInt32(0)
end

function run(b::MazeGenerator, iteration_id::Int64)
    if b.maze === nothing
        return
    end
    reset(b.maze)
    generate(b.maze)
    b.result_val += UInt32(middle_cell(b.maze).kind)
end

function checksum(b::MazeGenerator)::UInt32
    if b.maze === nothing
        return UInt32(0)
    end
    return b.result_val + checksum(b.maze)
end

struct BfsPathNode
    cell::Cell
    parent::Int
end

using DataStructures: Queue, enqueue!, dequeue!

mutable struct MazeBFS <: AbstractBenchmark
    width::Int64
    height::Int64
    maze::Union{Nothing,Maze}
    result_val::UInt32
    path::Vector{Cell}
end

function MazeBFS()
    width = Helper.config_i64("Maze::BFS", "w")
    height = Helper.config_i64("Maze::BFS", "h")
    return MazeBFS(width, height, nothing, UInt32(0), Cell[])
end

name(b::MazeBFS)::String = "Maze::BFS"

function prepare(b::MazeBFS)
    b.maze = Maze(b.width, b.height)
    generate(b.maze)
    b.result_val = UInt32(0)
    b.path = Cell[]
end

function bfs(maze::Maze, start::Cell, target::Cell)::Vector{Cell}
    if start === target
        return [start]
    end

    queue = Queue{Int}()
    visited = [falses(maze.width) for _ = 1:maze.height]
    path_nodes = BfsPathNode[]

    visited[start.y+1][start.x+1] = true
    push!(path_nodes, BfsPathNode(start, -1))
    enqueue!(queue, 1)

    while !isempty(queue)
        path_id = dequeue!(queue)
        node = path_nodes[path_id]

        for neighbor in node.cell.neighbors
            if neighbor === target
                result = [target]
                cur = path_id
                while cur > 0
                    push!(result, path_nodes[cur].cell)
                    cur = path_nodes[cur].parent
                end
                return reverse(result)
            end

            if is_walkable(neighbor.kind) && !visited[neighbor.y+1][neighbor.x+1]
                visited[neighbor.y+1][neighbor.x+1] = true
                push!(path_nodes, BfsPathNode(neighbor, path_id))
                enqueue!(queue, length(path_nodes))
            end
        end
    end

    return Cell[]
end

function mid_cell_checksum(path::Vector{Cell})::UInt32
    if isempty(path)
        return UInt32(0)
    end
    cell = path[div(length(path), 2)+1]
    return UInt32(cell.x * cell.y)
end

function run(b::MazeBFS, iteration_id::Int64)
    if b.maze === nothing
        return
    end
    b.path = bfs(b.maze, b.maze.start, b.maze.finish)
    b.result_val += UInt32(length(b.path))
end

function checksum(b::MazeBFS)::UInt32
    return b.result_val + mid_cell_checksum(b.path)
end

using DataStructures: BinaryMinHeap

mutable struct MazeAStar <: AbstractBenchmark
    width::Int64
    height::Int64
    maze::Union{Nothing,Maze}
    result_val::UInt32
    path::Vector{Cell}
end

function MazeAStar()
    width = Helper.config_i64("Maze::AStar", "w")
    height = Helper.config_i64("Maze::AStar", "h")
    return MazeAStar(width, height, nothing, UInt32(0), Cell[])
end

name(b::MazeAStar)::String = "Maze::AStar"

function prepare(b::MazeAStar)
    b.maze = Maze(b.width, b.height)
    generate(b.maze)
    b.result_val = UInt32(0)
    b.path = Cell[]
end

function heuristic(a::Cell, b::Cell)::Int32
    return Int32(abs(a.x - b.x) + abs(a.y - b.y))
end

function idx(y::Int, x::Int, width::Int)::Int64
    return Int64((y) * width + x)
end

function astar(maze::Maze, start::Cell, target::Cell)::Vector{Cell}
    if start === target
        return [start]
    end

    width = maze.width
    height = maze.height
    size = width * height

    came_from = fill(-1, size)
    g_score = fill(typemax(Int32), size)
    best_f = fill(typemax(Int32), size)

    start_idx = start.y * width + start.x + 1
    target_idx = target.y * width + target.x + 1

    open_set = BinaryMinHeap{Tuple{Int32,Int64}}()
    in_open = falses(size)

    g_score[start_idx] = 0
    f_start = heuristic(start, target)
    push!(open_set, (f_start, start_idx))
    best_f[start_idx] = f_start
    in_open[start_idx] = true

    while !isempty(open_set)
        f_val, current_idx = pop!(open_set)
        in_open[current_idx] = false

        if f_val != best_f[current_idx]
            continue
        end

        if current_idx == target_idx
            result = Cell[]
            cur = current_idx
            while cur != -1
                y = div(cur - 1, width) + 1
                x = (cur - 1) % width + 1
                push!(result, maze.cells[y, x])
                cur = came_from[cur]
            end
            return reverse(result)
        end

        current_y = div(current_idx - 1, width) + 1
        current_x = (current_idx - 1) % width + 1
        current_cell = maze.cells[current_y, current_x]
        current_g = g_score[current_idx]

        for neighbor in current_cell.neighbors
            if !is_walkable(neighbor.kind)
                continue
            end

            neighbor_idx = neighbor.y * width + neighbor.x + 1
            tentative_g = Int32(current_g + 1)

            if tentative_g < g_score[neighbor_idx]
                came_from[neighbor_idx] = current_idx
                g_score[neighbor_idx] = tentative_g
                f_new = tentative_g + heuristic(neighbor, target)

                if f_new < best_f[neighbor_idx]
                    best_f[neighbor_idx] = f_new
                    if in_open[neighbor_idx]

                        push!(open_set, (f_new, neighbor_idx))
                    else
                        push!(open_set, (f_new, neighbor_idx))
                        in_open[neighbor_idx] = true
                    end
                end
            end
        end
    end

    return Cell[]
end

function mid_cell_checksum(path::Vector{Cell})::UInt32
    if isempty(path)
        return UInt32(0)
    end
    cell = path[div(length(path), 2)+1]
    return UInt32(cell.x * cell.y)
end

function run(b::MazeAStar, iteration_id::Int64)
    if b.maze === nothing
        return
    end
    b.path = astar(b.maze, b.maze.start, b.maze.finish)
    b.result_val += UInt32(length(b.path))
end

function checksum(b::MazeAStar)::UInt32
    return b.result_val + mid_cell_checksum(b.path)
end
