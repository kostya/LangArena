module game_of_life;

import benchmark;
import helper;
import std::io;

struct Cell
{
	bool alive;
	bool next_state;
	Cell*[8] neighbors;
	int neighbor_count;
}

struct GameOfLifeGrid
{
	int width;
	int height;
	Cell*** cells;
}

struct GameOfLifeData
{
	uint result_val;
	long width_val;
	long height_val;
	GameOfLifeGrid grid;
}

fn uint fnv1a_hash(uint hash, uint value)
{
	const uint FNV_OFFSET_BASIS = 2166136261;
	const uint FNV_PRIME        = 16777619;

	if (hash == 0) hash = FNV_OFFSET_BASIS;
	hash ^= value;
	hash *= FNV_PRIME;
	return hash;
}

fn Cell* cell_create()
{
	return mem::new(Cell);
}

fn void cell_destroy(Cell* cell)
{
	free(cell);
}

fn void cell_add_neighbor(Cell* cell, Cell* neighbor)
{
	cell.neighbors[cell.neighbor_count] = neighbor;
	cell.neighbor_count++;
}

fn void cell_compute_next_state(Cell* cell)
{
	int alive_neighbors = 0;
	for (int i = 0; i < cell.neighbor_count; i++)
	{
		if (cell.neighbors[i].alive)
		{
			alive_neighbors++;
		}
	}

	if (cell.alive)
	{
		cell.next_state = (alive_neighbors == 2 || alive_neighbors == 3);
	}
	else
	{
		cell.next_state = (alive_neighbors == 3);
	}
}

fn void cell_update(Cell* cell)
{
	cell.alive = cell.next_state;
}

fn void game_of_life_grid_init(GameOfLifeGrid* grid, int width, int height)
{
	grid.width = width;
	grid.height = height;

	grid.cells = mem::alloc_array(Cell**, (usz)height);
	for (int y = 0; y < height; y++)
	{
		grid.cells[y] = mem::alloc_array(Cell*, (usz)width);
		for (int x = 0; x < width; x++)
		{
			grid.cells[y][x] = cell_create();
		}
	}

	for (int y = 0; y < height; y++)
	{
		for (int x = 0; x < width; x++)
		{
			Cell* cell = grid.cells[y][x];

			for (int dy = -1; dy <= 1; dy++)
			{
				for (int dx = -1; dx <= 1; dx++)
				{
					if (dx == 0 && dy == 0)
					{
						continue;
					}

					int ny = (y + dy + height) % height;
					int nx = (x + dx + width) % width;

					cell_add_neighbor(cell, grid.cells[ny][nx]);
				}
			}
		}
	}
}

fn void game_of_life_grid_free(GameOfLifeGrid* grid)
{
	for (int y = 0; y < grid.height; y++)
	{
		for (int x = 0; x < grid.width; x++)
		{
			cell_destroy(grid.cells[y][x]);
		}
		free(grid.cells[y]);
	}
	free(grid.cells);
}

fn void game_of_life_next_generation(GameOfLifeGrid* grid)
{
	for (int y = 0; y < grid.height; y++)
	{
		for (int x = 0; x < grid.width; x++)
		{
			cell_compute_next_state(grid.cells[y][x]);
		}
	}

	for (int y = 0; y < grid.height; y++)
	{
		for (int x = 0; x < grid.width; x++)
		{
			cell_update(grid.cells[y][x]);
		}
	}
}

fn int game_of_life_count_alive(GameOfLifeGrid* grid)
{
	int count = 0;
	for (int y = 0; y < grid.height; y++)
	{
		for (int x = 0; x < grid.width; x++)
		{
			if (grid.cells[y][x].alive)
			{
				count++;
			}
		}
	}
	return count;
}

fn uint game_of_life_grid_hash(GameOfLifeGrid* grid)
{
	uint hash = 0;

	for (int y = 0; y < grid.height; y++)
	{
		for (int x = 0; x < grid.width; x++)
		{
			uint alive = grid.cells[y][x].alive ? 1 : 0;
			hash = fnv1a_hash(hash, alive);
		}
	}

	return hash;
}

fn void game_of_life_prepare(Benchmark* self)
{
	GameOfLifeData* data = (GameOfLifeData*)self.data;

	data.width_val = helper::helper_config_i64(self.name, "w");
	data.height_val = helper::helper_config_i64(self.name, "h");

	game_of_life_grid_init(&data.grid, (int)data.width_val, (int)data.height_val);

	for (int y = 0; y < data.grid.height; y++)
	{
		for (int x = 0; x < data.grid.width; x++)
		{
			if (helper::helper_next_float(1.0) < 0.1)
			{
				data.grid.cells[y][x].alive = true;
			}
		}
	}
}

fn void game_of_life_run(Benchmark* self, int iteration_id)
{
	GameOfLifeData* data = (GameOfLifeData*)self.data;
	game_of_life_next_generation(&data.grid);
}

fn uint game_of_life_checksum(Benchmark* self)
{
	GameOfLifeData* data = (GameOfLifeData*)self.data;
	int alive            = game_of_life_count_alive(&data.grid);
	return game_of_life_grid_hash(&data.grid) + (uint)alive;
}

fn void game_of_life_cleanup(Benchmark* self)
{
	GameOfLifeData* data = (GameOfLifeData*)self.data;
	game_of_life_grid_free(&data.grid);
}

fn Benchmark* game_of_life_create() @cname("GameOfLife_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Etc::GameOfLife");

	GameOfLifeData* data = mem::new(GameOfLifeData);

	bench.data = data;
	bench.prepare = (PrepareFn)&game_of_life_prepare;
	bench.run = (RunFn)&game_of_life_run;
	bench.checksum = (ChecksumFn)&game_of_life_checksum;
	bench.cleanup = (CleanupFn)&game_of_life_cleanup;

	return bench;
}