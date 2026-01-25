package benchmarks

import Benchmark

class CacheSimulation : Benchmark() {
    private class LRUCache<K, V>(private val capacity: Int) {
        private data class Node<K, V>(
            val key: K,
            var value: V,
            var prev: Node<K, V>? = null,
            var next: Node<K, V>? = null
        )
        
        private val cache = mutableMapOf<K, Node<K, V>>()
        private var head: Node<K, V>? = null
        private var tail: Node<K, V>? = null
        private var size = 0
        
        fun get(key: K): V? {
            val node = cache[key] ?: return null
            
            // Перемещаем узел в начало списка (самый свежий)
            moveToFront(node)
            return node.value
        }
        
        fun put(key: K, value: V) {
            val existing = cache[key]
            if (existing != null) {
                // Обновляем существующий узел
                existing.value = value
                moveToFront(existing)
                return
            }
            
            // Удаляем самый старый если достигли capacity
            if (size >= capacity) {
                removeOldest()
            }
            
            // Создаем новый узел
            val node = Node(key, value)
            
            // Добавляем в хеш-таблицу
            cache[key] = node
            
            // Добавляем в начало списка
            addToFront(node)
            
            size++
        }
        
        fun getSize(): Int = size
        
        private fun moveToFront(node: Node<K, V>) {
            // Если уже в начале, ничего не делаем
            if (node == head) return
            
            // Удаляем из текущей позиции
            node.prev?.next = node.next
            node.next?.prev = node.prev
            
            // Обновляем tail если нужно
            if (node == tail) {
                tail = node.prev
            }
            
            // Вставляем в начало
            node.prev = null
            node.next = head
            head?.prev = node
            head = node
            
            // Если список был пустой, обновляем tail
            if (tail == null) {
                tail = node
            }
        }
        
        private fun addToFront(node: Node<K, V>) {
            node.next = head
            head?.prev = node
            head = node
            if (tail == null) {
                tail = node
            }
        }
        
        private fun removeOldest() {
            val oldest = tail ?: return
            
            // Удаляем из хеш-таблицы
            cache.remove(oldest.key)
            
            // Удаляем из списка
            oldest.prev?.next = null
            tail = oldest.prev
            
            // Обновляем head если нужно
            if (head == oldest) {
                head = null
            }
            
            size--
        }
    }
    
    private var operations: Int = 0
    private var _result: UInt = 0u
    
    init {
        operations = iterations * 1000
    }
    
    override fun run() {
        val cache = LRUCache<String, String>(1000)
        var hits = 0
        var misses = 0
        
        repeat(operations) { i ->
            val key = "item_${Helper.nextInt(2000)}"
            if (cache.get(key) != null) {
                hits++
                cache.put(key, "updated_$i")
            } else {
                misses++
                cache.put(key, "new_$i")
            }
        }
        
        val message = "hits:$hits|misses:$misses|size:${cache.getSize()}"
        _result = Helper.checksum(message)
    }
    
    override val result: Long
        get() = _result.toLong()
}