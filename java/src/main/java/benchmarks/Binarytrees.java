package benchmarks;

public class Binarytrees extends Benchmark {
    private int n;
    private long checkResult;
    
    static class TreeNode {
        final int item;
        final TreeNode left;
        final TreeNode right;
        
        TreeNode(int item, int depth) {
            this.item = item;
            if (depth > 0) {
                left = new TreeNode(2 * item - 1, depth - 1);
                right = new TreeNode(2 * item, depth - 1);
            } else {
                left = null;
                right = null;
            }
        }
        
        int check() {
            if (left == null) {
                return item;
            } else {
                return left.check() - right.check() + item;
            }
        }
        
        static TreeNode create(int item, int depth) {
            return new TreeNode(item, depth - 1);
        }
    }
    
    public Binarytrees() {
        n = getIterations();
    }
    
    @Override
    public void run() {
        checkResult = 0L;
        
        int minDepth = 4;
        int maxDepth = Math.max(minDepth + 2, n);
        int stretchDepth = maxDepth + 1;
        
        // 1. Stretch tree
        checkResult += TreeNode.create(0, stretchDepth).check();
        
        // 2. Деревья разных глубин
        for (int depth = minDepth; depth <= maxDepth; depth += 2) {
            int iterations = 1 << (maxDepth - depth + minDepth);
            
            for (int i = 1; i <= iterations; i++) {
                checkResult += TreeNode.create(i, depth).check();
                checkResult += TreeNode.create(-i, depth).check();
            }
        }
    }
    
    @Override
    public long getResult() {
        return checkResult;
    }
}