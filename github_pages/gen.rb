require "json"
require 'date'
require 'fileutils'

# To generate data for github pages just call this with results file
# ruby gen.rb ../results/2026-01-16-x86_64-linux-gnu.js

FILENAME = ARGV[0]
J = JSON.parse(File.read(FILENAME))

puts "Parse #{FILENAME}, date: #{J['date']}, arch: #{J['arch']}"

def history_data
	dir = File.dirname(FILENAME)
	arch = J['arch']
	pattern = File.join(dir, "*.js")
	current_date = Date.parse(J['date'])

	jsons = Dir.glob(pattern).map do |file|
	  if file != FILENAME
	    data = JSON.parse(File.read(file))
	    file_date = Date.parse(data['date'])	    
	    file_arch = data['arch']	    
	    if file_arch == arch && file_date < current_date && J['uname-name'] && J['uname-name'] == data['uname-name']
	    	data
	    end
	  end
	end.compact

	jsons.sort_by! do |j|
	  Date.parse(j['date'])
	end.reverse!

	jsons
end

HISTORY = history_data
puts "Found history data: #{HISTORY.map { |j| j['date'] }.inspect}"

class Gen
	def initialize(j)
		@j = j
    @tests = j['tests']
    @langs = j['langs']
    @runs_prod = []
    @runs_all = []
    j['runs'].each do |k, v|
      if v == "prod"
        @runs_prod << k
      end
      @runs_all << k
    end
	end

  def check_missing
    @tests.each do |test|
      @runs_all.each do |run|
        if !@j["#{test}-runtime"][run] || @j["#{test}-runtime"][run].is_a?(String)
          if @runs_prod.include?(run)
            puts "Warning Missing PROD #{run}:#{test}"
          else
            puts "Warning Missing HACK #{run}:#{test}"
          end
        end
      end
    end
  end

  # 1 table runtimes
  def runtime_table
    main_table('runtime')
  end

  def runtime_table_by_best_run
    t = main_table('runtime', _best_lang_run.values)
    t[:description] += "<br><strong>Only fastest configurations for each language are included.</strong>"
    t
  end

  def memory_table
    main_table('mem-mb')
  end

  def memory_table_by_best_run
    t = main_table('mem-mb', _best_lang_run.values)
    t[:description] += "<br><strong>Only fastest configurations for each language are included.</strong>"
    t    
  end

  def main_table(field, runs = @runs_prod)
    m = @tests.map do |test|
      runs.map do |run|
        if @j["#{test}-#{field}"][run]
          format_float @j["#{test}-#{field}"][run]
        else
          puts "Warning missing value for #{test} #{field} #{run}"
          nil
        end
      end
    end
    desc = <<-DESC
This table compares runtime performance for standard configurations across all languages.<br>
<br>
<strong>Matmul</strong> is matrix multiplication.<br>
<strong>Matmul4T</strong>, <strong>Matmul8T</strong>, and <strong>Matmul16T</strong> are multi-threaded versions that use 4, 8, and 16 threads respectively.<br>
The same matrix sizes are passed to each, so the threaded versions are expected to be faster.
<br>
    DESC
    {map: m, up_header: runs, left_header: @tests, summary: field == 'runtime' ? 'sum' : 'avg', lang: :up, first_row: "Test", description: desc}
  end

  def source
    sum_bcf = 0.0
    sum_lines = 0

    @langs.each do |lang|
      sz = @j["source-size-kb"][lang]
      gsz = @j["source-gzip-size-kb"][lang]
      sum_bcf += sz / gsz.to_f
      sum_lines += @j["source-lines-count"][lang]
    end

    avg_bcf = sum_bcf / @langs.size.to_f
    avg_lines = sum_lines / @langs.size.to_f

    m = []    
    @langs.each do |lang|
      sz = @j["source-size-kb"][lang]
      gsz = @j["source-gzip-size-kb"][lang]
      lines = @j["source-lines-count"][lang]
      bcf = sz / gsz.to_f / avg_bcf
      lcf = lines / avg_lines
      cf = bcf * (lcf ** 1.5)
      pc = -((cf - 1.0) * 100).round(1)

      m << [lang, sz.round(1), gsz.round(1), lines, (sz / gsz.to_f).round(2), bcf.round(3), lcf.round(3), cf.round(3), pc]
    end

    m.sort_by! { |arr| -arr[-1] }

    left_header = m.map { |arr| arr[0] }
    stars = _assign_stars(m.map { |arr| -arr[-1]})

    m.each_with_index { |arr, index| arr.shift; arr.append(_star_str stars[index]) }
    
    desc = <<-DESC
This table compares how concisely different programming languages express the same program.
<br><br>
• <strong>Boilerplate</strong> = source / gzip — lower means less redundant code<br>
• <strong>Boilerplate vs Avg</strong> = relative to average language (1.0 = average)<br>
• <strong>Lines vs Avg</strong> = line count relative to average (1.0 = average)<br>
• <strong>Expressiveness Score</strong> = overall conciseness - (Boilerplate vs Avg) × (Lines vs Avg)<sup>1.5</sup> — lower is better<br>
• <strong>Expressiveness vs Avg, %</strong> = how much better/worse than average language.<br>
• <strong>Award stars</strong> = overall rating (5★ = most expressive, 1★ = most verbose)
<br><br>
    DESC

    {map: m, up_header: ["Size, kb", "Gzip Size, kb", "Lines Count", "Boilerplate", "Boilerplate vs Avg", "Lines vs Avg", "Expressiveness Score", "Expressiveness vs Avg, %", "Award"], left_header: left_header, lang: :left, description: desc, first_row: "Lang"}
  end

  def versions
    left_header = []
    arr = @j['version'].map do |run, ver|
      if @runs_prod.include?(run)
        left_header << run
        [ver]
      end
    end.compact
    {map: arr, left_header: left_header, up_header: ["Version"], lang: :left, first_row: "Run"}
  end

  # def build_flags
  #   left_header = []
  #   arr = @j['build-cmd'].map do |run, ver|
  #     if @runs_prod.include?(run)
  #       left_header << run
  #       [ver]
  #     end
  #   end.compact
  #   {map: arr, left_header: left_header, up_header: ["Build Flags"], lang: :left}
  # end

  def compile(runs = @runs_prod)
    m = []
    runs.each do |run|
      m << [run, format_float(@j['compile-time-cold'][run]), format_float(@j['compile-mem-mb'][run]), format_float(@j['binary-size-kb'][run] / 1024.0)]
    end

    m.sort_by! do |line|
      line[1]
    end

    m2 = []
    left_header = []
    m.each do |line|
      m2 << line[1..-1]
      left_header << line[0]
    end

    desc = <<-DESC
      The timing measurement for compilation isn't quite accurate right now and may show incorrect results — I'll fix it soon.
    DESC

    {map: m2, left_header: left_header, up_header: ["Time, s", "Memory Peak, Mb", "Binary size, Mb"], lang: :left, first_row: "Run", description: desc}
  end

  def format_float(v)
    if v.abs >= 1000
      v.to_i
    elsif v.abs >= 100
      v.round(1)
    elsif v.abs >= 1
      v.round(2)
    else
      v.round(3)
    end
  end

  def _vert(matrix, index)
    res = []
    matrix.each { |line| res << line[index] }
    res
  end

  def main_legend
    legend_count = 3

    # редкостный говнокод тут, пофиг главное работает
    a = awards
    totals = _vert(a[:map], a[:up_header].index("Total")).map { |s| s =~ /([0-9\.]*?) \/ 100/; $1.to_f }
    totals = a[:left_header].zip(totals).map { |a, v| [a, "#{v} pts"] }
    
    b = lang_rank
    runtimes = _vert(b[:map], b[:up_header].index("Runtime, s")).map { |s| s =~ /([0-9\.]+)/; $1.to_f.round(1) }
    runtime = b[:left_header].zip(runtimes).sort_by { |lang, runtime| runtime }.map { |a, v| [a, "#{v}s"] }

    wins = _vert(b[:map], b[:up_header].index("Wins Count")).map { |s| s =~ /([0-9\.]+)/; $1.to_i }
    wins = b[:left_header].zip(wins).sort_by { |lang, win| -win }.map { |a, v| [a, "#{v}"] }

    ct = _vert(b[:map], b[:up_header].index("Compile Time, s")).map { |s| s =~ /([0-9\.]+)/; $1.to_f.round(1) }
    ct = b[:left_header].zip(ct).sort_by { |lang, v| v }.map { |a, v| [a, "#{v}s"] }

    exp = _vert(b[:map], b[:up_header].index("Expressiveness")).map { |s| s =~ /([\-0-9\.]+)/; $1.to_f.round(1) }
    exp = b[:left_header].zip(exp).sort_by { |lang, v| -v }.map { |a, v| [a, "#{v}%"] }

    {
      total: totals[0...legend_count], 
      runtime: runtime[0...legend_count], 
      wins: wins[0...legend_count], 
      compile_time: ct[0...legend_count], 
      expressiveness: exp[0...legend_count]
    }
  end

  def awards
    r, up_header = _lang_ranks

    m = []    
    r2 = r.sort_by { |k, v| v[1] } # sort by runtime
    left_header = []

    get_values = ->(index) { res = []; r2.each { |lang, data| res << [lang, data[index]] }; res }
    v3 = up_header.size.times.map do |index|
      get_values[index]
    end

    r2.each do |lang, data|
      left_header << lang

      data.each_with_index do |d, index|
        next if index == 0
        values = v3[index]
        values = (up_header[index] == "Wins Count" || up_header[index] == "Expressiveness") ? values.sort_by { |(a, b)| -b } : values.sort_by { |(a, b)| b }
        best = values[0][1]

        v = if up_header[index] == "Wins Count"
          ((d / best.to_f) * 100).round(1)
        elsif up_header[index] == "Looses Count"
          best = values[-1][1]
          d = (best - d) # 0 - 14, 14 - 0
          ((d / best.to_f) * 100).round(1)
        elsif up_header[index] == "Expressiveness"
          best = values[0][1] - values[-1][1]
          d -= values[-1][1]
          ((d / best.to_f) * 100).round(1)
        else
          ((best / d.to_f) * 100).round(1)
        end

        data[index] = if values[0][0] == lang
          %Q{<span class="value_badge gold">#{v} / 100</span>}
        elsif values[1][0] == lang
          %Q{<span class="value_badge silver">#{v} / 100</span>}
        elsif values[2][0] == lang
          %Q{<span class="value_badge bronze">#{v} / 100</span>}
        else
          "#{v} / 100"
        end
      end

      m << data
    end

    up_header = ["Best Config", "Runtime", "Memory", "Wins", "Looses", "Compile Time", "Compile Memory", "Binary Size", "Expressiveness", "Total", "Award"]
    # weights = [                  0.35,       0.3,      0.1,     0.03,    0.07,            0.02,              0.05,          0.08,         ]
    # weights = [                  0.35,       0.3,      0.07,     0.03,    0.07,            0.02,              0.05,          0.11,         ]
    weights = [                  0.5,        0.2,      0.1,     0.02,    0.1,            0.02,              0.01,          0.05,         ]
    unless weights.sum == 1.0
      raise "Bad weights #{weights.inspect} #{weights.sum}"
    end

    # ну и говнокод
    totals = []
    m.each_with_index do |arr, index|
      sum = 0.0
      weights.each_with_index do |w, i|
        v = arr[i + 1]
        v =~ /([\-0-9\.]*?) \/ 100/
        sum += $1.to_f * w        
      end
      totals << [index, sum.round(1)]
    end

    totals2 = totals.sort_by { |(a, b)| -b }
    m.each_with_index do |arr, index|
      v = totals[index][1]
      arr << if totals2[0][0] == index
        %Q{<span class="value_badge gold">#{v} / 100</span>}
      elsif totals2[1][0] == index
        %Q{<span class="value_badge silver">#{v} / 100</span>}
      elsif totals2[2][0] == index
        %Q{<span class="value_badge bronze">#{v} / 100</span>}
      else
        "#{v} / 100"
      end
    end

    m.each_with_index do |arr, index|
      arr << _star_str(_assign_stars(totals.map { |t| 100 - t[1] })[index])
    end

    m2 = []
    left_header2 = []
    totals2.each { |(i, _)| m2 << m[i]; left_header2 << left_header[i] }

    puts "Totals: #{totals.each_with_index.map { |t, i| [left_header[i], t[1]] }.inspect}" 

    formula = weights.each_with_index.map { |w, i| "#{up_header[i + 1]}(#{(w * 100).round(1)})%" } * " + "

    desc = <<-DESC
Summary language score<br><br>
<strong>Legend:</strong> <span class="value_badge gold">1st</span> <span class="value_badge silver">2nd</span> <span class="value_badge bronze">3rd</span><br><br>

All scores 0-100 (100 = best)<br><br>
<strong>Total</strong> = weighted average = #{formula}
    DESC
    {map: m2, up_header: up_header, lang: :left, description: desc, left_header: left_header2, first_row: "Lang"}
  end

  def lang_rank
    r, up_header = _lang_ranks

    m = []    
    r2 = r.sort_by { |k, v| v[1] } # sort by runtime
    left_header = []


    get_values = ->(index) { res = []; r2.each { |lang, data| res << [lang, data[index]] }; res }
    v3 = up_header.size.times.map do |index|
      get_values[index]      
    end

    r2.each do |lang, data|
      left_header << lang

      data.each_with_index do |d, index|
        next if index == 0
        values = v3[index]
        values = (up_header[index] == "Wins Count" || up_header[index] == "Expressiveness") ? values.sort_by { |(a, b)| -b } : values.sort_by { |(a, b)| b }

        data[index] = if values[0][0] == lang
          %Q{<span class="value_badge gold">#{d}</span>}
        elsif values[1][0] == lang
          %Q{<span class="value_badge silver">#{d}</span>}
        elsif values[2][0] == lang
          %Q{<span class="value_badge bronze">#{d}</span>}
        else
          d.to_s
        end
      end

      m << data
    end

    desc = <<-DESC
Summary language rankings<br><br>
Legend: <span class="value_badge gold">1st</span> <span class="value_badge silver">2nd</span> <span class="value_badge bronze">3rd</span><br><br>
<strong>Only fastest configurations for each language are included.</strong>
    DESC
    {map: m, up_header: up_header, lang: :left, description: desc, left_header: left_header, first_row: "Lang"}
  end

  def test_rank(field)
    left_header = @tests
    up_header = %w{1th 2th 3th worst}.map { |order| ["#{order}"] } .flatten
    m = []
    @tests.each do |test|
      d = @runs_prod.map do |run|
        [run, (@j["#{test}-#{field}"][run])]
      end.sort_by { |(a, b)| b }

      best = d[0]

      m << [0, 1, 2, -1].map do |i|
        v = d[i][1] / best[1]
        v = if v < 1.01
          v = "1"
        elsif v < 1.1
          v.round(2)
        else
          v.round(1)
        end
        v_str = i == 0 ? "" : " [#{v}x]"
        %Q{<span class="language-badge lang_#{_lang_for(d[i][0])}">#{d[i][0]}#{v_str}</span>}
      end.flatten
    end
    desc = <<-DESC
    DESC
    {map: m, left_header: left_header, up_header: up_header, description: desc, first_row: "Test", lang: :no}
  end

  def _lang_ranks
    result = Hash.new { |h, k| h[k] = [] }
    up_header = []

    runs = _best_lang_run.values
    up_header << "Best Config"
    runs.each do |run|
      result[_lang_for run] << run
    end

    # best runtime
    h = Hash.new(0.0)
    runs.each do |run|
      @tests.each do |test|
        h[run] += @j["#{test}-runtime"][run]
      end
    end
    min_runtime = h.min_by { |k, v| v }[1]

    up_header << "Runtime, s"
    # up_header << "Runtime vs Fastest"
    h.each do |run, runtime|
      result[_lang_for run] << format_float(runtime)
      # result[_lang_for run] << format_float(runtime / min_runtime)
    end

    # memory
    h = Hash.new(0.0)
    runs.each do |run|
      @tests.each do |test|
        h[run] += @j["#{test}-mem-mb"][run]
      end
    end
    h2 = {}
    h.each { |k, v| h2[k] = v / @tests.size.to_f }
    h = h2

    min_memory = h.min_by { |k, v| v }[1]

    up_header << "AvgMemory, Mb"
    # up_header << "AvgMemory vs Fastest"
    h.each do |run, mem|
      result[_lang_for run] << format_float(mem)
      # result[_lang_for run] << format_float(mem / min_memory)
    end

    # wins/looses count
    wins = {}
    looses = {}
    @tests.each do |test|
      best = 1000000000.0
      best_run = "-"
      worst = -best
      worst_run = "-"
      runs.each do |run|
        v = @j["#{test}-runtime"][run]
        if v < best
          best = v
          best_run = run
        elsif v > worst
          worst = v
          worst_run = run
        end
      end
      wins[test] = best_run
      looses[test] = worst_run
    end

    up_header << "Wins Count"
    up_header << "Looses Count"
    runs.each do |run|
      result[_lang_for run] << wins.count { |k, v| v == run }
      result[_lang_for run] << looses.count { |k, v| v == run }
    end

    # compile time
    h = Hash.new(0.0)
    runs.each do |run|
      h[run] = @j['compile-time-cold'][run]
    end
    min = h.min_by { |k, v| v }[1]

    up_header << "Compile Time, s"
    # up_header << "Compile Time vs Fastest"
    runs.each do |run|
      result[_lang_for run] << format_float(@j['compile-time-cold'][run])
      # result[_lang_for run] << format_float(@j['compile-time-cold'][run] / min)
    end

    # compile memory 
    h = Hash.new(0.0)
    runs.each do |run|
      h[run] = @j['compile-mem-mb'][run]
    end
    min = h.min_by { |k, v| v }[1]

    up_header << "Compile Memory, Mb"    
    # up_header << "Compile Memory vs Fastest"
    runs.each do |run|
      result[_lang_for run] << format_float(@j['compile-mem-mb'][run])
      # result[_lang_for run] << format_float(@j['compile-mem-mb'][run] / min)
    end

    # binary size
    h = Hash.new(0.0)
    runs.each do |run|
      h[run] = @j['binary-size-kb'][run] / 1024.0
    end
    min = h.min_by { |k, v| v }[1]

    up_header << "Binary Size, Mb"
    # up_header << "Binary Size vs Fastest"
    runs.each do |run|
      result[_lang_for run] << format_float(@j['binary-size-kb'][run] / 1024.0)
      # result[_lang_for run] << format_float(@j['binary-size-kb'][run] / 1024.0 / min)
    end

    # source
    up_header << "Expressiveness"
    s = source
    runs.each do |run|      
      left_index = s[:left_header].index(_lang_for run)
      up_index = s[:up_header].index("Expressiveness vs Avg, %")
      result[_lang_for run] << s[:map][left_index][up_index]
    end    

    [result, up_header]
  end

  def generate
    File.open("data.js", 'w') do |f| 
      f.write("var Data = ")
      f.write(to_h.to_json)
      f.write(";")
    end
  end

  def hacking
    res = {}
    @langs.each do |lang|
      runs = @runs_all.select { |run| _lang_for(run) == lang }
      res[lang] = main_table('runtime', runs)
      desc = <<-DESC
This table shows special "hacked" configurations — excluded from official rankings. <br>
Shows how optimization flags affect performance. <br>
Hacked configs marked with <strong>-Hack</strong> suffix.<br><br>
DESC

      runs.each do |run|
        desc += "• <strong>#{run}</strong> - #{@j['build-cmd'][run]}; #{@j['run-cmd'] ? @j['run-cmd'][run] : ""}<br>"
      end

      res[lang][:description] = desc
    end
    res
  end

  def history(runs = @runs_prod)
    res = {}

    runs.each do |run|
      runtime = 0.0
      cnt = 0

      @tests.each do |test|
        runtime += @j["#{test}-runtime"][run]
        cnt += 1
      end

      res[_lang_for(run)] ||= {}
      res[_lang_for(run)][run] = [[@j['date'], format_float(runtime)]]

      hist_log = []
      HISTORY.each do |hj|
        runtime2 = 0.0
        cnt2 = 0

        @tests.each do |test|
          if (rt = hj["#{test}-runtime"]) && rt[run]
            runtime2 += rt[run]
            cnt2 += 1
          end
        end

        if cnt == cnt2 # both have same runs and same counts numbers          
          res[_lang_for(run)][run].unshift [hj['date'], format_float(runtime2)]          
        else
          # puts "Skip history file #{hj['date']} for #{run}, because of #{cnt.inspect} != #{cnt2.inspect}"
        end
      end
      puts "History for #{run}: #{res[_lang_for(run)][run].map &:first}"
    end

    
    res
  end

  def prev_diff
    hist = nil

    HISTORY.each do |hj|
      cnt = 0
      @runs_prod.each do |run|
        @tests.each do |test|
          if (rt = hj["#{test}-runtime"]) && rt[run]
            cnt += 1
          end
        end
      end

      puts "Diff try version #{hj['date']}"
      if cnt > (@tests.size * @runs_prod.size * 0.8)
        hist = hj
        break
      end
    end

    return unless hist
    field = 'runtime'

    m = @tests.map do |test|
      @runs_prod.map do |run|
        if @j["#{test}-#{field}"][run]
          v = @j["#{test}-#{field}"][run]

          if (rt = hist["#{test}-#{field}"]) && rt[run]
            v -= rt[run]
          end

          format_float v
        else
          puts "Warning missing value for #{test} #{field} #{run}"
          nil
        end
      end
    end
    desc = <<-DESC
    Runtime diff with previous run, from #{hist['date']}.
    DESC
    {map: m, up_header: @runs_prod, left_header: @tests, summary: 'sum', lang: :up, description: desc, first_row: "Test"}
  end

  def to_h
    {
      "date": @j['date'],
      'arch': @j['arch'],
      'pc': @j['pc'],
      
      'langs_count': @langs.size,
      'runs_prod_count': @runs_prod.size,
      'tests_count': @j['tests'].size,

      'runtime_table': runtime_table,      
      'memory_table': memory_table,
      'runtime_table_by_lang': runtime_table_by_best_run,
      'memory_table_by_lang': memory_table_by_best_run,

      'source': source,
      'versions': versions,
      # 'build_flags': build_flags,
      'compile': compile,
      'compile_by_lang': compile(_best_lang_run.values),

      'hacking': hacking,
      'history': history,
      'prev_diff': prev_diff,

      'lang_rank': lang_rank,
      # 'test_rank_rt': test_rank('runtime'),
      # 'test_rank_mem': test_rank('mem-mb'),
      'awards': awards,
      'main_legend': main_legend,

    }
  end

  def _lang_for(run)
    v = run.downcase.split('/').first
    v.gsub("++", "pp").gsub("#", "sharp").gsub("go", "golang")
  end

  def _best_lang_run(runs = @runs_prod) # return {"lang" => "best run"}
    h = Hash.new(0.0)
    runs.each do |run|
      @tests.each do |test|
        h[run] += @j["#{test}-runtime"][run]
      end
    end

    # Find best result for each language
    h2 = {}
    @langs.each do |lang|
      keys = h.keys.select { |k| _lang_for(k) == lang }

      min_runtime = 100000000.0
      min_runtime_key = ""
      keys.each do |k|
        if h[k] < min_runtime
          min_runtime = h[k]
          min_runtime_key = k
        end
      end
      h2[lang] = min_runtime_key
    end
    h2
  end

  def _assign_stars(values)
    # Сортируем значения
    sorted = values.sort
    n = sorted.size

    # Создаем маппинг значение->звезды
    value_to_stars = {}
    sorted.each_with_index do |val, idx|
      # Определяем группу (0-4) и преобразуем в звезды (5-1)
      group = (idx * 5 / n.to_f).floor
      stars = 5 - group
      value_to_stars[val] = stars unless value_to_stars[val]  # сохраняем первое вхождение
    end

    # Возвращаем звезды в исходном порядке
    values.map { |val| value_to_stars[val] }
  end

  def _star_str(n, all = 5)
    res = ""
    n.times { res += "★" }
    (all-n).times { res += "☆" }
    res
  end
end

g = Gen.new(J)
g.check_missing
g.generate

