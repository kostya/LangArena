package benchmarks;

import java.util.HashMap;
import java.util.Map;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.regex.Pattern;
import java.util.regex.Matcher;

public abstract class Template extends Benchmark {
    protected static final String[] FIRST_NAMES = {"John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike"};
    protected static final String[] LAST_NAMES = {"Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis", "Miller", "Jones"};
    protected static final String[] CITIES = {"New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco"};

    protected static final String LOREM = "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. ";

    protected int count;
    protected long checksum;
    protected String text;
    protected String rendered;
    protected Map<String, String> vars;

    public Template() {
        this.count = (int) configVal("count");
        this.checksum = 0;
        this.text = "";
        this.rendered = "";
        this.vars = new HashMap<>();
    }

    @Override
    public void prepare() {
        StringBuilder sb = new StringBuilder();
        vars.clear();

        sb.append("<html><body>");
        sb.append("<h1>{{TITLE}}</h1>");
        vars.put("TITLE", "Template title");
        sb.append("<p>");
        sb.append(LOREM);
        sb.append("</p>");
        sb.append("<table>");

        for (int i = 0; i < count; i++) {
            if (i % 3 == 0) {
                sb.append("<!-- {comment} -->");
            }
            sb.append("<tr>");
            sb.append("<td>{{ FIRST_NAME").append(i).append(" }}</td>");
            sb.append("<td>{{LAST_NAME").append(i).append("}}</td>");
            sb.append("<td>{{  CITY").append(i).append("  }}</td>");

            vars.put("FIRST_NAME" + i, FIRST_NAMES[i % FIRST_NAMES.length]);
            vars.put("LAST_NAME" + i, LAST_NAMES[i % LAST_NAMES.length]);
            vars.put("CITY" + i, CITIES[i % CITIES.length]);

            sb.append("<td>{balance: ").append(i % 100).append("}</td>");
            sb.append("</tr>\n");
        }

        sb.append("</table>");
        sb.append("</body></html>");

        text = sb.toString();
    }

    @Override
    public long checksum() {
        return checksum + Helper.checksum(rendered.getBytes(StandardCharsets.UTF_8));
    }

    public static class Regex extends Template {
        private static final Pattern TEMPLATE_PATTERN = Pattern.compile("\\{\\{\\s*(.*?)\\s*\\}\\}");

        public Regex() {
            super();
        }

        @Override
        public String name() {
            return "Template::Regex";
        }

        @Override
        public void run(int iterationId) {
            StringBuilder sb = new StringBuilder(text.length());
            Matcher m = TEMPLATE_PATTERN.matcher(text);
            int lastEnd = 0;

            while (m.find()) {
                sb.append(text, lastEnd, m.start());
                String key = m.group(1);
                sb.append(vars.getOrDefault(key, ""));
                lastEnd = m.end();
            }
            sb.append(text, lastEnd, text.length());

            rendered = sb.toString();
            checksum += rendered.length();
        }
    }

    public static class Parse extends Template {

        public Parse() {
            super();
        }

        @Override
        public String name() {
            return "Template::Parse";
        }

        @Override
        public void run(int iterationId) {
            StringBuilder sb = new StringBuilder((int)(text.length() * 1.5));
            int i = 0;
            int len = text.length();

            while (i < len) {
                if (i + 1 < len && text.charAt(i) == '{' && text.charAt(i + 1) == '{') {
                    int j = i + 2;
                    while (j + 1 < len) {
                        if (text.charAt(j) == '}' && text.charAt(j + 1) == '}') {
                            break;
                        }
                        j++;
                    }

                    if (j + 1 < len) {
                        String key = text.substring(i + 2, j).trim();
                        String value = vars.get(key);
                        if (value != null) {
                            sb.append(value);
                        }
                        i = j + 2;
                        continue;
                    }
                }

                sb.append(text.charAt(i));
                i++;
            }

            rendered = sb.toString();
            checksum += rendered.length();
        }
    }
}