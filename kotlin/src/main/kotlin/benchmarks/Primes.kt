package benchmarks

import Benchmark
import kotlin.math.sqrt
import kotlin.math.ln

class Primes : Benchmark() {
    companion object {
        private const val PREFIX = 32338
    }

    private var _result: UInt = 5432u  // переименовал

    private class Node {
        val children = arrayOfNulls<Node>(10)
        var terminal = false
    }

    private fun generatePrimes(limit: Int): List<Int> {
        if (limit < 2) return emptyList()
        
        val isPrime = BooleanArray(limit + 1) { true }
        isPrime[0] = false
        isPrime[1] = false
        
        val sqrtLimit = sqrt(limit.toDouble()).toInt()
        
        for (p in 2..sqrtLimit) {
            if (isPrime[p]) {
                var multiple = p * p
                while (multiple <= limit) {
                    isPrime[multiple] = false
                    multiple += p
                }
            }
        }
        
        val estimatedSize = (limit / (ln(limit.toDouble()) - 1.1)).toInt()
        val primes = ArrayList<Int>(estimatedSize)
        
        for (i in 2..limit) {
            if (isPrime[i]) {
                primes.add(i)
            }
        }
        
        return primes
    }

    private fun buildTrie(primes: List<Int>): Node {
        val root = Node()
        
        for (prime in primes) {
            var current = root
            val digits = prime.toString()
            
            for (ch in digits) {
                val digit = ch - '0'
                if (current.children[digit] == null) {
                    current.children[digit] = Node()
                }
                current = current.children[digit]!!
            }
            current.terminal = true
        }
        
        return root
    }

    private fun findPrimesWithPrefix(root: Node, prefix: Int): List<Int> {
        val prefixStr = prefix.toString()
        var current = root
        
        for (ch in prefixStr) {
            val digit = ch - '0'
            current = current.children[digit] ?: return emptyList()
        }
        
        // BFS как в C++ версии
        val queue = ArrayDeque<Pair<Node, Int>>()
        queue.add(current to prefix)
        val results = mutableListOf<Int>()
        
        while (queue.isNotEmpty()) {
            val (node, number) = queue.removeFirst()
            
            if (node.terminal) {
                results.add(number)
            }
            
            for (digit in 0..9) {
                node.children[digit]?.let { child ->
                    queue.add(child to number * 10 + digit)
                }
            }
        }
        
        results.sort()
        return results
    }

    override fun run() {
        // 1. Генерация простых чисел (как в C++)
        val primes = generatePrimes(iterations)
        
        // 2. Построение префиксного дерева (как в C++)
        val trie = buildTrie(primes)
        
        // 3. Поиск по префиксу (как в C++)
        val results = findPrimesWithPrefix(trie, PREFIX)
        
        // 4. Вычисление результата в том же порядке
        var temp = _result.toLong()
        
        // Сначала добавляем размер (как в C++)
        temp = (temp + results.size) and 0xFFFFFFFFL
        
        // Затем добавляем все числа (как в C++)
        for (prime in results) {
            temp = (temp + prime) and 0xFFFFFFFFL
        }
        
        _result = temp.toUInt()
    }

    override val result: Long
        get() = _result.toLong()
}