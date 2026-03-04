using CSV
using Printf

mutable struct CsvParse <: AbstractBenchmark
    rows::Int64
    data::String
    result::UInt32

    function CsvParse()
        rows = Helper.config_i64("CSV::Parse", "rows")
        new(rows, "", UInt32(0))
    end
end

name(b::CsvParse)::String = "CSV::Parse"

function prepare(b::CsvParse)
    io = IOBuffer()
    for i = 0:(b.rows-1)
        c = Char('A' + (i % 26))
        x = Helper.next_float()
        z = Helper.next_float()
        y = Helper.next_float()

        write(io, "\"point $c\\n, \"\"$(i % 100)\"\"\",")
        write(io, @sprintf("%.10f,", x))
        write(io, ',')
        write(io, @sprintf("%.10f,", z))
        write(io, "\"[$(i % 2 == 0 ? "true" : "false")\\n, $(i % 100)]\",")
        write(io, @sprintf("%.10f\n", y))
    end
    b.data = String(take!(io))
end

struct Point
    x::Float64
    y::Float64
    z::Float64
end

function parse_points(data::String)::Vector{Point}
    io = IOBuffer(data)

    table = CSV.File(io; header = false, delim = ',', quotechar = '"')

    points = Point[]
    for row in table
        x = row[2]
        z = row[4]
        y = row[6]
        push!(points, Point(x, y, z))
    end

    return points
end

function run(b::CsvParse, iteration_id::Int64)
    points = parse_points(b.data)

    if isempty(points)
        return true
    end

    x_sum = y_sum = z_sum = 0.0
    for p in points
        x_sum += p.x
        y_sum += p.y
        z_sum += p.z
    end

    len = length(points)
    x_avg = x_sum / len
    y_avg = y_sum / len
    z_avg = z_sum / len

    checksum_x = Helper.checksum_f64(x_avg)
    checksum_y = Helper.checksum_f64(y_avg)
    checksum_z = Helper.checksum_f64(z_avg)

    b.result = (b.result + checksum_x + checksum_y + checksum_z) & 0xffffffff
    return true
end

function checksum(b::CsvParse)::UInt32
    return b.result
end
