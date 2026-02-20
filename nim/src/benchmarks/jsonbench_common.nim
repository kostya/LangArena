import std/[strformat, json, math]
import jsony
import ../helper

type
  Coordinate = object
    x*, y*, z*: float
    name: string
    opts: JsonNode

  JsonData* = object
    coordinates*: seq[Coordinate]
    info: string

proc customRound(value: float, precision: int32): float =
  if classify(value) in {fcNan, fcInf, fcNegInf}:
    return value

  let factor = pow(10.0, float(precision))
  let scaled = value * factor

  let fraction = scaled - floor(scaled)

  if abs(fraction) < 0.5:
    result = floor(scaled) / factor
  elif abs(fraction) > 0.5:
    result = ceil(scaled) / factor
  else:
    result = (round(scaled / 2.0) * 2.0) / factor

proc generateJsonData*(n: int64): JsonData =
  result.coordinates = newSeq[Coordinate](n)
  result.info = "some info"

  for i in 0..<n:
    let x = customRound(nextFloat(), 8)
    let y = customRound(nextFloat(), 8)
    let z = customRound(nextFloat(), 8)

    let name = &"{nextFloat():.7f} {nextInt(10000)}"

    let opts = %* {"1": [1, true]}

    result.coordinates[i] = Coordinate(
      x: x, y: y, z: z,
      name: name,
      opts: opts
    )

proc getJsonText*(n: int64): string =
  let data = generateJsonData(n)
  result = data.toJson()
