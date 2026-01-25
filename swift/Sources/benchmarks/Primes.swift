import Foundation

final class Primes: BenchmarkProtocol {
    private static let PREFIX = 32338
    
    private var n: Int = 0
    private var _result: UInt32 = 5432
    
    init() {
        n = iterations
    }
    
    private class Node {
        var children: [Node?] = Array(repeating: nil, count: 10)
        var terminal: Bool = false
    }
    
    private func generatePrimes(limit: Int) -> [Int] {
        guard limit >= 2 else { return [] }
        
        var isPrime = [Bool](repeating: true, count: limit + 1)
        isPrime[0] = false
        isPrime[1] = false
        
        let sqrtLimit = Int(sqrt(Double(limit)))
        
        for p in 2...sqrtLimit {
            if isPrime[p] {
                var multiple = p * p
                while multiple <= limit {
                    isPrime[multiple] = false
                    multiple += p
                }
            }
        }
        
        // Разумная оценка размера
        let estimatedSize = Int(Double(limit) / (log(Double(limit)) - 1.1))
        var primes = [Int]()
        primes.reserveCapacity(estimatedSize)
        
        for i in 2...limit {
            if isPrime[i] {
                primes.append(i)
            }
        }
        
        return primes
    }
    
    private func buildTrie(primes: [Int]) -> Node {
        let root = Node()
        
        for prime in primes {
            var current = root
            let digits = String(prime)
            
            for ch in digits {
                let digit = Int(ch.asciiValue! - Character("0").asciiValue!)
                if current.children[digit] == nil {
                    current.children[digit] = Node()
                }
                current = current.children[digit]!
            }
            current.terminal = true
        }
        
        return root
    }
    
    private func findPrimesWithPrefix(root: Node, prefix: Int) -> [Int] {
        let prefixStr = String(prefix)
        var current = root
        
        for ch in prefixStr {
            let digit = Int(ch.asciiValue! - Character("0").asciiValue!)
            guard let next = current.children[digit] else {
                return []
            }
            current = next
        }
        
        // BFS как в C++ версии
        var results = [Int]()
        var queue = [(node: Node, number: Int)]()
        queue.append((current, prefix))
        
        while !queue.isEmpty {
            let (node, number) = queue.removeFirst()
            
            if node.terminal {
                results.append(number)
            }
            
            for digit in 0..<10 {
                if let child = node.children[digit] {
                    queue.append((child, number * 10 + digit))
                }
            }
        }
        
        results.sort()
        return results
    }
    
    func run() {
        // 1. Генерация простых чисел (как в C++)
        let primes = generatePrimes(limit: n)
        
        // 2. Построение префиксного дерева (как в C++)
        let trie = buildTrie(primes: primes)
        
        // 3. Поиск по префиксу (как в C++)
        let results = findPrimesWithPrefix(root: trie, prefix: Primes.PREFIX)
        
        // 4. Вычисление результата в том же порядке
        var temp = UInt64(result)
        
        // Сначала добавляем размер (как в C++)
        temp = (temp + UInt64(results.count)) & 0xFFFFFFFF
        
        // Затем добавляем все числа (как в C++)
        for prime in results {
            temp = (temp + UInt64(prime)) & 0xFFFFFFFF
        }
        
        _result = UInt32(temp)
    }
    
    var result: Int64 {
        return Int64(_result)
    }
    
    func prepare() {}
}
