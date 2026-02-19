public class GameOfLife : Benchmark
{
    private class Cell
    {
        public bool Alive { get; set; }
        public bool NextState { get; set; }
        private Cell[] _neighbors = new Cell[8];
        private int _neighborCount;

        public void AddNeighbor(Cell cell) => _neighbors[_neighborCount++] = cell;

        public void ComputeNextState()
        {
            int aliveNeighbors = 0;
            foreach (var neighbor in _neighbors)
            {
                if (neighbor.Alive) aliveNeighbors++;
            }

            NextState = Alive
                ? aliveNeighbors == 2 || aliveNeighbors == 3
                : aliveNeighbors == 3;
        }

        public void Update() => Alive = NextState;
    }

    private class Grid
    {
        private readonly int _width;
        private readonly int _height;
        private readonly Cell[][] _cells;

        public Grid(int width, int height)
        {
            _width = width;
            _height = height;
            _cells = new Cell[height][];

            for (int y = 0; y < height; y++)
            {
                _cells[y] = new Cell[width];
                for (int x = 0; x < width; x++)
                    _cells[y][x] = new Cell();
            }

            LinkNeighbors();
        }

        private void LinkNeighbors()
        {
            for (int y = 0; y < _height; y++)
            {
                for (int x = 0; x < _width; x++)
                {
                    var cell = _cells[y][x];

                    for (int dy = -1; dy <= 1; dy++)
                    {
                        for (int dx = -1; dx <= 1; dx++)
                        {
                            if (dx == 0 && dy == 0) continue;

                            int ny = (y + dy + _height) % _height;
                            int nx = (x + dx + _width) % _width;

                            cell.AddNeighbor(_cells[ny][nx]);
                        }
                    }
                }
            }
        }

        public void NextGeneration()
        {

            foreach (var row in _cells)
                foreach (var cell in row)
                    cell.ComputeNextState();

            foreach (var row in _cells)
                foreach (var cell in row)
                    cell.Update();
        }

        public int CountAlive()
        {
            int count = 0;
            foreach (var row in _cells)
                foreach (var cell in row)
                    if (cell.Alive) count++;
            return count;
        }

        public uint ComputeHash()
        {
            const uint FNV_OFFSET_BASIS = 2166136261u;
            const uint FNV_PRIME = 16777619u;

            uint hash = FNV_OFFSET_BASIS;
            foreach (var row in _cells)
                foreach (var cell in row)
                {
                    uint alive = cell.Alive ? 1u : 0u;
                    hash = (hash ^ alive) * FNV_PRIME;
                }
            return hash;
        }

        public Cell[][] GetCells() => _cells;
    }

    private readonly int _width;
    private readonly int _height;
    private Grid _grid;

    public GameOfLife()
    {
        _width = (int)ConfigVal("w");
        _height = (int)ConfigVal("h");
        _grid = new Grid(_width, _height);
    }

    public override void Prepare()
    {
        foreach (var row in _grid.GetCells())
            foreach (var cell in row)
                if (Helper.NextFloat() < 0.1f)
                    cell.Alive = true;
    }

    public override void Run(long iterationId) => _grid.NextGeneration();

    public override uint Checksum
    {
        get
        {
            int alive = _grid.CountAlive();
            return _grid.ComputeHash() + (uint)alive;
        }
    }
}