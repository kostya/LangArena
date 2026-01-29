package benchmarks;

import java.util.*;

public class AStarPathfinder extends Benchmark {
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
        return (Math.abs(aX - bX) + Math.abs(aY - bY));
    }
    
    private Pair<Optional<List<Point>>, Integer> findPath() {
        boolean[][] grid = mazeGrid;
        
        int[][] gScores = new int[height][width];
        Point[][] cameFrom = new Point[height][width];
        
        // Оптимизированная инициализация gScores
        if (height > 0 && width > 0) {
            int[] firstRow = gScores[0];
            Arrays.fill(firstRow, Integer.MAX_VALUE);
            for (int y = 1; y < height; y++) {
                System.arraycopy(firstRow, 0, gScores[y], 0, width);
            }
        }
        
        BinaryHeap openSet = new BinaryHeap();
        int nodesExplored = 0;
        
        gScores[startY][startX] = 0;
        openSet.push(new Node(startX, startY, 
                             distance(startX, startY, goalX, goalY)));
        
        int[][] directions = CARDINAL_DIRECTIONS;
        
        while (!openSet.isEmpty()) {
            Node current = openSet.pop();
            nodesExplored++;
            
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
                return new Pair<>(Optional.of(path), nodesExplored);
            }
            
            int currentG = gScores[current.y][current.x];
            
            for (int[] dir : directions) {
                int nx = current.x + dir[0];
                int ny = current.y + dir[1];
                
                if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
                if (!grid[ny][nx]) continue;
                
                int tentativeG = currentG + STRAIGHT_COST;
                
                if (tentativeG < gScores[ny][nx]) {
                    cameFrom[ny][nx] = new Point(current.x, current.y);
                    gScores[ny][nx] = tentativeG;
                    
                    int fScore = tentativeG + distance(nx, ny, goalX, goalY);
                    openSet.push(new Node(nx, ny, fScore));
                }
            }
        }
        
        return new Pair<>(Optional.empty(), nodesExplored);
    }
    
    private static class Pair<A, B> {
        final A first;
        final B second;
        Pair(A first, B second) {
            this.first = first;
            this.second = second;
        }
    }
    
    @Override
    public void prepare() {
        mazeGrid = MazeGenerator.Maze.generateWalkableMaze(width, height);
    }
    
    @Override
    public void run(int iterationId) {
        Pair<Optional<List<Point>>, Integer> result = findPath();
        
        long localResult = 0;
        localResult = (localResult << 5) + (result.first.isPresent() ? result.first.get().size() : 0);
        localResult = (localResult << 5) + result.second;
        resultVal += localResult;
    }
    
    @Override
    public long checksum() {
        return resultVal;
    }
}