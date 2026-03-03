mutable struct TemplateBase <: AbstractBenchmark
    count::Int64
    checksum::UInt32
    text::String
    rendered::String
    vars::Dict{String,String}
end

const FIRST_NAMES = ["John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike"]
const LAST_NAMES =
    ["Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis", "Miller", "Jones"]
const CITIES = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco"]
const LOREM = "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. "

function prepare_base(base::TemplateBase)
    text = IOBuffer()
    vars = base.vars
    empty!(vars)

    write(text, "<html><body>")
    write(text, "<h1>{{TITLE}}</h1>")
    vars["TITLE"] = "Template title"
    write(text, "<p>")
    write(text, LOREM)
    write(text, "</p>")
    write(text, "<table>")

    for i = 0:(base.count-1)
        if i % 3 == 0
            write(text, "<!-- {comment} -->")
        end
        write(text, "<tr>")
        write(text, "<td>{{ FIRST_NAME$(i) }}</td>")
        write(text, "<td>{{LAST_NAME$(i)}}</td>")
        write(text, "<td>{{  CITY$(i)  }}</td>")

        vars["FIRST_NAME$i"] = FIRST_NAMES[i%length(FIRST_NAMES)+1]
        vars["LAST_NAME$i"] = LAST_NAMES[i%length(LAST_NAMES)+1]
        vars["CITY$i"] = CITIES[i%length(CITIES)+1]

        write(text, "<td>{balance: $(i % 100)}</td>")
        write(text, "</tr>\n")
    end

    write(text, "</table>")
    write(text, "</body></html>")

    base.text = String(take!(text))
end

mutable struct TemplateRegex <: AbstractBenchmark
    base::TemplateBase
end

function TemplateRegex()
    count = Helper.config_i64("Template::Regex", "count")
    base = TemplateBase(count, UInt32(0), "", "", Dict{String,String}())
    return TemplateRegex(base)
end

name(b::TemplateRegex)::String = "Template::Regex"

function prepare(b::TemplateRegex)
    prepare_base(b.base)
end

function run(b::TemplateRegex, iteration_id::Int64)
    base = b.base
    text = base.text
    vars = base.vars

    pattern = r"\{\{\s*(.*?)\s*\}\}"
    result = IOBuffer()
    last_pos = 1

    for m in eachmatch(pattern, text, overlap = false)
        write(result, SubString(text, last_pos, first(m.offset)-1))
        key = m.captures[1]
        write(result, Base.get(vars, key, ""))
        last_pos = m.offset + length(m.match)
    end
    write(result, SubString(text, last_pos, length(text)))

    base.rendered = String(take!(result))
    base.checksum += UInt32(length(base.rendered))
end

function checksum(b::TemplateRegex)::UInt32
    base = b.base
    return base.checksum + Helper.checksum(base.rendered)
end

mutable struct TemplateParse <: AbstractBenchmark
    base::TemplateBase
end

function TemplateParse()
    count = Helper.config_i64("Template::Parse", "count")
    base = TemplateBase(count, UInt32(0), "", "", Dict{String,String}())
    return TemplateParse(base)
end

name(b::TemplateParse)::String = "Template::Parse"

function prepare(b::TemplateParse)
    prepare_base(b.base)
end

function run(b::TemplateParse, iteration_id::Int64)
    base = b.base
    text = base.text
    vars = base.vars
    len = length(text)

    rendered = IOBuffer()

    i = 1
    while i <= len
        if i + 1 <= len && text[i] == '{' && text[i+1] == '{'
            j = i + 2
            while j + 1 <= len
                if text[j] == '}' && text[j+1] == '}'
                    break
                end
                j += 1
            end

            if j + 1 <= len

                key = strip(text[(i+2):(j-1)])
                if haskey(vars, key)
                    write(rendered, vars[key])
                end
                i = j + 2
                continue
            end
        end

        write(rendered, text[i])
        i += 1
    end

    base.rendered = String(take!(rendered))
    base.checksum += UInt32(length(base.rendered))
end

function checksum(b::TemplateParse)::UInt32
    base = b.base
    return base.checksum + Helper.checksum(base.rendered)
end
