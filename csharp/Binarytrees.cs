public class BinarytreesObj : Benchmark
{
    private long _n;
    private uint _result;

    public BinarytreesObj()
    {
        _result = 0;
        _n = ConfigVal("depth");
    }

    private class TreeNode
    {
        public TreeNode? Left { get; set; }
        public TreeNode? Right { get; set; }
        public int Item { get; }

        public TreeNode(int item, int depth)
        {
            Item = item;
            if (depth > 0)
            {
                int shift = 1 << (depth - 1);
                Left = new TreeNode(item - shift, depth - 1);
                Right = new TreeNode(item + shift, depth - 1);
            }
        }

        public uint Sum()
        {
            uint total = (uint)Item + 1;
            if (Left != null) total += Left.Sum();
            if (Right != null) total += Right.Sum();
            return total;
        }
    }

    public override void Run(long IterationId)
    {
        var root = new TreeNode(0, (int)_n);
        _result += root.Sum();

    }

    public override uint Checksum => _result;
    public override string TypeName => "Binarytrees::Obj";
}

public class BinarytreesArena : Benchmark
{
    private long _n;
    private uint _result;

    public BinarytreesArena()
    {
        _result = 0;
        _n = ConfigVal("depth");
    }

    private struct TreeNode
    {
        public int Item;
        public int Left;
        public int Right;

        public TreeNode(int item)
        {
            Item = item;
            Left = -1;
            Right = -1;
        }
    }

    private class TreeArena
    {
        private List<TreeNode> _nodes = new();

        public int Build(int item, int depth)
        {
            int idx = _nodes.Count;
            _nodes.Add(new TreeNode(item));

            if (depth > 0)
            {
                int shift = 1 << (depth - 1);
                int leftIdx = Build(item - shift, depth - 1);
                int rightIdx = Build(item + shift, depth - 1);

                var node = _nodes[idx];
                node.Left = leftIdx;
                node.Right = rightIdx;
                _nodes[idx] = node;
            }

            return idx;
        }

        public uint Sum(int idx)
        {
            var node = _nodes[idx];
            uint total = (uint)node.Item + 1;

            if (node.Left >= 0) total += Sum(node.Left);
            if (node.Right >= 0) total += Sum(node.Right);

            return total;
        }
    }

    public override void Run(long IterationId)
    {
        TreeArena _arena = new();
        int rootIdx = _arena.Build(0, (int)_n);
        _result += _arena.Sum(rootIdx);
    }

    public override uint Checksum => _result;
    public override string TypeName => "Binarytrees::Arena";
}