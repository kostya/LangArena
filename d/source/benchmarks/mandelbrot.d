module benchmarks.mandelbrot;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.math;
import benchmark;
import helper;

class Mandelbrot : Benchmark {
private:
    enum ITER = 50;
    enum LIMIT = 2.0;

    int w, h;
    ubyte[] resultBin;

protected:
    override string className() const { return "Mandelbrot"; }

public:
    this() {
        w = configVal("w");
        h = configVal("h");
        resultBin = [];
    }

    override void run(int iterationId) {

        string header = "P4\n" ~ to!string(w) ~ " " ~ to!string(h) ~ "\n";
        resultBin ~= cast(ubyte[])header;

        int bitNum = 0;
        ubyte byteAcc = 0;

        double tmpW = cast(double)w;
        double tmpH = cast(double)h;

        for (int y = 0; y < h; y++) {
            double ci = 2.0 * y / tmpH - 1.0;

            for (int x = 0; x < w; x++) {
                double cr = 2.0 * x / tmpW - 1.5;

                double zr = 0.0, zi = 0.0;
                double tr = 0.0, ti = 0.0;

                int i = 0;
                while (i < ITER && tr + ti <= LIMIT * LIMIT) {
                    zi = 2.0 * zr * zi + ci;
                    zr = tr - ti + cr;
                    tr = zr * zr;
                    ti = zi * zi;
                    i++;
                }

                byteAcc <<= 1;
                if (tr + ti <= LIMIT * LIMIT) {
                    byteAcc |= 0x01;
                }
                bitNum++;

                if (bitNum == 8) {
                    resultBin ~= byteAcc;
                    byteAcc = 0;
                    bitNum = 0;
                } else if (x == w - 1) {
                    byteAcc <<= (8 - (w % 8));
                    resultBin ~= byteAcc;
                    byteAcc = 0;
                    bitNum = 0;
                }
            }
        }
    }

    override uint checksum() {
        return Helper.checksum(resultBin);
    }
}