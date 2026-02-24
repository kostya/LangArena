import std/[strformat, tables]
import ../benchmark
import ../helper

type
  Node = ref object
    key: string
    value: string
    prev: Node
    next: Node

  FastLRUCache = ref object
    capacity: int
    cache: Table[string, Node]
    head: Node
    tail: Node
    size: int

  CacheSimulation* = ref object of Benchmark
    resultVal: uint32
    valuesSize: int
    cacheSize: int
    cache: FastLRUCache
    hits: int
    misses: int

proc newFastLRUCache(capacity: int): FastLRUCache =
  FastLRUCache(
    capacity: capacity,
    cache: initTable[string, Node](),
    head: nil,
    tail: nil,
    size: 0
  )

proc moveToFront(cache: FastLRUCache, node: Node) =
  if node == cache.head:
    return

  if node.prev != nil:
    node.prev.next = node.next
  if node.next != nil:
    node.next.prev = node.prev

  if node == cache.tail:
    cache.tail = node.prev

  node.prev = nil
  node.next = cache.head
  if cache.head != nil:
    cache.head.prev = node
  cache.head = node

  if cache.tail == nil:
    cache.tail = node

proc addToFront(cache: FastLRUCache, node: Node) =
  node.next = cache.head
  if cache.head != nil:
    cache.head.prev = node
  cache.head = node
  if cache.tail == nil:
    cache.tail = node

proc removeOldest(cache: FastLRUCache) =
  if cache.tail == nil:
    return

  let oldest = cache.tail

  cache.cache.del(oldest.key)

  if oldest.prev != nil:
    oldest.prev.next = nil
  cache.tail = oldest.prev

  if cache.head == oldest:
    cache.head = nil

  cache.size -= 1

proc get(cache: FastLRUCache, key: string): (bool, string) =
  if cache.cache.hasKey(key):
    let node = cache.cache[key]
    cache.moveToFront(node)
    return (true, node.value)
  (false, "")

proc put(cache: FastLRUCache, key: string, value: string) =
  if cache.cache.hasKey(key):
    let node = cache.cache[key]
    node.value = value
    cache.moveToFront(node)
    return

  if cache.size >= cache.capacity:
    cache.removeOldest()

  let node = Node(key: key, value: value, prev: nil, next: nil)

  cache.cache[key] = node
  cache.addToFront(node)
  cache.size += 1

proc size(cache: FastLRUCache): int =
  cache.size

proc newCacheSimulation(): Benchmark =
  CacheSimulation()

method name(self: CacheSimulation): string = "Etc::CacheSimulation"

method prepare(self: CacheSimulation) =
  self.valuesSize = int(self.config_val("values"))
  self.cacheSize = int(self.config_val("size"))
  self.cache = newFastLRUCache(self.cacheSize)
  self.hits = 0
  self.misses = 0
  self.resultVal = 5432'u32

method run(self: CacheSimulation, iteration_id: int) =
  let key = fmt"item_{nextInt(self.valuesSize.int32)}"

  let (found, _) = self.cache.get(key)
  if found:
    self.hits += 1
    let value = fmt"updated_{iteration_id}"
    self.cache.put(key, value)
  else:
    self.misses += 1
    let value = fmt"new_{iteration_id}"
    self.cache.put(key, value)

method checksum(self: CacheSimulation): uint32 =
  var finalResult = self.resultVal
  finalResult = (finalResult shl 5) + uint32(self.hits)
  finalResult = (finalResult shl 5) + uint32(self.misses)
  finalResult = (finalResult shl 5) + uint32(self.cache.size())
  finalResult

registerBenchmark("Etc::CacheSimulation", newCacheSimulation)
