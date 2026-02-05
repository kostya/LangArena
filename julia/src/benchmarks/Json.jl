using JSON
using JSON3
using StructTypes

mutable struct JsonGenerate <: AbstractBenchmark
    n::Int64
    data::Vector{Dict{String,Any}}
    text::IOBuffer
    result::UInt32
    prepared::Bool

    function JsonGenerate()
        n = Helper.config_i64("JsonGenerate", "coords")
        new(n, Vector{Dict{String,Any}}(), IOBuffer(), UInt32(0), false)
    end
end

name(b::JsonGenerate)::String = "JsonGenerate"

struct Coordinate
    x::Float64
    y::Float64
    z::Float64
    name::String
    opts::Dict{String,Vector{Any}}
end

StructTypes.StructType(::Type{Coordinate}) = StructTypes.Struct()
StructTypes.omitempties(::Type{Coordinate}) = (:opts,)

function prepare(b::JsonGenerate)
    if !b.prepared
        empty!(b.data)
        for _ in 1:b.n
            coord = Dict{String,Any}(
                "x" => round(Helper.next_float(), digits=8),
                "y" => round(Helper.next_float(), digits=8),
                "z" => round(Helper.next_float(), digits=8),
                "name" => "$(round(Helper.next_float(), digits=7)) $(Helper.next_int(Int32(10000)))",
                "opts" => Dict("1" => [1, true])
            )
            push!(b.data, coord)
        end
        b.prepared = true
    end
end

function run(b::JsonGenerate, iteration_id::Int64)

    prepare(b)

    io = b.text
    truncate(io, 0)
    seekstart(io)

    json_obj = Dict(
        "coordinates" => b.data,
        "info" => "some info"
    )

    json_str = JSON3.write(json_obj)
    write(io, json_str)

    seekstart(io)
    first_bytes = read(io, 15)
    if length(first_bytes) >= 15

        expected = UInt8['{', '"', 'c', 'o', 'o', 'r', 'd', 'i', 'n', 'a', 't', 'e', 's', '"', ':']
        if first_bytes == expected
            b.result += 1
        end
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

    seekstart(gen.text)
    b.text = String(take!(gen.text))
end

function calc_dom(text::String)::Tuple{Float64, Float64, Float64}

    json_obj = JSON.parse(text)

    coordinates = json_obj["coordinates"]
    len = length(coordinates)

    x_sum = y_sum = z_sum = 0.0

    for coord in coordinates
        x_sum += Float64(coord["x"])
        y_sum += Float64(coord["y"])
        z_sum += Float64(coord["z"])
    end

    return (x_sum / len, y_sum / len, z_sum / len)
end

function run(b::JsonParseDom, iteration_id::Int64)
    x, y, z = calc_dom(b.text)

    checksum_x = Helper.checksum_f64(x)
    checksum_y = Helper.checksum_f64(y)
    checksum_z = Helper.checksum_f64(z)

    b.result = (b.result + checksum_x + checksum_y + checksum_z) & 0xffffffff
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

name(b::JsonParseMapping)::String = "JsonParseMapping"

struct CoordinateMapping
    x::Float64
    y::Float64
    z::Float64
end

struct CoordinatesContainer
    coordinates::Vector{CoordinateMapping}
end

StructTypes.StructType(::Type{CoordinateMapping}) = StructTypes.Struct()
StructTypes.StructType(::Type{CoordinatesContainer}) = StructTypes.Struct()

function prepare(b::JsonParseMapping)

    gen = JsonGenerate()
    gen.n = b.n
    prepare(gen)
    run(gen, 0)

    seekstart(gen.text)
    b.text = String(take!(gen.text))
end

function calc_mapping(text::String)::Tuple{Float64, Float64, Float64}

    container = JSON3.read(text, CoordinatesContainer)
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