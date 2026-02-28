using System.Text;
using System.Text.RegularExpressions;

public class LogParser : Benchmark
{
    private static readonly (string Name, Regex Pattern)[] PATTERNS = new[]
    {
        ("errors", new Regex(@" [5][0-9]{2} ", RegexOptions.Compiled)),
        ("bots", new Regex(@"bot|crawler|scanner", RegexOptions.Compiled | RegexOptions.IgnoreCase)),
        ("suspicious", new Regex(@"etc/passwd|wp-admin|\.\./", RegexOptions.Compiled | RegexOptions.IgnoreCase)),
        ("ips", new Regex(@"\d{1,3}\.\d{1,3}\.\d{1,3}\.35", RegexOptions.Compiled)),
        ("api_calls", new Regex(@"/api/[^ ""]+", RegexOptions.Compiled)),
        ("post_requests", new Regex(@"POST [^ ]* HTTP", RegexOptions.Compiled)),
        ("auth_attempts", new Regex(@"/login|/signin", RegexOptions.Compiled | RegexOptions.IgnoreCase)),
        ("methods", new Regex(@"get|post", RegexOptions.Compiled | RegexOptions.IgnoreCase))
    };

    private static readonly string[] IPS = Enumerable.Range(1, 255).Select(i => $"192.168.1.{i}").ToArray();
    private static readonly string[] METHODS = { "GET", "POST", "PUT", "DELETE" };
    private static readonly string[] PATHS =
    {
        "/index.html", "/api/users", "/login", "/admin",
        "/images/logo.png", "/etc/passwd", "/wp-admin/setup.php"
    };
    private static readonly int[] STATUSES = { 200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503 };
    private static readonly string[] AGENTS =
    {
        "Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"
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
        return $"{IPS[i % IPS.Length]} - - [{i % 31}/Oct/2023:13:55:36 +0000] \"{METHODS[i % METHODS.Length]} {PATHS[i % PATHS.Length]} HTTP/1.0\" {STATUSES[i % STATUSES.Length]} 2326 \"-\" \"{AGENTS[i % AGENTS.Length]}\"\n";
    }

    public override void Prepare()
    {
        var sb = new StringBuilder(_linesCount * 150);
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
            matches[name] = 0;
        }

        foreach (Match match in Regex.Matches(_log, @"^.*$", RegexOptions.Multiline))
        {
            string line = match.Value;
            foreach (var (name, pattern) in PATTERNS)
            {
                matches[name] += pattern.Matches(line).Count;
            }
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