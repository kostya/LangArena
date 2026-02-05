public class Binarytrees : Benchmark
{
    private long _n;
    private uint _result;

    public Binarytrees()
    {
        _result = 0;
        _n = ConfigVal("depth");
    }

    private class TreeNode
    {
        public TreeNode? Left { get; set; }
        public TreeNode? Right { get; set; }
        public int Item { get; }

        public static TreeNode Create(int item, int depth) => new TreeNode(item, depth);

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
            if (Left == null || Right == null) return Item;
            return Left.Check() - Right.Check() + Item;
        }
    }

    public override void Run(long IterationId)
    {
        int minDepth = 4;
        int maxDepth = Math.Max(minDepth + 2, (int)_n);
        int stretchDepth = maxDepth + 1;

        _result += (uint)TreeNode.Create(0, stretchDepth).Check();

        var longLivedTree = TreeNode.Create(0, maxDepth);

        for (int depth = minDepth; depth <= maxDepth; depth += 2)
        {
            int iterations = 1 << (maxDepth - depth + minDepth);

            for (int i = 1; i <= iterations; i++)
            {
                _result += (uint)TreeNode.Create(i, depth).Check();
                _result += (uint)TreeNode.Create(-i, depth).Check();
            }
        }
    }

    public override uint Checksum => _result;
}