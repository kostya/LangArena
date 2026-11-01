from moregex import Regex, count
from helper import Helper
from benchmark import Benchmark, Config


struct LogParser(Benchmark):
    comptime _PATTERNS = [
        Regex(r" [5][0-9]{2} | [4][0-9]{2} "),
        Regex(
            r"bot|crawler|scanner|spider|indexing|crawl|robot|spider",
            case_insensitive=True,
        ),
        Regex(r"etc/passwd|wp-admin|\.\./", case_insensitive=True),
        Regex(r"\d+\.\d+\.\d+\.35"),
        Regex(r'/api/[^ " ]+'),
        Regex(r"POST [^ ]* HTTP"),
        Regex(r"/login|/signin", case_insensitive=True),
        Regex(r"get|post|put", case_insensitive=True),
        Regex(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"),
        Regex(r'password=[^&\s"]+'),
        Regex(r'token=[^&\s"]+|api[_-]?key=[^&\s"]+'),
        Regex(r'session[_-]?id=[^&\s"]+'),
        Regex(r"\[\d+/\w+/\d+:1[3-7]:\d+:\d+ [+\-]\d+\]"),
    ]

    var lines_count: Int
    var log: String
    var _checksum: UInt32

    def __init__(out self, config: Config) raises:
        self.lines_count = config.get_i64("Etc::LogParser", "lines_count")
        self.log = ""
        self._checksum = 0

    def class_name(self) -> String:
        return "Etc::LogParser"

    def prepare(mut self, mut helper: Helper) raises:
        self.log = self._generate_log()

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        comptime for pattern in Self._PATTERNS:
            self._checksum += UInt32(count[pattern](self.log))

    def checksum(self) -> UInt32:
        return self._checksum

    def _generate_log(self) -> String:
        var ips = List[String]()
        for i in range(1, 256):
            ips.append(String("192.168.1.", i))

        var methods = ["GET", "POST", "PUT", "DELETE"]
        var paths = [
            "/index.html",
            "/api/users",
            "/admin",
            "/images/logo.png",
            "/etc/passwd",
            "/wp-admin/setup.php",
        ]
        var statuses = [200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503]
        var agents = [
            "Mozilla/5.0",
            "Googlebot/2.1",
            "curl/7.68.0",
            "scanner/2.0",
        ]
        var users = [
            "john",
            "jane",
            "alex",
            "sarah",
            "mike",
            "anna",
            "david",
            "elena",
        ]
        var domains = [
            "example.com",
            "gmail.com",
            "yahoo.com",
            "hotmail.com",
            "company.org",
            "mail.ru",
        ]

        var log = ""
        for i in range(self.lines_count):
            log += ips[i % len(ips)]
            log += " - - ["
            log += String(i % 31)
            log += "/Oct/2023:"
            log += String(i % 60)
            log += ':55:36 +0000] "'
            log += methods[i % len(methods)]
            log += " "

            if i % 3 == 0:
                log += "/login?email="
                log += users[i % len(users)]
                log += String(i % 100)
                log += "@"
                log += domains[i % len(domains)]
                log += "&password=secret"
                log += String(i % 10000)
            elif i % 5 == 0:
                log += "/api/data?token="
                var token = "abcdef123456"
                for _ in range((i % 3) + 1):
                    log += token
            elif i % 7 == 0:
                log += "/user/profile?session_id=sess_"
                log += Self._to_hex(i * 12345)
            else:
                log += paths[i % len(paths)]

            log += ' HTTP/1.1" '
            log += String(statuses[i % len(statuses)])
            log += ' 2326 "http://'
            log += domains[i % len(domains)]
            log += '" "'
            log += agents[i % len(agents)]
            log += '"\n'

        return log

    @staticmethod
    def _to_hex(value: Int) -> String:
        if value == 0:
            return "0"

        var hex_chars = "0123456789abcdef"
        var result = ""
        var v = value

        while v > 0:
            var digit = v & 15
            result = String(hex_chars[byte=digit]) + result
            v >>= 4

        return result
