using System.Text;
using System.Text.RegularExpressions;

public class LogParser : Benchmark
{
    private static readonly (string Name, Regex Pattern)[] PATTERNS = new[]
    {
        ("errors", new Regex(@" [5][0-9]{2} | [4][0-9]{2} ", RegexOptions.Compiled)),
        ("bots", new Regex(@"bot|crawler|scanner|spider|indexing|crawl|robot|spider", RegexOptions.Compiled | RegexOptions.IgnoreCase)),
        ("suspicious", new Regex(@"etc/passwd|wp-admin|\.\./", RegexOptions.Compiled | RegexOptions.IgnoreCase)),
        ("ips", new Regex(@"\d+\.\d+\.\d+\.35", RegexOptions.Compiled)),
        ("api_calls", new Regex(@"/api/[^ "" ]+", RegexOptions.Compiled)),
        ("post_requests", new Regex(@"POST [^ ]* HTTP", RegexOptions.Compiled)),
        ("auth_attempts", new Regex(@"/login|/signin", RegexOptions.Compiled | RegexOptions.IgnoreCase)),
        ("methods", new Regex(@"get|post|put", RegexOptions.Compiled | RegexOptions.IgnoreCase)),
        ("emails", new Regex(@"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", RegexOptions.Compiled)),
        ("passwords", new Regex(@"password=[^&\s""]+", RegexOptions.Compiled)),
        ("tokens", new Regex(@"token=[^&\s""]+|api[_-]?key=[^&\s""]+", RegexOptions.Compiled)),
        ("sessions", new Regex(@"session[_-]?id=[^&\s""]+", RegexOptions.Compiled)),
        ("peak_hours", new Regex(@"\[\d+/\w+/\d+:1[3-7]:\d+:\d+ [+\-]\d+\]", RegexOptions.Compiled))
    };

    private static readonly string[] IPS = Enumerable.Range(1, 255).Select(i => $"192.168.1.{i}").ToArray();
    private static readonly string[] METHODS = { "GET", "POST", "PUT", "DELETE" };
    private static readonly string[] PATHS =
    {
        "/index.html", "/api/users", "/admin",
        "/images/logo.png", "/etc/passwd", "/wp-admin/setup.php"
    };
    private static readonly int[] STATUSES = { 200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503 };
    private static readonly string[] AGENTS =
    {
        "Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"
    };
    private static readonly string[] USERS =
    {
        "john", "jane", "alex", "sarah", "mike", "anna", "david", "elena"
    };
    private static readonly string[] DOMAINS =
    {
        "example.com", "gmail.com", "yahoo.com", "hotmail.com", "company.org", "mail.ru"
    };

    private int _linesCount;
    private string _log;
    private uint _checksum;

    public LogParser()
    {
        _linesCount = (int)ConfigVal("lines_count");
        _checksum = 0;
        _log = "";
    }

    public override string TypeName => "Etc::LogParser";

    private string GenerateLogLine(int i)
    {
        var sb = new StringBuilder();

        sb.Append(IPS[i % IPS.Length]);
        sb.Append($" - - [{i % 31}/Oct/2023:{i % 60}:55:36 +0000] \"");
        sb.Append(METHODS[i % METHODS.Length]);
        sb.Append(' ');

        if (i % 3 == 0)
        {
            sb.Append($"/login?email={USERS[i % USERS.Length]}{i % 100}@{DOMAINS[i % DOMAINS.Length]}&password=secret{i % 10000}");
        }
        else if (i % 5 == 0)
        {
            sb.Append("/api/data?token=");
            for (int j = 0; j < (i % 3) + 1; j++)
            {
                sb.Append("abcdef123456");
            }
        }
        else if (i % 7 == 0)
        {
            sb.Append($"/user/profile?session_id=sess_{(i * 12345):x}");
        }
        else
        {
            sb.Append(PATHS[i % PATHS.Length]);
        }

        sb.Append($" HTTP/1.1\" {STATUSES[i % STATUSES.Length]} 2326 \"http://{DOMAINS[i % DOMAINS.Length]}\" \"{AGENTS[i % AGENTS.Length]}\"\n");

        return sb.ToString();
    }

    public override void Prepare()
    {
        var sb = new StringBuilder(_linesCount * 200);
        for (int i = 0; i < _linesCount; i++)
        {
            sb.Append(GenerateLogLine(i));
        }
        _log = sb.ToString();
    }

    public override void Run(long iterationId)
    {
        var matches = new Dictionary<string, int>();

        foreach (var (name, pattern) in PATTERNS)
        {
            matches[name] = pattern.Matches(_log).Count;
        }

        uint total = 0;
        foreach (var count in matches.Values)
        {
            total += (uint)count;
        }
        _checksum += total;
    }

    public override uint Checksum => _checksum;
}