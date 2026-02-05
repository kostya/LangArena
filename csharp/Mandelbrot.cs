using System.Text;

public class Mandelbrot : Benchmark
{
    private const int ITER = 50;
    private const double LIMIT = 2.0;

    private long _w;
    private long _h;
    private MemoryStream _resultStream;

    public Mandelbrot()
    {
        _resultStream = new MemoryStream();
        _w = ConfigVal("w");
        _h = ConfigVal("h");
    }

    public override void Run(long IterationId)
    {
        int w = (int)_w;
        int h = (int)_h;

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
                if ((zr * zr + zi * zi) <= (LIMIT * LIMIT)) byte_acc |= 0x01;

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

    public override uint Checksum => Helper.Checksum(_resultStream.ToArray());
}