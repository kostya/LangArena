using System.Text;
using System.Text.RegularExpressions;

public class RegexDna : Benchmark
{
    private string _seq = "";
    private int _ilen;
    private int _clen;
    private StringBuilder _resultBuilder;
    
    public override long Result => Helper.Checksum(_resultBuilder.ToString());
    
    public RegexDna()
    {
        _resultBuilder = new StringBuilder();
    }
    
    public override void Prepare()
    {
        var fasta = new Fasta();
        fasta._n = Iterations;
        fasta.Prepare();
        fasta.Run();
        string fastaResult = fasta.GetResult();
        
        var seqBuilder = new StringBuilder();
        _ilen = 0;
        
        using (var reader = new StringReader(fastaResult))
        {
            string? line;
            while ((line = reader.ReadLine()) != null)
            {
                _ilen += line.Length + 1; // +1 для newline
                if (!line.StartsWith('>'))
                {
                    seqBuilder.Append(line);
                }
            }
        }
        
        _seq = seqBuilder.ToString();
        _clen = seqBuilder.Length;
    }
    
    private string GetFastaResultString(Fasta fasta)
    {
        // Нужен доступ к результату Fasta
        // Временно используем рефлексию
        var resultField = typeof(Fasta).GetField("_resultBuilder", 
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        if (resultField?.GetValue(fasta) is StringBuilder sb)
        {
            return sb.ToString();
        }
        return "";
    }
    
    public override void Run()
    {
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
        
        foreach (var pattern in patterns)
        {
            var regex = new Regex(pattern, RegexOptions.Compiled);
            int count = regex.Matches(_seq).Count;
            _resultBuilder.AppendFormat("{0} {1}\n", pattern, count);
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
        
        foreach (var kv in replacements)
        {
            _seq = Regex.Replace(_seq, kv.Key, kv.Value);
        }
        
        _resultBuilder.AppendFormat("\n{0}\n{1}\n{2}\n", _ilen, _clen, _seq.Length);
    }
}