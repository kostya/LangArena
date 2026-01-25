using System.Text;

public class Revcomp : Benchmark
{
    private string _input = "";
    private StringBuilder _resultBuilder;
    
    public override long Result => Helper.Checksum(_resultBuilder.ToString());
    
    public Revcomp()
    {
        _resultBuilder = new StringBuilder();
    }
    
    public override void Prepare()
    {
        var fasta = new Fasta();
        fasta._n = Iterations;
        fasta.Prepare();
        fasta.Run();
        _input = fasta.GetResult();
    }
    
    private string ReverseComplement(string seq)
    {
        // Создаем массив для результата
        char[] result = new char[seq.Length];
        
        // Трансляция символов
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
        
        return new string(result);
    }
    
    private void ProcessSequence(string seq)
    {
        string revcomp = ReverseComplement(seq);
        int stringlen = revcomp.Length - 1;
        
        for (int x = 0; x <= stringlen; x += 60)
        {
            int length = Math.Min(60, stringlen - x + 1);
            _resultBuilder.Append(revcomp, x, length);
            _resultBuilder.Append('\n');
        }
    }
    
    public override void Run()
    {
        var seqBuilder = new StringBuilder();
        
        using (var reader = new StringReader(_input))
        {
            string? line;
            while ((line = reader.ReadLine()) != null)
            {
                if (line.StartsWith('>'))
                {
                    if (seqBuilder.Length > 0)
                    {
                        ProcessSequence(seqBuilder.ToString());
                        seqBuilder.Clear();
                    }
                    _resultBuilder.Append(line);
                    _resultBuilder.Append('\n');
                }
                else
                {
                    seqBuilder.Append(line);
                }
            }
        }
        
        // Обработать последнюю последовательность
        if (seqBuilder.Length > 0)
        {
            ProcessSequence(seqBuilder.ToString());
        }
    }
}