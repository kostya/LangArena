package benchmarks;

import java.util.*;

public class AStarPathfinder extends Benchmark {
    private interface Heuristic {
        int distance(int aX, int aY, int bX, int bY);
    }
    
    private static class ManhattanHeuristic implements Heuristic {
        @Override
        public int distance(int aX, int aY, int bX, int bY) {
            return (Math.abs(aX - bX) + Math.abs(aY - bY)) * 1000;
        }
    }
    
    private static class EuclideanHeuristic implements Heuristic {
        @Override
        public int distance(int aX, int aY, int bX, int bY) {
            double dx = Math.abs(aX - bX);
            double dy = Math.abs(aY - bY);
            return (int)(Math.sqrt(dx * dx + dy * dy) * 1000.0); // Используем sqrt вместо hypot
        }
    }
    
    private static class ChebyshevHeuristic implements Heuristic {
        @Override
        public int distance(int aX, int aY, int bX, int bY) {
            return Math.max(Math.abs(aX - bX), Math.abs(aY - bY)) * 1000;
        }
    }
    
    private static class Node implements Comparable<Node> {
        int x;
        int y;
        int fScore;
        
        Node(int x, int y, int fScore) {
            this.x = x;
            this.y = y;
            this.fScore = fScore;
        }
        
        @Override
        public int compareTo(Node other) {
            if (fScore != other.fScore) {
                return Integer.compare(fScore, other.fScore);
            }
            if (y != other.y) {
                return Integer.compare(y, other.y);
            }
            return Integer.compare(x, other.x);
        }
    }
    
    private static class Point {
        int x, y;
        Point(int x, int y) { this.x = x; this.y = y; }
    }
    
    private static class BinaryHeap {
        private final List<Node> data;
        
        BinaryHeap() {
            data = new ArrayList<>();
        }
        
        void push(Node item) {
            data.add(item);
            siftUp(data.size() - 1);
        }
        
        Node pop() {
            if (data.isEmpty()) {
                return null;
            }
            
            if (data.size() == 1) {
                return data.remove(0);
            }
            
            Node result = data.get(0);
            data.set(0, data.get(data.size() - 1));
            data.remove(data.size() - 1);
            siftDown(0);
            return result;
        }
        
        boolean isEmpty() {
            return data.isEmpty();
        }
        
        private void siftUp(int index) {
            while (index > 0) {
                int parent = (index - 1) / 2;
                if (data.get(index).compareTo(data.get(parent)) >= 0) break;
                Collections.swap(data, index, parent);
                index = parent;
            }
        }
        
        private void siftDown(int index) {
            int size = data.size();
            while (true) {
                int left = index * 2 + 1;
                int right = left + 1;
                int smallest = index;
                
                if (left < size && data.get(left).compareTo(data.get(smallest)) < 0) {
                    smallest = left;
                }
                
                if (right < size && data.get(right).compareTo(data.get(smallest)) < 0) {
                    smallest = right;
                }
                
                if (smallest == index) break;
                
                Collections.swap(data, index, smallest);
                index = smallest;
            }
        }
    }
    
    // Константы для направлений
    private static final int[][] CARDINAL_DIRECTIONS = {
        {0, -1}, {1, 0}, {0, 1}, {-1, 0}
    };
    
    private static final int[][] ALL_DIRECTIONS = {
        {0, -1}, {1, 0}, {0, 1}, {-1, 0},
        {-1, -1}, {1, -1}, {1, 1}, {-1, 1}
    };
    
    private static final int DIAGONAL_COST = 1414;
    private static final int STRAIGHT_COST = 1000;
    
    private long resultVal;
    private final int startX;
    private final int startY;
    private final int goalX;
    private final int goalY;
    private final int width;
    private final int height;
    private boolean[][] mazeGrid;
    
    public AStarPathfinder() {
        this.width = getIterations();
        this.height = getIterations();
        this.startX = 1;
        this.startY = 1;
        this.goalX = width - 2;
        this.goalY = height - 2;
    }
    
    private boolean[][] generateWalkableMaze(int width, int height) {
        return MazeGenerator.Maze.generateWalkableMaze(width, height);
    }
    
    private boolean[][] ensureMazeGrid() {
        if (mazeGrid == null) {
            mazeGrid = generateWalkableMaze(width, height);
        }
        return mazeGrid;
    }
    
    private List<Point> findPath(Heuristic heuristic, boolean allowDiagonal) {
        boolean[][] grid = ensureMazeGrid();
        
        int[][] gScores = new int[height][width];
        Point[][] cameFrom = new Point[height][width]; // Используем Point вместо int[][][]
        
        // Оптимизированная инициализация gScores
        if (height > 0 && width > 0) {
            int[] firstRow = gScores[0];
            Arrays.fill(firstRow, Integer.MAX_VALUE);
            for (int y = 1; y < height; y++) {
                System.arraycopy(firstRow, 0, gScores[y], 0, width);
            }
        }
        
        BinaryHeap openSet = new BinaryHeap();
        
        gScores[startY][startX] = 0;
        openSet.push(new Node(startX, startY, 
                             heuristic.distance(startX, startY, goalX, goalY)));
        
        int[][] directions = allowDiagonal ? ALL_DIRECTIONS : CARDINAL_DIRECTIONS;
        int diagonalCost = allowDiagonal ? DIAGONAL_COST : STRAIGHT_COST;
        
        while (!openSet.isEmpty()) {
            Node current = openSet.pop();
            
            if (current.x == goalX && current.y == goalY) {
                List<Point> path = new ArrayList<>();
                int x = current.x;
                int y = current.y;
                
                while (x != startX || y != startY) {
                    path.add(new Point(x, y));
                    Point prev = cameFrom[y][x];
                    x = prev.x;
                    y = prev.y;
                }
                
                path.add(new Point(startX, startY));
                Collections.reverse(path);
                return path;
            }
            
            int currentG = gScores[current.y][current.x];
            
            for (int[] dir : directions) {
                int nx = current.x + dir[0];
                int ny = current.y + dir[1];
                
                if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
                if (!grid[ny][nx]) continue;
                
                int moveCost = (Math.abs(dir[0]) == 1 && Math.abs(dir[1]) == 1) ? diagonalCost : STRAIGHT_COST;
                int tentativeG = currentG + moveCost;
                
                if (tentativeG < gScores[ny][nx]) {
                    cameFrom[ny][nx] = new Point(current.x, current.y); // Создаем Point один раз
                    gScores[ny][nx] = tentativeG;
                    
                    int fScore = tentativeG + heuristic.distance(nx, ny, goalX, goalY);
                    openSet.push(new Node(nx, ny, fScore));
                }
            }
        }
        
        return null;
    }
    
    private int estimateNodesExplored(Heuristic heuristic, boolean allowDiagonal) {
        boolean[][] grid = ensureMazeGrid();
        
        int[][] gScores = new int[height][width];
        // Оптимизированная инициализация
        if (height > 0 && width > 0) {
            int[] firstRow = gScores[0];
            Arrays.fill(firstRow, Integer.MAX_VALUE);
            for (int y = 1; y < height; y++) {
                System.arraycopy(firstRow, 0, gScores[y], 0, width);
            }
        }
        
        BinaryHeap openSet = new BinaryHeap();
        boolean[][] closed = new boolean[height][width];
        
        gScores[startY][startX] = 0;
        openSet.push(new Node(startX, startY, 
                             heuristic.distance(startX, startY, goalX, goalY)));
        
        int[][] directions = allowDiagonal ? ALL_DIRECTIONS : CARDINAL_DIRECTIONS;
        
        int nodesExplored = 0;
        
        while (!openSet.isEmpty()) {
            Node current = openSet.pop();
            
            if (current.x == goalX && current.y == goalY) {
                break;
            }
            
            if (closed[current.y][current.x]) continue;
            
            closed[current.y][current.x] = true;
            nodesExplored++;
            
            int currentG = gScores[current.y][current.x];
            
            for (int[] dir : directions) {
                int nx = current.x + dir[0];
                int ny = current.y + dir[1];
                
                if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
                if (!grid[ny][nx]) continue;
                
                int moveCost = (Math.abs(dir[0]) == 1 && Math.abs(dir[1]) == 1) ? DIAGONAL_COST : STRAIGHT_COST;
                int tentativeG = currentG + moveCost;
                
                if (tentativeG < gScores[ny][nx]) {
                    gScores[ny][nx] = tentativeG;
                    
                    int fScore = tentativeG + heuristic.distance(nx, ny, goalX, goalY);
                    openSet.push(new Node(nx, ny, fScore));
                }
            }
        }
        
        return nodesExplored;
    }
    
    private int[] benchmarkDifferentApproaches() {
        Heuristic[] heuristics = {
            new ManhattanHeuristic(),
            new EuclideanHeuristic(),
            new ChebyshevHeuristic()
        };
        
        int totalPathsFound = 0;
        int totalPathLength = 0;
        int totalNodesExplored = 0;
        
        for (Heuristic heuristic : heuristics) {
            List<Point> path = findPath(heuristic, false);
            if (path != null) {
                totalPathsFound++;
                totalPathLength += path.size();
                totalNodesExplored += estimateNodesExplored(heuristic, false);
            }
        }
        
        return new int[]{totalPathsFound, totalPathLength, totalNodesExplored};
    }
    
    @Override
    public void prepare() {
        ensureMazeGrid();
    }
    
    @Override
    public void run() {
        int totalPathsFound = 0;
        int totalPathLength = 0;
        int totalNodesExplored = 0;
        
        int iters = 10;
        for (int i = 0; i < iters; i++) {
            int[] results = benchmarkDifferentApproaches();
            
            totalPathsFound += results[0];
            totalPathLength += results[1];
            totalNodesExplored += results[2];
        }
        
        long pathsChecksum = Helper.checksumF64((double) totalPathsFound);
        long lengthChecksum = Helper.checksumF64((double) totalPathLength);
        long nodesChecksum = Helper.checksumF64((double) totalNodesExplored);
        
        resultVal = (pathsChecksum) ^
                   ((lengthChecksum) << 16) ^
                   ((nodesChecksum) << 32);
    }
    
    @Override
    public long getResult() {
        return resultVal;
    }
}