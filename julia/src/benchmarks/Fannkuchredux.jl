using StaticArrays

mutable struct Fannkuchredux <: AbstractBenchmark
    n::Int64
    result::UInt32

    function Fannkuchredux()
        n = Helper.config_i64("Fannkuchredux", "n")
        new(n, UInt32(0))
    end
end

name(b::Fannkuchredux)::String = "Fannkuchredux"

function run(b::Fannkuchredux, iteration_id::Int64)
    n = Int32(b.n)

    perm1 = MVector{16, Int32}(undef)
    perm = MVector{16, Int32}(undef)
    count = MVector{16, Int32}(undef)

    i = Int32(0)
    while i < n
        perm1[i+1] = i  
        perm[i+1] = 0
        count[i+1] = 0
        i += 1
    end

    max_flips = Int32(0)
    perm_count = Int32(0)
    checksum = Int32(0)
    r = n

    while true

        while r > 1
            count[r] = r  
            r -= 1
        end

        i = Int32(0)
        while i < n
            perm[i+1] = perm1[i+1]
            i += 1
        end

        flips_count = Int32(0)
        k = perm[1]  

        while k != 0
            k2 = (k + 1) >> 1  

            i_local = Int32(0)
            while i_local < k2
                j = k - i_local

                temp = perm[i_local+1]
                perm[i_local+1] = perm[j+1]
                perm[j+1] = temp
                i_local += 1
            end

            flips_count += 1
            k = perm[1]  
        end

        if flips_count > max_flips
            max_flips = flips_count
        end

        if (perm_count & 1) == 0
            checksum += flips_count
        else
            checksum -= flips_count
        end

        while true

            if r == n

                result_int64 = (Int64(checksum) * 100 + Int64(max_flips)) & 0xffffffff
                b.result += UInt32(result_int64)
                return
            end

            perm0 = perm1[1]  

            i = Int32(0)
            while i < r
                perm1[i+1] = perm1[i+2]  
                i += 1
            end

            perm1[r+1] = perm0  

            count[r+1] -= 1  
            if count[r+1] > 0
                break
            end
            r += 1
        end

        perm_count += 1
    end
end

checksum(b::Fannkuchredux)::UInt32 = b.result