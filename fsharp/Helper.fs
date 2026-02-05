namespace Benchmarks

open System
open System.IO
open System.Text
open System.Text.Json

type Helper() =
    [<ThreadStatic; DefaultValue>]
    static val mutable private last: int64

    static let IM = 139968L
    static let IA = 3877L
    static let IC = 29573L
    static let INIT = 42L

    static let mutable config: JsonDocument = JsonDocument.Parse("{}")

    static member Config = config.RootElement

    static member Reset() = Helper.last <- INIT

    static member NextInt(max: int) : int =
        Helper.last <- (Helper.last * IA + IC) % IM
        int ((double Helper.last / double IM) * double max)

    static member NextInt(fromInclusive: int, toInclusive: int) : int =
        Helper.NextInt(toInclusive - fromInclusive + 1) + fromInclusive

    static member NextFloat(max: float) : float =
        Helper.last <- (Helper.last * IA + IC) % IM
        max * double Helper.last / double IM

    static member Checksum(s: string) : uint32 =
        let mutable hash = 5381u
        for b in Encoding.UTF8.GetBytes(s) do
            hash <- ((hash <<< 5) + hash) + uint32 b
        hash

    static member Checksum(bytes: byte[]) : uint32 =
        let mutable hash = 5381u
        for b in bytes do
            hash <- ((hash <<< 5) + hash) + uint32 b
        hash

    static member Checksum(v: float) : uint32 =
        Helper.Checksum(v.ToString("F7"))

    static member Config_i64(className: string, fieldName: string) : int64 =
        try
            let mutable benchObj = JsonElement()
            if Helper.Config.TryGetProperty(className, &benchObj) then
                let mutable value = JsonElement()
                if benchObj.TryGetProperty(fieldName, &value) then
                    value.GetInt64()
                else
                    Console.WriteLine($"Config not found for {className}, field: {fieldName}")
                    0L
            else
                Console.WriteLine($"Config not found for {className}, field: {fieldName}")
                0L
        with
        | ex ->
            Console.WriteLine($"Error in Config_i64: {ex.Message}")
            0L

    static member Config_s(className: string, fieldName: string) : string =
        try
            let mutable benchObj = JsonElement()
            if Helper.Config.TryGetProperty(className, &benchObj) then
                let mutable value = JsonElement()
                if benchObj.TryGetProperty(fieldName, &value) then
                    match value.GetString() with
                    | null -> ""
                    | s -> s
                else
                    Console.WriteLine($"Config not found for {className}, field: {fieldName}")
                    ""
            else
                Console.WriteLine($"Config not found for {className}, field: {fieldName}")
                ""
        with
        | ex ->
            Console.WriteLine($"Error in Config_s: {ex.Message}")
            ""

    static member LoadConfig(?filename: string) =
        let filename = defaultArg filename "test.js"

        let mutable foundFile = filename

        if not (File.Exists foundFile) then
            let alternatives = [
                Path.Combine("../", filename)
                Path.Combine("../../", filename)
                Path.GetFileName(filename)
            ]

            for alt in alternatives do
                if File.Exists alt then
                    foundFile <- alt

        if not (File.Exists foundFile) then
            Console.WriteLine($"Error: Config file not found: {filename}")
            Console.WriteLine($"Current directory: {Environment.CurrentDirectory}")
            config <- JsonDocument.Parse("{}")
        else
            try
                let jsonText = File.ReadAllText foundFile
                config <- JsonDocument.Parse jsonText
            with
            | ex -> 
                Console.WriteLine($"Error parsing JSON config: {ex.Message}")
                config <- JsonDocument.Parse("{}")