from std.algorithm.functional import vectorize
from helper import Helper
from benchmark import Benchmark, Config


struct HashSHA256(Benchmark, Movable):
    var size: Int
    var data: List[UInt8]
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("Hash::SHA256", "size")
        self.data = List[UInt8]()
        self.result = 0

    def class_name(self) -> String:
        return "Hash::SHA256"

    def prepare(mut self, mut helper: Helper) raises:
        self.data = List[UInt8](capacity=self.size)
        for _ in range(self.size):
            self.data.append(UInt8(helper.next_int(256)))

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.result += Self._simple_sha256(self.data)

    def checksum(mut self) -> UInt32:
        return self.result

    @staticmethod
    def _simple_sha256(data: List[UInt8]) -> UInt32:
        var hashes = SIMD[DType.uint32, 8](
            0x6A09E667,
            0xBB67AE85,
            0x3C6EF372,
            0xA54FF53A,
            0x510E527F,
            0x9B05688C,
            0x1F83D9AB,
            0x5BE0CD19,
        )

        var data_ptr = data.unsafe_ptr()

        def hash_chunk[width: Int](i: Int) {imm data_ptr, mut hashes}:
            comptime if width == 8:
                var bytes = (
                    data_ptr.unsafe_offset(i)
                    .unsafe_load[width=8, alignment=1]()
                    .cast[DType.uint32]()
                )
                hashes = ((hashes << 5) + hashes) + bytes
                hashes = (hashes + (hashes << 10)) ^ (hashes >> 6)
            else:
                var hash_idx = i & 7
                var hash = hashes[hash_idx]
                hash = ((hash << 5) + hash) + UInt32(data_ptr[unsafe_offset=i])
                hash = (hash + (hash << 10)) ^ (hash >> 6)
                hashes[hash_idx] = hash

        vectorize[8](len(data), hash_chunk)

        var h0 = hashes[0]
        var b0 = (h0 >> 24) & 0xFF
        var b1 = (h0 >> 16) & 0xFF
        var b2 = (h0 >> 8) & 0xFF
        var b3 = h0 & 0xFF

        return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0


struct HashCRC32(Benchmark, Movable):
    var size: Int
    var data: List[UInt8]
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("Hash::CRC32", "size")
        self.data = List[UInt8]()
        self.result = 0

    def class_name(self) -> String:
        return "Hash::CRC32"

    def prepare(mut self, mut helper: Helper) raises:
        self.data = List[UInt8]()
        for _ in range(self.size):
            self.data.append(UInt8(helper.next_int(256)))

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.result += Self._crc32(self.data)

    def checksum(mut self) -> UInt32:
        return self.result

    @staticmethod
    def _crc32(data: List[UInt8]) -> UInt32:
        var crc: UInt32 = 0xFFFFFFFF

        for byte in data:
            crc = crc ^ UInt32(byte)
            for _ in range(8):
                if (crc & 1) != 0:
                    crc = (crc >> 1) ^ 0xEDB88320
                else:
                    crc = crc >> 1

        return crc ^ 0xFFFFFFFF
