public class BrainfuckHashMap : Benchmark
{
    private string _text = "";
    private uint _result;
    private string _warmupText = "";
    
    public override uint Checksum => _result;
    
    public BrainfuckHashMap()
    {
        _text = Helper.Config_s(nameof(BrainfuckHashMap), "program");
        _warmupText = Helper.Config_s(nameof(BrainfuckHashMap), "warmup_program");
    }
    
    private class Tape
    {
        private List<byte> _tape = new() { 0 };
        private int _pos = 0;
        
        public byte Get() => _tape[_pos];
        
        public void Inc() => _tape[_pos] += 1;
        
        public void Dec() => _tape[_pos] -= 1;
        
        public void Advance()
        {
            _pos += 1;
            if (_tape.Count <= _pos) _tape.Add(0);
        }
        
        public void Devance()
        {
            if (_pos > 0) _pos -= 1;
        }
    }
    
    private class Program
    {
        private List<char> _chars = new();
        private Dictionary<int, int> _bracketMap = new();
        private uint _result = 0;
        
        public uint Result => _result;
        
        public Program(string text)
        {
            var leftStack = new Stack<int>();
            int pc = 0;
            
            foreach (char c in text)
            {
                if ("[]<>+-,.".Contains(c))
                {
                    _chars.Add(c);
                    
                    if (c == '[')
                    {
                        leftStack.Push(pc);
                    }
                    else if (c == ']' && leftStack.Count > 0)
                    {
                        int left = leftStack.Pop();
                        int right = pc;
                        _bracketMap[left] = right;
                        _bracketMap[right] = left;
                    }
                    
                    pc += 1;
                }
            }
        }
        
        public void Run()
        {
            var tape = new Tape();
            int pc = 0;
            
            while (pc < _chars.Count)
            {
                char c = _chars[pc];
                
                switch (c)
                {
                    case '+': tape.Inc(); break;
                    case '-': tape.Dec(); break;
                    case '>': tape.Advance(); break;
                    case '<': tape.Devance(); break;
                    case '[':
                        if (tape.Get() == 0) pc = _bracketMap[pc];
                        break;
                    case ']':
                        if (tape.Get() != 0) pc = _bracketMap[pc];
                        break;
                    case '.':
                        _result = ((_result << 2) + tape.Get());
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
        for (long i = 0; i < prepareIters; i++) RunProgram(_warmupText);
    }
    
    public override void Run(long IterationId) => _result += RunProgram(_text);
}