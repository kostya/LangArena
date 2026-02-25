package benchmarks

import scala.collection.mutable

class CacheSimulation extends Benchmark:
  private class LRUCache[K, V](private val capacity: Int):
    private case class Node[K, V](
        val key: K,
        var value: V,
        var prev: Node[K, V] = null,
        var next: Node[K, V] = null
    )

    private val cache = mutable.Map.empty[K, Node[K, V]]
    private var head: Node[K, V] = null
    private var tail: Node[K, V] = null
    private var size = 0

    def get(key: K): Option[V] =
      cache.get(key).map { node =>
        moveToFront(node)
        node.value
      }

    def put(key: K, value: V): Unit =
      cache.get(key) match
        case Some(existing) =>
          existing.value = value
          moveToFront(existing)
        case None =>
          if size >= capacity then removeOldest()
          val node = Node(key, value)
          cache(key) = node
          addToFront(node)
          size += 1

    def getSize(): Int = size

    private def moveToFront(node: Node[K, V]): Unit =
      if node == head then return

      node.prev match
        case null =>
        case p    => p.next = node.next

      node.next match
        case null =>
        case n    => n.prev = node.prev

      if node == tail then tail = node.prev

      node.prev = null
      node.next = head
      head match
        case null =>
        case h    => h.prev = node
      head = node

      if tail == null then tail = node

    private def addToFront(node: Node[K, V]): Unit =
      node.next = head
      head match
        case null =>
        case h    => h.prev = node
      head = node
      if tail == null then tail = node

    private def removeOldest(): Unit =
      val oldest = tail
      if oldest == null then return

      cache.remove(oldest.key)

      oldest.prev match
        case null =>
        case p    => p.next = null
      tail = oldest.prev

      if head == oldest then head = null

      size -= 1

  private var resultVal: Long = 5432L
  private val valuesSize: Int = configVal("values").toInt
  private val cacheSize: Int = configVal("size").toInt
  private var cache: LRUCache[String, String] = _
  private var hits: Long = 0L
  private var misses: Long = 0L

  override def name(): String = "Etc::CacheSimulation"

  override def prepare(): Unit =
    cache = LRUCache[String, String](cacheSize)
    hits = 0L
    misses = 0L

  override def run(iterationId: Int): Unit =
    var j = 0
    while (j < 1000) {
      val key = s"item_${Helper.nextInt(valuesSize)}"
      cache.get(key) match
        case Some(_) =>
          hits += 1
          cache.put(key, s"updated_$iterationId")
        case None =>
          misses += 1
          cache.put(key, s"new_$iterationId")
      j += 1
    }

  override def checksum(): Long =
    var finalResult = resultVal
    finalResult = (finalResult << 5) + hits
    finalResult = (finalResult << 5) + misses
    finalResult = (finalResult << 5) + cache.getSize().toLong
    finalResult & 0xffffffffL
