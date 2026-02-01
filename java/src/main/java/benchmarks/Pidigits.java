package benchmarks;

import java.io.ByteArrayOutputStream;
import java.math.BigInteger;

public class Pidigits extends Benchmark {
    private int nn;
    private ByteArrayOutputStream result;
    
    public Pidigits() {
        nn = (int) configVal("amount");
        result = new ByteArrayOutputStream();
    }
    
    @Override
    public String name() {
        return "Pidigits";
    }
    
    @Override
    public void run(int iterationId) {
        int i = 0;          // счетчик цифр
        int k = 0;          // k в формуле
        BigInteger ns = BigInteger.ZERO;  // накопленные цифры
        BigInteger a = BigInteger.ZERO;   // a в алгоритме
        int k1 = 1;         // k1 = 2k + 1
        BigInteger n = BigInteger.ONE;    // n в алгоритме
        BigInteger d = BigInteger.ONE;    // d в алгоритме
        
        while (i < nn) {
            k++;
            
            // t = n << 1 (умножение на 2)
            BigInteger t = n.shiftLeft(1);
            
            // Обновление переменных по формулам алгоритма Spigot
            n = n.multiply(BigInteger.valueOf(k));
            k1 += 2;
            a = a.add(t).multiply(BigInteger.valueOf(k1));
            d = d.multiply(BigInteger.valueOf(k1));
            
            // Проверка, можно ли получить следующую цифру
            if (a.compareTo(n) >= 0) {
                // Вычисление кандидата на цифру
                // t = floor((n*3 + a) / d)
                BigInteger[] divResult = n.multiply(BigInteger.valueOf(3))
                                         .add(a)
                                         .divideAndRemainder(d);
                int digit = divResult[0].intValue();
                BigInteger u = divResult[1].add(n);
                
                // Проверка, что цифра корректна
                if (d.compareTo(u) > 0) {
                    // Добавляем цифру
                    ns = ns.multiply(BigInteger.TEN).add(BigInteger.valueOf(digit));
                    i++;
                    
                    // Каждые 10 цифр выводим строку
                    if (i % 10 == 0) {
                        String line = String.format("%010d\t:%d\n", 
                            ns.longValue(), i);
                        try {
                            result.write(line.getBytes());
                        } catch (Exception e) {
                            // ignore
                        }
                        ns = BigInteger.ZERO;
                    }
                    
                    if (i >= nn) break;
                    
                    // Обновляем a и n для следующей итерации
                    a = a.subtract(d.multiply(BigInteger.valueOf(digit)))
                         .multiply(BigInteger.TEN);
                    n = n.multiply(BigInteger.TEN);
                }
            }
        }
        
        // Выводим оставшиеся цифры, если они есть
        if (ns.compareTo(BigInteger.ZERO) > 0) {
            String line = String.format("%0" + (nn % 10) + "d\t:%d\n",
                ns.longValue(), nn);
            try {
                result.write(line.getBytes());
            } catch (Exception e) {
                // ignore
            }
        }
    }
    
    @Override
    public long checksum() {
        return Helper.checksum(result.toString()) & 0xFFFFFFFFL;
    }
}