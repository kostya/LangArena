module benchmarks.words;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.math;
import std.random;
import std.ascii;
import std.utf;
import benchmark;
import helper;

class Words : Benchmark
{
private:
    int words;
    int wordLen;
    string text;
    uint checksumVal;

protected:
    override string className() const
    {
        return "Etc::Words";
    }

public:
    this()
    {
        words = configVal("words");
        wordLen = configVal("word_len");
        checksumVal = 0;
    }

    override void prepare()
    {
        char[] chars = "abcdefghijklmnopqrstuvwxyz".dup;
        int charCount = cast(int) chars.length;

        string[] wordsList;
        wordsList.reserve(words);

        for (int i = 0; i < words; i++)
        {
            int len = Helper.nextInt(wordLen) + Helper.nextInt(3) + 3;
            char[] wordChars = new char[len];
            for (int j = 0; j < len; j++)
            {
                int idx = Helper.nextInt(charCount);
                wordChars[j] = chars[idx];
            }
            wordsList ~= wordChars.idup;
        }

        text = join(wordsList, " ");
    }

    override void run(int iterationId)
    {

        int[string] frequencies;

        foreach (word; split(text, ' '))
        {
            if (word.empty)
                continue;
            frequencies[word] = frequencies.get(word, 0) + 1;
        }

        string maxWord = "";
        int maxCount = 0;

        foreach (word, count; frequencies)
        {
            if (count > maxCount)
            {
                maxCount = count;
                maxWord = word;
            }
        }

        uint freqSize = cast(uint) frequencies.length;
        uint wordChecksum = Helper.checksum(maxWord);

        checksumVal += cast(uint) maxCount + wordChecksum + freqSize;
    }

    override uint checksum()
    {
        return checksumVal;
    }
}
