package benchmarks;

import java.io.ByteArrayOutputStream;
import java.math.BigInteger;

public class Pidigits extends Benchmark {
    private int nn;
    private StringBuilder result;

    public Pidigits() {
        nn = (int) configVal("amount");
        result = new StringBuilder();
    }

    @Override
    public String name() {
        return "Pidigits";
    }

    @Override
    public void run(int iterationId) {
        int i = 0;          
        int k = 0;          
        BigInteger ns = BigInteger.ZERO;  
        BigInteger a = BigInteger.ZERO;   
        int k1 = 1;         
        BigInteger n = BigInteger.ONE;    
        BigInteger d = BigInteger.ONE;    

        while (i < nn) {
            k++;

            BigInteger t = n.shiftLeft(1);

            n = n.multiply(BigInteger.valueOf(k));
            k1 += 2;
            a = a.add(t).multiply(BigInteger.valueOf(k1));
            d = d.multiply(BigInteger.valueOf(k1));

            if (a.compareTo(n) >= 0) {

                BigInteger[] divResult = n.multiply(BigInteger.valueOf(3))
                                         .add(a)
                                         .divideAndRemainder(d);
                int digit = divResult[0].intValue();
                BigInteger u = divResult[1].add(n);

                if (d.compareTo(u) > 0) {

                    ns = ns.multiply(BigInteger.TEN).add(BigInteger.valueOf(digit));
                    i++;

                    if (i % 10 == 0) {
                        String line = String.format("%010d\t:%d\n", ns.longValue(), i);
                        result.append(line);
                        ns = BigInteger.ZERO;
                    }

                    if (i >= nn) break;

                    a = a.subtract(d.multiply(BigInteger.valueOf(digit)))
                         .multiply(BigInteger.TEN);
                    n = n.multiply(BigInteger.TEN);
                }
            }
        }

        if (ns.compareTo(BigInteger.ZERO) > 0) {
            String line = String.format("%0" + (nn % 10) + "d\t:%d\n", ns.longValue(), nn);
            result.append(line);
        }
    }

    @Override
    public long checksum() {
        return Helper.checksum(result.toString()) & 0xFFFFFFFFL;
    }
}