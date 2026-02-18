namespace Benchmarks

open System
open System.Text

type Base64Encode() =
    inherit Benchmark()

    let mutable n = 0
    let mutable str2 = ""
    let mutable bytes : byte[] = [||]
    let mutable result = 0u

    override this.Checksum =
        let str = Encoding.UTF8.GetString(bytes)
        let resultStr = 
            if str.Length > 4 then
                $"encode {str.Substring(0, 4)}... to {str2.Substring(0, 4)}...: {result}"
            else
                $"encode {str} to {str2}: {result}"
        Helper.Checksum(resultStr)

    override this.Prepare() =
        n <- Helper.Config_i64("Base64Encode", "size") |> int
        let str = String('a', n)
        bytes <- Encoding.UTF8.GetBytes(str)
        str2 <- Convert.ToBase64String(bytes)
        result <- 0u

    override this.Run(IterationId: int64) =
        str2 <- Convert.ToBase64String(bytes)
        result <- result + uint32 str2.Length

type Base64Decode() =
    inherit Benchmark()

    let mutable n = 0
    let mutable str2 = ""
    let mutable bytes : byte[] = [||]
    let mutable result = 0u

    override this.Checksum =
        let str3 = Encoding.UTF8.GetString(bytes)
        let resultStr = 
            if str2.Length > 4 then
                $"decode {str2.Substring(0, 4)}... to {str3.Substring(0, 4)}...: {result}"
            else
                $"decode {str2} to {str3}: {result}"
        Helper.Checksum(resultStr)

    override this.Prepare() =
        n <- Helper.Config_i64("Base64Decode", "size") |> int
        let str = String('a', n)
        bytes <- Encoding.UTF8.GetBytes(str)
        str2 <- Convert.ToBase64String(bytes)
        result <- 0u

    override this.Run(IterationId: int64) =
        bytes <- Convert.FromBase64String(str2)
        result <- result + uint32 bytes.Length