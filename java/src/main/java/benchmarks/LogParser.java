package benchmarks;

import java.util.*;
import java.util.regex.Pattern;
import java.util.regex.Matcher;

public class LogParser extends Benchmark {
    private int linesCount;
    private String log;
    private long checksumVal;

    private static final String[] IPS = generateIPs();
    private static final String[] METHODS = {"GET", "POST", "PUT", "DELETE"};
    private static final String[] PATHS = {
        "/index.html", "/api/users", "/login", "/admin",
        "/images/logo.png", "/etc/passwd", "/wp-admin/setup.php"
    };
    private static final int[] STATUSES = {200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503};
    private static final String[] AGENTS = {
        "Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"
    };

    private static final Pattern[] COMPILED_PATTERNS = {
        Pattern.compile(" [5][0-9]{2} "),
        Pattern.compile("bot|crawler|scanner", Pattern.CASE_INSENSITIVE),
        Pattern.compile("etc/passwd|wp-admin|\\.\\./", Pattern.CASE_INSENSITIVE),
        Pattern.compile("\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.35"),
        Pattern.compile("/api/[^ \"]+"),
        Pattern.compile("POST [^ ]* HTTP"),
        Pattern.compile("/login|/signin", Pattern.CASE_INSENSITIVE),
        Pattern.compile("get|post", Pattern.CASE_INSENSITIVE)
    };

    private static final String[] PATTERN_NAMES = {
        "errors", "bots", "suspicious", "ips",
        "api_calls", "post_requests", "auth_attempts", "methods"
    };

    private static String[] generateIPs() {
        String[] ips = new String[255];
        for (int i = 0; i < 255; i++) {
            ips[i] = "192.168.1." + (i + 1);
        }
        return ips;
    }

    public LogParser() {
        checksumVal = 0;
    }

    @Override
    public String name() {
        return "Etc::LogParser";
    }

    private String generateLogLine(int i) {
        return String.format("%s - - [%d/Oct/2023:13:55:36 +0000] \"%s %s HTTP/1.0\" %d 2326 \"-\" \"%s\"\n",
                             IPS[i % IPS.length],
                             i % 31,
                             METHODS[i % METHODS.length],
                             PATHS[i % PATHS.length],
                             STATUSES[i % STATUSES.length],
                             AGENTS[i % AGENTS.length]);
    }

    @Override
    public void prepare() {
        linesCount = (int) configVal("lines_count");

        StringBuilder sb = new StringBuilder(linesCount * 150);
        for (int i = 0; i < linesCount; i++) {
            sb.append(generateLogLine(i));
        }

        log = sb.toString();
    }

    @Override
    public void run(int iterationId) {
        Map<String, Integer> matches = new HashMap<>();

        for (int i = 0; i < COMPILED_PATTERNS.length; i++) {
            Matcher matcher = COMPILED_PATTERNS[i].matcher(log);
            int count = 0;
            while (matcher.find()) {
                count++;
            }
            matches.put(PATTERN_NAMES[i], count);
        }

        int total = 0;
        for (int count : matches.values()) {
            total += count;
        }
        checksumVal += total;
    }

    @Override
    public long checksum() {
        return checksumVal;
    }
}