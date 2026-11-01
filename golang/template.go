package main

import (
	"fmt"
	regexp "github.com/coregx/coregex"
	"strings"
)

type TemplateBase struct {
	BaseBenchmark
	count    int64
	checksum uint32
	text     string
	rendered string
	vars     map[string]string
}

var (
	firstNames = []string{"John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike"}
	lastNames  = []string{"Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis", "Miller", "Jones"}
	cities     = []string{"New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco"}
	lorem      = "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. "
)

func (t *TemplateBase) Prepare() {
	t.count = t.ConfigVal("count")
	t.vars = make(map[string]string)

	var buf strings.Builder
	buf.Grow(int(t.count) * 200)

	buf.WriteString("<html><body>")
	buf.WriteString("<h1>{{TITLE}}</h1>")
	t.vars["TITLE"] = "Template title"
	buf.WriteString("<p>")
	buf.WriteString(lorem)
	buf.WriteString("</p>")
	buf.WriteString("<table>")

	for i := 0; i < int(t.count); i++ {
		if i%3 == 0 {
			buf.WriteString("<!-- {comment} -->")
		}
		buf.WriteString("<tr>")
		buf.WriteString(fmt.Sprintf("<td>{{ FIRST_NAME%d }}</td>", i))
		buf.WriteString(fmt.Sprintf("<td>{{LAST_NAME%d}}</td>", i))
		buf.WriteString(fmt.Sprintf("<td>{{  CITY%d  }}</td>", i))

		t.vars[fmt.Sprintf("FIRST_NAME%d", i)] = firstNames[i%len(firstNames)]
		t.vars[fmt.Sprintf("LAST_NAME%d", i)] = lastNames[i%len(lastNames)]
		t.vars[fmt.Sprintf("CITY%d", i)] = cities[i%len(cities)]

		buf.WriteString(fmt.Sprintf("<td>{balance: %d}</td>", i%100))
		buf.WriteString("</tr>\n")
	}

	buf.WriteString("</table>")
	buf.WriteString("</body></html>")

	t.text = buf.String()
}

type TemplateRegex struct {
	TemplateBase
	re *regexp.Regexp
}

func (t *TemplateRegex) Name() string {
	return "Template::Regex"
}

func (t *TemplateRegex) Prepare() {
	t.TemplateBase.Prepare()
	t.re = regexp.MustCompile(`{{(.*?)}}`)
}

func (t *TemplateRegex) Run(iteration_id int) {
	result := t.re.ReplaceAllStringFunc(t.text, func(match string) string {

		key := match[2 : len(match)-2]
		key = strings.TrimSpace(key)
		if val, ok := t.vars[key]; ok {
			return val
		}
		return ""
	})

	t.rendered = result
	t.checksum += uint32(len(t.rendered))
}

func (t *TemplateRegex) Checksum() uint32 {
	return t.checksum + ChecksumBytes([]byte(t.rendered))
}

type TemplateParse struct {
	TemplateBase
}

func (t *TemplateParse) Name() string {
	return "Template::Parse"
}

func (t *TemplateParse) Run(iteration_id int) {
	text := t.text
	textLen := len(text)
	vars := t.vars

	var buf strings.Builder
	buf.Grow(int(float64(textLen) * 1.5))

	i := 0
	for i < textLen {
		if i+1 < textLen && text[i] == '{' && text[i+1] == '{' {

			j := i + 2
			for j+1 < textLen {
				if text[j] == '}' && text[j+1] == '}' {
					break
				}
				j++
			}

			if j+1 < textLen {

				key := text[i+2 : j]
				key = strings.TrimSpace(key)
				if val, ok := vars[key]; ok {
					buf.WriteString(val)
				}
				i = j + 2
				continue
			}
		}

		buf.WriteByte(text[i])
		i++
	}

	t.rendered = buf.String()
	t.checksum += uint32(len(t.rendered))
}

func (t *TemplateParse) Checksum() uint32 {
	return t.checksum + ChecksumBytes([]byte(t.rendered))
}
