using System.Text;

public class Revcomp : Benchmark
{
    private string _input = "";
    private uint _result;
    
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
                    seqBuilder.Append("\n---\n"); // Как в C++ версии
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
        char[] result = new char[seq.Length];
        
        for (int i = 0; i < seq.Length; i++)
        {
            char c = seq[i];
            char rc = c switch
            {
                'w' or 'W' => 'W',
                's' or 'S' => 'S',
                'a' or 'A' => 'T',
                't' or 'T' => 'A',
                'u' or 'U' => 'A',
                'g' or 'G' => 'C',
                'c' or 'C' => 'G',
                'y' or 'Y' => 'R',
                'r' or 'R' => 'Y',
                'k' or 'K' => 'M',
                'm' or 'M' => 'K',
                'b' or 'B' => 'V',
                'd' or 'D' => 'H',
                'h' or 'H' => 'D',
                'v' or 'V' => 'B',
                'n' or 'N' => 'N',
                _ => c
            };
            result[seq.Length - 1 - i] = rc;
        }
        
        // Добавляем переносы строк каждые 60 символов как в C++ версии
        var formatted = new StringBuilder();
        for (int i = 0; i < result.Length; i += 60)
        {
            int length = Math.Min(60, result.Length - i);
            formatted.Append(result, i, length);
            formatted.Append('\n');
        }
        
        return formatted.ToString();
    }
    
    public override void Run(long IterationId)
    {
        _result += Helper.Checksum(ReverseComplement(_input));
    }
    
    public override uint Checksum => _result;
}