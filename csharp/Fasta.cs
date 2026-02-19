using System.Text;

public class Fasta : Benchmark
{
    public long _n;
    private StringBuilder _resultBuilder;

    public Fasta()
    {
        _resultBuilder = new StringBuilder();
        _n = ConfigVal("n");
    }

    public override void Prepare() { }

    private char SelectRandom((char, double)[] genelist)
    {
        double r = Helper.NextFloat();
        if (r < genelist[0].Item2) return genelist[0].Item1;

        int lo = 0;
        int hi = genelist.Length - 1;

        while (hi > lo + 1)
        {
            int i = (hi + lo) / 2;
            if (r < genelist[i].Item2) hi = i;
            else lo = i;
        }
        return genelist[hi].Item1;
    }

    private const int LINE_LENGTH = 60;

    private void MakeRandomFasta(string id, string desc, (char, double)[] genelist, int n)
    {
        _resultBuilder.Append($">{id} {desc}\n");

        int todo = n;
        char[] buffer = new char[LINE_LENGTH];

        while (todo > 0)
        {
            int m = todo < LINE_LENGTH ? todo : LINE_LENGTH;

            for (int i = 0; i < m; i++) buffer[i] = SelectRandom(genelist);

            _resultBuilder.Append(buffer, 0, m);
            _resultBuilder.Append('\n');
            todo -= LINE_LENGTH;
        }
    }

    private void MakeRepeatFasta(string id, string desc, string s, int n)
    {
        _resultBuilder.Append($">{id} {desc}\n");

        int todo = n;
        int k = 0;
        int kn = s.Length;

        while (todo > 0)
        {
            int m = todo < LINE_LENGTH ? todo : LINE_LENGTH;

            while (m >= kn - k)
            {
                _resultBuilder.Append(s, k, kn - k);
                m -= kn - k;
                k = 0;
            }

            if (m > 0)
            {
                _resultBuilder.Append(s, k, m);
                k += m;
            }

            _resultBuilder.Append('\n');
            todo -= LINE_LENGTH;
        }
    }

    private static readonly (char, double)[] IUB = new (char, double)[]
    {
        ('a', 0.27), ('c', 0.39), ('g', 0.51), ('t', 0.78),
        ('B', 0.8), ('D', 0.8200000000000001), ('H', 0.8400000000000001),
        ('K', 0.8600000000000001), ('M', 0.8800000000000001),
        ('N', 0.9000000000000001), ('R', 0.9200000000000002),
        ('S', 0.9400000000000002), ('V', 0.9600000000000002),
        ('W', 0.9800000000000002), ('Y', 1.0000000000000002)
    };

    private static readonly (char, double)[] HOMO = new (char, double)[]
    {
        ('a', 0.302954942668), ('c', 0.5009432431601),
        ('g', 0.6984905497992), ('t', 1.0)
    };

    private const string ALU = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

    public override void Run(long IterationId)
    {
        MakeRepeatFasta("ONE", "Homo sapiens alu", ALU, (int)(_n * 2));
        MakeRandomFasta("TWO", "IUB ambiguity codes", IUB, (int)(_n * 3));
        MakeRandomFasta("THREE", "Homo sapiens frequency", HOMO, (int)(_n * 5));
    }

    public string GetResult() => _resultBuilder.ToString();
    public override uint Checksum => Helper.Checksum(_resultBuilder.ToString());
}