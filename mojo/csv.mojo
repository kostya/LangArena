from mojo_csv import CsvReader
from helper import Helper
from benchmark import Benchmark, Config

@fieldwise_init
struct CsvPoint(Copyable):
    var x: Float64
    var y: Float64
    var z: Float64


struct CsvParse(Benchmark):
    var rows: Int
    var _checksum: UInt32
    var data: String

    def __init__(out self, config: Config) raises:
        self.rows = config.get_i64("CSV::Parse", "rows")
        self._checksum = 0
        self.data = ""

    def class_name(self) -> String:
        return "CSV::Parse"

    def prepare(mut self, mut helper: Helper) raises:
        self.data = ""
        for i in range(self.rows):
            var c = chr(65 + (i % 26))
            var x = helper.next_float()
            var z = helper.next_float()
            var y = helper.next_float()

            var flag = "true" if i % 2 == 0 else "false"
            self.data += String(
                t'"point {c}\\n, ""{i % 100}""",{Self._format_f64(x)},,'
                t'{Self._format_f64(z)},"[{flag}\\n, {i % 100}]",'
                t'{Self._format_f64(y)}\n'
            )

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var reader = CsvReader(
            List[String](), col_count=6, has_header=False, num_threads=1
        )
        reader.raw = self.data
        reader.raw_length = reader.raw.byte_length()
        reader._create_threaded_reader()
        reader.length = len(reader.elements)

        var points = List[CsvPoint](capacity=self.rows)

        for row in range(reader.row_count):
            if reader.col_count >= 6:
                var offset = row * reader.col_count
                var x = atof(StringSlice(reader.elements[offset + 1]))
                var z = atof(StringSlice(reader.elements[offset + 3]))
                var y = atof(StringSlice(reader.elements[offset + 5]))

                points.append(CsvPoint(x, y, z))

        if len(points) == 0:
            return

        var x_sum: Float64 = 0.0
        var y_sum: Float64 = 0.0
        var z_sum: Float64 = 0.0

        for point in points:
            x_sum += point.x
            y_sum += point.y
            z_sum += point.z

        var count = len(points)
        var x_avg = x_sum / Float64(count)
        var y_avg = y_sum / Float64(count)
        var z_avg = z_sum / Float64(count)

        self._checksum += Helper.checksum_f64(x_avg)
        self._checksum += Helper.checksum_f64(y_avg)
        self._checksum += Helper.checksum_f64(z_avg)

    def checksum(self) -> UInt32:
        return self._checksum + Helper.checksum_string(self.data)

    @staticmethod
    def _format_f64(v: Float64) -> String:
        var result = ""
        var val = v
        if val < 0:
            result += "-"
            val = -val
        var int_part = Int(val)
        result += String(int_part)
        result += "."
        var frac_scaled = Int((val - Float64(int_part)) * 10000000000.0 + 0.5)
        var fs = String(frac_scaled)
        while fs.byte_length() < 10:
            fs = "0" + fs
        result += fs
        return result
