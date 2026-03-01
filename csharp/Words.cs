using System;
using System.Collections.Generic;
using System.Linq;

public class Words : Benchmark
{
    private int _words;
    private int _wordLen;
    private string _text;
    private uint _checksumVal;

    public Words()
    {
        _words = (int)ConfigVal("words");
        _wordLen = (int)ConfigVal("word_len");
        _checksumVal = 0;
    }

    public override void Prepare()
    {
        char[] chars = "abcdefghijklmnopqrstuvwxyz".ToCharArray();
        var words = new List<string>(_words);

        for (int i = 0; i < _words; i++)
        {
            int len = Helper.NextInt(_wordLen) + Helper.NextInt(3) + 3;
            char[] wordChars = new char[len];
            for (int j = 0; j < len; j++)
            {
                wordChars[j] = chars[Helper.NextInt(chars.Length)];
            }
            words.Add(new string(wordChars));
        }

        _text = string.Join(" ", words);
    }

    public override void Run(long IterationId)
    {

        var frequencies = new Dictionary<string, int>();

        foreach (var word in _text.Split(' '))
        {
            if (string.IsNullOrEmpty(word)) continue;
            frequencies.TryGetValue(word, out int count);
            frequencies[word] = count + 1;
        }

        string maxWord = "";
        int maxCount = 0;
        foreach (var kvp in frequencies)
        {
            if (kvp.Value > maxCount)
            {
                maxCount = kvp.Value;
                maxWord = kvp.Key;
            }
        }

        uint freqSize = (uint)frequencies.Count;
        uint wordChecksum = Helper.Checksum(maxWord);

        _checksumVal += (uint)maxCount + wordChecksum + freqSize;
    }

    public override uint Checksum => _checksumVal;
    public override string TypeName => "Etc::Words";
}