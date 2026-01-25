using System;
using System.Collections.Generic;
using System.Text;

public class Primes : Benchmark
{
    private const int PREFIX = 32338;
    private int _n;
    private uint _result;
    
    public override long Result => _result;
    
    public Primes()
    {
        _result = 5432;
    }
    
    public override void Prepare()
    {
        var className = nameof(Primes);
        if (Helper.Input.TryGetValue(className, out var value) && 
            int.TryParse(value, out var iter))
        {
            _n = iter;
        }
        else
        {
            _n = 5_000_000; // Дефолтное значение как в тестах
        }
    }
    
    // Оптимизированная структура Node
    private sealed class Node
    {
        // Используем массив вместо Dictionary - только 10 цифр
        public readonly Node?[] Children = new Node?[10];
        public bool Terminal;
        
        public Node GetOrCreateChild(int digit)
        {
            ref Node? child = ref Children[digit];
            if (child is null)
            {
                child = new Node();
            }
            return child;
        }
        
        public Node? GetChild(int digit) => Children[digit];
    }
    
    // Оптимизированное решето Эратосфена (проще и быстрее чем Аткина)
    private sealed class Sieve
    {
        private readonly int _limit;
        private readonly bool[] _isPrime;
        
        public Sieve(int limit)
        {
            _limit = limit;
            _isPrime = new bool[limit + 1];
            
            if (limit >= 2)
            {
                Array.Fill(_isPrime, true, 2, _isPrime.Length - 2);
            }
        }
        
        public List<int> CalculateAndGetPrimes()
        {
            if (_limit < 2)
                return new List<int>();
            
            int sqrtLimit = (int)Math.Sqrt(_limit);
            
            // Основной алгоритм решета
            for (int p = 2; p <= sqrtLimit; p++)
            {
                if (_isPrime[p])
                {
                    // Оптимизация: начинаем с p*p
                    for (int multiple = p * p; multiple <= _limit; multiple += p)
                    {
                        _isPrime[multiple] = false;
                    }
                }
            }
            
            // Собираем простые числа
            // Оценка количества: π(n) ≈ n / ln(n)
            int estimatedCount = _limit > 1000 ? (int)(_limit / Math.Log(_limit)) : _limit / 2;
            var primes = new List<int>(estimatedCount);
            
            // Добавляем 2 отдельно
            if (_limit >= 2)
                primes.Add(2);
            
            // Только нечетные числа
            for (int p = 3; p <= _limit; p += 2)
            {
                if (_isPrime[p])
                    primes.Add(p);
            }
            
            return primes;
        }
    }
    
    // Быстрое построение trie
    private static Node BuildTrie(List<int> primes)
    {
        var root = new Node();
        
        // Предварительное выделение StringBuilder для повторного использования
        var sb = new StringBuilder(12);
        
        foreach (int prime in primes)
        {
            Node current = root;
            
            // Быстрая конвертация числа в цифры
            sb.Clear();
            sb.Append(prime);
            ReadOnlySpan<char> digits = sb.ToString();
            
            foreach (char ch in digits)
            {
                int digit = ch - '0';
                current = current.GetOrCreateChild(digit);
            }
            
            current.Terminal = true;
        }
        
        return root;
    }
    
    // BFS поиск (быстрее чем DFS в этом случае)
    private static List<int> FindWithPrefix(Node trieRoot, int prefix)
    {
        // Находим узел префикса
        Node? current = trieRoot;
        int prefixValue = 0;
        
        // Быстрое разложение префикса на цифры
        int temp = prefix;
        Span<int> prefixDigits = stackalloc int[12];
        int digitCount = 0;
        
        while (temp > 0)
        {
            prefixDigits[digitCount++] = temp % 10;
            temp /= 10;
        }
        
        // Переходим от старшей цифры к младшей
        for (int i = digitCount - 1; i >= 0; i--)
        {
            int digit = prefixDigits[i];
            prefixValue = prefixValue * 10 + digit;
            
            current = current?.GetChild(digit);
            if (current is null)
                return new List<int>();
        }
        
        // BFS поиск
        var results = new List<int>();
        var queue = new Queue<(Node, int)>();
        queue.Enqueue((current!, prefixValue));
        
        while (queue.Count > 0)
        {
            (Node node, int number) = queue.Dequeue();
            
            if (node.Terminal)
                results.Add(number);
            
            // Проверяем все цифры 0-9
            for (int digit = 0; digit < 10; digit++)
            {
                Node? child = node.GetChild(digit);
                if (child is not null)
                {
                    queue.Enqueue((child, number * 10 + digit));
                }
            }
        }
        
        results.Sort();
        return results;
    }
    
    public override void Run()
    {
        // 1. Генерация простых чисел
        var sieve = new Sieve(_n);
        var primes = sieve.CalculateAndGetPrimes();
        
        // 2. Построение префиксного дерева
        var trie = BuildTrie(primes);
        
        // 3. Поиск по префиксу
        var results = FindWithPrefix(trie, PREFIX);
        
        // 4. Вычисление результата (точно как в других версиях)
        unchecked
        {
            _result += (uint)results.Count;
            
            foreach (int prime in results)
            {
                _result += (uint)prime;
            }
        }
    }
}