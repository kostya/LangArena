public class GameOfLife : Benchmark
{
    private enum Cell : byte { Dead = 0, Alive = 1 }

    private class Grid
    {
        private readonly int _width;
        private readonly int _height;
        private Cell[] _cells;           
        private Cell[] _buffer;          

        public Grid(int width, int height)
        {
            _width = width;
            _height = height;
            int size = width * height;
            _cells = new Cell[size];
            _buffer = new Cell[size];
        }

        private Grid(int width, int height, Cell[] cells, Cell[] buffer)
        {
            _width = width;
            _height = height;
            _cells = cells;
            _buffer = buffer;
        }

        private int Index(int x, int y) => y * _width + x;

        public Cell Get(int x, int y) => _cells[Index(x, y)];
        public void Set(int x, int y, Cell cell) => _cells[Index(x, y)] = cell;

        private int CountNeighbors(int x, int y, Cell[] cells)
        {

            int yPrev = y == 0 ? _height - 1 : y - 1;
            int yNext = y == _height - 1 ? 0 : y + 1;
            int xPrev = x == 0 ? _width - 1 : x - 1;
            int xNext = x == _width - 1 ? 0 : x + 1;

            int count = 0;

            int idx = yPrev * _width;
            if (cells[idx + xPrev] == Cell.Alive) count++;
            if (cells[idx + x] == Cell.Alive) count++;
            if (cells[idx + xNext] == Cell.Alive) count++;

            idx = y * _width;
            if (cells[idx + xPrev] == Cell.Alive) count++;
            if (cells[idx + xNext] == Cell.Alive) count++;

            idx = yNext * _width;
            if (cells[idx + xPrev] == Cell.Alive) count++;
            if (cells[idx + x] == Cell.Alive) count++;
            if (cells[idx + xNext] == Cell.Alive) count++;

            return count;
        }

        public Grid NextGeneration()
        {
            int width = _width;
            int height = _height;

            Cell[] cells = _cells;
            Cell[] buffer = _buffer;

            for (int y = 0; y < height; y++)
            {
                int yIdx = y * width;

                for (int x = 0; x < width; x++)
                {
                    int idx = yIdx + x;

                    int neighbors = CountNeighbors(x, y, cells);

                    Cell current = cells[idx];
                    Cell nextState = Cell.Dead;

                    if (current == Cell.Alive)
                    {
                        nextState = (neighbors == 2 || neighbors == 3) ? Cell.Alive : Cell.Dead;
                    }
                    else if (neighbors == 3)
                    {
                        nextState = Cell.Alive;
                    }

                    buffer[idx] = nextState;
                }
            }

            return new Grid(width, height)
            {
                _cells = buffer,
                _buffer = cells
            };
        }

        public uint ComputeHash()
        {
            const uint FNV_OFFSET_BASIS = 2166136261u;
            const uint FNV_PRIME = 16777619u;

            uint hash = FNV_OFFSET_BASIS;

            for (int i = 0; i < _cells.Length; i++)
            {
                uint alive = _cells[i] == Cell.Alive ? 1u : 0u;
                hash = (hash ^ alive) * FNV_PRIME;
            }

            return hash;
        }
    }

    private uint _result;
    private int _width;
    private int _height;
    private Grid _grid;

    public GameOfLife()
    {
        _width = (int)ConfigVal("w");
        _height = (int)ConfigVal("h");
        _grid = new Grid(_width, _height);
    }

    public override void Prepare()
    {

        for (int y = 0; y < _height; y++)
        {
            int yIdx = y * _width;

            for (int x = 0; x < _width; x++)
            {
                if (Helper.NextFloat() < 0.1f)
                {
                    _grid.Set(x, y, Cell.Alive);
                }
            }
        }
    }

    public override void Run(long IterationId) => _grid = _grid.NextGeneration();

    public override uint Checksum => _grid.ComputeHash();
}