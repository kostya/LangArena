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

const PATTERNS = [
    ("errors", r" [5][0-9]{2} "),
    ("bots", Regex("bot|crawler|scanner", "i")),
    ("suspicious", Regex("etc/passwd|wp-admin|\\.\\./", "i")),
    ("ips", r"\d{1,3}\.\d{1,3}\.\d{1,3}\.35"),
    ("api_calls", r"/api/[^ \"]+"),
    ("post_requests", r"POST [^ ]* HTTP"),
    ("auth_attempts", Regex("/login|/signin", "i")),
    ("methods", Regex("get|post", "i")),
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
    return "$(IPS[i % length(IPS) + 1]) - - [$(i % 31)/Oct/2023:13:55:36 +0000] \"$(METHODS[i % length(METHODS) + 1]) $(PATHS[i % length(PATHS) + 1]) HTTP/1.0\" $(STATUSES[i % length(STATUSES) + 1]) 2326 \"-\" \"$(AGENTS[i % length(AGENTS) + 1])\"\n"
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

    for (name, regex) in PATTERNS
        count = length(collect(eachmatch(regex, b.log)))
        matches[name] = count
    end

    total = Base.sum(values(matches))
    b.checksum_val += UInt32(total)
end

function checksum(b::LogParser)::UInt32
    return b.checksum_val
end
