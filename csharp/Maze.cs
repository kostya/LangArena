using System;
using System.Collections.Generic;

public class MazeGenerator : Benchmark
{
    public enum CellKind
    {
        Wall = 0,
        Space = 1,
        Start = 2,
        Finish = 3,
        Border = 4,
        Path = 5
    }

    public class Cell
    {
        public CellKind Kind;
        public List<Cell> Neighbors;
        public int X;
        public int Y;

        public Cell(int x, int y)
        {
            Kind = CellKind.Wall;
            X = x;
            Y = y;
            Neighbors = new List<Cell>(4);
        }

        public bool IsWalkable() =>
            Kind == CellKind.Space || Kind == CellKind.Start || Kind == CellKind.Finish;

        public void Reset()
        {
            if (Kind == CellKind.Space)
                Kind = CellKind.Wall;
        }
    }

    public class Maze
    {
        private readonly int _width;
        private readonly int _height;
        private readonly Cell[,] _cells;
        private readonly Cell _start;
        private readonly Cell _finish;
        private readonly Random _random = new Random();

        public Maze(int width, int height)
        {
            _width = Math.Max(width, 5);
            _height = Math.Max(height, 5);
            _cells = new Cell[_height, _width];

            for (int y = 0; y < _height; y++)
                for (int x = 0; x < _width; x++)
                    _cells[y, x] = new Cell(x, y);

            _start = _cells[1, 1];
            _finish = _cells[_height - 2, _width - 2];
            _start.Kind = CellKind.Start;
            _finish.Kind = CellKind.Finish;

            UpdateNeighbors();
        }

        public void UpdateNeighbors()
        {
            for (int y = 0; y < _height; y++)
            {
                for (int x = 0; x < _width; x++)
                {
                    var cell = _cells[y, x];
                    cell.Neighbors.Clear();

                    if (x > 0 && y > 0 && x < _width - 1 && y < _height - 1)
                    {
                        cell.Neighbors.Add(_cells[y - 1, x]);
                        cell.Neighbors.Add(_cells[y + 1, x]);
                        cell.Neighbors.Add(_cells[y, x + 1]);
                        cell.Neighbors.Add(_cells[y, x - 1]);

                        for (int t = 0; t < 4; t++)
                        {
                            int i = Helper.NextInt(4);
                            int j = Helper.NextInt(4);
                            if (i != j)
                            {
                                var temp = cell.Neighbors[i];
                                cell.Neighbors[i] = cell.Neighbors[j];
                                cell.Neighbors[j] = temp;
                            }
                        }
                    }
                    else
                    {
                        cell.Kind = CellKind.Border;
                    }
                }
            }
        }

        public void Reset()
        {
            foreach (var cell in _cells)
                cell.Reset();

            _start.Kind = CellKind.Start;
            _finish.Kind = CellKind.Finish;
        }

        private void Dig(Cell startCell)
        {
            var stack = new Stack<Cell>();
            stack.Push(startCell);

            while (stack.Count > 0)
            {
                var cell = stack.Pop();

                int walkable = 0;
                foreach (var n in cell.Neighbors)
                    if (n.IsWalkable()) walkable++;

                if (walkable != 1) continue;

                cell.Kind = CellKind.Space;

                foreach (var n in cell.Neighbors)
                    if (n.Kind == CellKind.Wall)
                        stack.Push(n);
            }
        }

        private void EnsureOpenFinish(Cell startCell)
        {
            var stack = new Stack<Cell>();
            stack.Push(startCell);

            while (stack.Count > 0)
            {
                var cell = stack.Pop();

                cell.Kind = CellKind.Space;

                int walkable = 0;
                foreach (var n in cell.Neighbors)
                    if (n.IsWalkable()) walkable++;

                if (walkable > 1) continue;

                foreach (var n in cell.Neighbors)
                    if (n.Kind == CellKind.Wall)
                        stack.Push(n);
            }
        }

        public void Generate()
        {
            foreach (var n in _start.Neighbors)
                if (n.Kind == CellKind.Wall)
                    Dig(n);

            foreach (var n in _finish.Neighbors)
                if (n.Kind == CellKind.Wall)
                    EnsureOpenFinish(n);
        }

        public Cell GetStart() => _start;
        public Cell GetFinish() => _finish;
        public Cell MiddleCell() => _cells[_height / 2, _width / 2];

        public uint Checksum()
        {
            uint hasher = 2166136261;
            uint prime = 16777619;

            for (int y = 0; y < _height; y++)
                for (int x = 0; x < _width; x++)
                    if (_cells[y, x].Kind == CellKind.Space)
                    {
                        uint val = (uint)(x * y);
                        hasher = (hasher ^ val) * prime;
                    }

            return hasher;
        }

        public void PrintToConsole()
        {
            for (int y = 0; y < _height; y++)
            {
                for (int x = 0; x < _width; x++)
                {
                    switch (_cells[y, x].Kind)
                    {
                        case CellKind.Space: Console.Write(" "); break;
                        case CellKind.Wall: Console.Write("\u001b[34m#\u001b[0m"); break;
                        case CellKind.Border: Console.Write("\u001b[31mO\u001b[0m"); break;
                        case CellKind.Start: Console.Write("\u001b[32m>\u001b[0m"); break;
                        case CellKind.Finish: Console.Write("\u001b[32m<\u001b[0m"); break;
                        case CellKind.Path: Console.Write("\u001b[33m.\u001b[0m"); break;
                    }
                }
                Console.WriteLine();
            }
            Console.WriteLine();
        }

        public Cell GetCell(int x, int y)
        {
            if (x >= 0 && x < _width && y >= 0 && y < _height)
                return _cells[y, x];
            return null;
        }
    }

    private uint _result;
    private readonly int _width;
    private readonly int _height;
    private readonly Maze _maze;

    public MazeGenerator()
    {
        _width = (int)ConfigVal("w");
        _height = (int)ConfigVal("h");
        _maze = new Maze(_width, _height);
        _result = 0;
    }

    public override void Prepare() { }

    public override void Run(long iterationId)
    {
        _maze.Reset();
        _maze.Generate();
        _result += (uint)_maze.MiddleCell().Kind;
    }

    public override uint Checksum => _result + _maze.Checksum();
    public override string TypeName => "Maze::Generator";
}

public class MazeBFS : Benchmark
{
    private uint _result;
    private readonly int _width;
    private readonly int _height;
    private readonly MazeGenerator.Maze _maze;
    private List<MazeGenerator.Cell> _path = new List<MazeGenerator.Cell>();

    public MazeBFS()
    {
        _width = (int)ConfigVal("w");
        _height = (int)ConfigVal("h");
        _maze = new MazeGenerator.Maze(_width, _height);
        _result = 0;
    }

    public override void Prepare()
    {
        _maze.Generate();
    }

    private List<MazeGenerator.Cell> Bfs(MazeGenerator.Cell start, MazeGenerator.Cell target)
    {
        if (start == target)
            return new List<MazeGenerator.Cell> { start };

        var queue = new Queue<int>();
        var visited = new bool[_height, _width];
        var path = new List<(MazeGenerator.Cell cell, int parent)>();

        visited[start.Y, start.X] = true;
        path.Add((start, -1));
        queue.Enqueue(0);

        while (queue.Count > 0)
        {
            int pathId = queue.Dequeue();
            var cell = path[pathId].cell;

            foreach (var neighbor in cell.Neighbors)
            {
                if (neighbor == target)
                {
                    var result = new List<MazeGenerator.Cell> { target };
                    int current = pathId;
                    while (current >= 0)
                    {
                        result.Add(path[current].cell);
                        current = path[current].parent;
                    }
                    result.Reverse();
                    return result;
                }

                if (neighbor.IsWalkable() && !visited[neighbor.Y, neighbor.X])
                {
                    visited[neighbor.Y, neighbor.X] = true;
                    path.Add((neighbor, pathId));
                    queue.Enqueue(path.Count - 1);
                }
            }
        }

        return new List<MazeGenerator.Cell>();
    }

    private uint MidCellChecksum(List<MazeGenerator.Cell> p)
    {
        if (p.Count == 0) return 0;
        var cell = p[p.Count / 2];
        return (uint)(cell.X * cell.Y);
    }

    public override void Run(long iterationId)
    {
        _path = Bfs(_maze.GetStart(), _maze.GetFinish());
        _result += (uint)_path.Count;
    }

    public override uint Checksum => _result + MidCellChecksum(_path);
    public override string TypeName => "Maze::BFS";
}

public class MazeAStar : Benchmark
{
    private uint _result;
    private readonly int _width;
    private readonly int _height;
    private readonly MazeGenerator.Maze _maze;
    private List<MazeGenerator.Cell> _path = new List<MazeGenerator.Cell>();

    public MazeAStar()
    {
        _width = (int)ConfigVal("w");
        _height = (int)ConfigVal("h");
        _maze = new MazeGenerator.Maze(_width, _height);
        _result = 0;
    }

    public override void Prepare()
    {
        _maze.Generate();
    }

    private int Heuristic(MazeGenerator.Cell a, MazeGenerator.Cell b) =>
        Math.Abs(a.X - b.X) + Math.Abs(a.Y - b.Y);

    private int Idx(int y, int x) => y * _width + x;

    private List<MazeGenerator.Cell> AStar(MazeGenerator.Cell start, MazeGenerator.Cell target)
    {
        if (start == target)
            return new List<MazeGenerator.Cell> { start };

        int size = _width * _height;

        var cameFrom = new int[size];
        var gScore = new int[size];
        var bestF = new int[size];

        for (int i = 0; i < size; i++)
        {
            cameFrom[i] = -1;
            gScore[i] = int.MaxValue;
            bestF[i] = int.MaxValue;
        }

        int startIdx = Idx(start.Y, start.X);
        int targetIdx = Idx(target.Y, target.X);

        var openSet = new PriorityQueue<int, int>();

        gScore[startIdx] = 0;
        int fStart = Heuristic(start, target);
        openSet.Enqueue(startIdx, fStart);
        bestF[startIdx] = fStart;

        while (openSet.Count > 0)
        {
            int currentIdx = openSet.Dequeue();

            if (gScore[currentIdx] == int.MaxValue) continue;

            if (currentIdx == targetIdx)
            {
                var result = new List<MazeGenerator.Cell>();
                int cur = currentIdx;
                while (cur != -1)
                {
                    int y = cur / _width;
                    int x = cur % _width;
                    result.Add(_maze.GetCell(x, y));
                    cur = cameFrom[cur];
                }
                result.Reverse();
                return result;
            }

            int currentY = currentIdx / _width;
            int currentX = currentIdx % _width;
            var current = _maze.GetCell(currentX, currentY);
            int currentG = gScore[currentIdx];

            foreach (var neighbor in current.Neighbors)
            {
                if (!neighbor.IsWalkable()) continue;

                int neighborIdx = Idx(neighbor.Y, neighbor.X);
                int tentativeG = currentG + 1;

                if (tentativeG < gScore[neighborIdx])
                {
                    cameFrom[neighborIdx] = currentIdx;
                    gScore[neighborIdx] = tentativeG;
                    int fNew = tentativeG + Heuristic(neighbor, target);

                    if (fNew < bestF[neighborIdx])
                    {
                        bestF[neighborIdx] = fNew;
                        openSet.Enqueue(neighborIdx, fNew);
                    }
                }
            }
        }

        return new List<MazeGenerator.Cell>();
    }

    private uint MidCellChecksum(List<MazeGenerator.Cell> p)
    {
        if (p.Count == 0) return 0;
        var cell = p[p.Count / 2];
        return (uint)(cell.X * cell.Y);
    }

    public override void Run(long iterationId)
    {
        _path = AStar(_maze.GetStart(), _maze.GetFinish());
        _result += (uint)_path.Count;
    }

    public override uint Checksum => _result + MidCellChecksum(_path);
    public override string TypeName => "Maze::AStar";
}