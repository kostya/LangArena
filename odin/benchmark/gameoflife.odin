package benchmark

import "core:fmt"

Cell :: enum u8 {
    Dead  = 0,
    Alive = 1,
}

Grid :: struct {
    width:  int,
    height: int,
    cells:  []Cell,
    buffer: []Cell,
}

grid_init :: proc(width, height: int) -> Grid {
    size := width * height
    return Grid{
        width  = width,
        height = height,
        cells  = make([]Cell, size),
        buffer = make([]Cell, size),
    }
}

grid_destroy :: proc(grid: ^Grid) {
    delete(grid.cells)
    delete(grid.buffer)
}

grid_get :: proc(grid: ^Grid, x, y: int) -> Cell {
    return grid.cells[y * grid.width + x]
}

grid_set :: proc(grid: ^Grid, x, y: int, cell: Cell) {
    grid.cells[y * grid.width + x] = cell
}

count_neighbors :: proc(grid: ^Grid, x, y: int, cells: []Cell) -> int {
    width, height := grid.width, grid.height

    y_prev := y == 0 ? height - 1 : y - 1
    y_next := y == height - 1 ? 0 : y + 1
    x_prev := x == 0 ? width - 1 : x - 1
    x_next := x == width - 1 ? 0 : x + 1

    count := 0
    count += int(cells[y_prev * width + x_prev] == Cell.Alive)
    count += int(cells[y_prev * width + x] == Cell.Alive)
    count += int(cells[y_prev * width + x_next] == Cell.Alive)
    count += int(cells[y * width + x_prev] == Cell.Alive)
    count += int(cells[y * width + x_next] == Cell.Alive)
    count += int(cells[y_next * width + x_prev] == Cell.Alive)
    count += int(cells[y_next * width + x] == Cell.Alive)
    count += int(cells[y_next * width + x_next] == Cell.Alive)

    return count
}

grid_next_generation :: proc(grid: ^Grid) {
    width, height := grid.width, grid.height
    cells := grid.cells
    buffer := grid.buffer

    for y in 0..<height {
        y_idx := y * width

        for x in 0..<width {
            idx := y_idx + x

            neighbors := count_neighbors(grid, x, y, cells)
            current := cells[idx]
            next_state := Cell.Dead

            if current == Cell.Alive {
                next_state = (neighbors == 2 || neighbors == 3) ? Cell.Alive : Cell.Dead
            } else {
                next_state = (neighbors == 3) ? Cell.Alive : Cell.Dead
            }

            buffer[idx] = next_state
        }
    }

    grid.cells, grid.buffer = buffer, cells
}

grid_compute_hash :: proc(grid: ^Grid) -> u32 {
    FNV_OFFSET_BASIS :: u32(2166136261)
    FNV_PRIME :: u32(16777619)

    hash: u32 = FNV_OFFSET_BASIS

    for cell in grid.cells {
        alive := u32(cell == Cell.Alive)
        hash = (hash ~ alive) * FNV_PRIME
    }

    return hash
}

GameOfLife :: struct {
    using base: Benchmark,
    result_val: u32,
    width:      int,
    height:     int,
    grid:       Grid,
}

gameoflife_run :: proc(bench: ^Benchmark, iteration_id: int) {
    gol := cast(^GameOfLife)bench
    grid_next_generation(&gol.grid)
}

gameoflife_checksum :: proc(bench: ^Benchmark) -> u32 {
    gol := cast(^GameOfLife)bench
    return grid_compute_hash(&gol.grid)
}

gameoflife_prepare :: proc(bench: ^Benchmark) {
    gol := cast(^GameOfLife)bench

    gol.width = int(config_i64(gol.name, "w"))
    gol.height = int(config_i64(gol.name, "h"))

    gol.grid = grid_init(gol.width, gol.height)

    for y in 0..<gol.height {
        for x in 0..<gol.width {
            if next_float(1.0) < 0.1 {
                grid_set(&gol.grid, x, y, Cell.Alive)
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
    bench.name = "GameOfLife"
    bench.vtable = default_vtable()

    bench.vtable.run = gameoflife_run
    bench.vtable.checksum = gameoflife_checksum
    bench.vtable.prepare = gameoflife_prepare
    bench.vtable.cleanup = gameoflife_cleanup
    bench.vtable.warmup = gameoflife_warmup

    return cast(^Benchmark)bench
}