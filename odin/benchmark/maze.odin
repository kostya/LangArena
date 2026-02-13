package benchmark

import "core:fmt"
import "core:math"
import "core:container/queue"
import pqueue "core:container/priority_queue"  
import "core:slice"

MazeCell :: enum {
    Wall,
    Path,
}

Maze :: struct {
    width:  int,
    height: int,
    cells:  [][]MazeCell,  
}

maze_init :: proc(width, height: int) -> Maze {

    actual_width := width > 5 ? width : 5
    actual_height := height > 5 ? height : 5

    cells := make([][]MazeCell, actual_height)
    for y in 0..<actual_height {
        cells[y] = make([]MazeCell, actual_width)
        for x in 0..<actual_width {
            cells[y][x] = MazeCell.Wall
        }
    }

    return Maze{
        width  = actual_width,
        height = actual_height,
        cells  = cells,
    }
}

maze_destroy :: proc(maze: ^Maze) {
    for y in 0..<maze.height {
        delete(maze.cells[y])
    }
    delete(maze.cells)
}

maze_get :: proc(maze: ^Maze, x, y: int) -> MazeCell {
    return maze.cells[y][x]
}

maze_set :: proc(maze: ^Maze, x, y: int, cell: MazeCell) {
    maze.cells[y][x] = cell
}

maze_add_random_paths :: proc(maze: ^Maze) {
    num_extra_paths := (maze.width * maze.height) / 20

    for i in 0..<num_extra_paths {
        x := next_int(maze.width - 2) + 1
        y := next_int(maze.height - 2) + 1

        if maze_get(maze, x, y) == MazeCell.Wall &&
           maze_get(maze, x - 1, y) == MazeCell.Wall &&
           maze_get(maze, x + 1, y) == MazeCell.Wall &&
           maze_get(maze, x, y - 1) == MazeCell.Wall &&
           maze_get(maze, x, y + 1) == MazeCell.Wall {
            maze_set(maze, x, y, MazeCell.Path)
        }
    }
}

maze_divide :: proc(maze: ^Maze, x1, y1, x2, y2: int) {
    width := x2 - x1
    height := y2 - y1

    if width < 2 || height < 2 do return

    width_for_wall := max(width - 2, 0)
    height_for_wall := max(height - 2, 0)
    width_for_hole := max(width - 1, 0)
    height_for_hole := max(height - 1, 0)

    if width_for_wall == 0 || height_for_wall == 0 ||
       width_for_hole == 0 || height_for_hole == 0 {
        return
    }

    if width > height {

        wall_range := max(width_for_wall / 2, 1)
        wall_offset := wall_range > 0 ? next_int(wall_range) * 2 : 0
        wall_x := x1 + 2 + wall_offset

        hole_range := max(height_for_hole / 2, 1)
        hole_offset := hole_range > 0 ? next_int(hole_range) * 2 : 0
        hole_y := y1 + 1 + hole_offset

        if wall_x > x2 || hole_y > y2 do return

        for y in y1..=y2 {
            if y != hole_y {
                maze_set(maze, wall_x, y, MazeCell.Wall)
            }
        }

        if wall_x > x1 + 1 {
            maze_divide(maze, x1, y1, wall_x - 1, y2)
        }
        if wall_x + 1 < x2 {
            maze_divide(maze, wall_x + 1, y1, x2, y2)
        }
    } else {

        wall_range := max(height_for_wall / 2, 1)
        wall_offset := wall_range > 0 ? next_int(wall_range) * 2 : 0
        wall_y := y1 + 2 + wall_offset

        hole_range := max(width_for_hole / 2, 1)
        hole_offset := hole_range > 0 ? next_int(hole_range) * 2 : 0
        hole_x := x1 + 1 + hole_offset

        if wall_y > y2 || hole_x > x2 do return

        for x in x1..=x2 {
            if x != hole_x {
                maze_set(maze, x, wall_y, MazeCell.Wall)
            }
        }

        if wall_y > y1 + 1 {
            maze_divide(maze, x1, y1, x2, wall_y - 1)
        }
        if wall_y + 1 < y2 {
            maze_divide(maze, x1, wall_y + 1, x2, y2)
        }
    }
}

maze_is_connected_impl :: proc(maze: ^Maze, start_x, start_y, goal_x, goal_y: int) -> bool {
    if start_x >= maze.width || start_y >= maze.height ||
       goal_x >= maze.width || goal_y >= maze.height {
        return false
    }

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

    q: queue.Queue([2]int)
    queue.init(&q)
    defer queue.destroy(&q)

    visited[start_y][start_x] = true
    queue.push_back(&q, [2]int{start_x, start_y})

    for queue.len(q) > 0 {
        point := queue.pop_front(&q)
        x, y := point[0], point[1]

        if x == goal_x && y == goal_y {
            return true
        }

        if y > 0 && maze_get(maze, x, y - 1) == MazeCell.Path && !visited[y - 1][x] {
            visited[y - 1][x] = true
            queue.push_back(&q, [2]int{x, y - 1})
        }

        if x + 1 < maze.width && maze_get(maze, x + 1, y) == MazeCell.Path && !visited[y][x + 1] {
            visited[y][x + 1] = true
            queue.push_back(&q, [2]int{x + 1, y})
        }

        if y + 1 < maze.height && maze_get(maze, x, y + 1) == MazeCell.Path && !visited[y + 1][x] {
            visited[y + 1][x] = true
            queue.push_back(&q, [2]int{x, y + 1})
        }

        if x > 0 && maze_get(maze, x - 1, y) == MazeCell.Path && !visited[y][x - 1] {
            visited[y][x - 1] = true
            queue.push_back(&q, [2]int{x - 1, y})
        }
    }

    return false
}

maze_generate :: proc(maze: ^Maze) {
    if maze.width < 5 || maze.height < 5 {

        for x in 0..<maze.width {
            maze_set(maze, x, maze.height / 2, MazeCell.Path)
        }
        return
    }

    maze_divide(maze, 0, 0, maze.width - 1, maze.height - 1)
    maze_add_random_paths(maze)
}

maze_to_bool_grid :: proc(maze: ^Maze) -> [][]bool {
    result := make([][]bool, maze.height)
    for y in 0..<maze.height {
        result[y] = make([]bool, maze.width)
        for x in 0..<maze.width {
            result[y][x] = maze_get(maze, x, y) == MazeCell.Path
        }
    }
    return result
}

maze_is_connected :: proc(maze: ^Maze, start_x, start_y, goal_x, goal_y: int) -> bool {
    return maze_is_connected_impl(maze, start_x, start_y, goal_x, goal_y)
}

generate_walkable_maze :: proc(width, height: int) -> [][]bool {
    maze := maze_init(width, height)
    defer maze_destroy(&maze)

    maze_generate(&maze)

    start_x, start_y := 1, 1
    goal_x, goal_y := width - 2, height - 2

    if !maze_is_connected(&maze, start_x, start_y, goal_x, goal_y) {

        for y in 0..<maze.height {
            for x in 0..<maze.width {
                if x == 1 || y == 1 || x == maze.width - 2 || y == maze.height - 2 {
                    maze_set(&maze, x, y, MazeCell.Path)
                }
            }
        }
    }

    return maze_to_bool_grid(&maze)
}

MazeGenerator :: struct {
    using base: Benchmark,
    result_val: u32,
    width:      int,
    height:     int,
    bool_grid:  [][]bool,
}

grid_checksum :: proc(grid: [][]bool) -> u32 {
    hasher: u32 = 2166136261
    prime: u32 = 16777619

    for y in 0..<len(grid) {
        row := grid[y]
        for x in 0..<len(row) {
            if row[x] {
                j_squared: u32 = u32(x * x)
                hasher = (hasher ~ j_squared) * prime
            }
        }
    }
    return hasher
}

mazegenerator_run :: proc(bench: ^Benchmark, iteration_id: int) {
    mg := cast(^MazeGenerator)bench

    for y in 0..<len(mg.bool_grid) {
        delete(mg.bool_grid[y])
    }
    delete(mg.bool_grid)

    mg.bool_grid = generate_walkable_maze(mg.width, mg.height)
}

mazegenerator_checksum :: proc(bench: ^Benchmark) -> u32 {
    mg := cast(^MazeGenerator)bench
    return grid_checksum(mg.bool_grid)
}

mazegenerator_prepare :: proc(bench: ^Benchmark) {
    mg := cast(^MazeGenerator)bench
    mg.width = int(config_i64(mg.name, "w"))
    mg.height = int(config_i64(mg.name, "h"))
    mg.result_val = 0
    mg.bool_grid = make([][]bool, 0)  
}

mazegenerator_cleanup :: proc(bench: ^Benchmark) {
    mg := cast(^MazeGenerator)bench

    for y in 0..<len(mg.bool_grid) {
        delete(mg.bool_grid[y])
    }
    delete(mg.bool_grid)
}

create_mazegenerator :: proc() -> ^Benchmark {
    bench := new(MazeGenerator)
    bench.name = "MazeGenerator"
    bench.vtable = default_vtable()

    bench.vtable.run = mazegenerator_run
    bench.vtable.checksum = mazegenerator_checksum
    bench.vtable.prepare = mazegenerator_prepare
    bench.vtable.cleanup = mazegenerator_cleanup

    return cast(^Benchmark)bench
}

ASTAR_INF :: max(int)
STRAIGHT_COST :: 1000

AStarNode :: struct {
    x, y:    int,
    f_score: int,
}

node_less :: proc(a, b: AStarNode) -> bool {
    if a.f_score != b.f_score do return a.f_score < b.f_score
    if a.y != b.y do return a.y < b.y
    return a.x < b.x
}

node_swap :: proc(arr: []AStarNode, i, j: int) {
    arr[i], arr[j] = arr[j], arr[i]
}

AStarPathfinder :: struct {
    using base: Benchmark,
    result_val: u32,
    width:      int,
    height:     int,
    start_x:    int,
    start_y:    int,
    goal_x:     int,
    goal_y:     int,
    maze_grid:  [][]bool,
    g_scores:   []int,     
    came_from:  []int,     
}

astar_heuristic :: proc(x1, y1, x2, y2: int) -> int {
    return abs(x1 - x2) + abs(y1 - y2)
}

pack_coords :: proc(width, x, y: int) -> int {
    return y * width + x
}

unpack_coords :: proc(width, idx: int) -> (int, int) {
    return idx % width, idx / width
}

astar_find_path :: proc(astar: ^AStarPathfinder) -> (path: [dynamic][2]int, nodes_explored: int) {
    size := astar.width * astar.height
    start_idx := pack_coords(astar.width, astar.start_x, astar.start_y)
    goal_idx := pack_coords(astar.width, astar.goal_x, astar.goal_y)

    for i in 0..<size {
        astar.g_scores[i] = ASTAR_INF
        astar.came_from[i] = -1
    }

    pq: pqueue.Priority_Queue(AStarNode)
    pqueue.init(&pq, node_less, node_swap)
    defer pqueue.destroy(&pq)

    astar.g_scores[start_idx] = 0
    pqueue.push(&pq, AStarNode{
        x = astar.start_x,
        y = astar.start_y,
        f_score = astar_heuristic(astar.start_x, astar.start_y, astar.goal_x, astar.goal_y),
    })

    nodes_explored = 0
    directions := [4][2]int{{0, -1}, {1, 0}, {0, 1}, {-1, 0}}  

    for pqueue.len(pq) > 0 {
        current := pqueue.pop(&pq)
        nodes_explored += 1

        if current.x == astar.goal_x && current.y == astar.goal_y {

            path = make([dynamic][2]int, 0, astar.width + astar.height)

            x, y := current.x, current.y
            for x != astar.start_x || y != astar.start_y {
                append(&path, [2]int{x, y})
                idx := pack_coords(astar.width, x, y)
                packed := astar.came_from[idx]
                if packed == -1 do break

                px, py := unpack_coords(astar.width, packed)
                x, y = px, py
            }

            append(&path, [2]int{astar.start_x, astar.start_y})

            slice.reverse(path[:])
            return
        }

        current_idx := pack_coords(astar.width, current.x, current.y)
        current_g := astar.g_scores[current_idx]

        for dir in directions {
            nx := current.x + dir[0]
            ny := current.y + dir[1]

            if nx < 0 || nx >= astar.width || ny < 0 || ny >= astar.height do continue
            if !astar.maze_grid[ny][nx] do continue

            tentative_g := current_g + STRAIGHT_COST
            neighbor_idx := pack_coords(astar.width, nx, ny)

            if tentative_g < astar.g_scores[neighbor_idx] {
                astar.came_from[neighbor_idx] = current_idx
                astar.g_scores[neighbor_idx] = tentative_g

                f_score := tentative_g + astar_heuristic(nx, ny, astar.goal_x, astar.goal_y)
                pqueue.push(&pq, AStarNode{x = nx, y = ny, f_score = f_score})
            }
        }
    }

    return {}, nodes_explored
}

astarpathfinder_run :: proc(bench: ^Benchmark, iteration_id: int) {
    astar := cast(^AStarPathfinder)bench

    path, nodes_explored := astar_find_path(astar)
    defer if path != nil do delete(path)

    local_result: i64 = 0
    if len(path) > 0 {
        local_result = (local_result << 5) + i64(len(path))
    }
    local_result = (local_result << 5) + i64(nodes_explored)
    astar.result_val += u32(local_result)
}

astarpathfinder_checksum :: proc(bench: ^Benchmark) -> u32 {
    astar := cast(^AStarPathfinder)bench
    return astar.result_val
}

astarpathfinder_prepare :: proc(bench: ^Benchmark) {
    astar := cast(^AStarPathfinder)bench

    astar.width = int(config_i64(astar.name, "w"))
    astar.height = int(config_i64(astar.name, "h"))
    astar.start_x = 1
    astar.start_y = 1
    astar.goal_x = astar.width - 2
    astar.goal_y = astar.height - 2
    astar.result_val = 0

    astar.maze_grid = generate_walkable_maze(astar.width, astar.height)

    size := astar.width * astar.height
    astar.g_scores = make([]int, size)
    astar.came_from = make([]int, size)
}

astarpathfinder_cleanup :: proc(bench: ^Benchmark) {
    astar := cast(^AStarPathfinder)bench

    for y in 0..<len(astar.maze_grid) {
        delete(astar.maze_grid[y])
    }
    delete(astar.maze_grid)

    delete(astar.g_scores)
    delete(astar.came_from)
}

create_astarpathfinder :: proc() -> ^Benchmark {
    bench := new(AStarPathfinder)
    bench.name = "AStarPathfinder"
    bench.vtable = default_vtable()

    bench.vtable.run = astarpathfinder_run
    bench.vtable.checksum = astarpathfinder_checksum
    bench.vtable.prepare = astarpathfinder_prepare
    bench.vtable.cleanup = astarpathfinder_cleanup

    return cast(^Benchmark)bench
}