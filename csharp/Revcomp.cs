using System.Text;

public class Revcomp : Benchmark
{
    private string _input = "";
    private uint _result;

    private static readonly char[] LookupTable;

    static Revcomp()
    {
        LookupTable = new char[256];
        for (int i = 0; i < 256; i++)
        {
            LookupTable[i] = (char)i;
        }

        string from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
        string to = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";

        for (int i = 0; i < from.Length; i++)
        {
            LookupTable[from[i]] = to[i];
        }
    }

    public Revcomp()
    {
        _result = 0;
    }

    public override void Prepare()
    {
        var fasta = new Fasta();
        fasta._n = ConfigVal("n");
        fasta.Prepare();
        fasta.Run(0);
        string fastaResult = fasta.GetResult();

        var seqBuilder = new StringBuilder();

        using (var reader = new StringReader(fastaResult))
        {
            string? line;
            while ((line = reader.ReadLine()) != null)
            {
                if (line.StartsWith(">"))
                {
                    seqBuilder.Append("\n---\n");
                }
                else
                {
                    seqBuilder.Append(line);
                }
            }
        }

        _input = seqBuilder.ToString();
    }

    private string ReverseComplement(string seq)
    {
        int length = seq.Length;
        int lines = (length + 59) / 60; 
        int totalSize = length + lines; 

        var result = new StringBuilder(totalSize);

        for (int start = length; start > 0; start -= 60)
        {
            int chunkStart = Math.Max(start - 60, 0);
            int chunkSize = start - chunkStart;

            for (int i = start - 1; i >= chunkStart; i--)
            {
                char c = seq[i];
                result.Append(LookupTable[c]);
            }

            result.Append('\n');
        }

        if (length % 60 == 0 && length > 0)
        {
            result.Length--;
        }

        return result.ToString();
    }

    public override void Run(long IterationId)
    {
        _result += Helper.Checksum(ReverseComplement(_input));
    }

    public override uint Checksum => _result;
}