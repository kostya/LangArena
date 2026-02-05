module benchmarks.gameoflife;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.random;
import std.range;
import benchmark;
import helper;

class GameOfLife : Benchmark {
private:

    enum Cell : ubyte {
        Dead = 0,
        Alive = 1
    }

    class Grid {
    private:
        int width;
        int height;
        Cell[] cells;      
        Cell[] buffer;     

        int countNeighbors(int x, int y, ref Cell[] cellsRef) const {

            int yPrev = (y == 0) ? height - 1 : y - 1;
            int yNext = (y == height - 1) ? 0 : y + 1;
            int xPrev = (x == 0) ? width - 1 : x - 1;
            int xNext = (x == width - 1) ? 0 : x + 1;

            int count = 0;
            count += cast(int)(cellsRef[yPrev * width + xPrev] == Cell.Alive);
            count += cast(int)(cellsRef[yPrev * width + x] == Cell.Alive);
            count += cast(int)(cellsRef[yPrev * width + xNext] == Cell.Alive);
            count += cast(int)(cellsRef[y * width + xPrev] == Cell.Alive);
            count += cast(int)(cellsRef[y * width + xNext] == Cell.Alive);
            count += cast(int)(cellsRef[yNext * width + xPrev] == Cell.Alive);
            count += cast(int)(cellsRef[yNext * width + x] == Cell.Alive);
            count += cast(int)(cellsRef[yNext * width + xNext] == Cell.Alive);

            return count;
        }

    public:
        this(int w, int h) {
            width = w;
            height = h;
            int size = width * height;
            cells.length = size;
            buffer.length = size;
            cells[] = Cell.Dead;
            buffer[] = Cell.Dead;
        }

        Cell get(int x, int y) const {
            return cells[y * width + x];
        }

        void set(int x, int y, Cell cell) {
            cells[y * width + x] = cell;
        }

        void nextGeneration() {
            const int w = width;
            const int h = height;
            const int size = w * h;

            Cell[] cellsRef = cells;
            Cell[] bufferRef = buffer;

            for (int y = 0; y < h; ++y) {
                const int yIdx = y * w;

                for (int x = 0; x < w; ++x) {
                    const int idx = yIdx + x;

                    int neighbors = countNeighbors(x, y, cellsRef);

                    Cell current = cellsRef[idx];
                    Cell nextState = Cell.Dead;

                    if (current == Cell.Alive) {
                        nextState = (neighbors == 2 || neighbors == 3) ? Cell.Alive : Cell.Dead;
                    } else {
                        nextState = (neighbors == 3) ? Cell.Alive : Cell.Dead;
                    }

                    bufferRef[idx] = nextState;
                }
            }

            swap(cells, buffer);
        }

        uint computeHash() const {
            enum FNV_OFFSET_BASIS = 2166136261u;
            enum FNV_PRIME = 16777619u;

            uint hash = FNV_OFFSET_BASIS;

            foreach (cell; cells) {
                uint alive = cast(uint)(cell == Cell.Alive);
                hash = cast(uint)((hash ^ alive) * FNV_PRIME);
            }

            return hash;
        }

        int getWidth() const { return width; }
        int getHeight() const { return height; }
    }

    uint resultVal;
    int width;
    int height;
    Grid grid;

protected:
    override string className() const { return "GameOfLife"; }

public:
    this() {
        resultVal = 0;
        width = configVal("w");
        height = configVal("h");
        grid = new Grid(width, height);
    }

    override void prepare() {

        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                if (Helper.nextFloat(1.0) < 0.1) {
                    grid.set(x, y, Cell.Alive);
                }
            }
        }
    }

    override void run(int iterationId) {

        grid.nextGeneration();
    }

    override uint checksum() {
        return grid.computeHash();
    }
}