const DEAD = 0x00
const ALIVE = 0x01

mutable struct Grid
    width::Int32
    height::Int32
    cells::Vector{UInt8}
    buffer::Vector{UInt8}

    function Grid(width::Int32, height::Int32)
        size = Int64(width) * Int64(height)
        cells = Vector{UInt8}(undef, size)
        fill!(cells, DEAD)
        buffer = Vector{UInt8}(undef, size)
        fill!(buffer, DEAD)
        new(width, height, cells, buffer)
    end

    function Grid(width::Int32, height::Int32, cells::Vector{UInt8}, buffer::Vector{UInt8})
        new(width, height, cells, buffer)
    end
end

function index(g::Grid, x::Int64, y::Int64)::Int64
    return Int64(y) * Int64(g.width) + Int64(x) + 1  
end

function get_cell(g::Grid, x::Int32, y::Int32)::UInt8
    return g.cells[index(g, x, y)]
end

function set_cell!(g::Grid, x::Int64, y::Int64, cell::UInt8)
    g.cells[index(g, x, y)] = cell
end

function with_buffers(width::Int32, height::Int32, cells::Vector{UInt8}, buffer::Vector{UInt8})::Grid
    return Grid(width, height, cells, buffer)
end

@inline function count_neighbors(g::Grid, x::Int32, y::Int32, cells::Vector{UInt8})::Int32
    w = g.width
    h = g.height

    y_prev = y == 0 ? h - 1 : y - 1
    y_next = y == h - 1 ? 0 : y + 1
    x_prev = x == 0 ? w - 1 : x - 1
    x_next = x == w - 1 ? 0 : x + 1

    count = Int32(0)

    idx = y_prev * w
    count += Int32(cells[idx + x_prev + 1])
    count += Int32(cells[idx + x + 1])
    count += Int32(cells[idx + x_next + 1])

    idx = y * w
    count += Int32(cells[idx + x_prev + 1])
    count += Int32(cells[idx + x_next + 1])

    idx = y_next * w
    count += Int32(cells[idx + x_prev + 1])
    count += Int32(cells[idx + x + 1])
    count += Int32(cells[idx + x_next + 1])

    return count
end

function next_generation(g::Grid)::Grid
    width = g.width
    height = g.height

    cells = g.cells
    buffer = g.buffer

    w_int = Int64(width)
    h_int = Int64(height)

    for y in 0:(height-1)
        y_idx = y * width

        y_prev_idx = (y == 0 ? height - 1 : y - 1) * width
        y_next_idx = (y == height - 1 ? 0 : y + 1) * width

        for x in 0:(width-1)
            idx = y_idx + x + 1  

            x_prev = x == 0 ? width - 1 : x - 1
            x_next = x == width - 1 ? 0 : x + 1

            neighbors = Int32(0)

            neighbors += Int32(cells[y_prev_idx + x_prev + 1])
            neighbors += Int32(cells[y_prev_idx + x + 1])
            neighbors += Int32(cells[y_prev_idx + x_next + 1])

            neighbors += Int32(cells[y_idx + x_prev + 1])
            neighbors += Int32(cells[y_idx + x_next + 1])

            neighbors += Int32(cells[y_next_idx + x_prev + 1])
            neighbors += Int32(cells[y_next_idx + x + 1])
            neighbors += Int32(cells[y_next_idx + x_next + 1])

            current = cells[idx]
            next_state = DEAD

            if current == ALIVE
                next_state = (neighbors == 2 || neighbors == 3) ? ALIVE : DEAD
            elseif neighbors == 3
                next_state = ALIVE
            end

            buffer[idx] = next_state
        end
    end

    return with_buffers(width, height, buffer, cells)
end

const FNV_OFFSET_BASIS = 0x811c9dc5  
const FNV_PRIME = 0x01000193         

function compute_hash(g::Grid)::UInt32
    hash = FNV_OFFSET_BASIS
    cells = g.cells

    @inbounds for i in eachindex(cells)
        alive = UInt32(cells[i])  
        hash = xor(hash, alive)
        hash = hash * FNV_PRIME
    end

    return hash
end

mutable struct GameOfLife <: AbstractBenchmark
    width::Int32
    height::Int32
    grid::Grid
    result::UInt32
end

function GameOfLife()
    width = Int32(Helper.config_i64("GameOfLife", "w"))
    height = Int32(Helper.config_i64("GameOfLife", "h"))
    grid = Grid(width, height)
    return GameOfLife(width, height, grid, UInt32(0))
end

name(b::GameOfLife)::String = "GameOfLife"

function prepare(b::GameOfLife)

    width = b.width
    height = b.height
    grid = b.grid

    for y in 0:(height-1)
        for x in 0:(width-1)
            if Helper.next_float(1.0) < 0.1
                set_cell!(grid, x, y, ALIVE)
            end
        end
    end
end

function run(b::GameOfLife, iteration_id::Int64)
    b.grid = next_generation(b.grid)

    b.result = compute_hash(b.grid)
end

function checksum(b::GameOfLife)::UInt32
    return b.result
end