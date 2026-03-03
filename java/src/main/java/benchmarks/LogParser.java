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
        "/index.html", "/api/users", "/admin",
        "/images/logo.png", "/etc/passwd", "/wp-admin/setup.php"
    };
    private static final int[] STATUSES = {200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503};
    private static final String[] AGENTS = {
        "Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"
    };
    private static final String[] USERS = {
        "john", "jane", "alex", "sarah", "mike", "anna", "david", "elena"
    };
    private static final String[] DOMAINS = {
        "example.com", "gmail.com", "yahoo.com", "hotmail.com", "company.org", "mail.ru"
    };

    private static final Pattern[] COMPILED_PATTERNS = {
        Pattern.compile(" [5][0-9]{2} | [4][0-9]{2} "),
        Pattern.compile("bot|crawler|scanner|spider|indexing|crawl|robot|spider", Pattern.CASE_INSENSITIVE),
        Pattern.compile("etc/passwd|wp-admin|\\.\\./", Pattern.CASE_INSENSITIVE),
        Pattern.compile("\\d+\\.\\d+\\.\\d+\\.35"),
        Pattern.compile("/api/[^ \" ]+"),
        Pattern.compile("POST [^ ]* HTTP"),
        Pattern.compile("/login|/signin", Pattern.CASE_INSENSITIVE),
        Pattern.compile("get|post|put", Pattern.CASE_INSENSITIVE),
        Pattern.compile("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"),
        Pattern.compile("password=[^&\\s\"]+"),
        Pattern.compile("token=[^&\\s\"]+|api[_-]?key=[^&\\s\"]+"),
        Pattern.compile("session[_-]?id=[^&\\s\"]+"),
        Pattern.compile("\\[\\d+/\\w+/\\d+:1[3-7]:\\d+:\\d+ [+\\-]\\d+\\]")
    };

    private static final String[] PATTERN_NAMES = {
        "errors", "bots", "suspicious", "ips", "api_calls",
        "post_requests", "auth_attempts", "methods", "emails",
        "passwords", "tokens", "sessions", "peak_hours"
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
        StringBuilder sb = new StringBuilder();

        sb.append(IPS[i % IPS.length]);
        sb.append(String.format(" - - [%d/Oct/2023:%d:55:36 +0000] \"", i % 31, i % 60));
        sb.append(METHODS[i % METHODS.length]);
        sb.append(" ");

        if (i % 3 == 0) {
            sb.append(String.format("/login?email=%s%d@%s&password=secret%d",
                                    USERS[i % USERS.length], i % 100,
                                    DOMAINS[i % DOMAINS.length], i % 10000));
        } else if (i % 5 == 0) {
            sb.append("/api/data?token=");
            for (int j = 0; j < (i % 3) + 1; j++) {
                sb.append("abcdef123456");
            }
        } else if (i % 7 == 0) {
            sb.append(String.format("/user/profile?session_id=sess_%x", i * 12345));
        } else {
            sb.append(PATHS[i % PATHS.length]);
        }

        sb.append(String.format(" HTTP/1.1\" %d 2326 \"http://%s\" \"%s\"\n",
                                STATUSES[i % STATUSES.length],
                                DOMAINS[i % DOMAINS.length],
                                AGENTS[i % AGENTS.length]));

        return sb.toString();
    }

    @Override
    public void prepare() {
        linesCount = (int) configVal("lines_count");

        StringBuilder sb = new StringBuilder(linesCount * 200);
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