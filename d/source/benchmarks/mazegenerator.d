module benchmarks.mazegenerator;

import benchmark;
import helper;
import std.stdio;
import std.algorithm;
import std.conv;
import std.array;
import std.range;
import std.random;
import std.typecons;

class MazeGenerator : Benchmark
{
private:
    enum Cell
    {
        Wall,
        Path
    }

    uint resultVal;
    int width_;
    int height_;
    bool[][] boolGrid;

public:

    static class Maze
    {
    private:
        int width_;
        int height_;
        Cell[][] cells_;

        void addRandomPaths()
        {
            int numExtraPaths = (width_ * height_) / 20;

            for (int i = 0; i < numExtraPaths; i++)
            {
                int x = Helper.nextInt(width_ - 2) + 1;
                int y = Helper.nextInt(height_ - 2) + 1;

                if (this.opIndex(x, y) == Cell.Wall && this.opIndex(x - 1,
                        y) == Cell.Wall && this.opIndex(x + 1, y) == Cell.Wall
                        && this.opIndex(x, y - 1) == Cell.Wall && this.opIndex(x, y + 1) == Cell
                            .Wall)
                {
                    this.opIndexAssign(x, y, Cell.Path);
                }
            }
        }

        void divide(int x1, int y1, int x2, int y2)
        {
            int width = x2 - x1;
            int height = y2 - y1;

            if (width < 2 || height < 2)
                return;

            int widthForWall = max(width - 2, 0);
            int heightForWall = max(height - 2, 0);
            int widthForHole = max(width - 1, 0);
            int heightForHole = max(height - 1, 0);

            if (widthForWall == 0 || heightForWall == 0 || widthForHole == 0 || heightForHole == 0)
                return;

            if (width > height)
            {
                int wallRange = max(widthForWall / 2, 1);
                int wallOffset = wallRange > 0 ? Helper.nextInt(wallRange) * 2 : 0;
                int wallX = x1 + 2 + wallOffset;

                int holeRange = max(heightForHole / 2, 1);
                int holeOffset = holeRange > 0 ? Helper.nextInt(holeRange) * 2 : 0;
                int holeY = y1 + 1 + holeOffset;

                if (wallX > x2 || holeY > y2)
                    return;

                for (int y = y1; y <= y2; y++)
                {
                    if (y != holeY)
                    {
                        this.opIndexAssign(wallX, y, Cell.Wall);
                    }
                }

                if (wallX > x1 + 1)
                    divide(x1, y1, wallX - 1, y2);
                if (wallX + 1 < x2)
                    divide(wallX + 1, y1, x2, y2);
            }
            else
            {
                int wallRange = max(heightForWall / 2, 1);
                int wallOffset = wallRange > 0 ? Helper.nextInt(wallRange) * 2 : 0;
                int wallY = y1 + 2 + wallOffset;

                int holeRange = max(widthForHole / 2, 1);
                int holeOffset = holeRange > 0 ? Helper.nextInt(holeRange) * 2 : 0;
                int holeX = x1 + 1 + holeOffset;

                if (wallY > y2 || holeX > x2)
                    return;

                for (int x = x1; x <= x2; x++)
                {
                    if (x != holeX)
                    {
                        this.opIndexAssign(x, wallY, Cell.Wall);
                    }
                }

                if (wallY > y1 + 1)
                    divide(x1, y1, x2, wallY - 1);
                if (wallY + 1 < y2)
                    divide(x1, wallY + 1, x2, y2);
            }
        }

        bool isConnectedImpl(Tuple!(int, int) start, Tuple!(int, int) goal) const
        {
            if (start[0] >= width_ || start[1] >= height_ || goal[0] >= width_ || goal[1] >= height_)
            {
                return false;
            }

            bool[][] visited = new bool[][](height_);
            foreach (i; 0 .. height_)
            {
                visited[i] = new bool[width_];
            }

            Tuple!(int, int)[] queue;

            visited[start[1]][start[0]] = true;
            queue ~= start;

            size_t front = 0;
            while (front < queue.length)
            {
                auto current = queue[front++];

                if (current == goal)
                    return true;

                int x = current[0];
                int y = current[1];

                if (y > 0 && this.opIndex(x, y - 1) == Cell.Path && !visited[y - 1][x])
                {
                    visited[y - 1][x] = true;
                    queue ~= tuple(x, y - 1);
                }

                if (x + 1 < width_ && this.opIndex(x + 1, y) == Cell.Path && !visited[y][x + 1])
                {
                    visited[y][x + 1] = true;
                    queue ~= tuple(x + 1, y);
                }

                if (y + 1 < height_ && this.opIndex(x, y + 1) == Cell.Path && !visited[y + 1][x])
                {
                    visited[y + 1][x] = true;
                    queue ~= tuple(x, y + 1);
                }

                if (x > 0 && this.opIndex(x - 1, y) == Cell.Path && !visited[y][x - 1])
                {
                    visited[y][x - 1] = true;
                    queue ~= tuple(x - 1, y);
                }
            }

            return false;
        }

    public:
        this(int width, int height)
        {
            width_ = width > 5 ? width : 5;
            height_ = height > 5 ? height : 5;

            cells_ = new Cell[][](height_);
            foreach (i; 0 .. height_)
            {
                cells_[i] = new Cell[width_];

                cells_[i][] = Cell.Wall;
            }
        }

        Cell opIndex(int x, int y) const
        {
            return cells_[y][x];
        }

        void opIndexAssign(int x, int y, Cell cell)
        {
            cells_[y][x] = cell;
        }

        void generate()
        {
            if (width_ < 5 || height_ < 5)
            {
                for (int x = 0; x < width_; x++)
                {
                    this.opIndexAssign(x, height_ / 2, Cell.Path);
                }
                return;
            }

            divide(0, 0, width_ - 1, height_ - 1);
            addRandomPaths();
        }

        bool[][] toBoolGrid() const
        {

            bool[][] result = new bool[][](height_);
            foreach (i; 0 .. height_)
            {
                result[i] = new bool[width_];
            }

            for (int y = 0; y < height_; y++)
            {
                for (int x = 0; x < width_; x++)
                {
                    result[y][x] = (cells_[y][x] == Cell.Path);
                }
            }

            return result;
        }

        bool isConnected(Tuple!(int, int) start, Tuple!(int, int) goal) const
        {
            return isConnectedImpl(start, goal);
        }

        static bool[][] generateWalkableMaze(int width, int height)
        {
            auto maze = new Maze(width, height);
            maze.generate();

            auto start = tuple(1, 1);
            auto goal = tuple(width - 2, height - 2);

            if (!maze.isConnected(start, goal))
            {
                for (int x = 0; x < width; x++)
                {
                    for (int y = 0; y < height; y++)
                    {
                        if (x < maze.width_ && y < maze.height_)
                        {
                            if (x == 1 || y == 1 || x == width - 2 || y == height - 2)
                            {
                                maze.opIndexAssign(x, y, Cell.Path);
                            }
                        }
                    }
                }
            }

            return maze.toBoolGrid();
        }

        int width() const
        {
            return width_;
        }

        int height() const
        {
            return height_;
        }
    }

    uint gridChecksum(const bool[][] grid) const
    {
        uint hasher = 2166136261UL;
        uint prime = 16777619UL;

        for (size_t i = 0; i < grid.length; i++)
        {
            const auto row = grid[i];
            for (size_t j = 0; j < row.length; j++)
            {
                if (row[j])
                {
                    uint jSquared = cast(uint)(j * j);
                    hasher = (hasher ^ jSquared) * prime;
                }
            }
        }
        return hasher;
    }

public:
    this()
    {
        resultVal = 0;
        width_ = configVal("w");
        height_ = configVal("h");
    }

    override string className() const
    {
        return "MazeGenerator";
    }

    override void run(int iterationId)
    {
        boolGrid = Maze.generateWalkableMaze(width_, height_);
    }

    override uint checksum()
    {
        return gridChecksum(boolGrid);
    }
}
