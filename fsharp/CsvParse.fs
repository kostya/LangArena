namespace Benchmarks

open System
open System.Globalization
open System.Text
open CsvHelper
open CsvHelper.Configuration

type CsvParse() =
    inherit Benchmark()

    let mutable rows = 0
    let mutable data = ""
    let mutable result = 0u

    override this.Name = "CSV::Parse"

    override this.Prepare() =
        rows <- int (Helper.Config_i64("CSV::Parse", "rows"))
        data <- ""
        result <- 0u

        let sb = StringBuilder(rows * 50)

        for i in 0 .. rows - 1 do
            let c = char (int 'A' + (i % 26))
            let x = Helper.NextFloat(1.0)
            let z = Helper.NextFloat(1.0)
            let y = Helper.NextFloat(1.0)

            sb.Append($"\"point {c}\\n, \"\"{i % 100}\"\"\",") |> ignore
            sb.Append($"{x:F10},") |> ignore
            sb.Append(',') |> ignore
            sb.Append($"{z:F10},") |> ignore

            let flag = if i % 2 = 0 then "true" else "false"
            sb.Append($"\"[{flag}\\n, {i % 100}]\",") |> ignore

            sb.Append($"{y:F10}\n") |> ignore

        data <- sb.ToString()

    member private this.parsePoints(csvData: string) =
        use reader = new System.IO.StringReader(csvData)

        use csv =
            new CsvReader(
                reader,
                new CsvConfiguration(CultureInfo.InvariantCulture, HasHeaderRecord = false, Mode = CsvMode.RFC4180)
            )

        let points = ResizeArray()

        while csv.Read() do

            let x = csv.GetField<float>(1)
            let z = csv.GetField<float>(3)
            let y = csv.GetField<float>(5)
            points.Add((x, y, z))

        points.ToArray()

    override this.Run(iterationId: int64) =
        let points = this.parsePoints data

        if points.Length = 0 then
            ()

        let mutable xSum = 0.0
        let mutable ySum = 0.0
        let mutable zSum = 0.0

        for (x, y, z) in points do
            xSum <- xSum + x
            ySum <- ySum + y
            zSum <- zSum + z

        let count = float points.Length
        let xAvg = xSum / count
        let yAvg = ySum / count
        let zAvg = zSum / count

        result <- result + Helper.Checksum(xAvg) + Helper.Checksum(yAvg) + Helper.Checksum(zAvg)

    override this.Checksum = result
