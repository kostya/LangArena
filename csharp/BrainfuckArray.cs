public class BrainfuckArray : Benchmark
{
    private string _programText = "";
    private string _warmupText = "";
    private uint _result;

    public override uint Checksum => _result;
    public override string TypeName => "Brainfuck::Array";

    public BrainfuckArray()
    {
        _programText = Helper.Config_s(TypeName, "program");
        _warmupText = Helper.Config_s(TypeName, "warmup_program");
    }

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
        public void Inc() => _tape[_pos] = (byte)(_tape[_pos] + 1);
        public void Dec() => _tape[_pos] = (byte)(_tape[_pos] - 1);

        public void Advance()
        {
            _pos += 1;
            if (_pos >= _tape.Length)
            {
                Array.Resize(ref _tape, _tape.Length + 1);
            }
        }

        public void Devance()
        {
            if (_pos > 0) _pos -= 1;
        }
    }

    private class Program
    {
        private List<byte> _commands;
        private int[] _jumps;

        public Program(string text)
        {
            _commands = new List<byte>(text.Length);
            foreach (char c in text)
            {
                switch (c)
                {
                    case '[':
                    case ']':
                    case '<':
                    case '>':
                    case '+':
                    case '-':
                    case ',':
                    case '.':
                        _commands.Add((byte)c);
                        break;
                }
            }

            _jumps = new int[_commands.Count];
            int[] stack = new int[_commands.Count];
            int sp = 0;

            for (int i = 0; i < _commands.Count; i++)
            {
                if (_commands[i] == '[')
                {
                    stack[sp++] = i;
                }
                else if (_commands[i] == ']' && sp > 0)
                {
                    int start = stack[--sp];
                    _jumps[start] = i;
                    _jumps[i] = start;
                }
            }
        }

        public uint Run()
        {
            var tape = new Tape();
            int pc = 0;
            var commands = _commands;
            var jumps = _jumps;
            uint result = 0;

            while (pc < commands.Count)
            {
                byte cmd = commands[pc];

                switch (cmd)
                {
                    case (byte)'+': tape.Inc(); break;
                    case (byte)'-': tape.Dec(); break;
                    case (byte)'>': tape.Advance(); break;
                    case (byte)'<': tape.Devance(); break;
                    case (byte)'[':
                        if (tape.Get() == 0)
                        {
                            pc = jumps[pc];
                            continue;
                        }
                        break;
                    case (byte)']':
                        if (tape.Get() != 0)
                        {
                            pc = jumps[pc];
                            continue;
                        }
                        break;
                    case (byte)'.':
                        result = unchecked((result << 2) + tape.Get());
                        break;
                }
                pc++;
            }

            return result;
        }
    }

    private uint RunProgram(string text)
    {
        return new Program(text).Run();
    }

    public override void Warmup()
    {
        long prepareIters = WarmupIterations;
        for (long i = 0; i < prepareIters; i++)
        {
            RunProgram(_warmupText);
        }
    }

    public override void Run(long IterationId)
    {
        _result = unchecked(_result + RunProgram(_programText));
    }
}