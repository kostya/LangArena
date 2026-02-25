package benchmarks

import Benchmark

class CacheSimulation : Benchmark() {
    private class LRUCache<K, V>(
        private val capacity: Int,
    ) {
        private data class Node<K, V>(
            val key: K,
            var value: V,
            var prev: Node<K, V>? = null,
            var next: Node<K, V>? = null,
        )

        private val cache = mutableMapOf<K, Node<K, V>>()
        private var head: Node<K, V>? = null
        private var tail: Node<K, V>? = null
        private var size = 0

        fun get(key: K): V? {
            val node = cache[key] ?: return null

            moveToFront(node)
            return node.value
        }

        fun put(
            key: K,
            value: V,
        ) {
            val existing = cache[key]
            if (existing != null) {
                existing.value = value
                moveToFront(existing)
                return
            }

            if (size >= capacity) {
                removeOldest()
            }

            val node = Node(key, value)

            cache[key] = node

            addToFront(node)

            size++
        }

        fun getSize(): Int = size

        private fun moveToFront(node: Node<K, V>) {
            if (node == head) return

            node.prev?.next = node.next
            node.next?.prev = node.prev

            if (node == tail) {
                tail = node.prev
            }

            node.prev = null
            node.next = head
            head?.prev = node
            head = node

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

            cache.remove(oldest.key)

            oldest.prev?.next = null
            tail = oldest.prev

            if (head == oldest) {
                head = null
            }

            size--
        }
    }

    private var resultVal: UInt = 5432u
    private val valuesSize: Int
    private val cacheSize: Int
    private lateinit var cache: LRUCache<String, String>
    private var hits: UInt = 0u
    private var misses: UInt = 0u

    init {
        valuesSize = configVal("values").toInt()
        cacheSize = configVal("size").toInt()
    }

    override fun prepare() {
        cache = LRUCache(cacheSize)
    }

    override fun run(iterationId: Int) {
        repeat(1000) {
            val key = "item_${Helper.nextInt(valuesSize)}"
            if (cache.get(key) != null) {
                hits++
                cache.put(key, "updated_$iterationId")
            } else {
                misses++
                cache.put(key, "new_$iterationId")
            }
        }
    }

    override fun checksum(): UInt {
        var finalResult = resultVal
        finalResult = (finalResult shl 5) + hits
        finalResult = (finalResult shl 5) + misses
        finalResult = (finalResult shl 5) + cache.getSize().toUInt()
        return finalResult
    }

    override fun name(): String = "Etc::CacheSimulation"
}
