module benchmarks.templates;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.regex;
import std.range;
import std.format;
import std.typecons;
import benchmark;
import helper;

static immutable string[] FIRST_NAMES = [
    "John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike"
];
static immutable string[] LAST_NAMES = [
    "Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis", "Miller", "Jones"
];
static immutable string[] CITIES = [
    "New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco"
];
static immutable string LOREM = "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. ";

void generateTemplate(ref string text, ref string[string] vars, int count)
{
    vars = null;
    auto sb = appender!string();
    sb.reserve(count * 200);

    sb.put("<html><body>");
    sb.put("<h1>{{TITLE}}</h1>");
    vars["TITLE"] = "Template title";
    sb.put("<p>");
    sb.put(LOREM);
    sb.put("</p>");
    sb.put("<table>");

    for (int i = 0; i < count; i++)
    {
        if (i % 3 == 0)
        {
            sb.put("<!-- {comment} -->");
        }
        sb.put("<tr>");
        sb.put(format!"<td>{{ FIRST_NAME%d }}</td>"(i));
        sb.put(format!"<td>{{LAST_NAME%d}}</td>"(i));
        sb.put(format!"<td>{{  CITY%d  }}</td>"(i));

        vars[format!"FIRST_NAME%d"(i)] = FIRST_NAMES[i % FIRST_NAMES.length];
        vars[format!"LAST_NAME%d"(i)] = LAST_NAMES[i % LAST_NAMES.length];
        vars[format!"CITY%d"(i)] = CITIES[i % CITIES.length];

        sb.put(format!"<td>{balance: %d}</td>"(i % 100));
        sb.put("</tr>\n");
    }

    sb.put("</table>");
    sb.put("</body></html>");

    text = sb.data;
}

class TemplateRegex : Benchmark
{
private:
    int count;
    string text;
    string rendered;
    uint checksumVal;
    string[string] vars;
    Regex!char re;

protected:
    override string className() const
    {
        return "Template::Regex";
    }

public:
    this()
    {
        count = configVal("count").to!int;
        checksumVal = 0;
        text = "";
        rendered = "";
        vars = null;
        re = regex(r"\{\{\s*(.*?)\s*\}\}", "g");
    }

    override void prepare()
    {
        generateTemplate(text, vars, count);
    }

    override void run(int iterationId)
    {
        auto result = appender!string();
        result.reserve(text.length);

        size_t lastPos = 0;
        auto matches = matchAll(text, re);

        foreach (m; matches)
        {
            if (lastPos < text.length)
            {
                result.put(text[lastPos .. m.pre.length]);
            }

            string key = m.captures[1].strip();
            if (key in vars)
            {
                result.put(vars[key]);
            }

            lastPos = text.length - m.post.length;
        }

        if (lastPos < text.length)
        {
            result.put(text[lastPos .. $]);
        }

        rendered = result.data;
        checksumVal += cast(uint) rendered.length;
    }

    override uint checksum()
    {
        return checksumVal + Helper.checksum(rendered);
    }
}

class TemplateParse : Benchmark
{
private:
    int count;
    string text;
    string rendered;
    uint checksumVal;
    string[string] vars;

protected:
    override string className() const
    {
        return "Template::Parse";
    }

public:
    this()
    {
        count = configVal("count").to!int;
        checksumVal = 0;
        text = "";
        rendered = "";
        vars = null;
    }

    override void prepare()
    {
        generateTemplate(text, vars, count);
    }

    override void run(int iterationId)
    {
        size_t len = text.length;
        auto result = appender!string();
        result.reserve(cast(int)(len * 1.5));

        size_t i = 0;
        while (i < len)
        {
            if (i + 1 < len && text[i] == '{' && text[i + 1] == '{')
            {
                size_t j = i + 2;
                while (j + 1 < len)
                {
                    if (text[j] == '}' && text[j + 1] == '}')
                    {
                        break;
                    }
                    j++;
                }

                if (j + 1 < len)
                {
                    string key = text[i + 2 .. j].strip();
                    if (key in vars)
                    {
                        result.put(vars[key]);
                    }
                    i = j + 2;
                    continue;
                }
            }

            result.put(text[i]);
            i++;
        }

        rendered = result.data;
        checksumVal += cast(uint) rendered.length;
    }

    override uint checksum()
    {
        return checksumVal + Helper.checksum(rendered);
    }
}
