public class Binarytrees : Benchmark
{
    private int _n;
    private long _result;
    
    public override long Result => _result;
    
    public Binarytrees()
    {
        _result = 0;
    }
    
    public override void Prepare()
    {
        var className = nameof(Binarytrees);
        if (Helper.Input.TryGetValue(className, out var value))
        {
            if (int.TryParse(value, out var iter))
            {
                _n = iter;
                return;
            }
        }
        _n = 1;
        Console.WriteLine($"Warning: Using default iterations for {className}");
    }
    
    private class TreeNode
    {
        public TreeNode? Left { get; set; }
        public TreeNode? Right { get; set; }
        public int Item { get; }
        
        public static TreeNode Create(int item, int depth)
        {
            return new TreeNode(item, depth);
        }
        
        public TreeNode(int item, int depth)
        {
            Item = item;
            if (depth > 0)
            {
                Left = new TreeNode(2 * item - 1, depth - 1);
                Right = new TreeNode(2 * item, depth - 1);
            }
        }
        
        public int Check()
        {
            if (Left == null || Right == null)
                return Item;
            return Left.Check() - Right.Check() + Item;
        }
    }
    
    public override void Run()
    {
        int minDepth = 4;
        int maxDepth = Math.Max(minDepth + 2, _n);
        int stretchDepth = maxDepth + 1;
        
        // Stretch tree
        _result += TreeNode.Create(0, stretchDepth).Check();
        
        // Long-lived tree
        var longLivedTree = TreeNode.Create(0, maxDepth);
        
        // Build trees
        for (int depth = minDepth; depth <= maxDepth; depth += 2)
        {
            int iterations = 1 << (maxDepth - depth + minDepth);
            
            for (int i = 1; i <= iterations; i++)
            {
                _result += TreeNode.Create(i, depth).Check();
                _result += TreeNode.Create(-i, depth).Check();
            }
        }
    }
}