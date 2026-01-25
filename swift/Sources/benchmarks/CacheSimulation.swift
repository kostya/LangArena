import Foundation
final class CacheSimulation: BenchmarkProtocol {
    private class LRUCache<Key: Hashable, Value> {
        private class Node {
            let key: Key
            var value: Value
            var prev: Node?
            var next: Node?
            init(key: Key, value: Value) {
                self.key = key
                self.value = value
            }
        }
        private let capacity: Int
        private var cache: [Key: Node] = [:]
        private var head: Node?
        private var tail: Node?
        private var size = 0
        init(capacity: Int) {
            self.capacity = capacity
        }
        func get(_ key: Key) -> Value? {
            guard let node = cache[key] else { return nil }
            // Перемещаем узел в начало списка (самый свежий)
            moveToFront(node)
            return node.value
        }
        func put(key: Key, value: Value) {
            if let existing = cache[key] {
                // Обновляем существующий узел
                existing.value = value
                moveToFront(existing)
                return
            }
            // Удаляем самый старый если достигли capacity
            if size >= capacity {
                removeOldest()
            }
            // Создаем новый узел
            let node = Node(key: key, value: value)
            // Добавляем в хеш-таблицу
            cache[key] = node
            // Добавляем в начало списка
            addToFront(node)
            size += 1
        }
        func getSize() -> Int {
            return size
        }
        private func moveToFront(_ node: Node) {
            // Если уже в начале, ничего не делаем
            if node === head { return }
            // Удаляем из текущей позиции
            node.prev?.next = node.next
            node.next?.prev = node.prev
            // Обновляем tail если нужно
            if node === tail {
                tail = node.prev
            }
            // Вставляем в начало
            node.prev = nil
            node.next = head
            head?.prev = node
            head = node
            // Если список был пустой, обновляем tail
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
            // Удаляем из хеш-таблицы
            cache.removeValue(forKey: oldest.key)
            // Удаляем из списка
            oldest.prev?.next = nil
            tail = oldest.prev
            // Обновляем head если нужно
            if head === oldest {
                head = nil
            }
            size -= 1
        }
    }
    private var operations: Int = 0
    private var _result: UInt32 = 0
    init() {
        operations = iterations * 1000
    }
    func run() {
        let cache = LRUCache<String, String>(capacity: 1000)
        var hits = 0
        var misses = 0
        for i in 0..<operations {
            let key = "item_\(Helper.nextInt(max: 2000))"
            if cache.get(key) != nil {
                hits += 1
                cache.put(key: key, value: "updated_\(i)")
            } else {
                misses += 1
                cache.put(key: key, value: "new_\(i)")
            }
        }
        let message = "hits:\(hits)|misses:\(misses)|size:\(cache.getSize())"
        _result = Helper.checksum(message)
    }
    var result: Int64 {
        return Int64(_result)
    }
    func prepare() {}
}