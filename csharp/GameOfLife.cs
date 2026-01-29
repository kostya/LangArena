public class GameOfLife : Benchmark
{
    private enum Cell : byte { Dead = 0, Alive = 1 }
    
    private class Grid
    {
        private readonly int _width;
        private readonly int _height;
        private readonly Cell[,] _cells;
        
        public Grid(int width, int height)
        {
            _width = width;
            _height = height;
            _cells = new Cell[height, width];
        }
        
        public Cell Get(int x, int y) => _cells[y, x];
        public void Set(int x, int y, Cell cell) => _cells[y, x] = cell;
        
        public Grid NextGeneration()
        {
            var nextGrid = new Grid(_width, _height);
            
            for (int y = 0; y < _height; y++)
            {
                for (int x = 0; x < _width; x++)
                {
                    int neighbors = 0;
                    
                    for (int dy = -1; dy <= 1; dy++)
                    {
                        for (int dx = -1; dx <= 1; dx++)
                        {
                            if (dx == 0 && dy == 0) continue;
                            
                            int nx = (x + dx) % _width;
                            int ny = (y + dy) % _height;
                            if (nx < 0) nx += _width;
                            if (ny < 0) ny += _height;
                            
                            if (_cells[ny, nx] == Cell.Alive) neighbors++;
                        }
                    }
                    
                    Cell nextState = Cell.Dead;
                    if (_cells[y, x] == Cell.Alive)
                    {
                        if (neighbors == 2 || neighbors == 3) nextState = Cell.Alive;
                    }
                    else if (neighbors == 3)
                    {
                        nextState = Cell.Alive;
                    }
                    
                    nextGrid.Set(x, y, nextState);
                }
            }
            
            return nextGrid;
        }
        
        public uint ComputeHash()
        {
            uint hasher = 2166136261;
            uint prime = 16777619;
            
            for (int y = 0; y < _height; y++)
            {
                for (int x = 0; x < _width; x++)
                {
                    uint alive = (_cells[y, x] == Cell.Alive) ? 1u : 0u;
                    hasher = (hasher ^ alive) * prime;
                }
            }
            return hasher;
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
            for (int x = 0; x < _width; x++)
            {
                if (Helper.NextFloat() < 0.1f) _grid.Set(x, y, Cell.Alive);
            }
        }
    }
    
    public override void Run(long IterationId) => _grid = _grid.NextGeneration();
    
    public override uint Checksum => _grid.ComputeHash();
}