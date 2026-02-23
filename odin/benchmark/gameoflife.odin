package benchmark

import "core:fmt"
import "core:slice"

Cell :: struct {
    alive:      bool,
    next_state: bool,
    neighbors:  [dynamic]^Cell,
}

cell_init :: proc() -> Cell {
    return Cell{
        alive = false,
        next_state = false,
        neighbors = make([dynamic]^Cell, 0, 8),
    }
}

cell_destroy :: proc(cell: ^Cell) {
    delete(cell.neighbors)
}

cell_add_neighbor :: proc(cell: ^Cell, neighbor: ^Cell) {
    append(&cell.neighbors, neighbor)
}

cell_compute_next_state :: proc(cell: ^Cell) {
    alive_neighbors := 0
    for n in cell.neighbors {
        if n.alive do alive_neighbors += 1
    }

    if cell.alive {
        cell.next_state = alive_neighbors == 2 || alive_neighbors == 3
    } else {
        cell.next_state = alive_neighbors == 3
    }
}

cell_update :: proc(cell: ^Cell) {
    cell.alive = cell.next_state
}

Grid :: struct {
    width:  int,
    height: int,
    cells:  [][]Cell,
}

grid_init :: proc(width, height: int) -> Grid {
    cells := make([][]Cell, height)
    for y in 0..<height {
        cells[y] = make([]Cell, width)
        for x in 0..<width {
            cells[y][x] = cell_init()
        }
    }

    grid := Grid{
        width  = width,
        height = height,
        cells  = cells,
    }

    grid_link_neighbors(&grid)
    return grid
}

grid_destroy :: proc(grid: ^Grid) {
    for y in 0..<grid.height {
        for x in 0..<grid.width {
            cell_destroy(&grid.cells[y][x])
        }
        delete(grid.cells[y])
    }
    delete(grid.cells)
}

grid_link_neighbors :: proc(grid: ^Grid) {
    for y in 0..<grid.height {
        for x in 0..<grid.width {
            cell := &grid.cells[y][x]

            for dy in -1..=1 {
                for dx in -1..=1 {
                    if dx == 0 && dy == 0 do continue

                    ny := (y + dy + grid.height) %% grid.height
                    nx := (x + dx + grid.width) %% grid.width

                    neighbor := &grid.cells[ny][nx]
                    cell_add_neighbor(cell, neighbor)
                }
            }
        }
    }
}

grid_next_generation :: proc(grid: ^Grid) {

    for row in grid.cells {
        for &cell in row {
            cell_compute_next_state(&cell)
        }
    }

    for row in grid.cells {
        for &cell in row {
            cell_update(&cell)
        }
    }
}

grid_count_alive :: proc(grid: ^Grid) -> u32 {
    count: u32 = 0
    for row in grid.cells {
        for cell in row {
            if cell.alive do count += 1
        }
    }
    return count
}

grid_compute_hash :: proc(grid: ^Grid) -> u32 {
    FNV_OFFSET_BASIS :: u32(2166136261)
    FNV_PRIME :: u32(16777619)

    hash := FNV_OFFSET_BASIS
    for row in grid.cells {
        for cell in row {
            alive := u32(cell.alive ? 1 : 0)
            hash = (hash ~ alive) * FNV_PRIME
        }
    }
    return hash
}

GameOfLife :: struct {
    using base: Benchmark,
    width:  int,
    height: int,
    grid:   Grid,
}

gameoflife_run :: proc(bench: ^Benchmark, iteration_id: int) {
    gol := cast(^GameOfLife)bench
    grid_next_generation(&gol.grid)
}

gameoflife_checksum :: proc(bench: ^Benchmark) -> u32 {
    gol := cast(^GameOfLife)bench
    alive := grid_count_alive(&gol.grid)
    return grid_compute_hash(&gol.grid) + alive
}

gameoflife_prepare :: proc(bench: ^Benchmark) {
    gol := cast(^GameOfLife)bench

    gol.width = int(config_i64(gol.name, "w"))
    gol.height = int(config_i64(gol.name, "h"))

    gol.grid = grid_init(gol.width, gol.height)

    for y in 0..<gol.height {
        for x in 0..<gol.width {
            if next_float(1.0) < 0.1 {
                gol.grid.cells[y][x].alive = true
            }
        }
    }
}

gameoflife_cleanup :: proc(bench: ^Benchmark) {
    gol := cast(^GameOfLife)bench
    grid_destroy(&gol.grid)
}

gameoflife_warmup :: proc(bench: ^Benchmark) {
    wi := warmup_iterations(bench)
    for i in 0..<wi {
        bench.vtable.run(bench, i)
    }
}

create_gameoflife :: proc() -> ^Benchmark {
    bench := new(GameOfLife)
    bench.name = "Etc::GameOfLife"
    bench.vtable = default_vtable()

    bench.vtable.run = gameoflife_run
    bench.vtable.checksum = gameoflife_checksum
    bench.vtable.prepare = gameoflife_prepare
    bench.vtable.cleanup = gameoflife_cleanup
    bench.vtable.warmup = gameoflife_warmup

    return cast(^Benchmark)bench
}