from std.base64 import b64encode, b64decode
from helper import Helper
from benchmark import Benchmark, Config


struct Base64Encode(Benchmark):
    var n: Int
    var str: String
    var str2: String
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.n = config.get_i64("Base64::Encode", "size")
        self.str = ""
        self.str2 = ""
        self.result = 0

    def class_name(self) -> String:
        return "Base64::Encode"

    def prepare(mut self, mut helper: Helper) raises:
        self.str = "a" * self.n
        self.str2 = b64encode(self.str.as_bytes())

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.str2 = b64encode(self.str.as_bytes())
        self.result += UInt32(self.str2.byte_length())

    def checksum(mut self) -> UInt32:
        var prefix1 = ""
        var prefix2 = ""
        if self.str.byte_length() >= 4:
            prefix1 = (
                String(self.str[byte=0])
                + String(self.str[byte=1])
                + String(self.str[byte=2])
                + String(self.str[byte=3])
            )
        if self.str2.byte_length() >= 4:
            prefix2 = (
                String(self.str2[byte=0])
                + String(self.str2[byte=1])
                + String(self.str2[byte=2])
                + String(self.str2[byte=3])
            )
        var desc = String(
            "encode ", prefix1, "... to ", prefix2, "...: ", self.result
        )
        return Helper.checksum_string(desc)


struct Base64Decode(Benchmark):
    var n: Int
    var str2: String
    var str3: List[UInt8]
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.n = config.get_i64("Base64::Decode", "size")
        self.str2 = ""
        self.str3 = []
        self.result = 0

    def class_name(self) -> String:
        return "Base64::Decode"

    def prepare(mut self, mut helper: Helper) raises:
        var str = "a" * self.n
        self.str2 = b64encode(str.as_bytes())
        self.str3 = b64decode(StringSlice(self.str2))

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.str3 = b64decode(StringSlice(self.str2))
        self.result += UInt32(self.str3.byte_length())

    def checksum(mut self) -> UInt32:
        var prefix1 = ""
        var prefix2 = ""
        if self.str2.byte_length() >= 4:
            prefix1 = (
                String(self.str2[byte=0])
                + String(self.str2[byte=1])
                + String(self.str2[byte=2])
                + String(self.str2[byte=3])
            )
        if self.str3.byte_length() >= 4:
            prefix2 = (
                String(chr(Int(self.str3[0])))
                + String(chr(Int(self.str3[1])))
                + String(chr(Int(self.str3[2])))
                + String(chr(Int(self.str3[3])))
            )
        var desc = String(
            "decode ", prefix1, "... to ", prefix2, "...: ", self.result
        )
        return Helper.checksum_string(desc)
