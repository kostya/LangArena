mutable struct Mandelbrot <: AbstractBenchmark
    w::Int64
    h::Int64
    io::IOBuffer

    function Mandelbrot()
        w = Helper.config_i64("Mandelbrot", "w")
        h = Helper.config_i64("Mandelbrot", "h")
        new(w, h, IOBuffer())
    end
end

name(b::Mandelbrot)::String = "Mandelbrot"

function run(b::Mandelbrot, iteration_id::Int64)
    ITER = 50
    LIMIT = 2.0
    LIMIT_SQ = LIMIT * LIMIT

    io = b.io

    write(io, "P4\n$(b.w) $(b.h)\n")

    bit_num = 0
    byte_acc = UInt8(0)

    h = b.h
    w = b.w

    for y in 0:h-1
        ci = (2.0 * y / h - 1.0)

        for x in 0:w-1
            cr = (2.0 * x / w - 1.5)

            zr = zi = tr = ti = 0.0

            i = 0
            while i < ITER && (tr + ti) <= LIMIT_SQ
                zi = 2.0 * zr * zi + ci
                zr = tr - ti + cr
                tr = zr * zr
                ti = zi * zi
                i += 1
            end

            byte_acc <<= 1
            if tr + ti <= LIMIT_SQ
                byte_acc |= 0x01
            end

            bit_num += 1

            if bit_num == 8
                write(io, byte_acc)
                byte_acc = 0x00
                bit_num = 0
            elseif x == w - 1
                byte_acc <<= (8 - (w % 8))
                write(io, byte_acc)
                byte_acc = 0x00
                bit_num = 0
            end
        end
    end
end

function checksum(b::Mandelbrot)::UInt32
    return Helper.checksum(take!(b.io))
end