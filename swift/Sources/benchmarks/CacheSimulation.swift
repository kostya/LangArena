import Foundation

final class CacheSimulation: BenchmarkProtocol {
    private class FastLRUCache {
        private class Node {
            let key: String
            var value: String
            var prev: Node?
            var next: Node?

            init(key: String, value: String) {
                self.key = key
                self.value = value
            }
        }

        private let capacity: Int
        private var cache: [String: Node] = [:]
        private var head: Node?
        private var tail: Node?

        init(capacity: Int) {
            self.capacity = capacity
        }

        func get(_ key: String) -> Bool {
            guard let node = cache[key] else { return false }
            moveToFront(node)
            return true
        }

        func put(key: String, value: String) {
            if let existing = cache[key] {
                existing.value = value
                moveToFront(existing)
                return
            }

            if cache.count >= capacity {
                removeOldest()
            }

            let node = Node(key: key, value: value)
            cache[key] = node
            addToFront(node)
        }

        private func moveToFront(_ node: Node) {
            if node === head { return }
            node.prev?.next = node.next
            node.next?.prev = node.prev

            if node === tail {
                tail = node.prev
            }

            node.prev = nil
            node.next = head
            head?.prev = node
            head = node

            if tail == nil {
                tail = node
            }
        }

        private func addToFront(_ node: Node) {
            node.next = head
            head?.prev = node
            head = node
            if tail == nil {
                tail = node
            }
        }

        private func removeOldest() {
            guard let oldest = tail else { return }
            cache.removeValue(forKey: oldest.key)
            oldest.prev?.next = nil
            tail = oldest.prev
            if head === oldest {
                head = nil
            }
        }

        func size() -> Int {
            return cache.count
        }
    }

    private var resultVal: UInt32 = 5432
    private var valuesSize: Int = 0
    private var cacheSize: Int = 0
    private var cache: FastLRUCache!
    private var hits = 0
    private var misses = 0

    init() {
        valuesSize = Int(configValue("values") ?? 0)
        cacheSize = Int(configValue("size") ?? 0)
    }

    func prepare() {
        cache = FastLRUCache(capacity: cacheSize)
    }

    func run(iterationId: Int) {
        let key = String(format: "item_%d", Helper.nextInt(max: valuesSize))

        if cache.get(key) {
            hits += 1
            let value = String(format: "updated_%d", iterationId)
            cache.put(key: key, value: value)
        } else {
            misses += 1
            let value = String(format: "new_%d", iterationId)
            cache.put(key: key, value: value)
        }
    }

    var checksum: UInt32 {
        var finalResult = resultVal
        finalResult = (finalResult << 5) &+ UInt32(hits)
        finalResult = (finalResult << 5) &+ UInt32(misses)
        finalResult = (finalResult << 5) &+ UInt32(cache.size())
        return finalResult
    }
}