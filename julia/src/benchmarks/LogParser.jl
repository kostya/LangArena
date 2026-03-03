mutable struct LogParser <: AbstractBenchmark
    lines_count::Int64
    log::String
    checksum_val::UInt32

    function LogParser()
        lines_count = Helper.config_i64("Etc::LogParser", "lines_count")
        new(lines_count, "", UInt32(0))
    end
end

name(b::LogParser)::String = "Etc::LogParser"

const PATTERN_NAMES = [
    "errors",
    "bots",
    "suspicious",
    "ips",
    "api_calls",
    "post_requests",
    "auth_attempts",
    "methods",
    "emails",
    "passwords",
    "tokens",
    "sessions",
    "peak_hours",
]

const PATTERNS = [
    r" [5][0-9]{2} | [4][0-9]{2} ",
    Regex("bot|crawler|scanner|spider|indexing|crawl|robot|spider", "i"),
    Regex("etc/passwd|wp-admin|\\.\\./", "i"),
    r"\d+\.\d+\.\d+\.35",
    r"/api/[^ \" ]+",
    r"POST [^ ]* HTTP",
    Regex("/login|/signin", "i"),
    Regex("get|post|put", "i"),
    r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}",
    r"password=[^&\s\"]+",
    r"token=[^&\s\"]+|api[_-]?key=[^&\s\"]+",
    r"session[_-]?id=[^&\s\"]+",
    r"\[\d+/\w+/\d+:1[3-7]:\d+:\d+ [+\-]\d+\]",
]

const IPS = ["192.168.1.$i" for i = 1:255]
const METHODS = ["GET", "POST", "PUT", "DELETE"]
const PATHS = [
    "/index.html",
    "/api/users",
    "/admin",
    "/images/logo.png",
    "/etc/passwd",
    "/wp-admin/setup.php",
]
const STATUSES = [200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503]
const AGENTS = ["Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"]
const USERS = ["john", "jane", "alex", "sarah", "mike", "anna", "david", "elena"]
const DOMAINS =
    ["example.com", "gmail.com", "yahoo.com", "hotmail.com", "company.org", "mail.ru"]

function generate_log_line(i::Int)::String
    idx = i - 1
    result = IOBuffer()

    write(result, IPS[idx%length(IPS)+1])
    write(
        result,
        " - - [",
        string(idx % 31 + 1),
        "/Oct/2023:",
        string(idx % 60),
        ":55:36 +0000] \"",
    )
    write(result, METHODS[idx%length(METHODS)+1], " ")

    if idx % 3 == 0
        write(
            result,
            "/login?email=",
            USERS[idx%length(USERS)+1],
            string(idx % 100),
            "@",
            DOMAINS[idx%length(DOMAINS)+1],
            "&password=secret",
            string(idx % 10000),
        )
    elseif idx % 5 == 0
        write(result, "/api/data?token=")
        for _ = 1:((idx%3)+1)
            write(result, "abcdef123456")
        end
    elseif idx % 7 == 0
        write(result, "/user/profile?session_id=sess_", string(idx * 12345, base = 16))
    else
        write(result, PATHS[idx%length(PATHS)+1])
    end

    write(
        result,
        " HTTP/1.1\" ",
        string(STATUSES[idx%length(STATUSES)+1]),
        " 2326 \"http://",
        DOMAINS[idx%length(DOMAINS)+1],
        "\" \"",
        AGENTS[idx%length(AGENTS)+1],
        "\"\n",
    )

    return String(take!(result))
end

function prepare(b::LogParser)
    log_builder = IOBuffer()
    for i = 1:b.lines_count
        write(log_builder, generate_log_line(i))
    end
    b.log = String(take!(log_builder))
end

function run(b::LogParser, iteration_id::Int64)
    matches = Dict{String,Int}()

    for (idx, pattern) in enumerate(PATTERNS)
        name = PATTERN_NAMES[idx]
        count = length(collect(eachmatch(pattern, b.log)))
        matches[name] = count
    end

    total = 0
    for v in values(matches)
        total += v
    end

    b.checksum_val += UInt32(total)
end

function checksum(b::LogParser)::UInt32
    return b.checksum_val
end
