using System.Text;

public class Mandelbrot : Benchmark
{
    private const int ITER = 50;
    private const double LIMIT = 2.0;
    
    private int _n;
    private MemoryStream _resultStream;
    
    public override long Result => Helper.Checksum(_resultStream.ToArray());
    
    public Mandelbrot()
    {
        _resultStream = new MemoryStream();
    }
    
    public override void Prepare()
    {
        var className = nameof(Mandelbrot);
        if (Helper.Input.TryGetValue(className, out var value))
        {
            if (int.TryParse(value, out var iter))
            {
                _n = iter;
                return;
            }
        }
        _n = 1;
    }
    
    public override void Run()
    {
        int w = _n;
        int h = _n;
        
        using (var writer = new StreamWriter(_resultStream, Encoding.ASCII, 1024, true))
        {
            writer.Write($"P4\n{w} {h}\n");
        }
        
        byte byte_acc = 0;
        int bit_num = 0;
        
        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                double zr = 0.0, zi = 0.0;
                double cr = (2.0 * x / w - 1.5);
                double ci = (2.0 * y / h - 1.0);
                
                int i = 0;
                double tr, ti;
                
                do
                {
                    tr = zr * zr - zi * zi + cr;
                    ti = 2.0 * zr * zi + ci;
                    zr = tr;
                    zi = ti;
                    i++;
                } while (i < ITER && (zr * zr + zi * zi) <= (LIMIT * LIMIT));
                
                byte_acc <<= 1;
                if ((zr * zr + zi * zi) <= (LIMIT * LIMIT))
                    byte_acc |= 0x01;
                
                bit_num++;
                
                if (bit_num == 8)
                {
                    _resultStream.WriteByte(byte_acc);
                    byte_acc = 0;
                    bit_num = 0;
                }
                else if (x == w - 1)
                {
                    byte_acc <<= (8 - w % 8);
                    _resultStream.WriteByte(byte_acc);
                    byte_acc = 0;
                    bit_num = 0;
                }
            }
        }
    }
}