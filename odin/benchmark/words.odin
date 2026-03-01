package benchmark

import "core:mem"
import "core:fmt"
import "core:strings"
import "core:mem/virtual"

Words :: struct {
    using base: Benchmark,
    words: int,
    word_len: int,
    text: string,
    checksum_val: u32,
}

words_prepare :: proc(bench: ^Benchmark) {
    w := cast(^Words)bench

    w.words = int(config_i64(w.name, "words"))
    w.word_len = int(config_i64(w.name, "word_len"))

    chars := "abcdefghijklmnopqrstuvwxyz"
    char_count := len(chars)

    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    for i in 0..<w.words {
        word_len := int(next_int(w.word_len)) + int(next_int(3)) + 3

        for j in 0..<word_len {
            idx := next_int(char_count)
            strings.write_byte(&builder, chars[idx])
        }
        if i < w.words - 1 {
            strings.write_byte(&builder, ' ')
        }
    }

    w.text = strings.clone(strings.to_string(builder))
}

words_run :: proc(bench: ^Benchmark, iteration_id: int) {
    w := cast(^Words)bench

    arena: virtual.Arena
    err := virtual.arena_init_growing(&arena)
    if err != nil {
        fmt.println("ERROR: failed to initialize arena")
        return
    }
    defer virtual.arena_destroy(&arena)

    allocator := virtual.arena_allocator(&arena)

    frequencies := make(map[string]int, allocator)

    it := w.text
    for word in strings.split_iterator(&it, " ") {
        if len(word) == 0 do continue

        val, ok := frequencies[word]
        if ok {
            frequencies[word] = val + 1
        } else {
            frequencies[word] = 1
        }
    }

    max_word: string = ""
    max_count: u32 = 0

    for word, count in frequencies {
        if count > int(max_count) {
            max_count = u32(count)
            max_word = word
        }
    }

    freq_size := u32(len(frequencies))
    word_checksum := checksum_string(max_word)

    w.checksum_val += max_count + word_checksum + freq_size
}

words_checksum :: proc(bench: ^Benchmark) -> u32 {
    w := cast(^Words)bench
    return w.checksum_val
}

words_cleanup :: proc(bench: ^Benchmark) {
    w := cast(^Words)bench
    delete(w.text)
}

create_words :: proc() -> ^Benchmark {
    w := new(Words)
    w.name = "Etc::Words"
    w.vtable = default_vtable()

    w.vtable.prepare = words_prepare
    w.vtable.run = words_run
    w.vtable.checksum = words_checksum
    w.vtable.cleanup = words_cleanup

    return cast(^Benchmark)w
}