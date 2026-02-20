public class BrainfuckRecursion : Benchmark
{
    private string _text = "";
    private string _warmupText = "";
    private uint _result;

    public BrainfuckRecursion()
    {
        _text = Helper.Config_s(nameof(BrainfuckRecursion), "program");
        _warmupText = Helper.Config_s(nameof(BrainfuckRecursion), "warmup_program");
    }

    private interface IOp { }
    private record struct Inc() : IOp;
    private record struct Dec() : IOp;
    private record struct Next() : IOp;
    private record struct Prev() : IOp;
    private record struct Print() : IOp;
    private record class Loop(List<IOp> Operations) : IOp;

    private struct Tape
    {
        private byte[] _tape;
        private int _pos;

        public Tape()
        {
            _tape = new byte[30000];
            _pos = 0;
        }

        public byte Get() => _tape[_pos];

        public void Inc() => _tape[_pos]++;

        public void Dec() => _tape[_pos]--;

        public void Next()
        {
            _pos++;
            if (_pos >= _tape.Length)
            {
                Array.Resize(ref _tape, _tape.Length + 1);
            }
        }

        public void Prev()
        {
            if (_pos > 0) _pos--;
        }
    }

    private sealed class Program
    {
        private readonly List<IOp> _operations;
        private uint _result = 0;

        public uint Result => _result;

        public Program(string code)
        {
            int index = 0;
            _operations = Parse(ref index, code);
        }

        private List<IOp> Parse(ref int index, string code)
        {
            var operations = new List<IOp>();

            while (index < code.Length)
            {
                char c = code[index++];

                IOp op = c switch
                {
                    '+' => new Inc(),
                    '-' => new Dec(),
                    '>' => new Next(),
                    '<' => new Prev(),
                    '.' => new Print(),
                    '[' => new Loop(Parse(ref index, code)),
                    ']' => null,
                    _ => null
                };

                if (op is not null) operations.Add(op);
                if (c == ']') break;
            }

            return operations;
        }

        public void Run()
        {
            var tape = new Tape();
            _result = 0;
            RunOperations(_operations, tape);
        }

        private void RunOperations(List<IOp> operations, Tape tape)
        {
            for (int i = 0; i < operations.Count; i++)
            {
                var op = operations[i];

                switch (op)
                {
                    case Inc: tape.Inc(); break;
                    case Dec: tape.Dec(); break;
                    case Next: tape.Next(); break;
                    case Prev: tape.Prev(); break;
                    case Print: _result = (_result << 2) + tape.Get(); break;
                    case Loop loop:
                        while (tape.Get() != 0)
                            RunOperations(loop.Operations, tape);
                        break;
                }
            }
        }
    }

    private uint RunProgram(string text)
    {
        var program = new Program(text);
        program.Run();
        return program.Result;
    }

    public override void Warmup()
    {
        long prepareIters = WarmupIterations;
        for (long i = 0; i < prepareIters; i++)
            RunProgram(_warmupText);
    }

    public override void Run(long IterationId)
    {
        _result = (_result + RunProgram(_text)) & 0xFFFFFFFF;
    }

    public override uint Checksum => _result;
}