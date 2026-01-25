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
            
            if (_size >= _capacity)
            {
                RemoveOldest();
            }
            
            node = new Node(key, value);
            _cache[key] = node;
            AddToFront(node);
            _size++;
        }
        
        public int Size => _size;
        
        private void MoveToFront(Node node)
        {
            if (node == _head) return;
            
            // Удаляем из текущей позиции
            if (node.Prev != null)
                node.Prev.Next = node.Next;
            if (node.Next != null)
                node.Next.Prev = node.Prev;
                
            if (node == _tail)
                _tail = node.Prev;
                
            // Вставляем в начало
            node.Prev = null;
            node.Next = _head;
            
            if (_head != null)
                _head.Prev = node;
                
            _head = node;
            
            if (_tail == null)
                _tail = node;
        }
        
        private void AddToFront(Node node)
        {
            node.Next = _head;
            if (_head != null)
                _head.Prev = node;
                
            _head = node;
            
            if (_tail == null)
                _tail = node;
        }
        
        private void RemoveOldest()
        {
            if (_tail == null) return;
            
            Node oldest = _tail;
            _cache.Remove(oldest.Key);
            
            if (oldest.Prev != null)
                oldest.Prev.Next = null;
                
            _tail = oldest.Prev;
            
            if (_head == oldest)
                _head = null;
                
            _size--;
        }
    }
    
    private int _operations;
    private uint _result;
    
    public override long Result => _result;
    
    public CacheSimulation()
    {
        _result = 0;
    }
    
    public override void Prepare()
    {
        var className = nameof(CacheSimulation);
        if (Helper.Input.TryGetValue(className, out var value))
        {
            if (int.TryParse(value, out var iter))
            {
                _operations = iter * 1000;
                return;
            }
        }
        _operations = 1000;
    }
    
    public override void Run()
    {
        var cache = new LRUCache<string, string>(1000);
        int hits = 0;
        int misses = 0;
        
        for (int i = 0; i < _operations; i++)
        {
            string key = $"item_{Helper.NextInt(2000)}";
            
            if (cache.Get(key) != null)
            {
                hits++;
                cache.Put(key, $"updated_{i}");
            }
            else
            {
                misses++;
                cache.Put(key, $"new_{i}");
            }
        }
        
        string resultStr = $"hits:{hits}|misses:{misses}|size:{cache.Size}";
        _result = Helper.Checksum(resultStr);
    }
}