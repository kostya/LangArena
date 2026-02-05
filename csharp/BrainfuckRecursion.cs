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
    private record struct Inc(int Value) : IOp;
    private record struct Move(int Value) : IOp;
    private record struct Print : IOp;
    private record class Loop(List<IOp> Operations) : IOp;

    private sealed class Tape
    {
        private byte[] _tape = new byte[1024];
        private int _pos = 0;

        public byte Get() => _tape[_pos];

        public void Inc(int x) => _tape[_pos] = (byte)(_tape[_pos] + x);

        public void Move(int x)
        {
            _pos += x;

            if (_pos < 0)
            {
                int needed = -_pos;
                byte[] newTape = new byte[_tape.Length + needed];
                Array.Copy(_tape, 0, newTape, needed, _tape.Length);
                _tape = newTape;
                _pos = needed;
            }
            else if (_pos >= _tape.Length)
            {
                int newSize = Math.Max(_tape.Length * 2, _pos + 1);
                Array.Resize(ref _tape, newSize);
            }
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
                    '+' => new Inc(1),
                    '-' => new Inc(-1),
                    '>' => new Move(1),
                    '<' => new Move(-1),
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
            RunOperations(_operations, tape);
        }

        private void RunOperations(List<IOp> operations, Tape tape)
        {
            for (int i = 0; i < operations.Count; i++)
            {
                var op = operations[i];

                switch (op)
                {
                    case Inc inc: tape.Inc(inc.Value); break;
                    case Move move: tape.Move(move.Value); break;
                    case Print: _result = ((_result << 2) + tape.Get()); break;
                    case Loop loop:
                        while (tape.Get() != 0) RunOperations(loop.Operations, tape);
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
        for (long i = 0; i < prepareIters; i++) RunProgram(_warmupText);
    }

    public override void Run(long IterationId) => _result += RunProgram(_text);

    public override uint Checksum => _result;
}