using System.Text;
using System.Text.RegularExpressions;

public class RegexDna : Benchmark
{
    private string _seq = "";
    private int _ilen;
    private int _clen;
    private StringBuilder _resultBuilder;
    private Regex[] _compiledPatterns;
    private uint _result;

    public override uint Checksum => _result;

    public RegexDna()
    {
        _resultBuilder = new StringBuilder();
    }

    public override void Prepare()
    {
        var fasta = new Fasta();
        fasta._n = ConfigVal("n");
        fasta.Prepare();
        fasta.Run(0);
        string fastaResult = fasta.GetResult();

        var seqBuilder = new StringBuilder();
        _ilen = 0;

        using (var reader = new StringReader(fastaResult))
        {
            string? line;
            while ((line = reader.ReadLine()) != null)
            {
                _ilen += line.Length + 1;
                if (!line.StartsWith('>')) seqBuilder.Append(line);
            }
        }

        _seq = seqBuilder.ToString();
        _clen = seqBuilder.Length;

        string[] patterns = {
            "agggtaaa|tttaccct",
            "[cgt]gggtaaa|tttaccc[acg]",
            "a[act]ggtaaa|tttacc[agt]t",
            "ag[act]gtaaa|tttac[agt]ct",
            "agg[act]taaa|ttta[agt]cct",
            "aggg[acg]aaa|ttt[cgt]ccct",
            "agggt[cgt]aa|tt[acg]accct",
            "agggta[cgt]a|t[acg]taccct",
            "agggtaa[cgt]|[acg]ttaccct"
        };

        _compiledPatterns = new Regex[patterns.Length];
        for (int i = 0; i < patterns.Length; i++)
        {
            _compiledPatterns[i] = new Regex(patterns[i], RegexOptions.Compiled);
        }
    }

    public override void Run(long IterationId)
    {
        for (int i = 0; i < _compiledPatterns.Length; i++)
        {
            int count = _compiledPatterns[i].Matches(_seq).Count;
            _resultBuilder.AppendFormat("{0} {1}\n", _compiledPatterns[i].ToString(), count);
        }

        var replacements = new Dictionary<string, string>
        {
            ["B"] = "(c|g|t)",
            ["D"] = "(a|g|t)",
            ["H"] = "(a|c|t)",
            ["K"] = "(g|t)",
            ["M"] = "(a|c)",
            ["N"] = "(a|c|g|t)",
            ["R"] = "(a|g)",
            ["S"] = "(c|t)",
            ["V"] = "(a|c|g)",
            ["W"] = "(a|t)",
            ["Y"] = "(c|t)"
        };

        string newSeq = _seq;
        foreach (var kv in replacements) newSeq = Regex.Replace(newSeq, kv.Key, kv.Value);

        _resultBuilder.AppendFormat("\n{0}\n{1}\n{2}\n", _ilen, _clen, newSeq.Length);

        _result = Helper.Checksum(_resultBuilder.ToString());
    }
}