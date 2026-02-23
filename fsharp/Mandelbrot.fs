namespace Benchmarks

open System
open System.IO
open System.Text

type Mandelbrot() =
    inherit Benchmark()

    let [<Literal>] ITER = 50
    let [<Literal>] LIMIT = 2.0

    let mutable width = 0L
    let mutable height = 0L
    let resultStream = new MemoryStream()

    let inMandelbrotSet (x: int) (y: int) (w: int) (h: int) =
        let rec iterate zr zi cr ci i =
            if i >= ITER then true
            else
                let tr = zr * zr - zi * zi + cr
                let ti = 2.0 * zr * zi + ci
                if tr * tr + ti * ti > LIMIT * LIMIT then false
                else iterate tr ti cr ci (i + 1)

        let cr = 2.0 * float x / float w - 1.5
        let ci = 2.0 * float y / float h - 1.0
        iterate 0.0 0.0 cr ci 0

    let processRow y w h (byteAcc, bitNum) (stream: MemoryStream) =
        let folder (byteAcc, bitNum) x =
            let inSet = inMandelbrotSet x y w h

            let newByteAcc = byteAcc <<< 1 ||| (if inSet then 0x01uy else 0x00uy)
            let newBitNum = bitNum + 1

            if newBitNum = 8 then
                stream.WriteByte(newByteAcc)
                (0uy, 0)
            elif x = w - 1 then
                let finalByte = newByteAcc <<< (8 - w % 8)
                stream.WriteByte(finalByte)
                (0uy, 0)
            else
                (newByteAcc, newBitNum)

        Seq.fold folder (byteAcc, bitNum) [0..w-1]

    override _.Checksum = Helper.Checksum(resultStream.ToArray())
    override this.Name = "CLBG::Mandelbrot"

    override _.Prepare() =
        width <- Helper.Config_i64("CLBG::Mandelbrot", "w")
        height <- Helper.Config_i64("CLBG::Mandelbrot", "h")
        resultStream.SetLength(0L)

    override _.Run(IterationId: int64) =
        let w = int width
        let h = int height

        use writer = new StreamWriter(resultStream, Encoding.ASCII, 1024, true)
        writer.Write($"P4\n{w} {h}\n")
        writer.Flush()

        let initialState = (0uy, 0)

        let rec processRows y (byteAcc, bitNum) =
            if y >= h then ()
            else
                let newState = processRow y w h (byteAcc, bitNum) resultStream
                processRows (y + 1) newState

        processRows 0 initialState