package benchmarks;

import java.util.*;

public class GameOfLife extends Benchmark {
    private enum Cell {
        DEAD, ALIVE
    }

    private static class Grid {
        private final int width;
        private final int height;
        private final Cell[] cells;           
        private final Cell[] buffer;          

        public Grid(int width, int height) {
            this.width = width;
            this.height = height;
            int size = width * height;
            this.cells = new Cell[size];
            this.buffer = new Cell[size];
            Arrays.fill(cells, Cell.DEAD);
            Arrays.fill(buffer, Cell.DEAD);
        }

        private Grid(int width, int height, Cell[] cells, Cell[] buffer) {
            this.width = width;
            this.height = height;
            this.cells = cells;
            this.buffer = buffer;
        }

        private int index(int x, int y) {
            return y * width + x;
        }

        public Cell get(int x, int y) {
            return cells[index(x, y)];
        }

        public void set(int x, int y, Cell cell) {
            cells[index(x, y)] = cell;
        }

        private int countNeighbors(int x, int y, Cell[] cells) {

            int yPrev = (y == 0) ? height - 1 : y - 1;
            int yNext = (y == height - 1) ? 0 : y + 1;
            int xPrev = (x == 0) ? width - 1 : x - 1;
            int xNext = (x == width - 1) ? 0 : x + 1;

            int count = 0;

            int idx = yPrev * width;
            if (cells[idx + xPrev] == Cell.ALIVE) count++;
            if (cells[idx + x] == Cell.ALIVE) count++;
            if (cells[idx + xNext] == Cell.ALIVE) count++;

            idx = y * width;
            if (cells[idx + xPrev] == Cell.ALIVE) count++;
            if (cells[idx + xNext] == Cell.ALIVE) count++;

            idx = yNext * width;
            if (cells[idx + xPrev] == Cell.ALIVE) count++;
            if (cells[idx + x] == Cell.ALIVE) count++;
            if (cells[idx + xNext] == Cell.ALIVE) count++;

            return count;
        }

        public Grid nextGeneration() {

            final int w = width;
            final int h = height;
            final Cell[] currentCells = cells;
            final Cell[] nextCells = buffer;

            for (int y = 0; y < h; y++) {
                final int yIdx = y * w;

                for (int x = 0; x < w; x++) {
                    final int idx = yIdx + x;

                    int neighbors = countNeighbors(x, y, currentCells);

                    Cell current = currentCells[idx];
                    Cell nextState = Cell.DEAD;

                    if (current == Cell.ALIVE) {
                        nextState = (neighbors == 2 || neighbors == 3) ? Cell.ALIVE : Cell.DEAD;
                    } else if (neighbors == 3) {
                        nextState = Cell.ALIVE;
                    }

                    nextCells[idx] = nextState;
                }
            }

            return new Grid(w, h, nextCells, currentCells);
        }

        public long computeHash() {
            final long FNV_OFFSET_BASIS = 2166136261L;
            final long FNV_PRIME = 16777619L;

            long hasher = FNV_OFFSET_BASIS;

            for (int i = 0; i < cells.length; i++) {
                long alive = (cells[i] == Cell.ALIVE) ? 1L : 0L;
                hasher = (hasher ^ alive) * FNV_PRIME;
            }

            return hasher;
        }
    }

    private long resultVal;
    private final int width;
    private final int height;
    private Grid grid;

    public GameOfLife() {
        this.width = (int) configVal("w");
        this.height = (int) configVal("h");
        this.grid = new Grid(width, height);
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "GameOfLife";
    }

    @Override
    public void prepare() {

        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                if (Helper.nextFloat() < 0.1f) {
                    grid.set(x, y, Cell.ALIVE);
                }
            }
        }
    }

    @Override
    public void run(int iterationId) {

        grid = grid.nextGeneration();
    }

    @Override
    public long checksum() {
        return grid.computeHash();
    }
}