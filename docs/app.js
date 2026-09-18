function changeTab(tabId, group_lang_option_checked = false, choose_lang = null) {
    window.currentTab = tabId;
    window.groupOption = group_lang_option_checked;
    
    let newUrl = window.location.pathname + '#/' + tabId;
    if (group_lang_option_checked) {
        newUrl += '/group';
    }
    if (choose_lang) {
        newUrl += '/lang/' + choose_lang;
    }
    history.pushState({ tab: tabId, group: group_lang_option_checked, lang: choose_lang }, '', newUrl);
    
    const tabNames = {
        'overview_tab': 'Overview',
        'runtime_tab': 'Runtime Performance',
        'memory_tab_rel': 'Runtime Score',
        'memory_tab': 'Memory Usage',
        'source_tab': 'Expressiveness',
        'compile_tab': 'Compile Time',
        'ranking_tab': 'Rankings',
        'awards_tab': 'Scores',
        'versions_tab': 'Versions',
        'analys_tab': 'AI Analysis',
        'critic_tab': 'AI Critic',
        'hacking_tab': 'Hacking',
        'prev_run_tab': 'Updates',
        'history_tab': 'History',
        'history_full_tab': 'Full History',
        'askai_tab': 'Q&A',
        'top_tab': 'Summary',
        'hacking_summary_tab': 'Hacking Summary'
    };
    document.title = tabNames[tabId] + ' | LangArena';
    
    $('.tabs .tab').removeClass('active');
    $(`#${tabId}`).addClass('active');

    const $results = $('#results');
    $results.empty();
    
    switch(tabId) {
        case 'overview_tab':
            loadScriptOnDemand('overview.js', function() {
                if (typeof overview_tab === 'function') {
                    overview_tab($results);
                } else {
                    $results.html('<div class="error">Module not available</div>');
                }
            });
            break;
        case 'runtime_tab':
            var data = window.Data.runtime_table;
            if (group_lang_option_checked) {
                data = window.Data.runtime_table_by_lang;
            };
            create_table($results, "Runtime, s", data, 1, true, group_lang_option_checked);
            break;
        case 'memory_tab_rel':
            var data = window.Data.runtime_table_rel;
            if (group_lang_option_checked) {
                data = window.Data.runtime_table_by_lang_rel;
            };
            create_table($results, "Runtime score, 0..100, higher better", data, 2, true, group_lang_option_checked);
            break;        
        case 'memory_tab':
            var data = window.Data.memory_table;
            if (group_lang_option_checked) {
                data = window.Data.memory_table_by_lang;
            };
            create_table($results, "Peak memory usage, Mb", data, 1, true, group_lang_option_checked);
            break;
        case 'source_tab':
            create_table($results, "Source Code", window.Data.source);
            break;
        case 'versions_tab':
            create_table($results, "Versions", window.Data.versions);
            break;
        case 'compile_tab':
            var data = window.Data.compile;
            if (group_lang_option_checked) {
                data = window.Data.compile_by_lang;
            };
            create_table($results, "Compile", data, 0, true, group_lang_option_checked);
            break;
        case 'hacking_tab':
            hacking_tab(choose_lang || 'c');            
            break;
        case 'analys_tab':
            loadScriptOnDemand('ai_analysis.js', function() {
                if (typeof ai_analys === 'function') {
                    ai_analys($results);
                } else {
                    $results.html('<div class="error">AI Analysis module not available</div>');
                }
            });
            break;
        case 'critic_tab':
            loadScriptOnDemand('ai_critic.js', function() {
                if (typeof ai_critic === 'function') {
                    ai_critic($results);
                } else {
                    $results.html('<div class="error">AI Critic module not available</div>');
                }
            });
            break;
        case 'history_tab':
            history_tab(choose_lang || 'c', 'history', 'history_tab');
            break;
        case 'history_full_tab':
            history_tab(choose_lang || 'c', 'history_full', 'history_full_tab');
            break;
        case 'prev_run_tab':
            prev_run_tab();
            break;
        case 'ranking_tab':
            create_table($results, "Summary language rankings", window.Data.lang_rank);
            break;
        case 'awards_tab':
            create_table($results, "Summary language score", window.Data.awards);
            break;        
        case 'askai_tab':
            $results.append(`<div style="text-align: center;"><iframe src="https://langarena.hopto.org" style="width: 90%; height: 4000px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);" title="AI Q&A System" loading="lazy"></iframe><div>`);
            break;
        case 'top_tab':
            top_tab();
            break;
        case 'hacking_summary_tab':
            hacking_summary_tab();
            break;
    }
}

function UpdateData(data) {
    document.getElementById('results-update-date').innerHTML = '<strong>Update date:</strong> ' + window.Data.date;
    langs_str = '';
    for (const lang of window.Data.langs) {
        langs_str += `<span class="language-badge lang_${run_name_to_lang_class_name(lang)}">${lang}</span>`;
    }
    document.getElementById('results-langs').innerHTML = '<strong>Languages:</strong> <span class=part_langs>' + langs_str + '</span>';
    
    var $u = $('ul#main_legend_total');
    $u.empty();
    for (let i = 0; i < window.Data.main_legend.total.length; i++ ) {
        $u.append(`
            <li style="padding: 8px 0; border-bottom: 1px solid #dee2e6; display: flex; justify-content: space-between;">
                <span class="language-badge lang_${run_name_to_lang_class_name(window.Data.main_legend.total[i][0])}">${lang_name_to_human(window.Data.main_legend.total[i][0])}</span>
                <span>${window.Data.main_legend.total[i][1]}</span>
            </li>
        `);
    }

    $u = $('ul#main_legend_runtime');
    $u.empty();
    for (let i = 0; i < window.Data.main_legend.runtime.length; i++ ) {
        $u.append(`
            <li style="padding: 8px 0; border-bottom: 1px solid #dee2e6; display: flex; justify-content: space-between;">
                <span class="language-badge lang_${window.Data.main_legend.runtime[i][0]}">${lang_name_to_human(window.Data.main_legend.runtime[i][0])}</span>
                <span>${window.Data.main_legend.runtime[i][1]}</span>
            </li>
        `);
    }

    $u = $('ul#main_legend_wins');
    $u.empty();
    for (let i = 0; i < window.Data.main_legend.wins.length; i++ ) {
        $u.append(`
            <li style="padding: 8px 0; border-bottom: 1px solid #dee2e6; display: flex; justify-content: space-between;">
                <span class="language-badge lang_${window.Data.main_legend.wins[i][0]}">${lang_name_to_human(window.Data.main_legend.wins[i][0])}</span>
                <span>${window.Data.main_legend.wins[i][1]} / ${window.Data.tests_count}</span>
            </li>
        `);
    }

    $u = $('ul#main_legend_compile_time');
    $u.empty();
    for (let i = 0; i < window.Data.main_legend.compile_time.length; i++ ) {
        $u.append(`
            <li style="padding: 8px 0; border-bottom: 1px solid #dee2e6; display: flex; justify-content: space-between;">
                <span class="language-badge lang_${window.Data.main_legend.compile_time[i][0]}">${lang_name_to_human(window.Data.main_legend.compile_time[i][0])}</span>
                <span>${window.Data.main_legend.compile_time[i][1]}</span>
            </li>
        `);
    }

    $u = $('ul#main_legend_expressiveness');
    $u.empty();
    for (let i = 0; i < window.Data.main_legend.expressiveness.length; i++ ) {
        $u.append(`
            <li style="padding: 8px 0; border-bottom: 1px solid #dee2e6; display: flex; justify-content: space-between;">
                <span class="language-badge lang_${window.Data.main_legend.expressiveness[i][0]}">${lang_name_to_human(window.Data.main_legend.expressiveness[i][0])}</span>
                <span>${window.Data.main_legend.expressiveness[i][1]}</span>
            </li>
        `);
    }
    
    const hash = window.location.hash;
    let tabFromUrl = null;
    let groupFromUrl = false;
    let langFromUrl = null;

    if (hash && hash.startsWith('#/')) {
        const parts = hash.substring(2).split('/');
        tabFromUrl = parts[0];
        
        for (let i = 1; i < parts.length; i++) {
            if (parts[i] === 'group') {
                groupFromUrl = true;
            } else if (parts[i] === 'lang' && parts[i+1]) {
                langFromUrl = parts[i+1];
                i++;
            }
        }
    }

    if (tabFromUrl && document.getElementById(tabFromUrl)) {
        changeTab(tabFromUrl, groupFromUrl, langFromUrl);
    } else {
        changeTab('top_tab', false, null);
    }

}

function create_table($parent_div, title, data, use_color_compare = 0, group_lang_option = false, group_lang_option_checked = false) {
    $parent_div.append(`<div class=table_header><h2>${title}</h2></div>`);

    if (group_lang_option) {
        var activeTabId = $('.tabs button.tab.active').attr('id');

        $parent_div.append(`
            <label class="ios-checkbox">
              <input id=group_lang_checkbox type="checkbox" onchange="changeTab('${activeTabId}', this.checked)" ${group_lang_option_checked ? "checked" : ""}>
              <span class="ios-checkbox-box"></span>
              <span class="ios-checkbox-text">Group Langs</span>
            </label>
        `);
    }

    const $div = $('<div>', {class: 'results-container'});
    $parent_div.append($div);

    const $table = $('<table>', {class: "results-table"});    
    const $thead = $('<thead>');
    const $tbody = $('<tbody>');
    const $tfoot = $('<tfoot>');
    $table.append($thead);
    $table.append($tbody);
    if (data.summary) {
        $table.append($tfoot);
    }    
    $div.append($table);

    const map = data.map;
    const up_header = data.up_header;
    const left_header = data.left_header;
    const lang_sticky_up = data.lang == "up";
    const lang_sticky_left = data.lang == "left";

    const $tr = $('<tr>');
    $thead.append($tr);
    const $th = $('<th>', {class: "lang_all"});
    if (data.first_row) $th.text(data.first_row);
    $tr.append($th);
    for (let h of up_header) {
        const $td = $('<th>').html(h.replace(/\//g, '<br>').replace(/TypeScript/g, 'TS').replace(/Mojo/g, 'Mojo*').replace(/Gossamer/g, 'Gsmr'));
        $tr.append($td);
        if (lang_sticky_up) $td.attr('class', 'lang_' + run_name_to_lang_class_name(h));
    }

    for (let i = 0; i < map.length; i++) {
        const line = map[i];
        const $tr = $('<tr>');
        const $td = $('<td>').text(left_header[i]);
        $tr.append($td);
        if (lang_sticky_left) $td.attr('class', 'lang_' + run_name_to_lang_class_name(left_header[i]));
        
        let speed_class;
        if (use_color_compare == 1) {
            speed_class = createSpeedClassFunction(line);
        } else if (use_color_compare == 2) {
            speed_class = createSpeedClassFunction(line, true);
        }

        for (let j = 0; j < line.length; j++) {
            const v = line[j];
            const $td = $('<td>', {title: `${left_header[i]}[${up_header[j]}]: ${v}`}).html(v);
            if (use_color_compare != 0) $td.attr('class', speed_class(v));
            $tr.append($td);
        };
        $tbody.append($tr);
    }

    if (data.summary) {
        const $tr2 = $('<tr>');
        $tfoot.append($tr2);
        const $td = $('<td>', {class: "lang_all"});
        $tr2.append($td)
        $td.text(data.summary.desc);

        const summaries = data.summary.data;

        if (use_color_compare == 1) {
            speed_class = createSpeedClassFunction(summaries);
        } else if (use_color_compare == 2) {
            speed_class = createSpeedClassFunction(summaries, true);
        }

        for (let j = 0; j < summaries.length; j++) {
            const s = summaries[j];
            const $td = $('<td>', {title: `${up_header[j]}: ${s}`}).text(s);
            if (use_color_compare != 0) $td.attr('class', speed_class(s));
            $tr2.append($td);
        }
    }

    if (data.description) {
        $parent_div.append(`<div class="table-legend">${data.description}</div>`);        
    }
}

function run_name_to_lang_class_name(run_name) {
    let s = run_name.split('/')[0].toLowerCase();
    s = s.replace('nim++', 'nim');
    s = s.replace('++', 'pp');
    s = s.replace('#', 'sharp');
    return s;
}

function lang_name_to_human(lang) {
    let s = lang.charAt(0).toUpperCase() + lang.slice(1);
    s = s.replace('pp', '++');
    s = s.replace('sharp', '#');
    return s;
}

function run_name_to_lang(run_name) {
    let s = run_name.split('/')[0].toLowerCase();
    return s.charAt(0).toUpperCase() + s.slice(1);
}

function createSpeedRankFunction(values, invert = false) {
    const min = Math.min(...values);
    const max = Math.max(...values);
    const range = max - min;
    
    if (range < 0.00001) {
        return function(value) {
            return invert ? 9 : 0;
        };
    }
    
    const shift = min <= 0 ? -min + 0.001 : 0;
    const shiftedValues = values.map(v => v + shift);
    const shiftedMin = min + shift;
    const shiftedMax = max + shift;
    
    const middleValues = shiftedValues.filter(v => 
        Math.abs(v - shiftedMin) > 0.00001 && 
        Math.abs(v - shiftedMax) > 0.00001
    );
    
    if (middleValues.length === 0) {
        return function(value) {
            const shiftedValue = value + shift;
            if (Math.abs(shiftedValue - shiftedMin) < 0.00001) {
                return invert ? 9 : 0;
            }
            return invert ? 0 : 9;
        };
    }
    
    const logValues = middleValues.map(v => Math.log10(v));
    const logMin = Math.min(...logValues);
    const logMax = Math.max(...logValues);
    const logRange = logMax - logMin;
    
    return function(value) {
        const shiftedValue = value + shift;
        
        if (Math.abs(shiftedValue - shiftedMin) < 0.00001) {
            return invert ? 9 : 0;
        }
        if (Math.abs(shiftedValue - shiftedMax) < 0.00001) {
            return invert ? 0 : 9;
        }
        if (shiftedValue <= 0) {
            return invert ? 9 : 0;
        }
        const logVal = Math.log10(shiftedValue);
        
        if (logRange < 0.00001) {
            return invert ? 4 : 5;
        }
        
        const normalized = (logVal - logMin) / logRange;
        let rank = 1 + Math.floor(normalized * 8);
        rank = Math.max(1, Math.min(8, rank));
        
        return invert ? 9 - rank : rank;
    };
}

function createSpeedClassFunction(values, invert = false) {
    const rankFunc = createSpeedRankFunction(values, invert);
    return function(value) {
        const rank = rankFunc(value);
        return `speed_${rank}`;
    };
}

function legendWord(i) {
    if (i == 0) return 'fastest';
    else if (i == 1 || i == 2) return 'faster';
    else if (i == 3 || i == 4) return 'fast';
    else if (i == 5 || i == 6) return 'slow';
    else if (i == 7 || i == 8) return 'slower';
    else if (i == 9) return 'slowest';
    return 'wtf';
}

function value_fixed(v) {
    if (v >= 1000) {
        return v.toFixed(0);
    } else if (v >= 100) {
        return v.toFixed(1);
    } else if (v >= 1) {
        return v.toFixed(2);
    } else {
        return v.toFixed(3);
    }    
}

function lang_color(lang) {
    const key = lang.toLowerCase();
    const colorMap = {
        'c': '#00599C',
        'cpp': '#F34B7D',
        'go': '#00ADD8',
        'golang': '#00ADD8',
        'crystal': '#000000',
        'rust': '#DEA584',
        'csharp': '#512BD4',
        'swift': '#F05138',
        'java': '#007396',
        'kotlin': '#7F52FF',
        'typescript': '#3178C6',
        'zig': '#F7A41D',
        'd': '#B03931',
        'v': '#5C87DB',
        'julia': '#8B0000',
        'nim': '#FFC200',
        'fsharp': '#378BBA',
        'dart': '#00B4AB',
        'python': '#3776AB',
        'odin': '#A16B3E',
        'scala': '#DC322F',
        'c3': '#3C99B1',
        'ruby': '#CC342D',
        'mojo': '#FF4D00',
        'php': '#8892BF',
        'gossamer': '#38BDF8',
        'js': '#F7DF1E'
    };

    return colorMap[key] || '#95a5a6';
}

function lang_rank_tab($results, lang_rank) {
    create_table($results, "Rankings", lang_rank);
    $results.append(`
        <div style="height: 400px; width: 100%;">
            <canvas id="chart" style="display: block; height: 100%; width: 100%;"></canvas>
        </div>
    `);

    const ctx = document.getElementById('chart');
    const data = lang_rank.map;
    const leftHeaders = lang_rank.left_header;

    let colors = leftHeaders.map(lang => { return lang_color(lang); });

    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: leftHeaders,
            datasets: [{
                label: 'Runtime (s)',
                data: data.map(d => d[1]),
                backgroundColor: colors,
                borderWidth: 1
            }]
        },
        options: {
            responsive: true,
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    callbacks: {
                        label: (ctx) => `${ctx.parsed.y.toFixed(2)} seconds`
                    }
                }
            },
            scales: {
                x: {
                    ticks: {
                        maxRotation: 90,
                        minRotation: 90,
                        autoSkip: false
                    }
                },
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: 'Best Runtime (seconds)'
                    }
                }
            }
        }
    });            
}

function hacking_tab(select_lang = 'c') {
    const $results = $('#results');
    $results.empty();
    $filters = $('<div>', {class: 'filters'});
    $filters.append('<span>Filter by language:</span>');

    const keys = Object.keys(window.Data['history_full']);
    for (const lang of keys) {
        $filters.append(`
            <button class="filter-btn" id="filter_button_${lang}" onclick="changeTab('hacking_tab', false, '${lang}')" style="border-left-color: ${lang_color(lang)}; border-left-width: 3px;">
                ${lang}
            </button>        
        `);
    }

    $results.append($filters);
    $('.filters .filter-btn').removeClass('active');    
    $(`#filter_button_${select_lang}`).addClass('active');
    create_table($results, select_lang, window.Data.hacking[select_lang], 1);
}

function history_tab(select_lang = 'c', key = 'history', tab = 'history_tab') {
    const $results = $('#results');
    $results.empty();
    
    $filters = $('<div>', {class: 'filters'});
    $filters.append('<span>Filter by language:</span>');

    const keys = Object.keys(window.Data[key]);
    for (const lang of keys) {
        $filters.append(`
            <button class="filter-btn" id="filter_button_${lang}" onclick="changeTab('${tab}', false, '${lang}')" style="border-left-color: ${lang_color(lang)}; border-left-width: 3px;">
                ${lang}
            </button>        
        `);
    }

    $results.append($filters);
    $('.filters .filter-btn').removeClass('active');    
    $(`#filter_button_${select_lang}`).addClass('active');
    
    $results.append(`<div class=table_header><h2>History runtime of language: ${select_lang}</h2></div>`);
    
    $results.append(`
        <div>
          <canvas id="historyChart"></canvas>
        </div>
    `);

    const historyData = window.Data[key][select_lang];

    function prepareChartData(selectedLang = null) {
      const allDates = new Set();
      const datasets = [];
      
      Object.entries(historyData).forEach(([lang, data]) => {
        data.forEach(([date]) => allDates.add(date));
      });
      
      const sortedDates = Array.from(allDates).sort();
      const colorPalette = [
        '#4CAF50', '#2196F3', '#FF9800', '#9C27B0', '#F44336',
        '#00BCD4', '#8BC34A', '#FF5722', '#795548', '#607D8B',
        '#3F51B5', '#009688', '#FFC107', '#E91E63', '#673AB7'
      ];
      
      let colorIndex = 0;
      Object.entries(historyData).forEach(([lang, data]) => {
        const values = new Array(sortedDates.length).fill(null);
        data.forEach(([date, value]) => {
          const dateIndex = sortedDates.indexOf(date);
          if (dateIndex !== -1) {
            values[dateIndex] = value;
          }
        });
        datasets.push({
          label: lang,
          data: values,
          borderColor: colorPalette[colorIndex % colorPalette.length],
          backgroundColor: colorPalette[colorIndex % colorPalette.length] + '20',
          borderWidth: 2,
          fill: false,
          tension: 0.1,
          pointRadius: 4,
          pointHoverRadius: 6
        });
        
        colorIndex++;
      });
      
      return {
        labels: sortedDates,
        datasets: datasets
      };
    }
    let chart;

    function initChart() {
  
      const canvas = document.getElementById('historyChart');
      if (!canvas) {
        console.error('Canvas element not found!');
        return;
      }
      
      const ctx = canvas.getContext('2d');
      
      chart = new Chart(ctx, {
        type: 'line',
        data: prepareChartData(),
        options: {
          responsive: true,
          maintainAspectRatio: false,
          interaction: {
            mode: 'index',
            intersect: false,
          },
          plugins: {
            legend: {
              position: 'right',
              labels: {
                boxWidth: 12,
                padding: 15
              }
            },
            tooltip: {
              callbacks: {
                label: function(context) {
                  return `${context.dataset.label}: ${context.parsed.y.toFixed(2)}s`;
                }
              }
            }
          },
          scales: {
            x: {
              title: {
                display: true,
                text: 'Date'
              }
            },
            y: {
              title: {
                display: true,
                text: 'Runtime (seconds)'
              },
              beginAtZero: false,
              suggestedMin: 0
            }
          }
        }
      });
    }
    
    setTimeout(() => {
      initChart();
    }, 100);
}

function prev_run_tab() {
    const $results = $('#results');
    $results.empty();
    if (window.Data.prev_diff) {
        create_table($results, "Previous update runtime diff, %", window.Data.prev_diff, 1);
    } else {
        $results.append(`<div class=table_header><h2>Previous update runtime diff, %</h2></div><br><br>No Data ...`);
    }
}

function top_tab() {
    const $results = $('#results');
    $results.empty();
    
    $results.append(`
        <div class=table_header><h2>Summary</h2></div>
    `);
    
    $results.append(`
        <div class="stats-grid">
            <div class="stat-card" style="height: 740px">
                <h3>Runtime Score 0-100</h3>
                <div style="height: 700px">
                <canvas id="chart_runtime_score"></canvas>
                </div>
            </div>
            <div class="stat-card" style="height: 740px">
                <h3>Runtime, s</h3>
                <div style="height: 700px">
                <canvas id="chart_runtime"></canvas>
                </div>
            </div>
            <div class="stat-card" style="height: 740px">
                <h3>Memory, Mb</h3>
                <div style="height: 700px">
                <canvas id="chart_memory"></canvas>
                </div>
            </div>
            <div class="stat-card" style="height: 740px">
                <h3>Compile Cold WallTime, s</h3>
                <div style="height: 700px">
                <canvas id="chart_compile"></canvas>
                </div>
            </div>
            <div class="stat-card" style="height: 740px">
                <h3>Expressiveness, %</h3>
                <div style="height: 700px">
                <canvas id="chart_expressiveness"></canvas>
                </div>
            </div>
        </div>
    `);
    
    setTimeout(() => {
        if (window.Data.runtime_table_by_lang_rel) {
            createTopChart(
                'chart_runtime_score',
                window.Data.runtime_table_by_lang_rel,
                '',
                false,
                100
            );
        }
        
        if (window.Data.runtime_table_by_lang) {
            createTopChart(
                'chart_runtime',
                window.Data.runtime_table_by_lang,
                '',
                true,
                null
            );
        }
        
        if (window.Data.memory_table_by_lang) {
            createTopChart(
                'chart_memory',
                window.Data.memory_table_by_lang,
                '',
                true,
                null
            );
        }
        
        if (window.Data.compile_by_lang) {
            createTopChartFromCompile(
                'chart_compile',
                window.Data.compile_by_lang,
                ''
            );
        }
        
        if (window.Data.source) {
            createTopChartFromSource(
                'chart_expressiveness',
                window.Data.source,
                ''
            );
        }
        
    }, 300);
}

function createTopChart(containerId, data, title, lowerIsBetter, maxValue) {
    if (!data || !data.up_header || !data.summary || !data.summary.data) {
        console.error('No data for chart:', containerId, data);
        return;
    }
    
    const canvas = document.getElementById(containerId);
    if (!canvas) {
        console.error('Canvas not found:', containerId);
        return;
    }
    
    const ctx = canvas.getContext('2d');
    
    const up_header = data.up_header;
    const summary = data.summary.data;
    
    const combined = up_header.map((name, index) => ({
        name: run_name_to_lang(name),
        value: summary[index]
    }));
    
    const sorted = lowerIsBetter 
        ? combined.sort((a, b) => a.value - b.value)
        : combined.sort((a, b) => b.value - a.value);
    
    const colors = sorted.map(item => {
        return lang_color(run_name_to_lang_class_name(item.name));
    });
    
    let max = maxValue;
    if (!max) {
        const values = sorted.map(item => item.value);
        max = Math.max(...values) * 1.15;
    }
    
    const axisLabel = lowerIsBetter 
        ? `${title} (lower is better)`
        : `${title} (higher is better)`;
    
    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: sorted.map(item => item.name),
            datasets: [{
                label: title,
                data: sorted.map(item => item.value),
                backgroundColor: colors,
                borderColor: colors,
                borderWidth: 2,
                borderRadius: 4,
                barThickness: 26
            }]
        },
        options: {
            indexAxis: 'y',
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return `${title}: ${context.parsed.x.toFixed(1)}`;
                        }
                    }
                }
            },
            scales: {
                x: {
                    beginAtZero: true,
                    max: max,
                    title: {
                        display: true,
                        text: axisLabel,
                        font: {
                            size: 10
                        }
                    },
                    ticks: {
                        font: {
                            size: 9
                        }
                    }
                },
                y: {
                    ticks: {
                        align: 'start',
                        font: {
                            size: 10
                        }
                    }
                }
            }
        }
    });
}

function createTopChartFromCompile(containerId, data, title) {
    if (!data || !data.left_header || !data.map || !data.up_header) {
        console.error('No data for chart:', containerId, data);
        return;
    }
    
    const canvas = document.getElementById(containerId);
    if (!canvas) {
        console.error('Canvas not found:', containerId);
        return;
    }
    
    const ctx = canvas.getContext('2d');
    
    const left_header = data.left_header;
    const map = data.map;
    const up_header = data.up_header;
    
    let incrementalIndex = up_header.findIndex(h => h.includes("Cold WallTime, s"));
    if (incrementalIndex === -1) {
        incrementalIndex = 2;
    }
    
    const combined = left_header.map((name, index) => {
        const row = map[index];
        const value = row[incrementalIndex] || 0;
        return {
            name: run_name_to_lang(name),
            value: value
        };
    });
    
    const sorted = combined.sort((a, b) => a.value - b.value);
    
    const colors = sorted.map(item => {
        return lang_color(run_name_to_lang_class_name(item.name));
    });
    
    const values = sorted.map(item => item.value);
    const max = Math.max(...values) * 1.15;
    
    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: sorted.map(item => item.name),
            datasets: [{
                label: title,
                data: values,
                backgroundColor: colors,
                borderColor: colors,
                borderWidth: 2,
                borderRadius: 4,
                barThickness: 26
            }]
        },
        options: {
            indexAxis: 'y',
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return `${title}: ${context.parsed.x.toFixed(2)}s`;
                        }
                    }
                }
            },
            scales: {
                x: {
                    beginAtZero: true,
                    max: max,
                    title: {
                        display: true,
                        text: `${title} (lower is better)`,
                        font: {
                            size: 10
                        }
                    },
                    ticks: {
                        font: {
                            size: 9
                        }
                    }
                },
                y: {
                    ticks: {
                        align: 'start',
                        font: {
                            size: 10
                        }
                    }
                }
            }
        }
    });
}

function createTopChartFromSource(containerId, data, title) {
    if (!data || !data.left_header || !data.map || !data.up_header) {
        console.error('No data for chart:', containerId, data);
        return;
    }
    
    const canvas = document.getElementById(containerId);
    if (!canvas) {
        console.error('Canvas not found:', containerId);
        return;
    }
    
    const ctx = canvas.getContext('2d');
    
    const left_header = data.left_header;
    const map = data.map;
    const up_header = data.up_header;
    
    let expressivenessIndex = up_header.findIndex(h => h.includes('Expressiveness vs Avg'));
    if (expressivenessIndex === -1) {
        expressivenessIndex = up_header.findIndex(h => h.includes('Expressiveness'));
    }
    if (expressivenessIndex === -1) {
        expressivenessIndex = up_header.length - 2;
    }
    
    const combined = left_header.map((name, index) => {
        const row = map[index];
        const value = row[expressivenessIndex] || 0;
        return {
            name: run_name_to_lang(name),
            value: value
        };
    });
    
    const sorted = combined.sort((a, b) => b.value - a.value);
    
    const colors = sorted.map(item => {
        return lang_color(run_name_to_lang_class_name(item.name));
    });
    
    const values = sorted.map(item => item.value);
    const max = Math.max(...values) * 1.15;
    
    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: sorted.map(item => item.name),
            datasets: [{
                label: title,
                data: values,
                backgroundColor: colors,
                borderColor: colors,
                borderWidth: 2,
                borderRadius: 4,
                barThickness: 26
            }]
        },
        options: {
            indexAxis: 'y',
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return `${title}: ${context.parsed.x.toFixed(1)}%`;
                        }
                    }
                }
            },
            scales: {
                x: {
                    beginAtZero: true,
                    max: max,
                    title: {
                        display: true,
                        text: `${title} (higher is better)`,
                        font: {
                            size: 10
                        }
                    },
                    ticks: {
                        font: {
                            size: 9
                        }
                    }
                },
                y: {
                    ticks: {
                        align: 'start',
                        font: {
                            size: 10
                        }
                    }
                }
            }
        }
    });
}

function hacking_summary_tab() {
    const $results = $('#results');
    $results.empty();
    
    $results.append(`<div class=table_header><h2>Hacking Summary</h2></div>`);
    
    $results.append(`
        <div class="stats-grid">
            <div class="stat-card" style="height: 1640px">
                <h3>Runtime (Summary), s</h3>
                <div style="height: 1600px">
                <canvas id="chart_hacking_runtime"></canvas>
                </div>
            </div>
            <div class="stat-card" style="height: 1640px">
                <h3>Runtime Score, pts</h3>
                <div style="height: 1600px">
                <canvas id="chart_hacking_rtscore"></canvas>
                </div>
            </div>
            <div class="stat-card" style="height: 1640px">
                <h3>Memory (Average), Mb</h3>
                <div style="height: 1600px">
                <canvas id="chart_hacking_memory"></canvas>
                </div>
            </div>
        </div>
    `);
    
    setTimeout(() => {
        if (window.Data.hacking_data_runtime) {
            createHackingChart(
                'chart_hacking_runtime',
                window.Data.hacking_data_runtime,
                'Runtime, s',
                true,
                300
            );
        }
        
        if (window.Data.hacking_data_rtscore) {
            createHackingChart(
                'chart_hacking_rtscore',
                window.Data.hacking_data_rtscore,
                'RtScore, pts',
                false,
                100
            );
        }
        
        if (window.Data.hacking_data_memory) {
            const memoryData = window.Data.hacking_data_memory;
            const maxMemory = Math.max(...memoryData.summary.data);
            const memoryLimit = maxMemory > 600 ? 600 : null;
            
            createHackingChart(
                'chart_hacking_memory',
                memoryData,
                'Memory, Mb',
                true,
                memoryLimit
            );
        }
    }, 300);
}

function createHackingChart(containerId, data, title, lowerIsBetter, maxValue = null) {
    const canvas = document.getElementById(containerId);
    if (!canvas) {
        console.error('Canvas not found:', containerId);
        return;
    }
    
    if (!data || !data.up_header || !data.summary || !data.summary.data) {
        console.error('Invalid data for chart:', containerId, data);
        return;
    }
    
    const ctx = canvas.getContext('2d');
    
    const up_header = data.up_header;
    const summary = data.summary.data;
    
    const combined = up_header.map((name, index) => ({
        name: name,
        value: summary[index],
        originalValue: summary[index]
    }));
    
    sorted = null;
    if (lowerIsBetter) {
        sorted = combined.sort((a, b) => a.value - b.value);
    } else {
        sorted = combined.sort((a, b) => b.value - a.value);
    }
    
    const displayData = sorted.map(item => ({
        ...item,
        displayValue: maxValue !== null && item.value > maxValue ? maxValue : item.value,
        isClipped: maxValue !== null && item.value > maxValue
    }));
    
    const colors = displayData.map(item => {
        const langName = item.name.split('/')[0];
        return lang_color(run_name_to_lang_class_name(langName));
    });
    
    const displayValues = displayData.map(item => item.displayValue);
    const originalValues = displayData.map(item => item.originalValue);
    
    let maxAxis = maxValue !== null ? maxValue * 1.05 : Math.max(...displayValues) * 1.15;
    
    const axisLabel = lowerIsBetter 
        ? `${title} (lower is better)`
        : `${title} (higher is better)`;
    
    let chartTitle = title;
    if (maxValue !== null) {
        const maxOriginal = Math.max(...originalValues);
        if (maxOriginal > maxValue) {
            chartTitle = `${title} (clipped at ${maxValue})`;
        }
    }
    
    const existingChart = Chart.getChart(containerId);
    if (existingChart) {
        existingChart.destroy();
    }
    
    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: displayData.map(item => {
                return item.isClipped ? `${item.name}*` : item.name;
            }),
            datasets: [{
                label: chartTitle,
                data: displayValues,
                backgroundColor: colors,
                borderColor: colors,
                borderWidth: 2,
                borderRadius: 4,
                barThickness: Math.max(12, Math.min(26, 800 / displayData.length))
            }]
        },
        options: {
            indexAxis: 'y',
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            const index = context.dataIndex;
                            const originalValue = originalValues[index];
                            const displayValue = displayValues[index];
                            const isClipped = displayData[index].isClipped;
                            
                            if (isClipped) {
                                return `${title}: ${originalValue.toFixed(2)} (clipped)`;
                            }
                            return `${title}: ${originalValue.toFixed(2)}`;
                        }
                    }
                }
            },
            scales: {
                x: {
                    beginAtZero: true,
                    max: maxAxis,
                    title: {
                        display: true,
                        text: axisLabel,
                        font: {
                            size: 10
                        }
                    },
                    ticks: {
                        font: {
                            size: 9
                        }
                    }
                },
                y: {
                    ticks: {
                        align: 'start',
                        font: {
                            size: 8
                        },
                        autoSkip: false
                    }
                }
            }
        }
    });
}

const s = document.createElement('script');
s.src = 'data.js';
s.onload = () => {
    UpdateData(window.Data);
};
document.head.appendChild(s);

window.addEventListener('popstate', function(event) {
    if (event.state) {
        changeTab(event.state.tab, event.state.group || false, event.state.lang || null);
    } else {
        const hash = window.location.hash;
        let tabFromUrl = null;
        let groupFromUrl = false;
        let langFromUrl = null;
        
        if (hash && hash.startsWith('#/')) {
            const parts = hash.substring(2).split('/');
            tabFromUrl = parts[0];
            
            for (let i = 1; i < parts.length; i++) {
                if (parts[i] === 'group') {
                    groupFromUrl = true;
                } else if (parts[i] === 'lang' && parts[i+1]) {
                    langFromUrl = parts[i+1];
                    i++;
                }
            }
        }
        
        if (tabFromUrl && document.getElementById(tabFromUrl)) {
            changeTab(tabFromUrl, groupFromUrl, langFromUrl);
        } else {
            changeTab('runtime_tab', false, null);
        }
    }
});

const loadedScripts = {};

function loadScriptOnDemand(scriptName, callback) {
    if (loadedScripts[scriptName]) {
        callback();
        return;
    }
    
    const existingScripts = document.querySelectorAll(`script[src="${scriptName}"]`);
    if (existingScripts.length > 0) {
        loadedScripts[scriptName] = true;
        callback();
        return;
    }

    const script = document.createElement('script');
    script.src = scriptName;
    script.onload = function() {
        loadedScripts[scriptName] = true;
        callback();
    };
    script.onerror = function() {
        $('#results').html(`<div class="error">Failed to load ${scriptName}</div>`);
    };
    document.head.appendChild(script);
}
