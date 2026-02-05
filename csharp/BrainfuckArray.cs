public class BrainfuckArray : Benchmark
{
    private string _programText = "";
    private string _warmupText = "";
    private uint _result;

    public override uint Checksum => _result;

    public BrainfuckArray()
    {
        _programText = Helper.Config_s(nameof(BrainfuckArray), "program");
        _warmupText = Helper.Config_s(nameof(BrainfuckArray), "warmup_program");
    }

    private class Tape
    {
        private byte[] _tape = new byte[30000];
        private int _pos = 0;

        public byte Get() => _tape[_pos];

        public void Inc() => _tape[_pos] = (byte)(_tape[_pos] + 1); 

        public void Dec() => _tape[_pos] = (byte)(_tape[_pos] - 1); 

        public void Advance()
        {
            _pos += 1;
            if (_pos >= _tape.Length)
            {

                Array.Resize(ref _tape, _tape.Length * 2);
            }
        }

        public void Devance()
        {
            if (_pos > 0) _pos -= 1;
        }
    }

    private class Program
    {
        private List<byte> _commands = new List<byte>();
        private int[] _jumps; 
        private uint _result = 0;

        public uint Result => _result;

        public Program(string text)
        {

            foreach (char c in text)
            {
                if ("[]<>+-,.".Contains(c))
                {
                    _commands.Add((byte)c);
                }
            }

            _jumps = new int[_commands.Count];
            Stack<int> stack = new Stack<int>();

            for (int i = 0; i < _commands.Count; i++)
            {
                byte cmd = _commands[i];
                if (cmd == '[')
                {
                    stack.Push(i);
                }
                else if (cmd == ']' && stack.Count > 0)
                {
                    int start = stack.Pop();
                    _jumps[start] = i;
                    _jumps[i] = start;
                }
            }
        }

        public void Run()
        {
            var tape = new Tape();
            int pc = 0;

            while (pc < _commands.Count)
            {
                byte cmd = _commands[pc];

                switch (cmd)
                {
                    case (byte)'+': 
                        tape.Inc(); 
                        break;
                    case (byte)'-': 
                        tape.Dec(); 
                        break;
                    case (byte)'>': 
                        tape.Advance(); 
                        break;
                    case (byte)'<': 
                        tape.Devance(); 
                        break;
                    case (byte)'[':
                        if (tape.Get() == 0)
                        {
                            pc = _jumps[pc];
                            continue; 
                        }
                        break;
                    case (byte)']':
                        if (tape.Get() != 0)
                        {
                            pc = _jumps[pc];
                            continue; 
                        }
                        break;
                    case (byte)'.':

                        _result = unchecked((_result << 2) + tape.Get());
                        break;
                }

                pc += 1;
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
        {
            RunProgram(_warmupText);
        }
    }

    public override void Run(long IterationId) 
    {
        _result = unchecked(_result + RunProgram(_programText));
    }
}