using JSON3
using StructTypes
using Printf

struct Opts
    key1::Vector{Any}
end

struct Coordinate
    x::Float64
    y::Float64
    z::Float64
    name::String
    opts::Opts
end

struct CoordinatesContainer
    coordinates::Vector{Coordinate}
    info::String
end

StructTypes.StructType(::Type{Opts}) = StructTypes.Struct()
StructTypes.StructType(::Type{Coordinate}) = StructTypes.Struct()
StructTypes.StructType(::Type{CoordinatesContainer}) = StructTypes.Struct()

mutable struct JsonGenerate <: AbstractBenchmark
    n::Int64
    data::Vector{Coordinate}
    text::String
    result::UInt32

    function JsonGenerate()
        n = Helper.config_i64("JsonGenerate", "coords")
        new(n, Coordinate[], "", UInt32(0))
    end
end

name(b::JsonGenerate)::String = "JsonGenerate"

function prepare(b::JsonGenerate)
    if isempty(b.data)
        empty!(b.data)
        sizehint!(b.data, b.n)

        for _ in 1:b.n
            coord = Coordinate(
                round(Helper.next_float(), digits=8),
                round(Helper.next_float(), digits=8),
                round(Helper.next_float(), digits=8),
                @sprintf("%.7f %d", Helper.next_float(), Helper.next_int(Int32(10000))),
                Opts([1, true])
            )
            push!(b.data, coord)
        end
    end
end

function run(b::JsonGenerate, iteration_id::Int64)
    prepare(b)

    container = CoordinatesContainer(b.data, "some info")
    b.text = JSON3.write(container)

    if startswith(b.text, "{\"coordinates\":")
        b.result += 1
    end

    return true
end

function checksum(b::JsonGenerate)::UInt32
    return b.result
end

mutable struct JsonParseDom <: AbstractBenchmark
    text::String
    result::UInt32
    n::Int64

    function JsonParseDom()
        n = Helper.config_i64("JsonParseDom", "coords")
        new("", UInt32(0), n)
    end
end

name(b::JsonParseDom)::String = "JsonParseDom"

function prepare(b::JsonParseDom)
    gen = JsonGenerate()
    gen.n = b.n
    prepare(gen)
    run(gen, 0)
    b.text = gen.text
end

function calc_dom(text::String)::Tuple{Float64, Float64, Float64}

    json_obj = JSON3.read(text)
    coordinates = json_obj.coordinates
    len = length(coordinates)

    x_sum = y_sum = z_sum = 0.0

    for i in 1:len
        coord = coordinates[i]
        x_sum += coord.x
        y_sum += coord.y
        z_sum += coord.z
    end

    return (x_sum / len, y_sum / len, z_sum / len)
end

function run(b::JsonParseDom, iteration_id::Int64)
    x, y, z = calc_dom(b.text)

    checksum_x = Helper.checksum_f64(x)
    checksum_y = Helper.checksum_f64(y)
    checksum_z = Helper.checksum_f64(z)

    b.result = (b.result + checksum_x + checksum_y + checksum_z) & 0xffffffff
    return true
end

function checksum(b::JsonParseDom)::UInt32
    return b.result
end

mutable struct JsonParseMapping <: AbstractBenchmark
    text::String
    result::UInt32
    n::Int64

    function JsonParseMapping()
        n = Helper.config_i64("JsonParseMapping", "coords")
        new("", UInt32(0), n)
    end
end

struct CoordinateMapping
    x::Float64
    y::Float64
    z::Float64
end

struct CoordinatesContainerMapping
    coordinates::Vector{CoordinateMapping}
end

StructTypes.StructType(::Type{CoordinateMapping}) = StructTypes.Struct()
StructTypes.StructType(::Type{CoordinatesContainerMapping}) = StructTypes.Struct()

name(b::JsonParseMapping)::String = "JsonParseMapping"

function prepare(b::JsonParseMapping)
    gen = JsonGenerate()
    gen.n = b.n
    prepare(gen)
    run(gen, 0)
    b.text = gen.text
end

function calc_mapping(text::String)::Tuple{Float64, Float64, Float64}

    container = JSON3.read(text, CoordinatesContainerMapping)
    coordinates = container.coordinates
    len = length(coordinates)

    x_sum = y_sum = z_sum = 0.0

    for coord in coordinates
        x_sum += coord.x
        y_sum += coord.y
        z_sum += coord.z
    end

    return (x_sum / len, y_sum / len, z_sum / len)
end

function run(b::JsonParseMapping, iteration_id::Int64)
    x, y, z = calc_mapping(b.text)

    checksum_x = Helper.checksum_f64(x)
    checksum_y = Helper.checksum_f64(y)
    checksum_z = Helper.checksum_f64(z)

    b.result = (b.result + checksum_x + checksum_y + checksum_z) & 0xffffffff
end

function checksum(b::JsonParseMapping)::UInt32
    return b.result
end