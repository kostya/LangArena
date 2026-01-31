package benchmarks;

import java.util.*;

public class AStarPathfinder extends Benchmark {
    private static class Node implements Comparable<Node> {
        final int x;
        final int y;
        final int fScore;
        
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
    
    // Константы для направлений
    private static final int[][] DIRECTIONS = {
        {0, -1}, {1, 0}, {0, 1}, {-1, 0}
    };
    
    private static final int STRAIGHT_COST = 1000;
    private static final int MAX_INT = Integer.MAX_VALUE;
    
    private long resultVal;
    private final int startX;
    private final int startY;
    private final int goalX;
    private final int goalY;
    private final int width;
    private final int height;
    private boolean[][] mazeGrid;
    
    // Кэшированные массивы (выделяются один раз)
    private int[][] gScoresCache;
    private int[][] cameFromCache; // Упакованные координаты: y * width + x
    
    public AStarPathfinder() {
        this.width = (int) configVal("w");
        this.height = (int) configVal("h");
        this.startX = 1;
        this.startY = 1;
        this.goalX = width - 2;
        this.goalY = height - 2;
        this.resultVal = 0L;
    }
    
    @Override
    public String name() {
        return "AStarPathfinder";
    }
    
    private int distance(int aX, int aY, int bX, int bY) {
        int dx = aX > bX ? aX - bX : bX - aX;
        int dy = aY > bY ? aY - bY : bY - aY;
        return dx + dy;
    }
    
    // Упаковка координат
    private int packCoords(int x, int y) {
        return y * width + x;
    }
    
    // Распаковка координат
    private int[] unpackCoords(int packed) {
        return new int[]{packed % width, packed / width};
    }
    
    // Инициализация кэшированных массивов
    private void initCachedArrays() {
        if (gScoresCache == null || gScoresCache.length != height) {
            gScoresCache = new int[height][width];
            cameFromCache = new int[height][width];
        }
    }
    
    private Result findPathOptimized() {
        boolean[][] grid = mazeGrid;
        
        // Используем кэшированные массивы
        int[][] gScores = gScoresCache;
        int[][] cameFrom = cameFromCache;
        
        // Быстрая инициализация массивов
        for (int y = 0; y < height; y++) {
            Arrays.fill(gScores[y], MAX_INT);
            Arrays.fill(cameFrom[y], -1);
        }
        
        // Используем PriorityQueue из стандартной библиотеки
        PriorityQueue<Node> openSet = new PriorityQueue<>(width * height);
        int nodesExplored = 0;
        
        gScores[startY][startX] = 0;
        openSet.offer(new Node(startX, startY, 
                             distance(startX, startY, goalX, goalY)));
        
        while (!openSet.isEmpty()) {
            Node current = openSet.poll();
            nodesExplored++;
            
            if (current.x == goalX && current.y == goalY) {
                List<int[]> path = new ArrayList<>(width * height);
                int x = current.x;
                int y = current.y;
                
                while (x != startX || y != startY) {
                    path.add(new int[]{x, y});
                    int packed = cameFrom[y][x];
                    if (packed == -1) break;
                    
                    int[] coords = unpackCoords(packed);
                    x = coords[0];
                    y = coords[1];
                }
                
                path.add(new int[]{startX, startY});
                Collections.reverse(path);
                return new Result(path, nodesExplored);
            }
            
            int currentG = gScores[current.y][current.x];
            
            for (int[] dir : DIRECTIONS) {
                int nx = current.x + dir[0];
                int ny = current.y + dir[1];
                
                if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
                if (!grid[ny][nx]) continue;
                
                int tentativeG = currentG + STRAIGHT_COST;
                
                if (tentativeG < gScores[ny][nx]) {
                    // Упаковываем координаты
                    cameFrom[ny][nx] = packCoords(current.x, current.y);
                    gScores[ny][nx] = tentativeG;
                    
                    int fScore = tentativeG + distance(nx, ny, goalX, goalY);
                    openSet.offer(new Node(nx, ny, fScore));
                }
            }
        }
        
        return new Result(null, nodesExplored);
    }
    
    private static class Result {
        final List<int[]> path;
        final int nodesExplored;
        
        Result(List<int[]> path, int nodesExplored) {
            this.path = path;
            this.nodesExplored = nodesExplored;
        }
    }
    
    @Override
    public void prepare() {
        mazeGrid = MazeGenerator.Maze.generateWalkableMaze(width, height);
        initCachedArrays();
    }
    
    @Override
    public void run(int iterationId) {
        Result result = findPathOptimized();
        
        long localResult = 0;
        localResult = (localResult << 5) + (result.path != null ? result.path.size() : 0);
        localResult = (localResult << 5) + result.nodesExplored;
        resultVal += localResult;
    }
    
    @Override
    public long checksum() {
        return resultVal;
    }
}