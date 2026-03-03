namespace Benchmarks

open System
open System.IO
open System.Text
open System.Text.RegularExpressions

type LogParser() =
    inherit Benchmark()

    let mutable linesCount = 0L
    let mutable log = ""
    let mutable checksumVal = 0u

    let PATTERNS =
        [| ("errors", @" [5][0-9]{2} | [4][0-9]{2} ", RegexOptions.None)
           ("bots", @"bot|crawler|scanner|spider|indexing|crawl|robot|spider", RegexOptions.IgnoreCase)
           ("suspicious", @"etc/passwd|wp-admin|\.\./", RegexOptions.IgnoreCase)
           ("ips", @"\d+\.\d+\.\d+\.35", RegexOptions.None)
           ("api_calls", @"/api/[^ "" ]+", RegexOptions.None)
           ("post_requests", @"POST [^ ]* HTTP", RegexOptions.None)
           ("auth_attempts", @"/login|/signin", RegexOptions.IgnoreCase)
           ("methods", @"get|post|put", RegexOptions.IgnoreCase)
           ("emails", @"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", RegexOptions.None)
           ("passwords", @"password=[^&\s""]+", RegexOptions.None)
           ("tokens", @"token=[^&\s""]+|api[_-]?key=[^&\s""]+", RegexOptions.None)
           ("sessions", @"session[_-]?id=[^&\s""]+", RegexOptions.None)
           ("peak_hours", @"\[\d+/\w+/\d+:1[3-7]:\d+:\d+ [+\-]\d+\]", RegexOptions.None) |]

    let compiledPatterns =
        lazy
            (PATTERNS
             |> Array.map (fun (name, pattern, options) -> name, Regex(pattern, options ||| RegexOptions.Compiled)))

    let IPS = [| for i in 1..255 -> sprintf "192.168.1.%d" i |]
    let METHODS = [| "GET"; "POST"; "PUT"; "DELETE" |]

    let PATHS =
        [| "/index.html"
           "/api/users"
           "/admin"
           "/images/logo.png"
           "/etc/passwd"
           "/wp-admin/setup.php" |]

    let STATUSES = [| 200; 201; 301; 302; 400; 401; 403; 404; 500; 502; 503 |]
    let AGENTS = [| "Mozilla/5.0"; "Googlebot/2.1"; "curl/7.68.0"; "scanner/2.0" |]

    let USERS = [| "john"; "jane"; "alex"; "sarah"; "mike"; "anna"; "david"; "elena" |]

    let DOMAINS =
        [| "example.com"
           "gmail.com"
           "yahoo.com"
           "hotmail.com"
           "company.org"
           "mail.ru" |]

    override _.Checksum = checksumVal
    override this.Name = "Etc::LogParser"

    member private this.generateLogLine(i: int) : string =
        let sb = StringBuilder()

        sb.Append(IPS.[i % IPS.Length]) |> ignore

        sb.Append(sprintf " - - [%d/Oct/2023:%d:55:36 +0000] \"" (i % 31) (i % 60))
        |> ignore

        sb.Append(METHODS.[i % METHODS.Length]) |> ignore
        sb.Append(' ') |> ignore

        if i % 3 = 0 then
            sb.Append(
                sprintf
                    "/login?email=%s%d@%s&password=secret%d"
                    USERS.[i % USERS.Length]
                    (i % 100)
                    DOMAINS.[i % DOMAINS.Length]
                    (i % 10000)
            )
            |> ignore
        elif i % 5 = 0 then
            sb.Append("/api/data?token=") |> ignore

            for j = 0 to (i % 3) do
                sb.Append("abcdef123456") |> ignore
        elif i % 7 = 0 then
            sb.Append(sprintf "/user/profile?session_id=sess_%x" (i * 12345)) |> ignore
        else
            sb.Append(PATHS.[i % PATHS.Length]) |> ignore

        sb.Append(
            sprintf
                " HTTP/1.1\" %d 2326 \"http://%s\" \"%s\"\n"
                STATUSES.[i % STATUSES.Length]
                DOMAINS.[i % DOMAINS.Length]
                AGENTS.[i % AGENTS.Length]
        )
        |> ignore

        sb.ToString()

    override this.Prepare() =
        linesCount <- Helper.Config_i64("Etc::LogParser", "lines_count")

        let sb = StringBuilder(int linesCount * 200)

        for i = 0 to (int linesCount - 1) do
            sb.Append(this.generateLogLine i) |> ignore

        log <- sb.ToString()

        let _ = compiledPatterns.Force()
        ()

    override this.Run(iterationId: int64) =

        let matches = System.Collections.Generic.Dictionary<string, int>()

        for (name, regex) in compiledPatterns.Value do
            matches.[name] <- regex.Matches(log).Count

        let total = matches.Values |> Seq.sum |> uint32
        checksumVal <- checksumVal + total
