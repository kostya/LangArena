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
        "/index.html", "/api/users", "/admin", "/images/logo.png",
        "/etc/passwd", "/wp-admin/setup.php"
    ];
    static immutable int[] STATUSES = [
        200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503
    ];
    static immutable string[] AGENTS = [
        "Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"
    ];
    static immutable string[] USERS = [
        "john", "jane", "alex", "sarah", "mike", "anna", "david", "elena"
    ];
    static immutable string[] DOMAINS = [
        "example.com", "gmail.com", "yahoo.com", "hotmail.com", "company.org",
        "mail.ru"
    ];

    static immutable Regex!char[] PATTERNS = [
        regex(" [5][0-9]{2} | [4][0-9]{2} "),
        regex("bot|crawler|scanner|spider|indexing|crawl|robot|spider", "i"),
        regex("etc/passwd|wp-admin|\\.\\./", "i"),
        regex("\\d+\\.\\d+\\.\\d+\\.35"), regex("/api/[^ \" ]+"),
        regex("POST [^ ]* HTTP"), regex("/login|/signin", "i"),
        regex("get|post|put", "i"),
        regex("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"),
        regex("password=[^&\\s\"]+"),
        regex("token=[^&\\s\"]+|api[_-]?key=[^&\\s\"]+"),
        regex("session[_-]?id=[^&\\s\"]+"),
        regex("\\[\\d+/\\w+/\\d+:1[3-7]:\\d+:\\d+ [+\\-]\\d+\\]")
    ];

    static immutable string[] PATTERN_NAMES = [
        "errors", "bots", "suspicious", "ips", "api_calls", "post_requests",
        "auth_attempts", "methods", "emails", "passwords", "tokens", "sessions",
        "peak_hours"
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
        string result;

        result ~= IPS[i % IPS.length];
        result ~= format(" - - [%d/Oct/2023:%d:55:36 +0000] \"%s ", i % 31,
                i % 60, METHODS[i % METHODS.length]);

        if (i % 3 == 0)
        {
            result ~= format("/login?email=%s%d@%s&password=secret%d",
                    USERS[i % USERS.length], i % 100, DOMAINS[i % DOMAINS.length], i % 10000);
        }
        else if (i % 5 == 0)
        {
            result ~= "/api/data?token=";
            for (int j = 0; j < (i % 3) + 1; j++)
            {
                result ~= "abcdef123456";
            }
        }
        else if (i % 7 == 0)
        {
            result ~= format("/user/profile?session_id=sess_%x", i * 12345);
        }
        else
        {
            result ~= PATHS[i % PATHS.length];
        }

        result ~= format(" HTTP/1.1\" %d 2326 \"http://%s\" \"%s\"\n",
                STATUSES[i % STATUSES.length], DOMAINS[i % DOMAINS.length],
                AGENTS[i % AGENTS.length]);

        return result;
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
        sb.reserve(linesCount * 200);

        for (int i = 0; i < linesCount; i++)
        {
            sb.put(generateLogLine(i));
        }

        log = sb.data;
    }

    override void run(int iterationId)
    {
        int[string] matches;

        for (int i = 0; i < PATTERNS.length; i++)
        {
            auto m = matchAll(log, PATTERNS[i]);
            matches[PATTERN_NAMES[i]] = cast(int) m.walkLength;
        }

        uint total = 0;
        foreach (count; matches.byValue())
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
