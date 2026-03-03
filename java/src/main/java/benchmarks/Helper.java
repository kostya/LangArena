package benchmarks;

import java.io.IOException;
import java.nio.file.*;
import java.util.*;
import java.util.function.Supplier;
import org.json.JSONObject;
import org.json.JSONArray;

public class Helper {
    private static final int IM = 139968;
    private static final int IA = 3877;
    private static final int IC = 29573;
    private static final int INIT = 42;

    private static int last = INIT;

    private static JSONObject CONFIG = new JSONObject();
    private static List<String> ORDER = new ArrayList<>();

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

    public static JSONObject getConfig() {
        return CONFIG;
    }

    public static List<String> getOrder() {
        return ORDER;
    }

    public static void loadConfig(String filename) throws IOException {
        String file = filename != null ? filename : "../test.js";
        String content = new String(Files.readAllBytes(Paths.get(file)));

        JSONArray array = new JSONArray(content);
        JSONObject dict = new JSONObject();
        ORDER.clear();

        for (int i = 0; i < array.length(); i++) {
            JSONObject item = array.getJSONObject(i);
            String name = item.getString("name");
            dict.put(name, item);
            ORDER.add(name);
        }
        CONFIG = dict;
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
}