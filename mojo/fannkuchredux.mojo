from helper import Helper
from benchmark import Benchmark, Config


struct Fannkuchredux(Benchmark):
    var n: Int
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.n = config.get_i64("CLBG::Fannkuchredux", "n")
        self.result = 0

    def class_name(self) -> String:
        return "CLBG::Fannkuchredux"

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var a, b = Self.fannkuchredux(self.n)
        self.result += UInt32(a * 100 + b)

    def checksum(mut self) -> UInt32:
        return self.result

    @staticmethod
    def fannkuchredux(n: Int) -> Tuple[Int, Int]:
        var perm1: List[Int] = [i for i in range(32)]
        var perm = List[Int](length=32, fill=0)
        var count = List[Int](length=32, fill=0)

        var max_flips = 0
        var checksum = 0
        var r = n
        var perm_count = 0

        while True:
            while r > 1:
                count[r - 1] = r
                r -= 1

            perm[:n].copy_from(perm1[:n])

            var flips = 0
            var k = perm[0]
            while k != 0:
                var k2 = (k + 1) >> 1
                for i in range(k2):
                    var j = k - i
                    perm.swap_elements(i, j)
                flips += 1
                k = perm[0]

            if flips > max_flips:
                max_flips = flips

            if perm_count % 2 == 0:
                checksum += flips
            else:
                checksum -= flips

            while True:
                if r == n:
                    return (checksum, max_flips)

                var perm0 = perm1[0]
                for i in range(r):
                    var j = i + 1
                    perm1.swap_elements(i, j)

                perm1[r] = perm0
                count[r] -= 1
                if count[r] > 0:
                    break
                r += 1

            perm_count += 1
