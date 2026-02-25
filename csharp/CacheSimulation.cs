using System.Text;

public class CacheSimulation : Benchmark
{
    private class LRUCache<TKey, TValue> where TKey : notnull
    {
        private class Node
        {
            public TKey Key;
            public TValue Value;
            public Node? Prev;
            public Node? Next;

            public Node(TKey key, TValue value)
            {
                Key = key;
                Value = value;
            }
        }

        private readonly int _capacity;
        private readonly Dictionary<TKey, Node> _cache;
        private Node? _head;
        private Node? _tail;
        private int _size;

        public LRUCache(int capacity)
        {
            _capacity = capacity;
            _cache = new Dictionary<TKey, Node>();
            _size = 0;
        }

        public TValue? Get(TKey key)
        {
            if (_cache.TryGetValue(key, out Node? node))
            {
                MoveToFront(node);
                return node.Value;
            }
            return default;
        }

        public void Put(TKey key, TValue value)
        {
            if (_cache.TryGetValue(key, out Node? node))
            {
                node.Value = value;
                MoveToFront(node);
                return;
            }

            if (_size >= _capacity) RemoveOldest();

            node = new Node(key, value);
            _cache[key] = node;
            AddToFront(node);
            _size++;
        }

        public int Size => _size;

        private void MoveToFront(Node node)
        {
            if (node == _head) return;

            if (node.Prev != null) node.Prev.Next = node.Next;
            if (node.Next != null) node.Next.Prev = node.Prev;

            if (node == _tail) _tail = node.Prev;

            node.Prev = null;
            node.Next = _head;

            if (_head != null) _head.Prev = node;

            _head = node;

            if (_tail == null) _tail = node;
        }

        private void AddToFront(Node node)
        {
            node.Next = _head;
            if (_head != null) _head.Prev = node;

            _head = node;

            if (_tail == null) _tail = node;
        }

        private void RemoveOldest()
        {
            if (_tail == null) return;

            Node oldest = _tail;
            _cache.Remove(oldest.Key);

            if (oldest.Prev != null) oldest.Prev.Next = null;

            _tail = oldest.Prev;

            if (_head == oldest) _head = null;

            _size--;
        }
    }

    private uint _result;
    private int _valuesSize;
    private int _cacheSize;
    private LRUCache<string, string> _cache;
    private int _hits = 0;
    private int _misses = 0;

    public CacheSimulation()
    {
        _result = 5432;
        _valuesSize = (int)ConfigVal("values");
        _cacheSize = (int)ConfigVal("size");
        _cache = new LRUCache<string, string>(_cacheSize);
    }

    public override void Prepare() => _cache = new LRUCache<string, string>(_cacheSize);

    public override void Run(long IterationId)
    {
        for (int n = 0; n < 1000; n++)
        {
            string key = $"item_{Helper.NextInt(_valuesSize)}";

            if (_cache.Get(key) != null)
            {
                _hits++;
                _cache.Put(key, $"updated_{Iterations}");
            }
            else
            {
                _misses++;
                _cache.Put(key, $"new_{Iterations}");
            }
        }
    }

    public override uint Checksum
    {
        get
        {
            uint finalResult = _result;
            finalResult = (finalResult << 5) + (uint)_hits;
            finalResult = (finalResult << 5) + (uint)_misses;
            finalResult = (finalResult << 5) + (uint)_cache.Size;
            return finalResult;
        }
    }
    public override string TypeName => "Etc::CacheSimulation";
}