from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from helper import Helper
from benchmark import Benchmark, Config


struct _LRUNode(Copyable):
    var key: String
    var value: String
    var prev: Optional[Pointer[_LRUNode, MutUntrackedOrigin]]
    var next: Optional[Pointer[_LRUNode, MutUntrackedOrigin]]

    def __init__(out self, var key: String, var value: String):
        self.key = key^
        self.value = value^
        self.prev = Optional[Pointer[_LRUNode, MutUntrackedOrigin]](None)
        self.next = Optional[Pointer[_LRUNode, MutUntrackedOrigin]](None)

    def __deinit__(deinit self):
        pass


struct _LRUCache:
    var capacity: Int
    var cache: Dict[String, Pointer[_LRUNode, MutUntrackedOrigin]]
    var head: Optional[Pointer[_LRUNode, MutUntrackedOrigin]]
    var tail: Optional[Pointer[_LRUNode, MutUntrackedOrigin]]
    var size_val: Int

    def __init__(out self, capacity: Int):
        self.capacity = capacity
        self.cache = Dict[String, Pointer[_LRUNode, MutUntrackedOrigin]]()
        self.head = Optional[Pointer[_LRUNode, MutUntrackedOrigin]](None)
        self.tail = Optional[Pointer[_LRUNode, MutUntrackedOrigin]](None)
        self.size_val = 0

    def __deinit__(deinit self):
        var current = self.head
        while current:
            var next = current.value()[].next
            var ptr = current.value()
            ptr.unsafe_deinit_pointee()
            ptr.unsafe_free()
            current = next

    def move_to_front(
        mut self, node_ptr: Pointer[_LRUNode, MutUntrackedOrigin]
    ):
        if self.head and self.head.value() == node_ptr:
            return

        if node_ptr[].prev:
            node_ptr[].prev.value()[].next = node_ptr[].next
        if node_ptr[].next:
            node_ptr[].next.value()[].prev = node_ptr[].prev

        if self.tail and self.tail.value() == node_ptr:
            self.tail = node_ptr[].prev

        node_ptr[].prev = Optional[Pointer[_LRUNode, MutUntrackedOrigin]](None)
        node_ptr[].next = self.head

        if self.head:
            self.head.value()[].prev = Optional[
                Pointer[_LRUNode, MutUntrackedOrigin]
            ](node_ptr)

        self.head = Optional[Pointer[_LRUNode, MutUntrackedOrigin]](node_ptr)

        if not self.tail:
            self.tail = Optional[Pointer[_LRUNode, MutUntrackedOrigin]](
                node_ptr
            )

    def add_to_front(mut self, node_ptr: Pointer[_LRUNode, MutUntrackedOrigin]):
        node_ptr[].next = self.head

        if self.head:
            self.head.value()[].prev = Optional[
                Pointer[_LRUNode, MutUntrackedOrigin]
            ](node_ptr)

        self.head = Optional[Pointer[_LRUNode, MutUntrackedOrigin]](node_ptr)

        if not self.tail:
            self.tail = Optional[Pointer[_LRUNode, MutUntrackedOrigin]](
                node_ptr
            )

    def remove_oldest(mut self) raises:
        if not self.tail:
            return

        var tail_ptr = self.tail.value()

        _ = self.cache.pop(tail_ptr[].key)

        if tail_ptr[].prev:
            tail_ptr[].prev.value()[].next = Optional[
                Pointer[_LRUNode, MutUntrackedOrigin]
            ](None)

        self.tail = tail_ptr[].prev

        if self.head and self.head.value() == tail_ptr:
            self.head = Optional[Pointer[_LRUNode, MutUntrackedOrigin]](None)

        tail_ptr.unsafe_deinit_pointee()
        tail_ptr.unsafe_free()

        self.size_val -= 1

    def get(mut self, key: String) raises -> Optional[String]:
        var it = self.cache.get(key)
        if not it:
            return Optional[String](None)

        var node_ptr = it[]
        self.move_to_front(node_ptr)
        return Optional[String](node_ptr[].value)

    def put(mut self, var key: String, var value: String) raises:
        var it = self.cache.get(key)
        if it:
            var node_ptr = it[]
            node_ptr[].value = value^
            self.move_to_front(node_ptr)
            return

        if self.size_val >= self.capacity:
            self.remove_oldest()

        var node_ptr = unsafe_alloc[_LRUNode](1)
        node_ptr.unsafe_write(_LRUNode(key^, value^))

        self.cache[node_ptr[].key] = node_ptr
        self.add_to_front(node_ptr)
        self.size_val += 1

    def count(self) -> Int:
        return self.size_val


struct CacheSimulation(Benchmark):
    var values_size: Int
    var cache_size: Int
    var cache: _LRUCache
    var hits: UInt32
    var misses: UInt32
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.values_size = config.get_i64("Etc::CacheSimulation", "values")
        self.cache_size = config.get_i64("Etc::CacheSimulation", "size")
        self.cache = _LRUCache(self.cache_size)
        self.hits = 0
        self.misses = 0
        self.result = 5432

    def class_name(self) -> String:
        return "Etc::CacheSimulation"

    def prepare(mut self, mut helper: Helper) raises:
        self.cache = _LRUCache(self.cache_size)
        self.hits = 0
        self.misses = 0

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        for _ in range(1000):
            var key = String("item_", helper.next_int(self.values_size))

            var value = self.cache.get(key)
            if value:
                self.hits += 1
                self.cache.put(key, String("updated_", iteration_id))
            else:
                self.misses += 1
                self.cache.put(key, String("new_", iteration_id))

    def checksum(self) -> UInt32:
        var r = self.result
        r = (r << 5) + self.hits
        r = (r << 5) + self.misses
        r = (r << 5) + UInt32(self.cache.count())
        return r
