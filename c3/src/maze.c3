module maze;

import benchmark;
import helper;
import std::io;
import std::collections::priorityqueue;

enum MazeCellKind
{
	MAZE_CELL_WALL,
	MAZE_CELL_SPACE,
	MAZE_CELL_START,
	MAZE_CELL_FINISH,
	MAZE_CELL_BORDER,
	MAZE_CELL_PATH,
}

struct MazeCell
{
	MazeCellKind kind;
	MazeCell*[4] neighbors;
	int neighbor_count;
	int x;
	int y;
}

struct Maze
{
	int width;
	int height;
	MazeCell** cells;
	MazeCell* start;
	MazeCell* finish;
}

fn void maze_cell_add_neighbor(MazeCell* cell, MazeCell* neighbor)
{
	if (cell.neighbor_count < 4)
	{
		cell.neighbors[cell.neighbor_count] = neighbor;
		cell.neighbor_count++;
	}
}

fn bool maze_cell_is_walkable(MazeCell* cell)
{
	return cell.kind == MAZE_CELL_SPACE || cell.kind == MAZE_CELL_START || cell.kind == MAZE_CELL_FINISH;
}

fn void maze_cell_reset(MazeCell* cell)
{
	if (cell.kind == MAZE_CELL_SPACE)
	{
		cell.kind = MAZE_CELL_WALL;
	}
}

fn void maze_update_neighbors(Maze* maze)
{
	for (int y = 0; y < maze.height; y++)
	{
		for (int x = 0; x < maze.width; x++)
		{
			MazeCell* cell = &maze.cells[y][x];
			cell.neighbor_count = 0;

			if (x > 0 && y > 0 && x < maze.width - 1 && y < maze.height - 1)
			{
				maze_cell_add_neighbor(cell, &maze.cells[y - 1][x]);
				maze_cell_add_neighbor(cell, &maze.cells[y + 1][x]);
				maze_cell_add_neighbor(cell, &maze.cells[y][x + 1]);
				maze_cell_add_neighbor(cell, &maze.cells[y][x - 1]);

				for (int t = 0; t < 4; t++)
				{
					int i = (int)helper::helper_next_int(4);
					int j = (int)helper::helper_next_int(4);
					if (i != j)
					{
						MazeCell* temp = cell.neighbors[i];
						cell.neighbors[i] = cell.neighbors[j];
						cell.neighbors[j] = temp;
					}
				}
			}
			else
			{
				cell.kind = MAZE_CELL_BORDER;
			}
		}
	}
}

fn Maze* maze_create(int width, int height)
{
	Maze* maze = mem::new(Maze);
	maze.width = width;
	maze.height = height;

	maze.cells = mem::alloc_array(MazeCell*, (usz)height);
	for (int y = 0; y < height; y++)
	{
		maze.cells[y] = mem::new_array(MazeCell, (usz)width);
		for (int x = 0; x < width; x++)
		{
			MazeCell* cell = &maze.cells[y][x];
			cell.x = x;
			cell.y = y;
		}
	}

	maze.start = &maze.cells[1][1];
	maze.finish = &maze.cells[height - 2][width - 2];
	maze.start.kind = MAZE_CELL_START;
	maze.finish.kind = MAZE_CELL_FINISH;

	maze_update_neighbors(maze);

	return maze;
}

fn void maze_reset(Maze* maze)
{
	for (int y = 0; y < maze.height; y++)
	{
		for (int x = 0; x < maze.width; x++)
		{
			maze_cell_reset(&maze.cells[y][x]);
		}
	}
	maze.start.kind = MAZE_CELL_START;
	maze.finish.kind = MAZE_CELL_FINISH;
}

fn void maze_dig(Maze* maze, MazeCell* start_cell)
{
	usz max_size     = (usz)(maze.width * maze.height);
	MazeCell** stack = mem::alloc_array(MazeCell*, (sz)max_size);
	usz stack_size   = 0;
	stack[stack_size++] = start_cell;

	while (stack_size > 0)
	{
		MazeCell* cell = stack[--stack_size];

		int walkable = 0;
		for (int i = 0; i < cell.neighbor_count; i++)
		{
			if (maze_cell_is_walkable(cell.neighbors[i]))
			{
				walkable++;
			}
		}

		if (walkable != 1) continue;

		cell.kind = MAZE_CELL_SPACE;

		for (int i = 0; i < cell.neighbor_count; i++)
		{
			MazeCell* n = cell.neighbors[i];
			if (n.kind == MAZE_CELL_WALL)
			{
				if (stack_size >= max_size)
				{
					max_size *= 2;
					stack = mem::realloc(stack, (sz)max_size * void*::size);
				}
				stack[stack_size++] = n;
			}
		}
	}

	free(stack);
}

fn void maze_ensure_open_finish(Maze* maze, MazeCell* cell)
{
	cell.kind = MAZE_CELL_SPACE;

	int walkable = 0;
	for (int i = 0; i < cell.neighbor_count; i++)
	{
		if (maze_cell_is_walkable(cell.neighbors[i]))
		{
			walkable++;
		}
	}

	if (walkable > 1) return;

	for (int i = 0; i < cell.neighbor_count; i++)
	{
		MazeCell* n = cell.neighbors[i];
		if (n.kind == MAZE_CELL_WALL)
		{
			maze_ensure_open_finish(maze, n);
		}
	}
}

fn void maze_generate(Maze* maze)
{
	for (int i = 0; i < maze.start.neighbor_count; i++)
	{
		MazeCell* n = maze.start.neighbors[i];
		if (n.kind == MAZE_CELL_WALL)
		{
			maze_dig(maze, n);
		}
	}

	for (int i = 0; i < maze.finish.neighbor_count; i++)
	{
		MazeCell* n = maze.finish.neighbors[i];
		if (n.kind == MAZE_CELL_WALL)
		{
			maze_ensure_open_finish(maze, n);
		}
	}
}

fn MazeCell* maze_middle_cell(Maze* maze)
{
	return &maze.cells[maze.height / 2][maze.width / 2];
}

fn uint maze_checksum(Maze* maze)
{
	uint hasher = 2166136261;
	uint prime  = 16777619;

	for (int y = 0; y < maze.height; y++)
	{
		for (int x = 0; x < maze.width; x++)
		{
			if (maze.cells[y][x].kind == MAZE_CELL_SPACE)
			{
				uint val = (uint)(x * y);
				hasher = (hasher ^ val) * prime;
			}
		}
	}
	return hasher;
}

fn void maze_free(Maze* maze)
{
	if (!maze) return;
	for (int y = 0; y < maze.height; y++)
	{
		free(maze.cells[y]);
	}
	free(maze.cells);
	free(maze);
}

struct MazeGeneratorData
{
	uint result_val;
	int width;
	int height;
	Maze* maze;
}

fn void maze_generator_prepare(Benchmark* self)
{
}

fn void maze_generator_run(Benchmark* self, int iteration_id)
{
	MazeGeneratorData* data = (MazeGeneratorData*)self.data;

	maze_reset(data.maze);
	maze_generate(data.maze);

	data.result_val += (uint)maze_middle_cell(data.maze).kind;
}

fn uint maze_generator_checksum(Benchmark* self)
{
	MazeGeneratorData* data = (MazeGeneratorData*)self.data;
	return data.result_val + maze_checksum(data.maze);
}

fn void maze_generator_cleanup(Benchmark* self)
{
	MazeGeneratorData* data = (MazeGeneratorData*)self.data;
	maze_free(data.maze);
	data.maze = null;
}

fn Benchmark* maze_generator_create() @cname("MazeGenerator_create") @export
{
	Benchmark* bench        = benchmark::benchmark_create("Maze::Generator");
	MazeGeneratorData* data = mem::new(MazeGeneratorData);

	data.width = (int)helper::helper_config_i64(bench.name, "w");
	data.height = (int)helper::helper_config_i64(bench.name, "h");

	data.maze = maze_create(data.width, data.height);

	bench.data = data;
	bench.prepare = (PrepareFn)&maze_generator_prepare;
	bench.run = (RunFn)&maze_generator_run;
	bench.checksum = (ChecksumFn)&maze_generator_checksum;
	bench.cleanup = (CleanupFn)&maze_generator_cleanup;

	return bench;
}

struct PathNode
{
	MazeCell* cell;
	int parent;
}

struct MazeBFSData
{
	uint result_val;
	int width;
	int height;
	Maze* maze;
	MazeCell** path;
	int path_length;
}

fn MazeCell** maze_bfs(Maze* maze, MazeCell* start, MazeCell* target, int* out_length)
{
	if (start == target)
	{
		*out_length = 1;
		MazeCell** result = mem::alloc_array(MazeCell*, 1);
		result[0] = start;
		return result;
	}

	int width  = maze.width;
	int height = maze.height;

	int* queue     = mem::alloc_array(int, (usz)(width * height));
	int queue_head = 0;
	int queue_tail = 0;

	bool** visited = mem::alloc_array(bool*, (usz)height);
	for (int y = 0; y < height; y++)
	{
		visited[y] = mem::new_array(bool, (usz)width);
	}

	PathNode* path_nodes = mem::alloc_array(PathNode, (usz)(width * height));
	int path_count       = 0;

	visited[start.y][start.x] = true;
	path_nodes[path_count].cell = start;
	path_nodes[path_count].parent = -1;
	path_count++;
	queue[queue_tail++] = 0;

	while (queue_head < queue_tail)
	{
		int path_id    = queue[queue_head++];
		MazeCell* cell = path_nodes[path_id].cell;

		for (int i = 0; i < cell.neighbor_count; i++)
		{
			MazeCell* neighbor = cell.neighbors[i];

			if (neighbor == target)
			{
				int length = 1;
				int cur    = path_id;
				while (cur >= 0)
				{
					length++;
					cur = path_nodes[cur].parent;
				}

				MazeCell** result = mem::alloc_array(MazeCell*, (usz)length);
				int idx           = length - 1;
				result[idx--] = target;

				cur = path_id;
				while (cur >= 0)
				{
					result[idx--] = path_nodes[cur].cell;
					cur = path_nodes[cur].parent;
				}

				*out_length = length;
				free(queue);
				for (int y = 0; y < height; y++)
				{
					free(visited[y]);
				}
				free(visited);
				free(path_nodes);
				return result;
			}

			if (maze_cell_is_walkable(neighbor) && !visited[neighbor.y][neighbor.x])
			{
				visited[neighbor.y][neighbor.x] = true;
				path_nodes[path_count].cell = neighbor;
				path_nodes[path_count].parent = path_id;
				queue[queue_tail++] = path_count;
				path_count++;
			}
		}
	}

	*out_length = 0;
	free(queue);
	for (int y = 0; y < height; y++)
	{
		free(visited[y]);
	}
	free(visited);
	free(path_nodes);
	return null;
}

fn void maze_bfs_prepare(Benchmark* self)
{
	MazeBFSData* data = (MazeBFSData*)self.data;
	maze_generate(data.maze);
}

fn void maze_bfs_run(Benchmark* self, int iteration_id)
{
	MazeBFSData* data = (MazeBFSData*)self.data;

	free(data.path);
	data.path = maze_bfs(data.maze, data.maze.start, data.maze.finish, &data.path_length);
	data.result_val += (uint)data.path_length;
}

fn uint maze_bfs_checksum(Benchmark* self)
{
	MazeBFSData* data = (MazeBFSData*)self.data;
	if (data.path_length == 0) return data.result_val;
	int mid = data.path_length / 2;
	return data.result_val + (uint)(data.path[mid].x * data.path[mid].y);
}

fn void maze_bfs_cleanup(Benchmark* self)
{
	MazeBFSData* data = (MazeBFSData*)self.data;
	free(data.path);
	maze_free(data.maze);
}

fn Benchmark* maze_bfs_create() @cname("MazeBFS_create") @export
{
	Benchmark* bench  = benchmark::benchmark_create("Maze::BFS");
	MazeBFSData* data = mem::new(MazeBFSData);

	data.width = (int)helper::helper_config_i64(bench.name, "w");
	data.height = (int)helper::helper_config_i64(bench.name, "h");

	data.maze = maze_create(data.width, data.height);

	bench.data = data;
	bench.prepare = (PrepareFn)&maze_bfs_prepare;
	bench.run = (RunFn)&maze_bfs_run;
	bench.checksum = (ChecksumFn)&maze_bfs_checksum;
	bench.cleanup = (CleanupFn)&maze_bfs_cleanup;

	return bench;
}

struct AStarEntry
{
	int priority;
	int vertex;
}

fn bool AStarEntry.less(self, AStarEntry other)
{
	return self.priority < other.priority;
}

alias AStarQueue = PriorityQueue{AStarEntry};

struct MazeAStarData
{
	uint result_val;
	int width;
	int height;
	Maze* maze;
	MazeCell** path;
	int path_length;
}

fn int astar_heuristic(MazeCell* a, MazeCell* b)
{
	int dx = a.x - b.x;
	int dy = a.y - b.y;
	return (dx > 0 ? dx : -dx) + (dy > 0 ? dy : -dy);
}

fn int astar_idx(int y, int x, int width)
{
	return y * width + x;
}

fn MazeCell** maze_astar(Maze* maze, MazeCell* start, MazeCell* target, int* out_length)
{
	if (start == target)
	{
		*out_length = 1;
		MazeCell** result = mem::alloc_array(MazeCell*, 1);
		result[0] = start;
		return result;
	}

	int width  = maze.width;
	int height = maze.height;
	int size   = width * height;

	int* came_from = mem::alloc_array(int, (usz)size);
	int* g_score   = mem::alloc_array(int, (usz)size);
	int* best_f    = mem::alloc_array(int, (usz)size);
	for (int i = 0; i < size; i++)
	{
		came_from[i] = -1;
		g_score[i] = int::max;
		best_f[i] = int::max;
	}

	int start_idx  = astar_idx(start.y, start.x, width);
	int target_idx = astar_idx(target.y, target.x, width);

	AStarQueue open_set;
	open_set.init(mem, (usz)size);

	g_score[start_idx] = 0;
	int f_start = astar_heuristic(start, target);
	open_set.push({ f_start, start_idx });
	best_f[start_idx] = f_start;

	while (!open_set.is_empty())
	{
		AStarEntry entry = open_set.pop()!!;
		int current_idx  = entry.vertex;

		if (current_idx == target_idx)
		{
			int length = 0;
			int cur    = current_idx;
			while (cur != -1)
			{
				length++;
				cur = came_from[cur];
			}

			MazeCell** result = mem::alloc_array(MazeCell*, (usz)length);
			cur = current_idx;
			for (int i = length - 1; i >= 0; i--)
			{
				int yy = cur / width;
				int xx = cur % width;
				result[i] = &maze.cells[yy][xx];
				cur = came_from[cur];
			}

			*out_length = length;
			free(came_from);
			free(g_score);
			free(best_f);
			open_set.free();
			return result;
		}

		int current_y     = current_idx / width;
		int current_x     = current_idx % width;
		MazeCell* current = &maze.cells[current_y][current_x];
		int current_g     = g_score[current_idx];

		for (int i = 0; i < current.neighbor_count; i++)
		{
			MazeCell* neighbor = current.neighbors[i];
			if (!maze_cell_is_walkable(neighbor)) continue;

			int neighbor_idx = astar_idx(neighbor.y, neighbor.x, width);
			int tentative_g  = current_g + 1;

			if (tentative_g < g_score[neighbor_idx])
			{
				came_from[neighbor_idx] = current_idx;
				g_score[neighbor_idx] = tentative_g;
				int f_new = tentative_g + astar_heuristic(neighbor, target);

				if (f_new < best_f[neighbor_idx])
				{
					best_f[neighbor_idx] = f_new;
					open_set.push({ f_new, neighbor_idx });
				}
			}
		}
	}

	*out_length = 0;
	free(came_from);
	free(g_score);
	free(best_f);
	open_set.free();
	return null;
}

fn void maze_astar_prepare(Benchmark* self)
{
	MazeAStarData* data = (MazeAStarData*)self.data;
	maze_generate(data.maze);
}

fn void maze_astar_run(Benchmark* self, int iteration_id)
{
	MazeAStarData* data = (MazeAStarData*)self.data;

	free(data.path);
	data.path = maze_astar(data.maze, data.maze.start, data.maze.finish, &data.path_length);
	data.result_val += (uint)data.path_length;
}

fn uint maze_astar_checksum(Benchmark* self)
{
	MazeAStarData* data = (MazeAStarData*)self.data;
	if (data.path_length == 0) return data.result_val;
	int mid = data.path_length / 2;
	return data.result_val + (uint)(data.path[mid].x * data.path[mid].y);
}

fn void maze_astar_cleanup(Benchmark* self)
{
	MazeAStarData* data = (MazeAStarData*)self.data;
	free(data.path);
	maze_free(data.maze);
}

fn Benchmark* maze_astar_create() @cname("MazeAStar_create") @export
{
	Benchmark* bench    = benchmark::benchmark_create("Maze::AStar");
	MazeAStarData* data = mem::new(MazeAStarData);

	data.width = (int)helper::helper_config_i64(bench.name, "w");
	data.height = (int)helper::helper_config_i64(bench.name, "h");

	data.maze = maze_create(data.width, data.height);

	bench.data = data;
	bench.prepare = (PrepareFn)&maze_astar_prepare;
	bench.run = (RunFn)&maze_astar_run;
	bench.checksum = (ChecksumFn)&maze_astar_checksum;
	bench.cleanup = (CleanupFn)&maze_astar_cleanup;

	return bench;
}