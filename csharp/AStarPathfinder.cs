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
        private readonly List<Node> _data = new List<Node>();
        
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
                int parent = (index - 1) / 2;
                if (_data[index].CompareTo(_data[parent]) >= 0) break;
                (_data[index], _data[parent]) = (_data[parent], _data[index]);
                index = parent;
            }
        }
        
        private void SiftDown(int index)
        {
            int size = _data.Count;
            while (true)
            {
                int left = index * 2 + 1;
                int right = left + 1;
                int smallest = index;
                
                if (left < size && _data[left].CompareTo(_data[smallest]) < 0) smallest = left;
                if (right < size && _data[right].CompareTo(_data[smallest]) < 0) smallest = right;
                
                if (smallest == index) break;
                
                (_data[index], _data[smallest]) = (_data[smallest], _data[index]);
                index = smallest;
            }
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
    
    public AStarPathfinder()
    {
        _width = (int)ConfigVal("w");
        _height = (int)ConfigVal("h");
        _startX = 1;
        _startY = 1;
        _goalX = _width - 2;
        _goalY = _height - 2;
    }
    
    private bool[,] GenerateWalkableMaze(int width, int height)
    {
        return MazeGenerator.Maze.GenerateWalkableMaze(width, height);
    }
    
    private int Distance(int aX, int aY, int bX, int bY)
    {
        return (Math.Abs(aX - bX) + Math.Abs(aY - bY));
    }
    
    private (List<(int x, int y)>? path, int nodesExplored) FindPath()
    {
        bool[,] grid = _mazeGrid;
        
        int[,] gScores = new int[_height, _width];
        (int x, int y)[,] cameFrom = new (int, int)[_height, _width];
        
        for (int y = 0; y < _height; y++)
        {
            for (int x = 0; x < _width; x++)
            {
                gScores[y, x] = int.MaxValue;
                cameFrom[y, x] = (-1, -1);
            }
        }
        
        BinaryHeap openSet = new BinaryHeap();
        int nodesExplored = 0;
        
        gScores[_startY, _startX] = 0;
        openSet.Push(new Node(_startX, _startY, Distance(_startX, _startY, _goalX, _goalY)));
        
        List<(int dx, int dy)> directions = new() { (0, -1), (1, 0), (0, 1), (-1, 0) };
        
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
                    var (prevX, prevY) = cameFrom[y, x];
                    x = prevX;
                    y = prevY;
                }
                
                path.Add((_startX, _startY));
                path.Reverse();
                return (path, nodesExplored);
            }
            
            int currentG = gScores[current.Y, current.X];
            
            foreach (var (dx, dy) in directions)
            {
                int nx = current.X + dx;
                int ny = current.Y + dy;
                
                if (nx < 0 || nx >= _width || ny < 0 || ny >= _height) continue;
                if (!grid[ny, nx]) continue;
                
                int tentativeG = currentG + 1000;
                
                if (tentativeG < gScores[ny, nx])
                {
                    cameFrom[ny, nx] = (current.X, current.Y);
                    gScores[ny, nx] = tentativeG;
                    
                    int fScore = tentativeG + Distance(nx, ny, _goalX, _goalY);
                    openSet.Push(new Node(nx, ny, fScore));
                }
            }
        }
        
        return (null, nodesExplored);
    }
    
    public override void Prepare() => _mazeGrid = GenerateWalkableMaze(_width, _height);
    
    public override void Run(long IterationId)
    {
        var (path, nodesExplored) = FindPath();
        
        long localResult = 0;
        localResult = (localResult << 5) + (path?.Count ?? 0);
        localResult = (localResult << 5) + nodesExplored;
        _result += (uint)localResult;
    }
    
    public override uint Checksum => _result;
}