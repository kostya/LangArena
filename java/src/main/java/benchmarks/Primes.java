package benchmarks;

import java.util.*;

public class Primes extends Benchmark {
    private static class Node {
        final Node[] children = new Node[10];
        boolean terminal = false;
    }
    
    private long resultVal;
    private long n;
    private long prefix;
    
    public Primes() {
        n = configVal("limit");
        prefix = configVal("prefix");
        resultVal = 5432L;
    }
    
    @Override
    public String name() {
        return "Primes";
    }
    
    private static List<Integer> generatePrimes(int limit) {
        if (limit < 2) {
            return Collections.emptyList();
        }
        
        boolean[] isPrime = new boolean[limit + 1];
        Arrays.fill(isPrime, true);
        isPrime[0] = isPrime[1] = false;
        
        int sqrtLimit = (int) Math.sqrt(limit);
        
        for (int p = 2; p <= sqrtLimit; p++) {
            if (isPrime[p]) {
                for (int multiple = p * p; multiple <= limit; multiple += p) {
                    isPrime[multiple] = false;
                }
            }
        }
        
        // Предварительно оцениваем количество простых чисел
        int estimatedSize = (int) (limit / (Math.log(limit) - 1.1));
        List<Integer> primes = new ArrayList<>(estimatedSize);
        
        for (int i = 2; i <= limit; i++) {
            if (isPrime[i]) {
                primes.add(i);
            }
        }
        
        return primes;
    }
    
    // Построение префиксного дерева
    private static Node buildTrie(List<Integer> primes) {
        Node root = new Node();
        
        for (int prime : primes) {
            Node current = root;
            String digits = Integer.toString(prime);
            
            for (int i = 0; i < digits.length(); i++) {
                int digit = digits.charAt(i) - '0';
                
                if (current.children[digit] == null) {
                    current.children[digit] = new Node();
                }
                current = current.children[digit];
            }
            current.terminal = true;
        }
        
        return root;
    }
    
    // Поиск чисел с заданным префиксом с использованием BFS (как в C++)
    private static List<Integer> findPrimesWithPrefix(Node root, int prefix) {
        String prefixStr = Integer.toString(prefix);
        Node current = root;
        
        // Находим узел, соответствующий префиксу
        for (int i = 0; i < prefixStr.length(); i++) {
            int digit = prefixStr.charAt(i) - '0';
            
            if (current.children[digit] == null) {
                return Collections.emptyList();
            }
            current = current.children[digit];
        }
        
        // BFS обход - используем Queue как в C++ версии
        Queue<Map.Entry<Node, Integer>> queue = new ArrayDeque<>();
        queue.offer(new AbstractMap.SimpleEntry<>(current, prefix));
        
        List<Integer> results = new ArrayList<>();
        
        while (!queue.isEmpty()) {
            Map.Entry<Node, Integer> entry = queue.poll();
            Node node = entry.getKey();
            int number = entry.getValue();
            
            if (node.terminal) {
                results.add(number);
            }
            
            // Перебираем все дочерние узлы
            for (int digit = 0; digit < 10; digit++) {
                if (node.children[digit] != null) {
                    queue.offer(new AbstractMap.SimpleEntry<>(
                        node.children[digit],
                        number * 10 + digit
                    ));
                }
            }
        }
        
        // Сортируем результаты как в C++ версии
        Collections.sort(results);
        return results;
    }
    
    @Override
    public void run(int iterationId) {
        // 1. Генерация простых чисел (как в C++)
        List<Integer> primes = generatePrimes((int) n);
        
        // 2. Построение префиксного дерева (как в C++)
        Node trie = buildTrie(primes);
        
        // 3. Поиск по префиксу (как в C++)
        List<Integer> results = findPrimesWithPrefix(trie, (int) prefix);
        
        // 4. Вычисление результата в том же порядке, что и в C++
        resultVal += results.size();
        
        // Затем добавляем все числа (как в C++)
        for (int prime : results) {
            resultVal += prime;
        }
    }
    
    @Override
    public long checksum() {
        return resultVal;
    }
}