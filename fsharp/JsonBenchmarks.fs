namespace Benchmarks

open System
open System.Collections.Generic
open System.Text.Json
open System.Text.Json.Serialization

[<CLIMutable>]
type Coordinate = {
    [<JsonPropertyName("x")>] X: double
    [<JsonPropertyName("y")>] Y: double
    [<JsonPropertyName("z")>] Z: double
    [<JsonPropertyName("name")>] Name: string
    [<JsonPropertyName("opts")>] Opts: Dictionary<string, Tuple<int, bool>>
}

[<CLIMutable>]
type CoordinatesWrapper = {
    coordinates: Coordinate list
    info: string
}

module JsonGenerator =
    let generateData (n: int64) =

        [
            for i in 1L .. n do
                let x = Math.Round(Helper.NextFloat(1.0), 8)
                let y = Math.Round(Helper.NextFloat(1.0), 8)
                let z = Math.Round(Helper.NextFloat(1.0), 8)
                let name = String.Format("{0:F7} {1}", Helper.NextFloat(1.0), Helper.NextInt(10000))

                let opts = Dictionary<string, Tuple<int, bool>>()
                opts.["1"] <- Tuple.Create(1, true)

                { X = x; Y = y; Z = z; Name = name; Opts = opts }
        ]

    let serializeData (data: Coordinate list) =
        let wrapper = { coordinates = data; info = "some info" }
        let options = JsonSerializerOptions(WriteIndented = false)
        JsonSerializer.Serialize(wrapper, options)

type JsonGenerate() =
    inherit Benchmark()

    let mutable n = 0L
    let mutable data: Coordinate list = []
    let mutable result = 0u

    override this.Checksum = result
    override this.Name = "Json::Generate"

    override this.Prepare() =
        n <- Helper.Config_i64("Json::Generate", "coords")
        data <- JsonGenerator.generateData n
        result <- 0u

    override this.Run(IterationId: int64) =

        let json = JsonGenerator.serializeData data

        if json.StartsWith("{\"coordinates\":") then
            result <- result + 1u

    member _.GetJson() = JsonGenerator.serializeData data

type JsonParseDom() =
    inherit Benchmark()

    let mutable text = ""
    let mutable result = 0u

    let calc (text: string) =
        try
            use doc = JsonDocument.Parse(text)
            let root = doc.RootElement

            let mutable coordsElement = Unchecked.defaultof<JsonElement>
            if root.TryGetProperty("coordinates", &coordsElement) && 
               coordsElement.ValueKind = JsonValueKind.Array then

                let mutable x = 0.0
                let mutable y = 0.0
                let mutable z = 0.0
                let mutable count = 0

                for coord in coordsElement.EnumerateArray() do
                    let mutable xProp = Unchecked.defaultof<JsonElement>
                    let mutable yProp = Unchecked.defaultof<JsonElement>
                    let mutable zProp = Unchecked.defaultof<JsonElement>

                    if coord.TryGetProperty("x", &xProp) && xProp.ValueKind = JsonValueKind.Number then
                        x <- x + xProp.GetDouble()

                    if coord.TryGetProperty("y", &yProp) && yProp.ValueKind = JsonValueKind.Number then
                        y <- y + yProp.GetDouble()

                    if coord.TryGetProperty("z", &zProp) && zProp.ValueKind = JsonValueKind.Number then
                        z <- z + zProp.GetDouble()

                    count <- count + 1

                if count > 0 then
                    (x / double count, y / double count, z / double count)
                else
                    (0.0, 0.0, 0.0)
            else
                (0.0, 0.0, 0.0)
        with
        | _ -> (0.0, 0.0, 0.0)

    override this.Checksum = result
    override this.Name = "Json::ParseDom"

    override this.Prepare() =
        text <- ""
        result <- 0u

        let n = Helper.Config_i64("Json::ParseDom", "coords")
        let data = JsonGenerator.generateData n
        text <- JsonGenerator.serializeData data

    override this.Run(IterationId: int64) =
        let (x, y, z) = calc text
        result <- result + Helper.Checksum(x) + Helper.Checksum(y) + Helper.Checksum(z)

type JsonParseMapping() =
    inherit Benchmark()

    let mutable text = ""
    let mutable result = 0u

    let calcWithReader (json: string) =
        let data = System.Text.Encoding.UTF8.GetBytes(json)
        let reader = Utf8JsonReader(data)

        let mutable sumX = 0.0
        let mutable sumY = 0.0
        let mutable sumZ = 0.0
        let mutable count = 0
        let mutable found = false

        try
            while reader.Read() && not found do
                if reader.TokenType = JsonTokenType.PropertyName && 
                   reader.ValueTextEquals("coordinates".AsSpan()) then
                    reader.Read() |> ignore 

                    while reader.TokenType <> JsonTokenType.EndArray do
                        if reader.TokenType = JsonTokenType.StartObject then
                            let mutable x = 0.0
                            let mutable y = 0.0
                            let mutable z = 0.0
                            let mutable hasX = false
                            let mutable hasY = false
                            let mutable hasZ = false

                            while reader.TokenType <> JsonTokenType.EndObject do
                                reader.Read() |> ignore
                                if reader.TokenType = JsonTokenType.PropertyName then
                                    if reader.ValueTextEquals("x".AsSpan()) then
                                        reader.Read() |> ignore
                                        x <- reader.GetDouble()
                                        hasX <- true
                                    elif reader.ValueTextEquals("y".AsSpan()) then
                                        reader.Read() |> ignore
                                        y <- reader.GetDouble()
                                        hasY <- true
                                    elif reader.ValueTextEquals("z".AsSpan()) then
                                        reader.Read() |> ignore
                                        z <- reader.GetDouble()
                                        hasZ <- true
                                    else
                                        reader.Read() |> ignore
                                        reader.Skip() |> ignore

                            if hasX && hasY && hasZ then
                                sumX <- sumX + x
                                sumY <- sumY + y
                                sumZ <- sumZ + z
                                count <- count + 1

                            reader.Read() |> ignore 
                        else
                            reader.Read() |> ignore
                    found <- true
            if count > 0 then
                (sumX / double count, sumY / double count, sumZ / double count)
            else
                (0.0, 0.0, 0.0)
        with
        | _ -> (0.0, 0.0, 0.0)

    override this.Checksum = result
    override this.Name = "Json::ParseMapping"

    override this.Prepare() =
        text <- ""
        result <- 0u

        let n = Helper.Config_i64("Json::ParseMapping", "coords")
        let data = JsonGenerator.generateData n
        text <- JsonGenerator.serializeData data

    override this.Run(IterationId: int64) =
        let (x, y, z) = calcWithReader text
        result <- result + Helper.Checksum(x) + Helper.Checksum(y) + Helper.Checksum(z)