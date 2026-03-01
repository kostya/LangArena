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
]

const PATTERNS = [
    r" [5][0-9]{2} ",
    Regex("bot|crawler|scanner", "i"),
    Regex("etc/passwd|wp-admin|\\.\\./", "i"),
    r"\d{1,3}\.\d{1,3}\.\d{1,3}\.35",
    r"/api/[^ \"]+",
    r"POST /[^ ]* HTTP",
    Regex("/login|/signin", "i"),
    Regex("get|post", "i"),
]

const IPS = ["192.168.1.$i" for i = 1:255]
const METHODS = ["GET", "POST", "PUT", "DELETE"]
const PATHS = [
    "/index.html",
    "/api/users",
    "/login",
    "/admin",
    "/images/logo.png",
    "/etc/passwd",
    "/wp-admin/setup.php",
]
const STATUSES = [200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503]
const AGENTS = ["Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"]

function generate_log_line(i::Int)::String
    idx = i - 1
    return "$(IPS[idx % length(IPS) + 1]) - - [$(idx % 31 + 1)/Oct/2023:13:55:36 +0000] \"$(METHODS[idx % length(METHODS) + 1]) $(PATHS[idx % length(PATHS) + 1]) HTTP/1.0\" $(STATUSES[idx % length(STATUSES) + 1]) 2326 \"-\" \"$(AGENTS[idx % length(AGENTS) + 1])\"\n"
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
