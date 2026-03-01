mutable struct Words <: AbstractBenchmark
    words::Int64
    word_len::Int64
    text::String
    checksum_val::UInt32

    function Words()
        words = Helper.config_i64("Etc::Words", "words")
        word_len = Helper.config_i64("Etc::Words", "word_len")
        new(words, word_len, "", UInt32(0))
    end
end

name(b::Words)::String = "Etc::Words"

function prepare(b::Words)
    chars = 'a':'z'
    char_count = length(chars)

    words = b.words
    word_len = b.word_len

    text_parts = String[]
    sizehint!(text_parts, words)

    for i = 1:words
        len = Helper.next_int(word_len) + Helper.next_int(3) + 3
        word = String([chars[Helper.next_int(char_count)+1] for _ = 1:len])
        push!(text_parts, word)
    end

    b.text = join(text_parts, ' ')
end

function run(b::Words, iteration_id::Int64)

    frequencies = Dict{String,Int}()

    for word in split(b.text, ' ')
        if word == ""
            continue
        end
        frequencies[word] = Base.get(frequencies, word, 0) + 1
    end

    max_word = ""
    max_count = 0

    for (word, count) in frequencies
        if count > max_count
            max_count = count
            max_word = word
        end
    end

    freq_size = UInt32(length(frequencies))
    word_checksum = Helper.checksum(max_word)

    b.checksum_val += UInt32(max_count) + word_checksum + freq_size
end

function checksum(b::Words)::UInt32
    return b.checksum_val
end
