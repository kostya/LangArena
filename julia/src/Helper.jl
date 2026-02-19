module Helper

using JSON3
using Printf: @sprintf
using Base.Threads

const IM = 139968
const IA = 3877
const IC = 29573

const CONFIG = Ref{Dict{String,Any}}(Dict{String,Any}())

const THREAD_LAST = [42 for _ = 1:Threads.nthreads()]

function load_config(filename = "../test.js")
    try
        content = read(filename, String)

        json_obj = JSON3.read(content)

        CONFIG[] = convert_json3_to_dict(json_obj)
    catch e
        @warn "Cannot open or parse config file: $filename - $e"
        CONFIG[] = Dict{String,Any}()
    end
end

function convert_json3_to_dict(obj)::Dict{String,Any}
    result = Dict{String,Any}()

    if typeof(obj) <: JSON3.Object

        for (key, value) in pairs(obj)
            key_str = string(key)
            if typeof(value) <: JSON3.Object
                result[key_str] = convert_json3_to_dict(value)
            elseif typeof(value) <: JSON3.Array
                result[key_str] = convert_json3_array(value)
            else
                result[key_str] = value
            end
        end
    end

    return result
end

function convert_json3_array(arr)::Vector{Any}
    result = Vector{Any}()
    for item in arr
        if typeof(item) <: JSON3.Object
            push!(result, convert_json3_to_dict(item))
        elseif typeof(item) <: JSON3.Array
            push!(result, convert_json3_array(item))
        else
            push!(result, item)
        end
    end
    return result
end

function reset()
    for i in eachindex(THREAD_LAST)
        THREAD_LAST[i] = 42
    end
end

function _last()
    return THREAD_LAST[threadid()]
end

function _set_last(val::Int64)
    THREAD_LAST[threadid()] = val
end

function next_int(max::Int32)::Int32
    old = _last()
    new_val = (old * IA + IC) % IM
    _set_last(new_val)
    return Int32((new_val * max) ÷ IM)
end

function next_int(max::Int64)::Int32
    return next_int(Int32(max))
end

function next_int(from::Int32, to::Int32)::Int32
    return next_int(to - from + 1) + from
end

function next_float(max::Float64 = 1.0)::Float64
    old = _last()
    new_val = (old * IA + IC) % IM
    _set_last(new_val)
    return max * Float64(new_val) / IM
end

function to_u32(v::Int64)::UInt32

    return UInt32(v & 0xffffffff)
end

function checksum(v::AbstractString)::UInt32
    hash = UInt32(5381)
    for c in v
        hash = ((hash << 5) + hash) + UInt32(c)
    end
    return hash
end

function checksum(v::Vector{UInt8})::UInt32
    hash = UInt32(5381)
    for byte in v
        hash = ((hash << 5) + hash) + UInt32(byte)
    end
    return hash
end

function checksum_f64(v::Float64)::UInt32
    str = @sprintf("%.7f", v)
    return checksum(str)
end

function config_i64(class_name::String, field_name::String)::Int64
    try
        if haskey(CONFIG[], class_name) && haskey(CONFIG[][class_name], field_name)
            return CONFIG[][class_name][field_name]
        else
            error("Config not found for $class_name, field: $field_name")
        end
    catch e
        @warn e
        return 0
    end
end

function config_s(class_name::String, field_name::String)::String
    try
        if haskey(CONFIG[], class_name) && haskey(CONFIG[][class_name], field_name)
            return string(CONFIG[][class_name][field_name])
        else
            error("Config not found for $class_name, field: $field_name")
        end
    catch e
        @warn e
        return ""
    end
end

end
