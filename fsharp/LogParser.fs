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

    let PATTERNS = [|
        ("errors", @" [5][0-9]{2} ")
        ("bots", @"bot|crawler|scanner")
        ("suspicious", @"etc/passwd|wp-admin|\.\./")
        ("ips", @"\d{1,3}\.\d{1,3}\.\d{1,3}\.35")
        ("api_calls", @"/api/[^ ""]+")
        ("post_requests", @"POST [^ ]* HTTP")
        ("auth_attempts", @"/login|/signin")
        ("methods", @"get|post")
    |]

    let IPS = [| for i in 1 .. 255 -> sprintf "192.168.1.%d" i |]
    let METHODS = [| "GET"; "POST"; "PUT"; "DELETE" |]
    let PATHS = [| 
        "/index.html"; "/api/users"; "/login"; "/admin"
        "/images/logo.png"; "/etc/passwd"; "/wp-admin/setup.php" 
    |]
    let STATUSES = [| 200; 201; 301; 302; 400; 401; 403; 404; 500; 502; 503 |]
    let AGENTS = [| "Mozilla/5.0"; "Googlebot/2.1"; "curl/7.68.0"; "scanner/2.0" |]

    override _.Checksum = checksumVal
    override this.Name = "Etc::LogParser"

    member private this.generateLogLine(i: int) : string =
        sprintf "%s - - [%d/Oct/2023:13:55:36 +0000] \"%s %s HTTP/1.0\" %d 2326 \"-\" \"%s\"\n"
            (IPS.[i % IPS.Length])
            (i % 31)
            (METHODS.[i % METHODS.Length])
            (PATHS.[i % PATHS.Length])
            (STATUSES.[i % STATUSES.Length])
            (AGENTS.[i % AGENTS.Length])

    override this.Prepare() =
        linesCount <- Helper.Config_i64("Etc::LogParser", "lines_count")

        let sb = StringBuilder(int linesCount * 150)
        for i = 0 to (int linesCount - 1) do
            sb.Append(this.generateLogLine i) |> ignore

        log <- sb.ToString()

    override this.Run(iterationId: int64) =

        let compiledPatterns = 
            PATTERNS 
            |> Array.map (fun (name, pattern) -> 
                name, Regex(pattern, RegexOptions.Compiled ||| RegexOptions.IgnoreCase))

        let matches = 
            compiledPatterns
            |> Array.map (fun (name, regex) -> 
                let count = regex.Matches(log).Count  
                name, count)
            |> dict

        let total = matches.Values |> Seq.sum |> uint32
        checksumVal <- checksumVal + total