function changeTab(tabId, group_lang_option_checked = false) {
    // $('.tab-content').removeClass('active');
    $('.tabs .tab').removeClass('active');
    $(`#${tabId}`).addClass('active');

    const $results = $('#results');
    $results.empty();
    
    switch(tabId) {
        case 'overview_tab':
            overview_tab($results);
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
            hacking_tab();            
            break;
        case 'analys_tab':
            ai_analys($results);
            break;
        case 'history_tab':
            history_tab();
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
        // case 'test_rank_rt_tab':
        //     create_table($results, "Test winners by runtime, s", window.Data.test_rank_rt);
        //     break;
        // case 'test_rank_mem_tab':
        //     create_table($results, "Test winners by memory, Mb", window.Data.test_rank_mem);
        //     break;

    }
}

function UpdateData(data) {
    document.getElementById('results-update-date').innerHTML = '<strong>Update date:</strong> ' + window.Data.date;
    document.getElementById('resutls-arch').innerHTML = '<strong>Architecture:</strong> ' + window.Data.arch;
    document.getElementById('resutls-pc').innerHTML = '<strong>Pc:</strong> ' + window.Data.pc;
    document.getElementById('results-tests-count').innerHTML = '<strong>Tests:</strong> ' + window.Data.tests_count;
    document.getElementById('results-runs-count').innerHTML = '<strong>Configurations:</strong> ' + window.Data.runs_prod_count;
    document.getElementById('results-langs-count').innerHTML = '<strong>Languages:</strong> ' + window.Data.langs_count;

    const medals = ["🥇", "🥈", "🥉"];
    
    var $u = $('ul#main_legend_total');
    $u.empty();
    for (let i = 0; i < window.Data.main_legend.total.length; i++ ) {
        $u.append(`
            <li style="padding: 8px 0; border-bottom: 1px solid #dee2e6; display: flex; justify-content: space-between;">
                <span class="language-badge lang_${window.Data.main_legend.total[i][0]}">${lang_name_to_human(window.Data.main_legend.total[i][0])}</span>
                <span>${medals[i]} ${window.Data.main_legend.total[i][1]}</span>
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
    
    changeTab('runtime_tab');
}

function create_table($parent_div, title, data, use_color_compare = 0, group_lang_option = false, group_lang_option_checked = false) {
    // use_color_compare = 0 - no colors, use_color_compare = 1 colors lower better, use_color_compare = 2 color higher better
    // $parent_div.empty();
    $parent_div.append(`<h2>${title}</h2>`);

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
        const $td = $('<th>').html(h.replace(/\//g, '<br>'));
        $tr.append($td);
        if (lang_sticky_up) $td.attr('class', 'lang_' + run_name_to_lang_class_name(h));
    }

    const summaries = new Array(up_header.length).fill(0);

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
            summaries[j] += v;
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
        if (data.summary == 'avg') {
            for (let j = 0; j < summaries.length; j++) {    
                summaries[j] = summaries[j] / map.length;
            }
            $td.text("Average");
        } else {
            $td.text("Summary");
        }

        if (use_color_compare == 1) {
            speed_class = createSpeedClassFunction(summaries);
        } else if (use_color_compare == 2) {
            speed_class = createSpeedClassFunction(summaries, true);
        }

        for (let j = 0; j < summaries.length; j++) {
            const s = summaries[j];
            const $td = $('<td>', {title: `${up_header[j]}: ${value_fixed(s)}`}).text(value_fixed(s));
            if (use_color_compare != 0) $td.attr('class', speed_class(s));
            $tr2.append($td);
        }
    }

    if (data.description) {
        $parent_div.append(`<div class="table-legend">${data.description}</div>`);        
    }

    // $parent_div.append(`<div class="legend"><span style="padding: 13px">Legend: </span></div>`);
    // const $legend = $parent_div.find('.legend');
    // for (let i = 0; i < 10; i++) {
    //     $legend.append(`<div class="legend-item">
    //         <table><tbody><tr><td style="padding: 10px" class=speed_${i}>${legendWord(i)}</td></tr><tbody></table>            
    //         </div>`);
    // }
}

// "C#/JIT" => "csharp"
function run_name_to_lang_class_name(run_name) {
    let s = run_name.split('/')[0].toLowerCase();
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

function createSpeedRankFunction(values, invert = false) {
    const min = Math.min(...values);
    const max = Math.max(...values);
    const range = max - min;
    
    // Если все значения одинаковые
    if (range < 0.00001) {
        return function(value) {
            return invert ? 9 : 0;
        };
    }
    
    // Сдвиг для отрицательных и нулевых значений
    const shift = min <= 0 ? -min + 0.001 : 0;
    const shiftedValues = values.map(v => v + shift);
    const shiftedMin = min + shift;
    const shiftedMax = max + shift;
    
    // Фильтруем средние значения (без крайних)
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
    
    // Логарифмическая шкала только для средних значений
    const logValues = middleValues.map(v => Math.log10(v));
    const logMin = Math.min(...logValues);
    const logMax = Math.max(...logValues);
    const logRange = logMax - logMin;
    
    return function(value) {
        const shiftedValue = value + shift;
        
        // Абсолютные экстремумы
        if (Math.abs(shiftedValue - shiftedMin) < 0.00001) {
            return invert ? 9 : 0;
        }
        if (Math.abs(shiftedValue - shiftedMax) < 0.00001) {
            return invert ? 0 : 9;
        }
        
        // Проверяем, что значение положительное для логарифма
        if (shiftedValue <= 0) {
            return invert ? 9 : 0;
        }
        
        // Логарифмическое преобразование
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
    // Маппинг языков на цвета
    const colorMap = {
        'c': '#3498db',
        'cpp': '#2ecc71',
        'go': '#9b59b6',
        'golang': '#9b59b6',
        'crystal': '#e67e22',
        'rust': '#e74c3c',
        'csharp': '#1abc9c',
        'swift': '#356ba2',
        'java': '#f1c40f',
        'kotlin': '#7c83ea',
        'typescript': '#16a085',
        'zig': '#a41111',
        'd': '#24366c',
        'v': '#3069c1',
        'julia': '#fd4137',
        'nim': '#16bad5',
        'fsharp': '#16deff'
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

    // Получаем цвета для каждого языка
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

    const keys = Object.keys(window.Data['history']);
    for (const lang of keys) {
        $filters.append(`
            <button class="filter-btn" id="filter_button_${lang}" onclick="hacking_tab('${lang}')" style="border-left-color: ${lang_color(lang)}; border-left-width: 3px;">
                ${lang}
            </button>        
        `);
    }

    $results.append($filters);
    $('.filters .filter-btn').removeClass('active');    
    $(`#filter_button_${select_lang}`).addClass('active');
    create_table($results, select_lang, window.Data.hacking[select_lang], 1);
}

function history_tab(select_lang = 'c') {
    const $results = $('#results');
    $results.empty();
    
    $filters = $('<div>', {class: 'filters'});
    $filters.append('<span>Filter by language:</span>');

    const keys = Object.keys(window.Data['history']);
    for (const lang of keys) {
        $filters.append(`
            <button class="filter-btn" id="filter_button_${lang}" onclick="history_tab('${lang}')" style="border-left-color: ${lang_color(lang)}; border-left-width: 3px;">
                ${lang}
            </button>        
        `);
    }

    $results.append($filters);
    $('.filters .filter-btn').removeClass('active');    
    $(`#filter_button_${select_lang}`).addClass('active');
    
    $results.append(`<h2>History runtime of language: ${select_lang}</h2>`);
    
    $results.append(`
        <div>
          <canvas id="historyChart"></canvas>
        </div>
    `);

    const historyData = window.Data['history'][select_lang];

    // Подготовка данных для Chart.js
    function prepareChartData(selectedLang = null) {
      const allDates = new Set();
      const datasets = [];
      
      // Собираем все уникальные даты
      Object.entries(historyData).forEach(([lang, data]) => {
        data.forEach(([date]) => allDates.add(date));
      });
      
      // Сортируем даты
      const sortedDates = Array.from(allDates).sort();
      
      // Создаём палитру цветов
      const colorPalette = [
        '#4CAF50', '#2196F3', '#FF9800', '#9C27B0', '#F44336',
        '#00BCD4', '#8BC34A', '#FF5722', '#795548', '#607D8B',
        '#3F51B5', '#009688', '#FFC107', '#E91E63', '#673AB7'
      ];
      
      let colorIndex = 0;
      
      // Формируем dataset для каждого языка
      Object.entries(historyData).forEach(([lang, data]) => {
        // Создаём массив значений для всех дат
        const values = new Array(sortedDates.length).fill(null);
        
        // Заполняем значения
        data.forEach(([date, value]) => {
          const dateIndex = sortedDates.indexOf(date);
          if (dateIndex !== -1) {
            values[dateIndex] = value;
          }
        });
        
        // Готовим dataset
        datasets.push({
          label: lang,
          data: values,
          borderColor: colorPalette[colorIndex % colorPalette.length],
          backgroundColor: colorPalette[colorIndex % colorPalette.length] + '20',
          borderWidth: 2,
          fill: false,
          tension: 0.1, // Сглаживание линий
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

    // Инициализация графика
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
        create_table($results, "Previous Run runtime diff, s", window.Data.prev_diff, 1);
    } else {
        $results.append(`<h2>Previous Run runtime diff, s</h2><br><br>No Data ...`);
    }
}

const s = document.createElement('script');
s.src = 'data.js';
s.onload = () => {
    UpdateData(window.Data);
};
document.head.appendChild(s);

const s2 = document.createElement('script');
s2.src = 'overview.js';
document.head.appendChild(s2);

const s3 = document.createElement('script');
s3.src = 'ai_analysis.js';
document.head.appendChild(s3);