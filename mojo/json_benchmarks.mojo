from json import Value, deserialize_json, dumps, loads
from helper import Helper
from benchmark import Benchmark, Config


def build_json_tree(n: Int, mut helper: Helper) raises -> Value:
    var coords = Value.array()

    for _ in range(n):
        var coord = Value.object()
        coord.set("x", Value(round(helper.next_float(), 8)))
        coord.set("y", Value(round(helper.next_float(), 8)))
        coord.set("z", Value(round(helper.next_float(), 8)))
        coord.set(
            "name",
            Value(
                String("%.7f %d").format(
                    helper.next_float(), helper.next_int(10000)
                )
            ),
        )
        var pair = Value.array()
        pair.append(Value(1))
        pair.append(Value(True))
        var opts = Value.object()
        opts.set("1", pair^)
        coord.set("opts", opts^)
        coords.append(coord^)

    var root = Value.object()
    root.set("coordinates", coords^)
    root.set("info", Value("some info"))

    return root^


def generate_json_data(n: Int, mut helper: Helper) raises -> String:
    return dumps(build_json_tree(n, helper))


@fieldwise_init
struct Coordinate(Copyable):
    var x: Float64
    var y: Float64
    var z: Float64


@fieldwise_init
struct Coordinates:
    var coordinates: List[Coordinate]


struct JsonGenerate(Benchmark):
    var n: Int
    var result: UInt32
    var text: String
    var root: Value

    def __init__(out self, config: Config) raises:
        self.n = config.get_i64("Json::Generate", "coords")
        self.result = 0
        self.text = ""
        self.root = Value.object()

    def class_name(self) -> String:
        return "Json::Generate"

    def prepare(mut self, mut helper: Helper) raises:
        self.root = build_json_tree(self.n, helper)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.text = dumps(self.root)

        var prefix = '{"coordinates":'
        if self.text.startswith(prefix):
            self.result += 1

    def checksum(self) -> UInt32:
        return self.result


struct JsonParseDom(Benchmark):
    var n: Int
    var text: String
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.n = config.get_i64("Json::ParseDom", "coords")
        self.text = ""
        self.result = 0

    def class_name(self) -> String:
        return "Json::ParseDom"

    def prepare(mut self, mut helper: Helper) raises:
        self.text = generate_json_data(self.n, helper)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var data = loads(self.text)

        var coordinates = data["coordinates"]
        var len_coords = Float64(len(coordinates))

        var x_sum: Float64 = 0.0
        var y_sum: Float64 = 0.0
        var z_sum: Float64 = 0.0

        for coord in coordinates:
            x_sum += coord["x"].float_value()
            y_sum += coord["y"].float_value()
            z_sum += coord["z"].float_value()

        self.result += Helper.checksum_f64(x_sum / len_coords)
        self.result += Helper.checksum_f64(y_sum / len_coords)
        self.result += Helper.checksum_f64(z_sum / len_coords)

    def checksum(self) -> UInt32:
        return self.result


struct JsonParseMapping(Benchmark):
    var n: Int
    var text: String
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.n = config.get_i64("Json::ParseMapping", "coords")
        self.text = ""
        self.result = 0

    def class_name(self) -> String:
        return "Json::ParseMapping"

    def prepare(mut self, mut helper: Helper) raises:
        self.text = generate_json_data(self.n, helper)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var data = deserialize_json[Coordinates](self.text)

        ref coordinates = data.coordinates
        var len_coords = Float64(len(coordinates))

        var x_sum: Float64 = 0.0
        var y_sum: Float64 = 0.0
        var z_sum: Float64 = 0.0

        for coord in coordinates:
            x_sum += coord.x
            y_sum += coord.y
            z_sum += coord.z

        self.result += Helper.checksum_f64(x_sum / len_coords)
        self.result += Helper.checksum_f64(y_sum / len_coords)
        self.result += Helper.checksum_f64(z_sum / len_coords)

    def checksum(self) -> UInt32:
        return self.result
