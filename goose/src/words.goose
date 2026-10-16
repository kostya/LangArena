namespace words;

import std;
import dictionary;
import bench;
import helper;

struct WordCount { word: const u8[:], count: i32 }

struct Words { words: i64, word_len: i64, checksum_val: u32, text: u8[>..] }

fn new_words() -> Words {
    Words {
        words: config_i64("Etc::Words", "words"),
        word_len: config_i64("Etc::Words", "word_len"),
        checksum_val: 0,
        text: [],
    }
}

fn prepare(s: Words&) {
    let chars = "abcdefghijklmnopqrstuvwxyz";
    for i in s.words {
        let word_len = next_int(s.word_len) + next_int(3) + 3;
        for j in word_len { s.text.push(chars[next_int(chars.len)]); }
        if i < s.words - 1 { s.text.push(' '); }
    }
}

fn run(s: Words&, iteration_id: i64) {
    var frequencies = dictionary<const u8[:], i32> {};
    each_word(s.text) { word => frequencies.update(word, 0) { it += 1; }; };
    var top = WordCount { word: "", count: 0 };
    frequencies.each() { word, count =>
        if count > top.count { top = WordCount { word, count }; }
    };
    s.checksum_val += (top.count as! u32) + checksum_str(top.word) + (frequencies.count as! u32);
}

fn checksum(s: Words&) -> u32 { s.checksum_val }