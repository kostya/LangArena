import std/[strformat, tables, lists]
import ../benchmark
import ../helper

type
  FastLRUCache = ref object
    capacity: int
    cache: Table[string, tuple[value: string, node: DoublyLinkedNode[string]]]
    lruList: DoublyLinkedList[string]

  CacheSimulation* = ref object of Benchmark
    resultVal: uint32
    valuesSize: int
    cacheSize: int
    cache: FastLRUCache
    hits: int
    misses: int

proc newFastLRUCache(capacity: int): FastLRUCache =
  result = FastLRUCache(
    capacity: capacity,
    cache: initTable[string, tuple[value: string, node: DoublyLinkedNode[string]]](),
    lruList: initDoublyLinkedList[string]()
  )

proc get(cache: FastLRUCache, key: string): bool =
  if cache.cache.hasKey(key):
    let node = cache.cache[key].node
    cache.lruList.remove(node)
    cache.lruList.prepend(node)
    return true
  false

proc put(cache: FastLRUCache, key, value: string) =
  if cache.cache.hasKey(key):

    let node = cache.cache[key].node
    cache.lruList.remove(node)
    cache.lruList.prepend(node)
    cache.cache[key] = (value: value, node: node)
    return

  if cache.cache.len >= cache.capacity:

    let oldestNode = cache.lruList.tail
    if oldestNode != nil:
      let oldestKey = oldestNode.value
      cache.lruList.remove(oldestNode)
      cache.cache.del(oldestKey)

  let node = newDoublyLinkedNode(key)
  cache.lruList.prepend(node)
  cache.cache[key] = (value: value, node: node)

proc size(cache: FastLRUCache): int =
  cache.cache.len

proc newCacheSimulation(): Benchmark =
  CacheSimulation()

method name(self: CacheSimulation): string = "CacheSimulation"

method prepare(self: CacheSimulation) =
  self.valuesSize = int(self.config_val("values"))
  self.cacheSize = int(self.config_val("size"))
  self.cache = newFastLRUCache(self.cacheSize)
  self.hits = 0
  self.misses = 0
  self.resultVal = 5432'u32

method run(self: CacheSimulation, iteration_id: int) =
  let key = fmt"item_{nextInt(self.valuesSize.int32)}"

  if self.cache.get(key):
    inc self.hits
    let value = fmt"updated_{iteration_id}"
    self.cache.put(key, value)
  else:
    inc self.misses
    let value = fmt"new_{iteration_id}"
    self.cache.put(key, value)

method checksum(self: CacheSimulation): uint32 =
  var finalResult = self.resultVal
  finalResult = (finalResult shl 5) + uint32(self.hits)
  finalResult = (finalResult shl 5) + uint32(self.misses)
  finalResult = (finalResult shl 5) + uint32(self.cache.size())
  finalResult

registerBenchmark("CacheSimulation", newCacheSimulation)