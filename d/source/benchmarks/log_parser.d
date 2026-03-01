module benchmarks.logparser;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.regex;
import std.range;
import std.format;
import benchmark;
import helper;

class LogParser : Benchmark
{
private:
    static immutable string[] IPS = generateIPs();

    static string[] generateIPs()
    {
        string[] ips;
        for (int i = 1; i <= 255; i++)
        {
            ips ~= "192.168.1." ~ i.to!string;
        }
        return ips;
    }

    static immutable string[] METHODS = ["GET", "POST", "PUT", "DELETE"];
    static immutable string[] PATHS = [
        "/index.html", "/api/users", "/login", "/admin", "/images/logo.png",
        "/etc/passwd", "/wp-admin/setup.php"
    ];
    static immutable int[] STATUSES = [
        200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503
    ];
    static immutable string[] AGENTS = [
        "Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"
    ];

    static immutable string[] PATTERN_NAMES = [
        "errors", "bots", "suspicious", "ips", "api_calls", "post_requests",
        "auth_attempts", "methods"
    ];

    static immutable string[] PATTERN_STRS = [
        " [5][0-9]{2} ", "bot|crawler|scanner", "etc/passwd|wp-admin|\\.\\./",
        "\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.35", "/api/[^ \"]+",
        "POST [^ ]* HTTP", "/login|/signin", "get|post",
    ];

    static immutable string[] PATTERN_FLAGS = [
        "", "i", "i", "", "", "", "i", "i"
    ];

    int linesCount;
    string log;
    uint checksumVal;

protected:
    override string className() const
    {
        return "Etc::LogParser";
    }

    string generateLogLine(int i)
    {
        return format("%s - - [%d/Oct/2023:13:55:36 +0000] \"%s %s HTTP/1.0\" %d 2326 \"-\" \"%s\"\n",
                IPS[i % IPS.length], i % 31, METHODS[i % METHODS.length],
                PATHS[i % PATHS.length], STATUSES[i % STATUSES.length], AGENTS[i % AGENTS.length]);
    }

public:
    this()
    {
        linesCount = configVal("lines_count").to!int;
        checksumVal = 0;
        log = "";
    }

    override void prepare()
    {
        auto sb = appender!string();
        sb.reserve(linesCount * 150);

        for (int i = 0; i < linesCount; i++)
        {
            sb.put(generateLogLine(i));
        }

        log = sb.data;
    }

    override void run(int iterationId)
    {
        int[string] matches;

        foreach (name; PATTERN_NAMES)
        {
            matches[name] = 0;
        }

        for (int i = 0; i < PATTERN_NAMES.length; i++)
        {
            string name = PATTERN_NAMES[i];
            string patternStr = PATTERN_STRS[i];
            string flags = PATTERN_FLAGS[i];

            auto re = regex(patternStr, flags ~ "g");
            auto m = matchAll(log, re);
            matches[name] += cast(int) m.walkLength;
        }

        uint total = 0;
        foreach (count; matches)
        {
            total += cast(uint) count;
        }
        checksumVal += total;
    }

    override uint checksum()
    {
        return checksumVal;
    }
}
