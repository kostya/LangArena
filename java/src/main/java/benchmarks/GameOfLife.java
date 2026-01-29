package benchmarks;

import java.util.*;

public class GameOfLife extends Benchmark {
    private enum Cell {
        DEAD, ALIVE
    }
    
    private static class Grid {
        private final int width;
        private final int height;
        private final Cell[][] cells;
        
        public Grid(int width, int height) {
            this.width = width;
            this.height = height;
            this.cells = new Cell[height][width];
            for (int y = 0; y < height; y++) {
                Arrays.fill(cells[y], Cell.DEAD);
            }
        }
        
        public Cell get(int x, int y) {
            return cells[y][x];
        }
        
        public void set(int x, int y, Cell cell) {
            cells[y][x] = cell;
        }
        
        public int countNeighbors(int x, int y) {
            int count = 0;
            
            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    if (dx == 0 && dy == 0) continue;
                    
                    // Тороидальные координаты
                    int nx = (x + dx) % width;
                    int ny = (y + dy) % height;
                    if (nx < 0) nx += width;
                    if (ny < 0) ny += height;
                    
                    if (cells[ny][nx] == Cell.ALIVE) {
                        count++;
                    }
                }
            }
            
            return count;
        }
        
        public Grid nextGeneration() {
            Grid nextGrid = new Grid(width, height);
            
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    int neighbors = countNeighbors(x, y);
                    Cell current = cells[y][x];
                    
                    Cell nextState = Cell.DEAD;
                    if (current == Cell.ALIVE) {
                        if (neighbors == 2 || neighbors == 3) {
                            nextState = Cell.ALIVE;
                        }
                    } else {
                        if (neighbors == 3) {
                            nextState = Cell.ALIVE;
                        }
                    }
                    
                    nextGrid.cells[y][x] = nextState;
                }
            }
            
            return nextGrid;
        }
        
        public long computeHash() {
            final long FNV_OFFSET_BASIS = 2166136261L;
            final long FNV_PRIME = 16777619L;
            
            long hasher = FNV_OFFSET_BASIS;
            for (Cell[] row : cells) {
                for (Cell cell : row) {
                    long alive = (cell == Cell.ALIVE) ? 1L : 0L;
                    hasher = (hasher ^ alive) * FNV_PRIME;
                }
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
        // Инициализация случайными клетками
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
        // Только одна итерация
        grid = grid.nextGeneration();
    }
    
    @Override
    public long checksum() {
        return grid.computeHash();
    }
}