mutable struct MazeGenerator <: AbstractBenchmark
    width::Int64
    height::Int64
    bool_grid::Vector{Vector{Bool}}
    result::UInt32
end

@enum Cell Wall=0 Path=1

mutable struct Maze
    width::Int64
    height::Int64
    cells::Vector{Vector{Cell}}

    function Maze(width::Int64, height::Int64)
        w = width > 5 ? width : Int64(5)
        h = height > 5 ? height : Int64(5)
        cells = [[Wall for _ in 1:w] for _ in 1:h]
        return new(w, h, cells)
    end
end

function Base.getindex(m::Maze, x::Int64, y::Int64)::Cell

    return m.cells[y+1][x+1]  
end

function Base.setindex!(m::Maze, value::Cell, x::Int64, y::Int64)
    m.cells[y+1][x+1] = value
end

function get_cell_1based(m::Maze, x::Int64, y::Int64)::Cell
    return m.cells[y][x]
end

function generate!(m::Maze)
    if m.width < 5 || m.height < 5

        for x in 0:m.width-1
            m[x, m.height ÷ 2] = Path
        end
        return
    end

    divide!(m, 0, 0, m.width - 1, m.height - 1)
    add_random_paths!(m)
end

function add_random_paths!(m::Maze)
    num_extra_paths = (m.width * m.height) ÷ 20

    for _ in 1:num_extra_paths

        x = Int64(Helper.next_int(m.width - 2)) + 1  

        y = Int64(Helper.next_int(m.height - 2)) + 1  

        if m[x, y] == Wall &&
           m[x - 1, y] == Wall &&
           m[x + 1, y] == Wall &&
           m[x, y - 1] == Wall &&
           m[x, y + 1] == Wall
            m[x, y] = Path
        end
    end
end

function divide!(m::Maze, x1::Int64, y1::Int64, x2::Int64, y2::Int64)
    width = x2 - x1
    height = y2 - y1

    if width < 2 || height < 2
        return
    end

    width_for_wall = max(width - 2, 0)
    height_for_wall = max(height - 2, 0)
    width_for_hole = max(width - 1, 0)
    height_for_hole = max(height - 1, 0)

    if width_for_wall == 0 || height_for_wall == 0 ||
       width_for_hole == 0 || height_for_hole == 0
        return
    end

    if width > height

        wall_range = max(width_for_wall ÷ 2, 1)
        wall_offset = wall_range > 0 ? Int64(Helper.next_int(wall_range)) * 2 : 0
        wall_x = x1 + 2 + wall_offset  

        hole_range = max(height_for_hole ÷ 2, 1)
        hole_offset = hole_range > 0 ? Int64(Helper.next_int(hole_range)) * 2 : 0
        hole_y = y1 + 1 + hole_offset  

        if wall_x > x2 || hole_y > y2
            return
        end

        for y in y1:y2
            if y != hole_y
                m[wall_x, y] = Wall
            end
        end

        if wall_x > x1 + 1
            divide!(m, x1, y1, wall_x - 1, y2)
        end
        if wall_x + 1 < x2
            divide!(m, wall_x + 1, y1, x2, y2)
        end
    else

        wall_range = max(height_for_wall ÷ 2, 1)
        wall_offset = wall_range > 0 ? Int64(Helper.next_int(wall_range)) * 2 : 0
        wall_y = y1 + 2 + wall_offset  

        hole_range = max(width_for_hole ÷ 2, 1)
        hole_offset = hole_range > 0 ? Int64(Helper.next_int(hole_range)) * 2 : 0
        hole_x = x1 + 1 + hole_offset  

        if wall_y > y2 || hole_x > x2
            return
        end

        for x in x1:x2
            if x != hole_x
                m[x, wall_y] = Wall
            end
        end

        if wall_y > y1 + 1
            divide!(m, x1, y1, x2, wall_y - 1)
        end
        if wall_y + 1 < y2
            divide!(m, x1, wall_y + 1, x2, y2)
        end
    end
end

function is_connected(m::Maze, start::Tuple{Int64,Int64}, goal::Tuple{Int64,Int64})::Bool
    sx, sy = start
    gx, gy = goal

    if sx >= m.width || sy >= m.height || gx >= m.width || gy >= m.height
        return false
    end

    visited = [[false for _ in 1:m.width] for _ in 1:m.height]
    queue = Vector{Tuple{Int64,Int64}}()

    visited[sy+1][sx+1] = true  
    push!(queue, (sx, sy))

    while !isempty(queue)
        x, y = popfirst!(queue)

        if (x, y) == (gx, gy)
            return true
        end

        if y > 0 && m[x, y-1] == Path && !visited[y][x+1]  
            visited[y][x+1] = true
            push!(queue, (x, y-1))
        end

        if x + 1 < m.width && m[x+1, y] == Path && !visited[y+1][x+2]
            visited[y+1][x+2] = true
            push!(queue, (x+1, y))
        end

        if y + 1 < m.height && m[x, y+1] == Path && !visited[y+2][x+1]
            visited[y+2][x+1] = true
            push!(queue, (x, y+1))
        end

        if x > 0 && m[x-1, y] == Path && !visited[y+1][x]
            visited[y+1][x] = true
            push!(queue, (x-1, y))
        end
    end

    return false
end

function to_bool_grid(m::Maze)::Vector{Vector{Bool}}
    result = Vector{Vector{Bool}}(undef, m.height)

    for y in 1:m.height
        row = Vector{Bool}(undef, m.width)
        for x in 1:m.width

            row[x] = m[x-1, y-1] == Path
        end
        result[y] = row
    end

    return result
end

function generate_walkable_maze(width::Int64, height::Int64)::Vector{Vector{Bool}}
    maze = Maze(width, height)
    generate!(maze)

    start = (Int64(1), Int64(1))  
    goal = (width - 2, height - 2)  

    if !is_connected(maze, start, goal)
        for x in 0:width-1
            for y in 0:height-1
                if x == 1 || y == 1 || x == width - 2 || y == height - 2
                    maze[x, y] = Path
                end
            end
        end
    end

    return to_bool_grid(maze)
end

function MazeGenerator()
    width = Helper.config_i64("MazeGenerator", "w")
    height = Helper.config_i64("MazeGenerator", "h")
    bool_grid = Vector{Vector{Bool}}()
    return MazeGenerator(width, height, bool_grid, UInt32(0))
end

name(b::MazeGenerator)::String = "MazeGenerator"

function run(b::MazeGenerator, iteration_id::Int64)
    b.bool_grid = generate_walkable_maze(b.width, b.height)

    hasher = 0x811c9dc5  
    prime = 0x01000193   

    for row in b.bool_grid
        for (j, cell) in enumerate(row)
            if cell

                j0 = UInt32(j - 1)  
                j_squared = j0 * j0
                hasher = xor(hasher, j_squared)
                hasher = hasher * prime
            end
        end
    end

    b.result = hasher
end

function checksum(b::MazeGenerator)::UInt32
    return b.result
end