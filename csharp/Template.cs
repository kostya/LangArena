using System.Text;
using System.Collections.Generic;

public abstract class Template : Benchmark
{
    protected static readonly string[] FIRST_NAMES = { "John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike" };
    protected static readonly string[] LAST_NAMES = { "Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis", "Miller", "Jones" };
    protected static readonly string[] CITIES = { "New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco" };
    protected const string LOREM = "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. ";

    protected long _count;
    protected uint _checksum;
    protected string _text;
    protected string _rendered;
    protected Dictionary<string, string> _vars;

    public Template()
    {
        _count = ConfigVal("count");
        _checksum = 0;
        _text = "";
        _rendered = "";
        _vars = new Dictionary<string, string>();
    }

    public override void Prepare()
    {
        var sb = new StringBuilder((int)(_count * 200));
        _vars.Clear();

        sb.Append("<html><body>");
        sb.Append("<h1>{{TITLE}}</h1>");
        _vars["TITLE"] = "Template title";
        sb.Append("<p>");
        sb.Append(LOREM);
        sb.Append("</p>");
        sb.Append("<table>");

        for (int i = 0; i < _count; i++)
        {
            if (i % 3 == 0)
            {
                sb.Append("<!-- {comment} -->");
            }
            sb.Append("<tr>");
            sb.Append($"<td>{{{{ FIRST_NAME{i} }}}}</td>");
            sb.Append($"<td>{{{{LAST_NAME{i}}}}}</td>");
            sb.Append($"<td>{{{{  CITY{i}  }}}}</td>");

            _vars[$"FIRST_NAME{i}"] = FIRST_NAMES[i % FIRST_NAMES.Length];
            _vars[$"LAST_NAME{i}"] = LAST_NAMES[i % LAST_NAMES.Length];
            _vars[$"CITY{i}"] = CITIES[i % CITIES.Length];

            sb.Append($"<td>{{balance: {i % 100}}}</td>");
            sb.Append("</tr>\n");
        }

        sb.Append("</table>");
        sb.Append("</body></html>");

        _text = sb.ToString();
    }

    public override uint Checksum => _checksum + Helper.Checksum(_rendered);
}

public class TemplateRegex : Template
{
    private static readonly System.Text.RegularExpressions.Regex _regex =
        new System.Text.RegularExpressions.Regex(@"\{\{(.*?)\}\}",
            System.Text.RegularExpressions.RegexOptions.Compiled);

    public override string TypeName => "Template::Regex";

    public override void Run(long iterationId)
    {

        var result = new StringBuilder(_text.Length);
        int lastPos = 0;

        var matches = _regex.Matches(_text);
        foreach (System.Text.RegularExpressions.Match match in matches)
        {

            if (match.Index > lastPos)
            {
                result.Append(_text, lastPos, match.Index - lastPos);
            }

            string key = match.Groups[1].Value.Trim();

            if (_vars.TryGetValue(key, out string? value))
            {
                result.Append(value);
            }

            lastPos = match.Index + match.Length;
        }

        if (lastPos < _text.Length)
        {
            result.Append(_text, lastPos, _text.Length - lastPos);
        }

        _rendered = result.ToString();
        _checksum += (uint)_rendered.Length;
    }
}

public class TemplateParse : Template
{
    public override string TypeName => "Template::Parse";

    public override void Run(long iterationId)
    {
        int len = _text.Length;
        var result = new StringBuilder((int)(len * 1.5));

        int i = 0;
        while (i < len)
        {
            if (i + 1 < len && _text[i] == '{' && _text[i + 1] == '{')
            {
                int j = i + 2;
                while (j + 1 < len)
                {
                    if (_text[j] == '}' && _text[j + 1] == '}')
                    {
                        break;
                    }
                    j++;
                }

                if (j + 1 < len)
                {
                    string key = _text.Substring(i + 2, j - (i + 2)).Trim();
                    if (_vars.TryGetValue(key, out string? value))
                    {
                        result.Append(value);
                    }
                    i = j + 2;
                    continue;
                }
            }

            result.Append(_text[i]);
            i++;
        }

        _rendered = result.ToString();
        _checksum += (uint)_rendered.Length;
    }
}