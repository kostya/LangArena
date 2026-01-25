public class GameOfLife : Benchmark
{
    private enum Cell : byte { Dead = 0, Alive = 1 }
    
    private class DoubleBufferedGrid
    {
        private readonly int _width;
        private readonly int _height;
        private readonly Cell[,] _current;
        private readonly Cell[,] _next;
        private bool _useFirstAsCurrent = true;
        
        public int Width => _width;
        public int Height => _height;
        
        public Cell[,] Current => _useFirstAsCurrent ? _current : _next;
        public Cell[,] Next => _useFirstAsCurrent ? _next : _current;
        
        public DoubleBufferedGrid(int width, int height)
        {
            _width = width;
            _height = height;
            _current = new Cell[height, width];
            _next = new Cell[height, width];
        }
        
        public Cell Get(int x, int y) => Current[y, x];
        public void Set(int x, int y, Cell cell) => Current[y, x] = cell;
        
        public int CountNeighbors(int x, int y)
        {
            int count = 0;
            var cells = Current;
            int width = _width;
            int height = _height;
            
            // Предвычисленные смещения соседей (9 позиций)
            // ... тот же код, но без создания нового Grid
            return count;
        }
        
        public void SwapBuffers()
        {
            _useFirstAsCurrent = !_useFirstAsCurrent;
        }
        
        public void ComputeNextGeneration()
        {
            var current = Current;
            var next = Next;
            int width = _width;
            int height = _height;
            
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    int neighbors = 0;
                    // Быстрый подсчет соседей inline
                    for (int dy = -1; dy <= 1; dy++)
                    {
                        for (int dx = -1; dx <= 1; dx++)
                        {
                            if (dx == 0 && dy == 0) continue;
                            
                            int nx = (x + dx) % width;
                            int ny = (y + dy) % height;
                            if (nx < 0) nx += width;
                            if (ny < 0) ny += height;
                            
                            if (current[ny, nx] == Cell.Alive)
                                neighbors++;
                        }
                    }
                    
                    Cell nextState = Cell.Dead;
                    if (current[y, x] == Cell.Alive)
                    {
                        if (neighbors == 2 || neighbors == 3)
                            nextState = Cell.Alive;
                    }
                    else if (neighbors == 3)
                    {
                        nextState = Cell.Alive;
                    }
                    
                    next[y, x] = nextState;
                }
            }
            
            SwapBuffers();
        }
        
        public int AliveCount()
        {
            int count = 0;
            var cells = Current;
            int height = _height;
            int width = _width;
            
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    if (cells[y, x] == Cell.Alive)
                        count++;
                }
            }
            return count;
        }
    }
    
    private long _resultVal;
    private readonly int _width = 256;
    private readonly int _height = 256;
    private DoubleBufferedGrid _grid;
    
    public GameOfLife()
    {
        _grid = new DoubleBufferedGrid(_width, _height);
    }
    
    public override void Prepare()
    {
        // Инициализация случайными клетками
        for (int y = 0; y < _height; y++)
        {
            for (int x = 0; x < _width; x++)
            {
                if (Helper.NextFloat() < 0.1f)
                    _grid.Set(x, y, Cell.Alive);
            }
        }
    }
    
    public override void Run()
    {
        int iters = Iterations;
        for (int i = 0; i < iters; i++)
        {
            _grid.ComputeNextGeneration(); // Без выделения памяти!
        }
        
        _resultVal = _grid.AliveCount();
    }
    
    public override long Result => _resultVal;
}