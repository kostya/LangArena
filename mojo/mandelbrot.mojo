from helper import Helper
from benchmark import Benchmark, Config


struct Mandelbrot(Benchmark, Movable):
    var w: Int
    var h: Int
    var result_data: List[UInt8]
    var result_val: UInt32

    def __init__(out self, config: Config) raises:
        self.w = config.get_i64("CLBG::Mandelbrot", "w")
        self.h = config.get_i64("CLBG::Mandelbrot", "h")
        self.result_data = List[UInt8]()
        self.result_val = 0

    def class_name(self) -> String:
        return "CLBG::Mandelbrot"

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var header = (
            String("P4\n") + String(self.w) + " " + String(self.h) + "\n"
        )
        for b in header.as_bytes():
            self.result_data.append(b)

        comptime ITER: Int = 50
        comptime LIMIT: Float64 = 2.0
        comptime LIMIT_SQ = LIMIT * LIMIT

        var bit_num: Int = 0
        var byte_acc: UInt8 = 0

        for y in range(self.h):
            var ci = 2.0 * Float64(y) / Float64(self.h) - 1.0
            for x in range(self.w):
                var zr: Float64 = 0.0
                var zi: Float64 = 0.0
                var tr: Float64 = 0.0
                var ti: Float64 = 0.0
                var cr = 2.0 * Float64(x) / Float64(self.w) - 1.5

                var i = 0
                while i < ITER and tr + ti <= LIMIT_SQ:
                    zi = 2.0 * zr * zi + ci
                    zr = tr - ti + cr
                    tr = zr * zr
                    ti = zi * zi
                    i += 1

                byte_acc <<= 1
                if tr + ti <= LIMIT_SQ:
                    byte_acc |= 0x01

                bit_num += 1

                if bit_num == 8:
                    self.result_data.append(byte_acc)
                    byte_acc = 0
                    bit_num = 0
                elif x == self.w - 1:
                    byte_acc <<= UInt8(8 - (self.w % 8))
                    self.result_data.append(byte_acc)
                    byte_acc = 0
                    bit_num = 0

    def checksum(mut self) -> UInt32:
        var hash: UInt32 = 5381
        for b in self.result_data:
            hash = ((hash << 5) + hash) + UInt32(b)
        return hash
