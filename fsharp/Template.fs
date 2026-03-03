namespace Benchmarks

open System
open System.Text
open System.Text.RegularExpressions

module TemplateConstants =
    let FIRST_NAMES =
        [| "John"; "Jane"; "Bob"; "Alice"; "Charlie"; "Diana"; "Sarah"; "Mike" |]

    let LAST_NAMES =
        [| "Smith"
           "Johnson"
           "Brown"
           "Taylor"
           "Wilson"
           "Davis"
           "Miller"
           "Jones" |]

    let CITIES =
        [| "New York"
           "Los Angeles"
           "Chicago"
           "Houston"
           "Phoenix"
           "San Francisco" |]

    let LOREM =
        "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. "

[<AbstractClass>]
type TemplateBase() =
    inherit Benchmark()

    let mutable count = 0L
    let mutable text = ""
    let mutable rendered = ""
    let mutable checksumVal = 0u
    let vars = System.Collections.Generic.Dictionary<string, string>()

    member this.Count
        with get () = count
        and set (v) = count <- v

    member this.Text
        with get () = text
        and set (v) = text <- v

    member this.Rendered
        with get () = rendered
        and set (v) = rendered <- v

    member this.ChecksumVal
        with get () = checksumVal
        and set (v) = checksumVal <- v

    member this.Vars = vars

    member this.PrepareBase() =
        this.Vars.Clear()
        let sb = StringBuilder(this.Count * 200L |> int)

        sb.Append("<html><body>") |> ignore
        sb.Append("<h1>{{TITLE}}</h1>") |> ignore
        this.Vars.["TITLE"] <- "Template title"
        sb.Append("<p>") |> ignore
        sb.Append(TemplateConstants.LOREM) |> ignore
        sb.Append("</p>") |> ignore
        sb.Append("<table>") |> ignore

        for i = 0 to (int this.Count - 1) do
            if i % 3 = 0 then
                sb.Append("<!-- {comment} -->") |> ignore

            sb.Append("<tr>") |> ignore
            sb.Append(sprintf "<td>{{ FIRST_NAME%d }}</td>" i) |> ignore
            sb.Append(sprintf "<td>{{LAST_NAME%d}}</td>" i) |> ignore
            sb.Append(sprintf "<td>{{  CITY%d  }}</td>" i) |> ignore

            this.Vars.[sprintf "FIRST_NAME%d" i] <-
                TemplateConstants.FIRST_NAMES.[i % TemplateConstants.FIRST_NAMES.Length]

            this.Vars.[sprintf "LAST_NAME%d" i] <-
                TemplateConstants.LAST_NAMES.[i % TemplateConstants.LAST_NAMES.Length]

            this.Vars.[sprintf "CITY%d" i] <- TemplateConstants.CITIES.[i % TemplateConstants.CITIES.Length]

            sb.Append(sprintf "<td>{balance: %d}</td>" (i % 100)) |> ignore
            sb.Append("</tr>\n") |> ignore

        sb.Append("</table>") |> ignore
        sb.Append("</body></html>") |> ignore

        this.Text <- sb.ToString()

    member this.UpdateChecksum() =
        this.ChecksumVal <- this.ChecksumVal + uint32 this.Rendered.Length

    override this.Checksum = this.ChecksumVal + Helper.Checksum(this.Rendered)

type TemplateRegex() =
    inherit TemplateBase()

    let regex = Regex(@"\{\{\s*(.*?)\s*\}\}", RegexOptions.Compiled)

    override this.Prepare() =
        this.Count <- Helper.Config_i64(this.Name, "count")
        this.PrepareBase()

    override this.Run(iterationId: int64) =
        let sb = StringBuilder(this.Text.Length)
        let mutable lastPos = 0

        for mtch in regex.Matches(this.Text) do

            if mtch.Index > lastPos then
                sb.Append(this.Text.Substring(lastPos, mtch.Index - lastPos)) |> ignore

            let key = mtch.Groups.[1].Value.Trim()

            match this.Vars.TryGetValue(key) with
            | true, value -> sb.Append(value) |> ignore
            | _ -> ()

            lastPos <- mtch.Index + mtch.Length

        if lastPos < this.Text.Length then
            sb.Append(this.Text.Substring(lastPos)) |> ignore

        this.Rendered <- sb.ToString()
        this.UpdateChecksum()

    override this.Name = "Template::Regex"

type TemplateParse() =
    inherit TemplateBase()

    override this.Prepare() =
        this.Count <- Helper.Config_i64(this.Name, "count")
        this.PrepareBase()

    override this.Run(iterationId: int64) =
        let len = this.Text.Length
        let sb = StringBuilder(float len * 1.5 |> int)

        let rec parse i =
            if i >= len then
                i
            elif i + 1 < len && this.Text.[i] = '{' && this.Text.[i + 1] = '{' then
                let mutable j = i + 2
                let mutable found = false

                while j + 1 < len && not found do
                    if this.Text.[j] = '}' && this.Text.[j + 1] = '}' then
                        found <- true
                    else
                        j <- j + 1

                if found && j + 1 < len then
                    let key = this.Text.Substring(i + 2, j - i - 2).Trim()

                    match this.Vars.TryGetValue(key) with
                    | true, value -> sb.Append(value) |> ignore
                    | _ -> ()

                    j + 2
                else
                    sb.Append(this.Text.[i]) |> ignore
                    i + 1
            else
                sb.Append(this.Text.[i]) |> ignore
                i + 1

        let mutable pos = 0

        while pos < len do
            pos <- parse pos

        this.Rendered <- sb.ToString()
        this.UpdateChecksum()

    override this.Name = "Template::Parse"
