using System.Text;

public class Knuckeotide : Benchmark
{
    private string _seq = "";
    private StringBuilder _resultBuilder;

    public override uint Checksum => Helper.Checksum(_resultBuilder.ToString());
    public override string TypeName => "CLBG::Knuckeotide";

    public Knuckeotide()
    {
        _resultBuilder = new StringBuilder();
    }

    public override void Prepare()
    {
        var fasta = new Fasta();
        fasta._n = ConfigVal("n");
        fasta.Prepare();
        fasta.Run(0);
        string result = fasta.GetResult();

        var seqBuilder = new StringBuilder();
        bool three = false;

        using (var reader = new StringReader(result))
        {
            string? line;
            while ((line = reader.ReadLine()) != null)
            {
                if (line.StartsWith(">THREE"))
                {
                    three = true;
                    continue;
                }
                if (three) seqBuilder.Append(line.Trim());
            }
        }

        _seq = seqBuilder.ToString();
    }

    private (int n, Dictionary<string, int> table) Frequency(string seq, int length)
    {
        int n = seq.Length - length + 1;
        var table = new Dictionary<string, int>();

        for (int i = 0; i < n; i++)
        {
            string sub = seq.Substring(i, length);
            table[sub] = table.GetValueOrDefault(sub, 0) + 1;
        }

        return (n, table);
    }

    private void SortByFreq(string seq, int length)
    {
        var (n, table) = Frequency(seq, length);

        var sorted = table.OrderByDescending(kv => kv.Value);

        foreach (var kv in sorted)
        {
            double freq = (kv.Value * 100.0) / n;
            _resultBuilder.AppendFormat("{0} {1:F3}\n", kv.Key.ToUpperInvariant(), freq);
        }
        _resultBuilder.Append('\n');
    }

    private void FindSeq(string seq, string s)
    {
        var (n, table) = Frequency(seq, s.Length);
        int count = table.GetValueOrDefault(s, 0);
        _resultBuilder.AppendFormat("{0}\t{1}\n", count, s.ToUpperInvariant());
    }

    public override void Run(long IterationId)
    {
        for (int i = 1; i <= 2; i++) SortByFreq(_seq, i);

        string[] patterns = { "ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt" };
        foreach (var pattern in patterns) FindSeq(_seq, pattern);
    }
}