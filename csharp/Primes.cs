using System.Text;

public class Primes : Benchmark
{
    private const int PREFIX = 32338;
    private long _n;
    private long _prefix;
    private uint _result;

    public Primes()
    {
        _result = 5432;
        _n = ConfigVal("limit");
        _prefix = ConfigVal("prefix");
    }

    private sealed class Node
    {
        public readonly Node?[] Children = new Node?[10];
        public bool Terminal;

        public Node GetOrCreateChild(int digit)
        {
            ref Node? child = ref Children[digit];
            if (child is null) child = new Node();
            return child;
        }

        public Node? GetChild(int digit) => Children[digit];
    }

    private sealed class Sieve
    {
        private readonly int _limit;
        private readonly bool[] _isPrime;

        public Sieve(int limit)
        {
            _limit = limit;
            _isPrime = new bool[limit + 1];

            if (limit >= 2) Array.Fill(_isPrime, true, 2, _isPrime.Length - 2);
        }

        public List<int> CalculateAndGetPrimes()
        {
            if (_limit < 2) return new List<int>();

            int sqrtLimit = (int)Math.Sqrt(_limit);

            for (int p = 2; p <= sqrtLimit; p++)
            {
                if (_isPrime[p])
                {
                    for (int multiple = p * p; multiple <= _limit; multiple += p)
                    {
                        _isPrime[multiple] = false;
                    }
                }
            }

            int estimatedCount = _limit > 1000 ? (int)(_limit / Math.Log(_limit)) : _limit / 2;
            var primes = new List<int>(estimatedCount);

            if (_limit >= 2) primes.Add(2);

            for (int p = 3; p <= _limit; p += 2)
            {
                if (_isPrime[p]) primes.Add(p);
            }

            return primes;
        }
    }

    private static Node BuildTrie(List<int> primes)
    {
        var root = new Node();

        static void AddPrimeToTrie(Node root, int prime)
        {
            Node current = root;
            int temp = prime;
            Span<int> digits = stackalloc int[12];
            int digitCount = 0;

            while (temp > 0)
            {
                digits[digitCount++] = temp % 10;
                temp /= 10;
            }

            for (int i = digitCount - 1; i >= 0; i--)
            {
                current = current.GetOrCreateChild(digits[i]);
            }

            current.Terminal = true;
        }

        foreach (int prime in primes)
        {
            AddPrimeToTrie(root, prime);
        }

        return root;
    }

    private static List<int> FindWithPrefix(Node trieRoot, int prefix)
    {
        Node? current = trieRoot;
        int prefixValue = 0;

        int temp = prefix;
        Span<int> prefixDigits = stackalloc int[12];
        int digitCount = 0;

        while (temp > 0)
        {
            prefixDigits[digitCount++] = temp % 10;
            temp /= 10;
        }

        for (int i = digitCount - 1; i >= 0; i--)
        {
            int digit = prefixDigits[i];
            prefixValue = prefixValue * 10 + digit;

            current = current?.GetChild(digit);
            if (current is null) return new List<int>();
        }

        var results = new List<int>();
        var queue = new Queue<(Node, int)>();
        queue.Enqueue((current!, prefixValue));

        while (queue.Count > 0)
        {
            (Node node, int number) = queue.Dequeue();

            if (node.Terminal) results.Add(number);

            for (int digit = 0; digit < 10; digit++)
            {
                Node? child = node.GetChild(digit);
                if (child is not null) queue.Enqueue((child, number * 10 + digit));
            }
        }

        results.Sort();
        return results;
    }

    public override void Run(long IterationId)
    {
        var sieve = new Sieve((int)_n);
        var primes = sieve.CalculateAndGetPrimes();

        var trie = BuildTrie(primes);

        var results = FindWithPrefix(trie, (int)_prefix);

        _result += (uint)results.Count;
        foreach (int prime in results) _result += (uint)prime;
    }

    public override uint Checksum => _result;
}