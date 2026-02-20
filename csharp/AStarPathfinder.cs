using System;
using System.Collections.Generic;

public class AStarPathfinder : Benchmark
{
    private class Node : IComparable<Node>
    {
        public int X { get; }
        public int Y { get; }
        public int FScore { get; }

        public Node(int x, int y, int fScore)
        {
            X = x;
            Y = y;
            FScore = fScore;
        }

        public int CompareTo(Node? other)
        {
            if (other == null) return 1;

            if (FScore != other.FScore) return FScore.CompareTo(other.FScore);
            if (Y != other.Y) return Y.CompareTo(other.Y);
            return X.CompareTo(other.X);
        }
    }

    private class BinaryHeap
    {
        private readonly List<Node> _data;

        public BinaryHeap(int initialCapacity = 64)
        {
            _data = new List<Node>(initialCapacity);
        }

        public void Push(Node item)
        {
            _data.Add(item);
            SiftUp(_data.Count - 1);
        }

        public Node? Pop()
        {
            if (_data.Count == 0) return null;

            if (_data.Count == 1)
            {
                Node result = _data[0];
                _data.RemoveAt(0);
                return result;
            }

            Node resultNode = _data[0];
            _data[0] = _data[_data.Count - 1];
            _data.RemoveAt(_data.Count - 1);
            SiftDown(0);
            return resultNode;
        }

        public bool IsEmpty() => _data.Count == 0;

        private void SiftUp(int index)
        {
            while (index > 0)
            {
                int parent = (index - 1) >> 1;
                if (_data[index].CompareTo(_data[parent]) >= 0) break;
                Swap(index, parent);
                index = parent;
            }
        }

        private void SiftDown(int index)
        {
            int size = _data.Count;
            while (true)
            {
                int left = (index << 1) + 1;
                int right = left + 1;
                int smallest = index;

                if (left < size && _data[left].CompareTo(_data[smallest]) < 0)
                    smallest = left;
                if (right < size && _data[right].CompareTo(_data[smallest]) < 0)
                    smallest = right;

                if (smallest == index) break;

                Swap(index, smallest);
                index = smallest;
            }
        }

        private void Swap(int i, int j)
        {
            Node temp = _data[i];
            _data[i] = _data[j];
            _data[j] = temp;
        }
    }

    private uint _result;
    private int _startX;
    private int _startY;
    private int _goalX;
    private int _goalY;
    private int _width;
    private int _height;
    private bool[,] _mazeGrid;

    private int[] _gScoresCache;
    private int[] _cameFromCache;

    private static readonly (int dx, int dy)[] _directions = new[]
    {
        (0, -1), (1, 0), (0, 1), (-1, 0)
    };

    private const int STRAIGHT_COST = 1000;

    public AStarPathfinder()
    {
        _width = (int)ConfigVal("w");
        _height = (int)ConfigVal("h");
        _startX = 1;
        _startY = 1;
        _goalX = _width - 2;
        _goalY = _height - 2;

        int size = _width * _height;
        _gScoresCache = new int[size];
        _cameFromCache = new int[size];
    }

    private bool[,] GenerateWalkableMaze(int width, int height)
    {
        return MazeGenerator.Maze.GenerateWalkableMaze(width, height);
    }

    private int Distance(int aX, int aY, int bX, int bY)
    {
        return Math.Abs(aX - bX) + Math.Abs(aY - bY);
    }

    private int PackCoords(int x, int y) => y * _width + x;

    private (int x, int y) UnpackCoords(int packed) => (packed % _width, packed / _width);

    private (List<(int x, int y)>? path, int nodesExplored) FindPath()
    {
        bool[,] grid = _mazeGrid;
        int width = _width;
        int height = _height;

        int[] gScores = _gScoresCache;
        int[] cameFrom = _cameFromCache;

        Array.Fill(gScores, int.MaxValue);
        Array.Fill(cameFrom, -1);

        BinaryHeap openSet = new BinaryHeap(width * height);
        int nodesExplored = 0;

        int startIdx = PackCoords(_startX, _startY);
        gScores[startIdx] = 0;
        openSet.Push(new Node(_startX, _startY, Distance(_startX, _startY, _goalX, _goalY)));

        while (!openSet.IsEmpty())
        {
            Node? current = openSet.Pop();
            if (current == null) break;

            nodesExplored++;

            if (current.X == _goalX && current.Y == _goalY)
            {
                List<(int x, int y)> path = new List<(int, int)>();
                int x = current.X;
                int y = current.Y;

                while (x != _startX || y != _startY)
                {
                    path.Add((x, y));
                    int idx = PackCoords(x, y);
                    int packed = cameFrom[idx];
                    if (packed == -1) break;

                    var (prevX, prevY) = UnpackCoords(packed);
                    x = prevX;
                    y = prevY;
                }

                path.Add((_startX, _startY));
                path.Reverse();
                return (path, nodesExplored);
            }

            int currentIdx = PackCoords(current.X, current.Y);
            int currentG = gScores[currentIdx];

            foreach (var (dx, dy) in _directions)
            {
                int nx = current.X + dx;
                int ny = current.Y + dy;

                if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
                if (!grid[ny, nx]) continue;

                int tentativeG = currentG + STRAIGHT_COST;
                int neighborIdx = PackCoords(nx, ny);

                if (tentativeG < gScores[neighborIdx])
                {

                    cameFrom[neighborIdx] = currentIdx;
                    gScores[neighborIdx] = tentativeG;

                    int fScore = tentativeG + Distance(nx, ny, _goalX, _goalY);
                    openSet.Push(new Node(nx, ny, fScore));
                }
            }
        }

        return (null, nodesExplored);
    }

    public override void Prepare()
    {
        _mazeGrid = GenerateWalkableMaze(_width, _height);
    }

    public override void Run(long IterationId)
    {
        var (path, nodesExplored) = FindPath();

        uint localResult = 0;

        localResult = (uint)(path?.Count ?? 0);

        localResult = (localResult << 5) + (uint)nodesExplored;

        _result = (uint)((long)_result + localResult);
    }

    public override uint Checksum => _result;
}