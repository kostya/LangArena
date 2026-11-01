from json import Value, loads
from helper import Helper


struct ConfigEntry(Copyable):
    var name: String
    var fields: Value

    def __init__(out self, var fields: Value) raises:
        self.name = fields["name"].as_string()
        self.fields = fields^


struct Config(Copyable):
    var entries: List[ConfigEntry]

    def __init__(out self, path: String) raises:
        with open(path, "r") as f:
            var raw = f.read()
            var data = loads(raw)
            self.entries = [ConfigEntry(item^) for item in data]


    def _get_field(
        self, class_name: String, field_name: String
    ) raises -> Value:
        for entry in self.entries:
            if entry.name == class_name:
                if field_name in entry.fields:
                    return entry.fields[field_name]
                raise Error(
                    String("field not found: ", field_name, " in ", class_name)
                )
        raise Error(String("class not found: ", class_name))

    def get_i64(self, class_name: String, field_name: String) raises -> Int:
        return Int(self._get_field(class_name, field_name).as_int())

    def get_s(self, class_name: String, field_name: String) raises -> String:
        return self._get_field(class_name, field_name).as_string()


trait Benchmark:
    def prepare(mut self, mut helper: Helper) raises:
        pass

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        ...

    def checksum(mut self) -> UInt32:
        ...

    def warmup_iterations(mut self, config: Config) raises -> Int:
        try:
            return config.get_i64(self.class_name(), "warmup_iterations")
        except:
            var iters = self.iterations(config)
            var w = Int(Float64(iters) * 0.2)
            return 1 if w < 1 else w

    def warmup(mut self, warmup_iters: Int, mut helper: Helper) raises:
        for i in range(warmup_iters):
            self.run(i, helper)

    def iterations(self, config: Config) raises -> Int:
        return config.get_i64(self.class_name(), "iterations")

    def expected_checksum(self, config: Config) raises -> UInt32:
        return UInt32(config.get_i64(self.class_name(), "checksum"))

    def class_name(self) -> String:
        ...
