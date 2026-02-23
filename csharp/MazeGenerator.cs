using System.Collections.Generic;

public class MazeGenerator : Benchmark
{
    public enum Cell { Wall, Path }

    public class Maze
    {
        private readonly int _width;
        private readonly int _height;
        private readonly Cell[,] _cells;

        public Maze(int width, int height)
        {
            _width = width > 5 ? width : 5;
            _height = height > 5 ? height : 5;
            _cells = new Cell[_height, _width];
            for (int y = 0; y < _height; y++)
                for (int x = 0; x < _width; x++)
                    _cells[y, x] = Cell.Wall;
        }

        public Cell Get(int x, int y) => _cells[y, x];
        public void Set(int x, int y, Cell cell) => _cells[y, x] = cell;

        private void Divide(int x1, int y1, int x2, int y2)
        {
            int width = x2 - x1;
            int height = y2 - y1;

            if (width < 2 || height < 2) return;

            int widthForWall = width - 2;
            int heightForWall = height - 2;
            int widthForHole = width - 1;
            int heightForHole = height - 1;

            if (widthForWall <= 0 || heightForWall <= 0 ||
                widthForHole <= 0 || heightForHole <= 0) return;

            if (width > height)
            {
                int wallRange = System.Math.Max(widthForWall / 2, 1);
                int wallOffset = wallRange > 0 ? (Helper.NextInt(wallRange)) * 2 : 0;
                int wallX = x1 + 2 + wallOffset;

                int holeRange = System.Math.Max(heightForHole / 2, 1);
                int holeOffset = holeRange > 0 ? (Helper.NextInt(holeRange)) * 2 : 0;
                int holeY = y1 + 1 + holeOffset;

                if (wallX > x2 || holeY > y2) return;

                for (int y = y1; y <= y2; y++)
                    if (y != holeY) Set(wallX, y, Cell.Wall);

                if (wallX > x1 + 1) Divide(x1, y1, wallX - 1, y2);
                if (wallX + 1 < x2) Divide(wallX + 1, y1, x2, y2);
            }
            else
            {
                int wallRange = System.Math.Max(heightForWall / 2, 1);
                int wallOffset = wallRange > 0 ? (Helper.NextInt(wallRange)) * 2 : 0;
                int wallY = y1 + 2 + wallOffset;

                int holeRange = System.Math.Max(widthForHole / 2, 1);
                int holeOffset = holeRange > 0 ? (Helper.NextInt(holeRange)) * 2 : 0;
                int holeX = x1 + 1 + holeOffset;

                if (wallY > y2 || holeX > x2) return;

                for (int x = x1; x <= x2; x++)
                    if (x != holeX) Set(x, wallY, Cell.Wall);

                if (wallY > y1 + 1) Divide(x1, y1, x2, wallY - 1);
                if (wallY + 1 < y2) Divide(x1, wallY + 1, x2, y2);
            }
        }

        private void AddRandomPaths()
        {
            int numExtraPaths = (_width * _height) / 20;

            for (int i = 0; i < numExtraPaths; i++)
            {
                int x = Helper.NextInt(_width - 2) + 1;
                int y = Helper.NextInt(_height - 2) + 1;

                if (Get(x, y) == Cell.Wall &&
                    Get(x - 1, y) == Cell.Wall &&
                    Get(x + 1, y) == Cell.Wall &&
                    Get(x, y - 1) == Cell.Wall &&
                    Get(x, y + 1) == Cell.Wall)
                {
                    Set(x, y, Cell.Path);
                }
            }
        }

        private bool IsConnectedImpl(int startX, int startY, int goalX, int goalY)
        {
            if (startX >= _width || startY >= _height ||
                goalX >= _width || goalY >= _height) return false;

            bool[,] visited = new bool[_height, _width];
            var queue = new Queue<(int x, int y)>();

            visited[startY, startX] = true;
            queue.Enqueue((startX, startY));

            while (queue.Count > 0)
            {
                var (x, y) = queue.Dequeue();

                if (x == goalX && y == goalY) return true;

                if (y > 0 && Get(x, y - 1) == Cell.Path && !visited[y - 1, x])
                {
                    visited[y - 1, x] = true;
                    queue.Enqueue((x, y - 1));
                }

                if (x + 1 < _width && Get(x + 1, y) == Cell.Path && !visited[y, x + 1])
                {
                    visited[y, x + 1] = true;
                    queue.Enqueue((x + 1, y));
                }

                if (y + 1 < _height && Get(x, y + 1) == Cell.Path && !visited[y + 1, x])
                {
                    visited[y + 1, x] = true;
                    queue.Enqueue((x, y + 1));
                }

                if (x > 0 && Get(x - 1, y) == Cell.Path && !visited[y, x - 1])
                {
                    visited[y, x - 1] = true;
                    queue.Enqueue((x - 1, y));
                }
            }

            return false;
        }

        public void Generate()
        {
            if (_width < 5 || _height < 5)
            {
                for (int x = 0; x < _width; x++) Set(x, _height / 2, Cell.Path);
                return;
            }

            Divide(0, 0, _width - 1, _height - 1);
            AddRandomPaths();
        }

        public bool[,] ToBoolGrid()
        {
            bool[,] result = new bool[_height, _width];
            for (int y = 0; y < _height; y++)
                for (int x = 0; x < _width; x++)
                    result[y, x] = (_cells[y, x] == Cell.Path);
            return result;
        }

        public bool IsConnected(int startX, int startY, int goalX, int goalY)
            => IsConnectedImpl(startX, startY, goalX, goalY);

        public static bool[,] GenerateWalkableMaze(int width, int height)
        {
            Maze maze = new Maze(width, height);
            maze.Generate();

            int startX = 1, startY = 1;
            int goalX = width - 2, goalY = height - 2;

            if (!maze.IsConnected(startX, startY, goalX, goalY))
            {
                for (int x = 0; x < width; x++)
                {
                    for (int y = 0; y < height; y++)
                    {
                        if (x < maze._width && y < maze._height)
                        {
                            if (x == 1 || y == 1 || x == width - 2 || y == height - 2)
                                maze.Set(x, y, Cell.Path);
                        }
                    }
                }
            }

            return maze.ToBoolGrid();
        }
    }

    private uint _result;
    private int _width;
    private int _height;
    private bool[,] _boolGrid;

    public MazeGenerator()
    {
        _width = (int)ConfigVal("w");
        _height = (int)ConfigVal("h");
    }

    private uint GridChecksum(bool[,] grid)
    {
        uint hasher = 2166136261;
        uint prime = 16777619;

        for (int i = 0; i < grid.GetLength(0); i++)
        {
            for (int j = 0; j < grid.GetLength(1); j++)
            {
                if (grid[i, j])
                {
                    uint jSquared = (uint)(j * j);
                    hasher = (hasher ^ jSquared) * prime;
                }
            }
        }
        return hasher;
    }

    public override void Run(long IterationId)
    {
        _boolGrid = Maze.GenerateWalkableMaze(_width, _height);
    }

    public override uint Checksum => GridChecksum(_boolGrid);
    public override string TypeName => "MazeGenerator";
}