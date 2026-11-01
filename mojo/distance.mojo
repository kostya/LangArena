from helper import Helper
from benchmark import Benchmark, Config


def generate_pair_strings(
    mut helper: Helper, n: Int, m: Int
) -> List[Tuple[String, String]]:
    var pairs = List[Tuple[String, String]](capacity=n)
    var chars = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]

    for _ in range(n):
        var len1 = helper.next_int(m) + 4
        var len2 = helper.next_int(m) + 4

        var str1 = ""
        for _ in range(len1):
            str1 += chars[helper.next_int(10)]

        var str2 = ""
        for _ in range(len2):
            str2 += chars[helper.next_int(10)]

        pairs.append((str1^, str2^))

    return pairs^


struct DistanceJaro(Benchmark):
    var count: Int
    var size: Int
    var pairs: List[Tuple[String, String]]
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.count = config.get_i64("Distance::Jaro", "count")
        self.size = config.get_i64("Distance::Jaro", "size")
        self.pairs = List[Tuple[String, String]]()
        self.result = 0

    def class_name(self) -> String:
        return "Distance::Jaro"

    def prepare(mut self, mut helper: Helper) raises:
        self.pairs = generate_pair_strings(helper, self.count, self.size)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        for pair in self.pairs:
            self.result += UInt32(Self.jaro(pair[0], pair[1]) * 1000)

    def checksum(self) -> UInt32:
        return self.result

    @staticmethod
    def jaro(s1: String, s2: String) -> Float64:
        var b1 = s1.as_bytes()
        var b2 = s2.as_bytes()
        var len1 = s1.byte_length()
        var len2 = s2.byte_length()

        if len1 == 0 or len2 == 0:
            return 0.0

        var match_dist = max(len1, len2) // 2 - 1
        if match_dist < 0:
            match_dist = 0

        var s1_matches = List[Bool](length=len1, fill=False)
        var s2_matches = List[Bool](length=len2, fill=False)

        var matches: Int = 0
        for i in range(len1):
            var start = max(0, i - match_dist)
            var fin = min(len2 - 1, i + match_dist)

            for j in range(start, fin + 1):
                if not s2_matches[j] and b1[i] == b2[j]:
                    s1_matches[i] = True
                    s2_matches[j] = True
                    matches += 1
                    break

        if matches == 0:
            return 0.0

        var k: Int = 0
        var transpositions: Int = 0
        for i in range(len1):
            if s1_matches[i]:
                while k < len2 and not s2_matches[k]:
                    k += 1
                if k < len2:
                    if b1[i] != b2[k]:
                        transpositions += 1
                    k += 1

        transpositions //= 2

        var m = Float64(matches)
        return (
            m / Float64(len1)
            + m / Float64(len2)
            + (m - Float64(transpositions)) / m
        ) / 3.0


struct DistanceNGram(Benchmark):
    var count: Int
    var size: Int
    var pairs: List[Tuple[String, String]]
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.count = config.get_i64("Distance::NGram", "count")
        self.size = config.get_i64("Distance::NGram", "size")
        self.pairs = List[Tuple[String, String]]()
        self.result = 0

    def class_name(self) -> String:
        return "Distance::NGram"

    def prepare(mut self, mut helper: Helper) raises:
        self.pairs = generate_pair_strings(helper, self.count, self.size)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        for pair in self.pairs:
            self.result += UInt32(Self.ngram(pair[0], pair[1]) * 1000)

    def checksum(mut self) -> UInt32:
        return self.result

    @staticmethod
    def ngram(s1: String, s2: String) -> Float64:
        var bytes1 = s1.as_bytes()
        var bytes2 = s2.as_bytes()
        var len1 = s1.byte_length()
        var len2 = s2.byte_length()

        var grams1 = Dict[UInt32, Int]()

        for i in range(len1 - 3):
            var gram = (
                (UInt32(bytes1[i]) << 24)
                | (UInt32(bytes1[i + 1]) << 16)
                | (UInt32(bytes1[i + 2]) << 8)
                | UInt32(bytes1[i + 3])
            )
            var existing = grams1.get(gram).or_else(0)
            grams1[gram] = existing + 1

        var grams2 = Dict[UInt32, Int]()
        var intersection: Int = 0

        for i in range(len2 - 3):
            var gram = (
                (UInt32(bytes2[i]) << 24)
                | (UInt32(bytes2[i + 1]) << 16)
                | (UInt32(bytes2[i + 2]) << 8)
                | UInt32(bytes2[i + 3])
            )
            var existing2 = grams2.get(gram).or_else(0)
            grams2[gram] = existing2 + 1

            var v = grams1.get(gram).or_else(0)
            if v > 0:
                var g2_val = grams2.get(gram).or_else(0)
                if g2_val <= v:
                    intersection += 1

        var total = len(grams1) + len(grams2)
        if total > 0:
            return Float64(intersection) / Float64(total)
        return 0.0
