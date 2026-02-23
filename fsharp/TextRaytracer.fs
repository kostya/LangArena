namespace Benchmarks

open System

[<Struct>]
type Vector =
    val X: double
    val Y: double
    val Z: double

    new(x, y, z) = { X = x; Y = y; Z = z }

    member this.Scale(s: double) = Vector(this.X * s, this.Y * s, this.Z * s)
    member this.Add(other: Vector) = Vector(this.X + other.X, this.Y + other.Y, this.Z + other.Z)
    member this.Subtract(other: Vector) = Vector(this.X - other.X, this.Y - other.Y, this.Z - other.Z)
    member this.Dot(other: Vector) = this.X * other.X + this.Y * other.Y + this.Z * other.Z
    member this.Magnitude = sqrt(this.Dot(this))
    member this.Normalize() = this.Scale(1.0 / this.Magnitude)

[<Struct>]
type Ray =
    val Orig: Vector
    val Dir: Vector
    new(orig, dir) = { Orig = orig; Dir = dir }

[<Struct>]
type Color =
    val R: double
    val G: double
    val B: double

    new(r, g, b) = { R = r; G = g; B = b }

    member this.Scale(s: double) = Color(this.R * s, this.G * s, this.B * s)
    member this.Add(other: Color) = Color(this.R + other.R, this.G + other.G, this.B + other.B)

[<Struct>]
type Sphere =
    val Center: Vector
    val Radius: double
    val SphereColor: Color

    new(center, radius, color) = 
        { Center = center; Radius = radius; SphereColor = color }

    member this.GetNormal(pt: Vector) = 
        pt.Subtract(this.Center).Normalize()

[<Struct>]
type Light =
    val Position: Vector
    val LightColor: Color

    new(position, color) = 
        { Position = position; LightColor = color }

type TextRaytracer() =
    inherit Benchmark()

    let WHITE = Color(1.0, 1.0, 1.0)
    let RED = Color(1.0, 0.0, 0.0)
    let GREEN = Color(0.0, 1.0, 0.0)
    let BLUE = Color(0.0, 0.0, 1.0)

    let LIGHT1 = Light(Vector(0.7, -1.0, 1.7), WHITE)
    let LUT = [| '.'; '-'; '+'; '*'; 'X'; 'M' |]

    let SCENE = [|
        Sphere(Vector(-1.0, 0.0, 3.0), 0.3, RED)
        Sphere(Vector(0.0, 0.0, 3.0), 0.8, GREEN)
        Sphere(Vector(1.0, 0.0, 3.0), 0.4, BLUE)
    |]

    let mutable w = 0
    let mutable h = 0
    let mutable result = 0u

    let shadePixel (ray: Ray) (obj: Sphere) (tval: double) =
        let pi = ray.Orig.Add(ray.Dir.Scale(tval))

        let n = obj.GetNormal(pi)
        let lightDir = LIGHT1.Position.Subtract(pi).Normalize()
        let lam1 = lightDir.Dot(n)
        let lam2 = 
            if lam1 < 0.0 then 0.0
            elif lam1 > 1.0 then 1.0
            else lam1

        let color = LIGHT1.LightColor.Scale(lam2 * 0.5).Add(obj.SphereColor.Scale(0.3))
        let col = (color.R + color.G + color.B) / 3.0

        let idx = int(col * 6.0)
        if idx < 0 then 0
        elif idx >= 6 then 5
        else idx

    let intersectSphere (ray: Ray) (center: Vector) (radius: double) =
        let l = center.Subtract(ray.Orig)
        let tca = l.Dot(ray.Dir)

        if tca < 0.0 then None
        else
            let d2 = l.Dot(l) - tca * tca
            let r2 = radius * radius

            if d2 > r2 then None
            else
                let thc = sqrt(r2 - d2)
                let t0 = tca - thc

                if t0 > 10000.0 then None
                else Some t0

    override this.Checksum = result
    override this.Name = "Etc::TextRaytracer"

    override this.Prepare() =
        w <- int (this.ConfigVal("w"))
        h <- int (this.ConfigVal("h"))
        result <- 0u

    override this.Run(_: int64) =
        let fw = double w
        let fh = double h

        for j = 0 to h - 1 do
            let fj = double j

            for i = 0 to w - 1 do
                let fi = double i

                let dirTmp = Vector((fi - fw / 2.0) / fw, (fj - fh / 2.0) / fh, 1.0)
                let dir = dirTmp.Normalize()

                let ray = Ray(Vector(0.0, 0.0, 0.0), dir)

                let mutable hitObj = None
                let mutable tval = None
                let mutable found = false

                for k = 0 to SCENE.Length - 1 do
                    if not found then
                        let obj = SCENE.[k]
                        match intersectSphere ray obj.Center obj.Radius with
                        | Some t ->
                            hitObj <- Some obj
                            tval <- Some t
                            found <- true
                        | None -> ()

                match hitObj, tval with
                | Some obj, Some t ->
                    let shadeIdx = shadePixel ray obj t
                    result <- result + uint32 (int LUT.[shadeIdx])
                | _ ->
                    result <- result + uint32 ' '