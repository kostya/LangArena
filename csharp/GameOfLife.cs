public class GameOfLife : Benchmark
{
    private enum Cell : byte { Dead = 0, Alive = 1 }
    
    private class Grid
    {
        private readonly int _width;
        private readonly int _height;
        private Cell[] _cells;           // Плоский массив для лучшей производительности
        private Cell[] _buffer;          // Предварительно аллоцированный буфер
        
        public Grid(int width, int height)
        {
            _width = width;
            _height = height;
            int size = width * height;
            _cells = new Cell[size];
            _buffer = new Cell[size];
        }
        
        // Инлайн метод для быстрого доступа
        private int Index(int x, int y) => y * _width + x;
        
        public Cell Get(int x, int y) => _cells[Index(x, y)];
        public void Set(int x, int y, Cell cell) => _cells[Index(x, y)] = cell;
        
        // Оптимизированный подсчет соседей
        private int CountNeighbors(int x, int y, Cell[] cells)
        {
            // Предварительно вычисленные индексы с тороидальными границами
            int y_prev = y == 0 ? _height - 1 : y - 1;
            int y_next = y == _height - 1 ? 0 : y + 1;
            int x_prev = x == 0 ? _width - 1 : x - 1;
            int x_next = x == _width - 1 ? 0 : x + 1;
            
            // Развернутый подсчет 8 соседей
            int count = 0;
            
            // Верхний ряд
            int idx = y_prev * _width;
            if (cells[idx + x_prev] == Cell.Alive) count++;
            if (cells[idx + x] == Cell.Alive) count++;
            if (cells[idx + x_next] == Cell.Alive) count++;
            
            // Средний ряд
            idx = y * _width;
            if (cells[idx + x_prev] == Cell.Alive) count++;
            if (cells[idx + x_next] == Cell.Alive) count++;
            
            // Нижний ряд
            idx = y_next * _width;
            if (cells[idx + x_prev] == Cell.Alive) count++;
            if (cells[idx + x] == Cell.Alive) count++;
            if (cells[idx + x_next] == Cell.Alive) count++;
            
            return count;
        }
        
        public Grid NextGeneration()
        {
            int width = _width;
            int height = _height;
            int size = width * height;
            
            // Локальные ссылки для лучшей производительности
            Cell[] cells = _cells;
            Cell[] buffer = _buffer;
            
            // Оптимизированный параллелизуемый цикл
            for (int y = 0; y < height; y++)
            {
                int y_idx = y * width;
                int y_prev_idx = (y == 0 ? height - 1 : y - 1) * width;
                int y_next_idx = (y == height - 1 ? 0 : y + 1) * width;
                
                for (int x = 0; x < width; x++)
                {
                    int idx = y_idx + x;
                    
                    // Вычисляем индексы соседей
                    int x_prev = x == 0 ? width - 1 : x - 1;
                    int x_next = x == width - 1 ? 0 : x + 1;
                    
                    // Развернутый подсчет соседей
                    int neighbors = 0;
                    
                    // Верхний ряд
                    if (cells[y_prev_idx + x_prev] == Cell.Alive) neighbors++;
                    if (cells[y_prev_idx + x] == Cell.Alive) neighbors++;
                    if (cells[y_prev_idx + x_next] == Cell.Alive) neighbors++;
                    
                    // Средний ряд
                    if (cells[y_idx + x_prev] == Cell.Alive) neighbors++;
                    if (cells[y_idx + x_next] == Cell.Alive) neighbors++;
                    
                    // Нижний ряд
                    if (cells[y_next_idx + x_prev] == Cell.Alive) neighbors++;
                    if (cells[y_next_idx + x] == Cell.Alive) neighbors++;
                    if (cells[y_next_idx + x_next] == Cell.Alive) neighbors++;
                    
                    // Оптимизированная логика игры
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
            
            // Возвращаем новый Grid с обмененными буферами
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
            
            // Оптимизированный цикл хэширования
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
        // Оптимизированная инициализация
        for (int y = 0; y < _height; y++)
        {
            int y_idx = y * _width;
            
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