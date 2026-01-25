public class BrainfuckRecursion : Benchmark
{
    private string _text = "";
    private long _result = 0;
    
    public override long Result => _result;
    
    public BrainfuckRecursion() { }
    
    public override void Prepare()
    {
        _text = Helper.Input.GetValueOrDefault(nameof(BrainfuckRecursion), "");
    }
    
    // Используем readonly record struct для value types
    private interface IOp { }
    private readonly record struct Inc(int Value) : IOp;
    private readonly record struct Move(int Value) : IOp;
    private readonly record struct Print : IOp;
    private record class Loop(List<IOp> Operations) : IOp;
    
    private sealed class Tape
    {
        private byte[] _tape = new byte[1024];  // Начальный размер
        private int _pos = 0;
        
        public byte Get() => _tape[_pos];
        
        public void Inc(int x) => _tape[_pos] = (byte)(_tape[_pos] + x);
        
        public void Move(int x)
        {
            _pos += x;
            
            if (_pos < 0)
            {
                // Движение влево - расширяем в начале
                int needed = -_pos;
                byte[] newTape = new byte[_tape.Length + needed];
                Array.Copy(_tape, 0, newTape, needed, _tape.Length);
                _tape = newTape;
                _pos = needed;
            }
            else if (_pos >= _tape.Length)
            {
                // Движение вправо - удваиваем размер
                int newSize = Math.Max(_tape.Length * 2, _pos + 1);
                Array.Resize(ref _tape, newSize);
            }
        }
    }
    
    private sealed class Program
    {
        private readonly List<IOp> _operations;
        private long _result = 0;
        
        public long Result => _result;
        
        public Program(string code)
        {
            int index = 0;
            _operations = Parse(ref index, code);
            _operations.TrimExcess();  // Освобождаем лишнюю память
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
                
                if (op is not null)
                    operations.Add(op);
                
                if (c == ']')
                    break;
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
            // Используем for вместо foreach для избежания аллокации enumerator
            for (int i = 0; i < operations.Count; i++)
            {
                var op = operations[i];
                
                switch (op)
                {
                    case Inc inc:
                        tape.Inc(inc.Value);
                        break;
                        
                    case Move move:
                        tape.Move(move.Value);
                        break;
                        
                    case Print:
                        _result = ((_result << 2) + tape.Get());
                        break;
                        
                    case Loop loop:
                        // Предвычисляем condition вне цикла
                        byte condition;
                        while ((condition = tape.Get()) != 0)
                        {
                            RunOperations(loop.Operations, tape);
                        }
                        break;
                }
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