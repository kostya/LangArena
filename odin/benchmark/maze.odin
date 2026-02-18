package benchmark

import "core:fmt"
import "core:math"
import "core:container/queue"
import "core:container/priority_queue"
import "core:slice"
import "core:mem"

MazeCellKind :: enum {
    Wall = 0,
    Space = 1,
    Start = 2,
    Finish = 3,
    Border = 4,
    Path = 5,
}

MazeCell :: struct {
    kind: MazeCellKind,
    neighbors: [dynamic]^MazeCell,
    x, y: int,
}

Maze :: struct {
    width, height: int,
    cells: [][]MazeCell,
    start, finish: ^MazeCell,
}

MazePathNode :: struct {
    cell: ^MazeCell,
    parent: int,
}

MazeAStarItem :: struct {
    priority: int,
    vertex: int,
}

maze_cell_init :: proc(x, y: int) -> MazeCell {
    return MazeCell{
        kind = .Wall,
        neighbors = {},
        x = x,
        y = y,
    }
}

maze_cell_destroy :: proc(cell: ^MazeCell) {
    delete(cell.neighbors)
}

maze_is_walkable :: proc(kind: MazeCellKind) -> bool {
    return kind == .Space || kind == .Start || kind == .Finish
}

maze_init :: proc(width, height: int) -> Maze {
    w := max(width, 5)
    h := max(height, 5)

    cells := make([][]MazeCell, h)
    for y in 0..<h {
        cells[y] = make([]MazeCell, w)
        for x in 0..<w {
            cells[y][x] = maze_cell_init(x, y)
        }
    }

    maze := Maze{
        width = w,
        height = h,
        cells = cells,
        start = &cells[1][1],
        finish = &cells[h-2][w-2],
    }

    maze.start.kind = .Start
    maze.finish.kind = .Finish

    maze_update_neighbors(&maze)

    return maze
}

maze_destroy :: proc(maze: ^Maze) {
    for y in 0..<maze.height {
        for x in 0..<maze.width {
            maze_cell_destroy(&maze.cells[y][x])
        }
        delete(maze.cells[y])
    }
    delete(maze.cells)
}

maze_update_neighbors :: proc(maze: ^Maze) {
    for y in 0..<maze.height {
        for x in 0..<maze.width {
            cell := &maze.cells[y][x]
            clear(&cell.neighbors)

            if x > 0 && y > 0 && x < maze.width - 1 && y < maze.height - 1 {
                append(&cell.neighbors, &maze.cells[y-1][x]) 
                append(&cell.neighbors, &maze.cells[y+1][x]) 
                append(&cell.neighbors, &maze.cells[y][x+1]) 
                append(&cell.neighbors, &maze.cells[y][x-1]) 

                for _ in 0..<4 {
                    i := next_int(4)
                    j := next_int(4)
                    if i != j {
                        cell.neighbors[i], cell.neighbors[j] = cell.neighbors[j], cell.neighbors[i]
                    }
                }
            } else {
                cell.kind = .Border
            }
        }
    }
}

maze_reset :: proc(maze: ^Maze) {
    for y in 0..<maze.height {
        for x in 0..<maze.width {
            cell := &maze.cells[y][x]
            if cell.kind == .Space {
                cell.kind = .Wall
            }
        }
    }
    maze.start.kind = .Start
    maze.finish.kind = .Finish
}

maze_dig :: proc(maze: ^Maze, start_cell: ^MazeCell) {
    stack := make([dynamic]^MazeCell)
    defer delete(stack)

    append(&stack, start_cell)

    for len(stack) > 0 {
        cell := pop(&stack)

        walkable := 0
        for n in cell.neighbors {
            if maze_is_walkable(n.kind) {
                walkable += 1
            }
        }

        if walkable == 1 {
            cell.kind = .Space
            for n in cell.neighbors {
                if n.kind == .Wall {
                    append(&stack, n)
                }
            }
        }
    }
}

maze_ensure_open_finish :: proc(maze: ^Maze, start_cell: ^MazeCell) {
    stack := make([dynamic]^MazeCell)
    defer delete(stack)

    append(&stack, start_cell)

    for len(stack) > 0 {
        cell := pop(&stack)

        cell.kind = .Space

        walkable := 0
        for n in cell.neighbors {
            if maze_is_walkable(n.kind) {
                walkable += 1
            }
        }

        if walkable <= 1 {
            for n in cell.neighbors {
                if n.kind == .Wall {
                    append(&stack, n)
                }
            }
        }
    }
}

maze_generate :: proc(maze: ^Maze) {
    for n in maze.start.neighbors {
        if n.kind == .Wall {
            maze_dig(maze, n)
        }
    }

    for n in maze.finish.neighbors {
        if n.kind == .Wall {
            maze_ensure_open_finish(maze, n)
        }
    }
}

maze_middle_cell :: proc(maze: ^Maze) -> ^MazeCell {
    return &maze.cells[maze.height / 2][maze.width / 2]
}

maze_checksum :: proc(maze: ^Maze) -> u32 {
    hasher: u32 = 2166136261
    prime: u32 = 16777619

    for y in 0..<maze.height {
        for x in 0..<maze.width {
            if maze.cells[y][x].kind == .Space {
                val := u32(x * y)
                hasher = (hasher ~ val) * prime
            }
        }
    }
    return hasher
}

maze_print_to_console :: proc(maze: ^Maze) {
    for y in 0..<maze.height {
        for x in 0..<maze.width {
            switch maze.cells[y][x].kind {
                case .Space:   fmt.print(" ")
                case .Wall:    fmt.print("\e[34m#\e[0m")
                case .Border:  fmt.print("\e[31mO\e[0m")
                case .Start:   fmt.print("\e[32m>\e[0m")
                case .Finish:  fmt.print("\e[32m<\e[0m")
                case .Path:    fmt.print("\e[33m.\e[0m")
            }
        }
        fmt.println()
    }
    fmt.println()
}

MazeGenerator :: struct {
    using base: Benchmark,
    result_val: u32,
    width, height: int,
    maze: Maze,
}

maze_generator_prepare :: proc(bench: ^Benchmark) {
    mg := cast(^MazeGenerator)bench
    mg.width = int(config_i64(mg.name, "w"))
    mg.height = int(config_i64(mg.name, "h"))
    mg.maze = maze_init(mg.width, mg.height)
    mg.result_val = 0
}

maze_generator_run :: proc(bench: ^Benchmark, iteration_id: int) {
    mg := cast(^MazeGenerator)bench
    maze_reset(&mg.maze)
    maze_generate(&mg.maze)
    mg.result_val += u32(maze_middle_cell(&mg.maze).kind)
}

maze_generator_checksum :: proc(bench: ^Benchmark) -> u32 {
    mg := cast(^MazeGenerator)bench
    return mg.result_val + maze_checksum(&mg.maze)
}

maze_generator_cleanup :: proc(bench: ^Benchmark) {
    mg := cast(^MazeGenerator)bench
    maze_destroy(&mg.maze)
}

create_maze_generator :: proc() -> ^Benchmark {
    bench := new(MazeGenerator)
    bench.name = "Maze::Generator"
    bench.vtable = default_vtable()
    bench.vtable.prepare = maze_generator_prepare
    bench.vtable.run = maze_generator_run
    bench.vtable.checksum = maze_generator_checksum
    bench.vtable.cleanup = maze_generator_cleanup
    return cast(^Benchmark)bench
}

MazeBFS :: struct {
    using base: Benchmark,
    result_val: u32,
    width, height: int,
    maze: Maze,
    path: [dynamic]^MazeCell,
}

maze_bfs_prepare :: proc(bench: ^Benchmark) {
    bfs := cast(^MazeBFS)bench
    bfs.width = int(config_i64(bfs.name, "w"))
    bfs.height = int(config_i64(bfs.name, "h"))
    bfs.maze = maze_init(bfs.width, bfs.height)
    maze_generate(&bfs.maze)
    bfs.result_val = 0
    bfs.path = {}
}

maze_bfs_search :: proc(maze: ^Maze, start, target: ^MazeCell) -> [dynamic]^MazeCell {
    if start == target {
        path := make([dynamic]^MazeCell)
        append(&path, start)
        return path
    }

    q: queue.Queue(int)
    queue.init(&q)
    defer queue.destroy(&q)

    visited := make([][]bool, maze.height)
    for y in 0..<maze.height {
        visited[y] = make([]bool, maze.width)
    }
    defer {
        for y in 0..<maze.height {
            delete(visited[y])
        }
        delete(visited)
    }

    path_nodes := make([dynamic]MazePathNode)
    defer delete(path_nodes)

    visited[start.y][start.x] = true
    append(&path_nodes, MazePathNode{cell = start, parent = -1})
    queue.push_back(&q, 0)

    for queue.len(q) > 0 {
        path_id := queue.pop_front(&q)
        node := path_nodes[path_id]

        for neighbor in node.cell.neighbors {
            if neighbor == target {
                cur := path_id
                res := make([dynamic]^MazeCell)
                append(&res, target)
                for cur >= 0 {
                    append(&res, path_nodes[cur].cell)
                    cur = path_nodes[cur].parent
                }
                slice.reverse(res[:])
                return res
            }

            if maze_is_walkable(neighbor.kind) && !visited[neighbor.y][neighbor.x] {
                visited[neighbor.y][neighbor.x] = true
                append(&path_nodes, MazePathNode{cell = neighbor, parent = path_id})
                queue.push_back(&q, len(path_nodes) - 1)
            }
        }
    }

    return {}
}

maze_bfs_mid_cell_checksum :: proc(path: [dynamic]^MazeCell) -> u32 {
    if len(path) == 0 do return 0
    cell := path[len(path) / 2]
    return u32(cell.x * cell.y)
}

maze_bfs_run :: proc(bench: ^Benchmark, iteration_id: int) {
    bfs := cast(^MazeBFS)bench
    if len(bfs.path) > 0 do delete(bfs.path)
    bfs.path = maze_bfs_search(&bfs.maze, bfs.maze.start, bfs.maze.finish)
    bfs.result_val += u32(len(bfs.path))
}

maze_bfs_checksum :: proc(bench: ^Benchmark) -> u32 {
    bfs := cast(^MazeBFS)bench
    return bfs.result_val + maze_bfs_mid_cell_checksum(bfs.path)
}

maze_bfs_cleanup :: proc(bench: ^Benchmark) {
    bfs := cast(^MazeBFS)bench
    if len(bfs.path) > 0 do delete(bfs.path)
    maze_destroy(&bfs.maze)
}

create_maze_bfs :: proc() -> ^Benchmark {
    bench := new(MazeBFS)
    bench.name = "Maze::BFS"
    bench.vtable = default_vtable()
    bench.vtable.prepare = maze_bfs_prepare
    bench.vtable.run = maze_bfs_run
    bench.vtable.checksum = maze_bfs_checksum
    bench.vtable.cleanup = maze_bfs_cleanup
    return cast(^Benchmark)bench
}

maze_astar_item_less :: proc(a, b: MazeAStarItem) -> bool {
    if a.priority != b.priority {
        return a.priority < b.priority
    }
    return a.vertex < b.vertex
}

maze_astar_item_swap :: proc(arr: []MazeAStarItem, i, j: int) {
    arr[i], arr[j] = arr[j], arr[i]
}

MazeAStar :: struct {
    using base: Benchmark,
    result_val: u32,
    width, height: int,
    maze: Maze,
    path: [dynamic]^MazeCell,
}

maze_astar_prepare :: proc(bench: ^Benchmark) {
    astar := cast(^MazeAStar)bench
    astar.width = int(config_i64(astar.name, "w"))
    astar.height = int(config_i64(astar.name, "h"))
    astar.maze = maze_init(astar.width, astar.height)
    maze_generate(&astar.maze)
    astar.result_val = 0
    astar.path = {}
}

maze_astar_heuristic :: proc(a, b: ^MazeCell) -> int {
    return abs(a.x - b.x) + abs(a.y - b.y)
}

maze_astar_idx :: proc(y, x, width: int) -> int {
    return y * width + x
}

maze_astar_search :: proc(maze: ^Maze, start, target: ^MazeCell) -> [dynamic]^MazeCell {
    if start == target {
        path := make([dynamic]^MazeCell)
        append(&path, start)
        return path
    }

    width := maze.width
    height := maze.height
    size := width * height

    came_from := make([]int, size)
    g_score := make([]int, size)
    best_f := make([]int, size)
    defer {
        delete(came_from)
        delete(g_score)
        delete(best_f)
    }

    for i in 0..<size {
        came_from[i] = -1
        g_score[i] = max(int)
        best_f[i] = max(int)
    }

    start_idx := maze_astar_idx(start.y, start.x, width)
    target_idx := maze_astar_idx(target.y, target.x, width)

    pq: priority_queue.Priority_Queue(MazeAStarItem)
    priority_queue.init(&pq, maze_astar_item_less, maze_astar_item_swap)
    defer priority_queue.destroy(&pq)

    in_open := make([]bool, size)
    defer delete(in_open)

    g_score[start_idx] = 0
    f_start := maze_astar_heuristic(start, target)
    priority_queue.push(&pq, MazeAStarItem{priority = f_start, vertex = start_idx})
    best_f[start_idx] = f_start
    in_open[start_idx] = true

    for priority_queue.len(pq) > 0 {
        current := priority_queue.pop(&pq)
        current_idx := current.vertex
        in_open[current_idx] = false

        if current_idx == target_idx {
            cur := current_idx
            res := make([dynamic]^MazeCell)
            for cur != -1 {
                y := cur / width
                x := cur % width
                append(&res, &maze.cells[y][x])
                cur = came_from[cur]
            }
            slice.reverse(res[:])
            return res
        }

        current_y := current_idx / width
        current_x := current_idx % width
        current_cell := &maze.cells[current_y][current_x]
        current_g := g_score[current_idx]

        for neighbor in current_cell.neighbors {
            if !maze_is_walkable(neighbor.kind) do continue

            neighbor_idx := maze_astar_idx(neighbor.y, neighbor.x, width)
            tentative_g := current_g + 1

            if tentative_g < g_score[neighbor_idx] {
                came_from[neighbor_idx] = current_idx
                g_score[neighbor_idx] = tentative_g
                f_new := tentative_g + maze_astar_heuristic(neighbor, target)

                if f_new < best_f[neighbor_idx] {
                    best_f[neighbor_idx] = f_new
                    priority_queue.push(&pq, MazeAStarItem{priority = f_new, vertex = neighbor_idx})
                    in_open[neighbor_idx] = true
                }
            }
        }
    }

    return {}
}

maze_astar_mid_cell_checksum :: proc(path: [dynamic]^MazeCell) -> u32 {
    if len(path) == 0 do return 0
    cell := path[len(path) / 2]
    return u32(cell.x * cell.y)
}

maze_astar_run :: proc(bench: ^Benchmark, iteration_id: int) {
    astar := cast(^MazeAStar)bench
    if len(astar.path) > 0 do delete(astar.path)
    astar.path = maze_astar_search(&astar.maze, astar.maze.start, astar.maze.finish)
    astar.result_val += u32(len(astar.path))
}

maze_astar_checksum :: proc(bench: ^Benchmark) -> u32 {
    astar := cast(^MazeAStar)bench
    if len(astar.path) == 0 do return astar.result_val
    cell := astar.path[len(astar.path) / 2]
    return astar.result_val + u32(cell.x * cell.y)
}

maze_astar_cleanup :: proc(bench: ^Benchmark) {
    astar := cast(^MazeAStar)bench
    if len(astar.path) > 0 do delete(astar.path)
    maze_destroy(&astar.maze)
}

create_maze_astar :: proc() -> ^Benchmark {
    bench := new(MazeAStar)
    bench.name = "Maze::AStar"
    bench.vtable = default_vtable()
    bench.vtable.prepare = maze_astar_prepare
    bench.vtable.run = maze_astar_run
    bench.vtable.checksum = maze_astar_checksum
    bench.vtable.cleanup = maze_astar_cleanup
    return cast(^Benchmark)bench
}