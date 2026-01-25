public class BrainfuckHashMap : Benchmark
{
    private string _text = "";
    private long _result = 0;
    
    public override long Result => _result;
    
    public BrainfuckHashMap()
    {
    }
    
    public override void Prepare()
    {
        _text = Helper.Input.GetValueOrDefault(nameof(BrainfuckHashMap), "");
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
            if (_tape.Count <= _pos)
                _tape.Add(0);
        }
        
        public void Devance()
        {
            if (_pos > 0)
                _pos -= 1;
        }
    }
    
    private class Program
    {
        private List<char> _chars = new();
        private Dictionary<int, int> _bracketMap = new();
        private long _result = 0;
        
        public long Result => _result;
        
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
                    case '+':
                        tape.Inc();
                        break;
                    case '-':
                        tape.Dec();
                        break;
                    case '>':
                        tape.Advance();
                        break;
                    case '<':
                        tape.Devance();
                        break;
                    case '[':
                        if (tape.Get() == 0)
                            pc = _bracketMap[pc];
                        break;
                    case ']':
                        if (tape.Get() != 0)
                            pc = _bracketMap[pc];
                        break;
                    case '.':
                        unchecked
                        {
                            _result = ((_result << 2) + tape.Get());
                        }
                        break;
                }
                
                pc += 1;
            }
        }
    }
    
    public override void Run()
    {
        var program = new Program(_text);
        program.Run();
        _result = program.Result;
    }
}