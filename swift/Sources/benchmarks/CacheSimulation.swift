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
    private var currentSize: Int = 0

    init(capacity: Int) {
      self.capacity = capacity
    }

    func get(_ key: String) -> String? {
      guard let node = cache[key] else { return nil }
      moveToFront(node)
      return node.value
    }

    func put(_ key: String, _ value: String) {
      if let existing = cache[key] {
        existing.value = value
        moveToFront(existing)
        return
      }

      if currentSize >= capacity {
        removeOldest()
      }

      let node = Node(key: key, value: value)
      cache[key] = node
      addToFront(node)
      currentSize += 1
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

      if let prevNode = oldest.prev {
        prevNode.next = nil
        tail = prevNode
      } else {
        head = nil
        tail = nil
      }

      currentSize -= 1
    }

    var size: Int {
      return currentSize
    }
  }

  private var resultVal: UInt32 = 5432
  private var valuesSize: Int = 0
  private var cacheSize: Int = 0
  private var cache: FastLRUCache!
  private var hits = 0
  private var misses = 0

  func prepare() {
    valuesSize = Int(configValue("values") ?? 0)
    cacheSize = Int(configValue("size") ?? 0)
    cache = FastLRUCache(capacity: cacheSize)
    hits = 0
    misses = 0
  }

  func run(iterationId: Int) {
    var j = 0
    while j < 1000 {
      let key = String(format: "item_%d", Helper.nextInt(max: valuesSize))

      if cache.get(key) != nil {
        hits += 1
        let value = String(format: "updated_%d", iterationId)
        cache.put(key, value)
      } else {
        misses += 1
        let value = String(format: "new_%d", iterationId)
        cache.put(key, value)
      }
      j += 1
    }
  }

  var checksum: UInt32 {
    var finalResult = resultVal
    finalResult = (finalResult << 5) &+ UInt32(hits)
    finalResult = (finalResult << 5) &+ UInt32(misses)
    finalResult = (finalResult << 5) &+ UInt32(cache.size)
    return finalResult
  }

  func name() -> String {
    return "Etc::CacheSimulation"
  }
}
