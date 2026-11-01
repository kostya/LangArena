from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from helper import Helper
from benchmark import Benchmark, Config


struct TreeNodeObj:
    comptime _NodePointer = Optional[Pointer[TreeNodeObj, MutUntrackedOrigin]]

    var item: Int32
    var left: Self._NodePointer
    var right: Self._NodePointer

    def __init__(out self, item: Int32):
        self.item = item
        self.left = Self._NodePointer()
        self.right = Self._NodePointer()

    def __init__(
        out self,
        item: Int32,
        left: Self._NodePointer,
        right: Self._NodePointer,
    ):
        self.item = item
        self.left = left
        self.right = right

    def __deinit__(deinit self):
        if self.left:
            var nn = self.left.value()
            nn.unsafe_deinit_pointee()
            nn.unsafe_free()
        if self.right:
            var nn = self.right.value()
            nn.unsafe_deinit_pointee()
            nn.unsafe_free()

    def sum(self) -> Int32:
        var total = self.item + 1
        if self.left:
            total += self.left.value()[].sum()
        if self.right:
            total += self.right.value()[].sum()
        return total


struct BinarytreesObj(Benchmark):
    var n: Int
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.n = config.get_i64("Binarytrees::Obj", "depth")
        self.result = 0

    def class_name(self) -> String:
        return "Binarytrees::Obj"

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var root = Self.build_tree(0, Int32(self.n))
        self.result += UInt32(root.sum())

    def checksum(mut self) -> UInt32:
        return self.result

    @staticmethod
    def build_tree(item: Int32, depth: Int32) raises -> TreeNodeObj:
        if depth > 0:
            var shift = 1 << (depth - 1)
            var left_ptr = unsafe_alloc[TreeNodeObj](1)
            left_ptr.unsafe_write(Self.build_tree(item - shift, depth - 1))
            var right_ptr = unsafe_alloc[TreeNodeObj](1)
            right_ptr.unsafe_write(Self.build_tree(item + shift, depth - 1))
            return TreeNodeObj(item, left_ptr, right_ptr)
        return TreeNodeObj(item)


struct TreeNodeArena(Copyable, ImplicitlyCopyable):
    var item: Int32
    var left: Int32
    var right: Int32

    def __init__(out self, item: Int32, left: Int32 = -1, right: Int32 = -1):
        self.item = item
        self.left = left
        self.right = right


struct BinarytreesArena(Benchmark):
    var n: Int
    var result: UInt32
    var arena: List[TreeNodeArena]

    def __init__(out self, config: Config) raises:
        self.n = config.get_i64("Binarytrees::Arena", "depth")
        self.result = 0
        self.arena = List[TreeNodeArena]()

    def class_name(self) -> String:
        return "Binarytrees::Arena"

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.arena = List[TreeNodeArena]()
        _ = self.build_tree(0, Int32(self.n))
        self.result += UInt32(self.sum(0))

    def build_tree(mut self, item: Int32, depth: Int32) raises -> Int32:
        var idx = Int32(len(self.arena))
        self.arena.append(TreeNodeArena(item, -1, -1))

        if depth > 0:
            var shift = 1 << (depth - 1)
            var left_idx = self.build_tree(item - shift, depth - 1)
            var right_idx = self.build_tree(item + shift, depth - 1)
            ref node = self.arena[Int(idx)]
            node.left = left_idx
            node.right = right_idx

        return idx

    def sum(self, idx: Int32) -> Int32:
        var node = self.arena[Int(idx)]
        var total = node.item + 1
        if node.left >= 0:
            total += self.sum(node.left)
        if node.right >= 0:
            total += self.sum(node.right)
        return total

    def checksum(mut self) -> UInt32:
        return self.result
