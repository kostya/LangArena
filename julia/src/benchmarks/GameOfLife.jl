mutable struct GCell
    alive::Bool
    next_state::Bool
    neighbors::Vector{GCell}

    function GCell()
        new(false, false, GCell[])
    end
end

function add_neighbor(cell::GCell, neighbor::GCell)
    push!(cell.neighbors, neighbor)
end

function compute_next_state(cell::GCell)
    alive_neighbors = 0
    for n in cell.neighbors
        if n.alive
            alive_neighbors += 1
        end
    end

    if cell.alive
        cell.next_state = (alive_neighbors == 2 || alive_neighbors == 3)
    else
        cell.next_state = (alive_neighbors == 3)
    end
end

function update(cell::GCell)
    cell.alive = cell.next_state
end

mutable struct Grid
    width::Int32
    height::Int32
    cells::Matrix{GCell}
end

function Grid(width::Int32, height::Int32)
    cells = Matrix{GCell}(undef, height, width)

    for y = 1:height
        for x = 1:width
            cells[y, x] = GCell()
        end
    end

    grid = Grid(width, height, cells)
    link_neighbors!(grid)
    return grid
end

function link_neighbors!(grid::Grid)
    for y = 1:grid.height
        for x = 1:grid.width
            cell = grid.cells[y, x]

            for dy = -1:1
                for dx = -1:1
                    if dx == 0 && dy == 0
                        continue
                    end

                    ny = mod1(y + dy, grid.height)
                    nx = mod1(x + dx, grid.width)

                    add_neighbor(cell, grid.cells[ny, nx])
                end
            end
        end
    end
end

function next_generation!(grid::Grid)

    for y = 1:grid.height
        for x = 1:grid.width
            compute_next_state(grid.cells[y, x])
        end
    end

    for y = 1:grid.height
        for x = 1:grid.width
            update(grid.cells[y, x])
        end
    end
end

function count_alive(grid::Grid)::UInt32
    count = 0
    for y = 1:grid.height
        for x = 1:grid.width
            if grid.cells[y, x].alive
                count += 1
            end
        end
    end
    return count
end

function compute_hash(grid::Grid)::UInt32
    FNV_OFFSET_BASIS = 0x811c9dc5
    FNV_PRIME = 0x01000193
    hash = FNV_OFFSET_BASIS
    for y = 1:grid.height
        for x = 1:grid.width
            alive = UInt32(grid.cells[y, x].alive ? 1 : 0)
            hash = xor(hash, alive)
            hash = hash * FNV_PRIME
        end
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
    width = Int32(Helper.config_i64("Etc::GameOfLife", "w"))
    height = Int32(Helper.config_i64("Etc::GameOfLife", "h"))
    grid = Grid(width, height)
    return GameOfLife(width, height, grid, UInt32(0))
end

name(b::GameOfLife)::String = "Etc::GameOfLife"

function prepare(b::GameOfLife)
    for y = 1:b.height
        for x = 1:b.width
            if Helper.next_float(1.0) < 0.1
                b.grid.cells[y, x].alive = true
            end
        end
    end
end

function run(b::GameOfLife, iteration_id::Int64)
    next_generation!(b.grid)
end

function checksum(b::GameOfLife)::UInt32
    alive = count_alive(b.grid)
    return compute_hash(b.grid) + alive
end
