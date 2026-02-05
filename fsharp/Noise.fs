namespace Benchmarks

open System

[<Struct>]
type Vec2 = { X: float; Y: float }

[<AllowNullLiteral>]
type Noise2DContext(size: int) =
    let sizeMask = size - 1
    let rgradients = Array.init size (fun _ -> 
        let v = Helper.NextFloat(1.0) * Math.PI * 2.0
        { X = Math.Cos(v); Y = Math.Sin(v) })

    let permutations = 
        let arr = Array.init size id
        for i in 0..size-1 do
            let a = Helper.NextInt(size)
            let b = Helper.NextInt(size)
            let temp = arr.[a]
            arr.[a] <- arr.[b]
            arr.[b] <- temp
        arr

    static member inline gradient (orig: Vec2) (grad: Vec2) (p: Vec2) =
        let spX = p.X - orig.X
        let spY = p.Y - orig.Y
        grad.X * spX + grad.Y * spY

    static member inline lerp a b v = a * (1.0 - v) + b * v
    static member inline smooth v = v * v * (3.0 - 2.0 * v)

    member private this.getGradient x y =
        let idx = permutations.[x &&& sizeMask] + permutations.[y &&& sizeMask]
        rgradients.[idx &&& sizeMask]

    member this.Get(x: float, y: float) =
        let x0f = Math.Floor(x)
        let y0f = Math.Floor(y)
        let x0 = int x0f
        let y0 = int y0f
        let x1 = x0 + 1
        let y1 = y0 + 1

        let g00 = this.getGradient x0 y0
        let g10 = this.getGradient x1 y0
        let g01 = this.getGradient x0 y1
        let g11 = this.getGradient x1 y1

        let p = { X = x; Y = y }

        let v0 = Noise2DContext.gradient { X = x0f; Y = y0f } g00 p
        let v1 = Noise2DContext.gradient { X = x0f + 1.0; Y = y0f } g10 p
        let v2 = Noise2DContext.gradient { X = x0f; Y = y0f + 1.0 } g01 p
        let v3 = Noise2DContext.gradient { X = x0f + 1.0; Y = y0f + 1.0 } g11 p

        let fx = Noise2DContext.smooth (x - x0f)
        let vx0 = Noise2DContext.lerp v0 v1 fx
        let vx1 = Noise2DContext.lerp v2 v3 fx

        let fy = Noise2DContext.smooth (y - y0f)
        Noise2DContext.lerp vx0 vx1 fy

type Noise() =
    inherit Benchmark()

    [<Literal>]
    let symLength = 6
    let sym = [| ' '; '░'; '▒'; '▓'; '█'; '█' |]

    let mutable size = 0L
    let mutable result = 0u
    let mutable n2d : Noise2DContext = Unchecked.defaultof<Noise2DContext>

    override this.Checksum = result

    override this.Prepare() =
        size <- Helper.Config_i64("Noise", "size")
        result <- 0u
        n2d <- Noise2DContext(int size)

    override this.Run(IterationId: int64) =
        if not (obj.ReferenceEquals(n2d, null)) then
            let yAdd = float (IterationId * 128L) * 0.1
            let stepX = 0.1
            let stepY = 0.1

            let mutable yf = yAdd
            for y in 0L..size-1L do
                let mutable xf = 0.0
                for x in 0L..size-1L do
                    let v = n2d.Get(xf, yf) * 0.5 + 0.5

                    let idx = int (v * 5.0)
                    let idx' = if idx >= symLength then symLength - 1 else idx
                    result <- result + uint32 (int sym.[idx'])

                    xf <- xf + stepX
                yf <- yf + stepY