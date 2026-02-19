package benchmarks;

import java.io.IOException;
import java.nio.file.*;
import java.util.*;
import java.util.function.Supplier;
import org.json.JSONObject;

public class Helper {
    private static final int IM = 139968;
    private static final int IA = 3877;
    private static final int IC = 29573;
    private static final int INIT = 42;

    private static int last = INIT;

    public static void reset() {
        last = INIT;
    }

    public static int nextInt(int max) {
        last = (last * IA + IC) % IM;
        return (int)((last / (double)IM) * max);
    }

    public static int nextInt(int from, int to) {
        return nextInt(to - from + 1) + from;
    }

    public static double nextFloat(double max) {
        last = (last * IA + IC) % IM;
        return max * last / (double)IM;
    }

    public static double nextFloat() {
        return nextFloat(1.0);
    }

    public static void debug(Supplier<String> message) {
        if ("1".equals(System.getenv("DEBUG"))) {
            System.out.println(message.get());
        }
    }

    public static long checksum(String v) {
        long hash = 5381;
        for (char c : v.toCharArray()) {
            hash = ((hash << 5) + hash) + c;
        }
        return hash & 0xFFFFFFFFL;
    }

    public static long checksum(byte[] v) {
        long hash = 5381;
        for (byte b : v) {
            hash = ((hash << 5) + hash) + (b & 0xFF);
        }
        return hash & 0xFFFFFFFFL;
    }

    public static long checksumF64(double v) {
        return checksum(String.format(Locale.US, "%.7f", v)) & 0xFFFFFFFFL;
    }

    public static JSONObject CONFIG = new JSONObject();

    public static void loadConfig(String filename) throws IOException {
        String file = filename != null ? filename : "../test.js";
        String content = new String(Files.readAllBytes(Paths.get(file)));
        CONFIG = new JSONObject(content);
    }

    public static long configI64(String className, String fieldName) {
        try {
            if (CONFIG.has(className) && CONFIG.getJSONObject(className).has(fieldName)) {
                return CONFIG.getJSONObject(className).getLong(fieldName);
            } else {
                throw new RuntimeException("Config not found for " + className + ", field: " + fieldName);
            }
        } catch (Exception e) {
            System.err.println(e.getMessage());
            return 0;
        }
    }

    public static String configS(String className, String fieldName) {
        try {
            if (CONFIG.has(className) && CONFIG.getJSONObject(className).has(fieldName)) {
                return CONFIG.getJSONObject(className).getString(fieldName);
            } else {
                throw new RuntimeException("Config not found for " + className + ", field: " + fieldName);
            }
        } catch (Exception e) {
            System.err.println(e.getMessage());
            return "";
        }
    }

    private static String inspect(String str) {
        StringBuilder sb = new StringBuilder("\"");
        for (char c : str.toCharArray()) {
            switch (c) {
            case '\n':
                sb.append("\\n");
                break;
            case '\r':
                sb.append("\\r");
                break;
            case '\t':
                sb.append("\\t");
                break;
            case '\\':
                sb.append("\\\\");
                break;
            case '\"':
                sb.append("\\\"");
                break;
            default:
                if (c >= ' ' && c <= '~') {
                    sb.append(c);
                } else {
                    sb.append(String.format("\\u%04x", (int)c));
                }
            }
        }
        sb.append("\"");
        return sb.toString();
    }
}