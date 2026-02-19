abstract type AbstractBenchmark end

function name(b::AbstractBenchmark)::String
    error("Method 'name' not implemented")
end

function run(b::AbstractBenchmark, iteration_id::Int64)
    error("Method 'run' not implemented")
end

function checksum(b::AbstractBenchmark)::UInt32
    error("Method 'checksum' not implemented")
end

function prepare(b::AbstractBenchmark)

end

function warmup(b::AbstractBenchmark)
    warmup_iters = warmup_iterations(b)
    for i = 1:warmup_iters
        run(b, i)
    end
end

function run_all(b::AbstractBenchmark)
    iters = iterations(b)
    for i = 1:iters
        run(b, i)
    end
end

function warmup_iterations(b::AbstractBenchmark)::Int64
    name_str = name(b)
    config = Helper.CONFIG[]

    if haskey(config, name_str) && haskey(config[name_str], "warmup_iterations")
        return config[name_str]["warmup_iterations"]
    else
        iters = iterations(b)
        return max(Int64(round(iters * 0.2)), 1)
    end
end

function iterations(b::AbstractBenchmark)::Int64
    return Helper.config_i64(name(b), "iterations")
end

function expected_checksum(b::AbstractBenchmark)::UInt32
    return UInt32(Helper.config_i64(name(b), "checksum"))
end

function config_val(b::AbstractBenchmark, field_name::String)::Int64
    return Helper.config_i64(name(b), field_name)
end

Benchmark() = Benchmark(0.0)
