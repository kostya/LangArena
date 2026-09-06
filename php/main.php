<?php declare(strict_types=1);

class Helper
{
    const IM = 139968;
    const IA = 3877;
    const IC = 29573;

    private static int $last = 42;

    public static function reset(): void
    {
        self::$last = 42;
    }

    public static function toUint32(int $value): int
    {
        return $value & 0xFFFFFFFF;
    }

    public static function nextInt(int $max): int
    {
        self::$last = (self::$last * self::IA + self::IC) % self::IM;
        $result = (int) ((self::$last * $max) / self::IM);
        return self::toUint32($result);
    }

    public static function nextIntRange(int $from, int $to): int
    {
        return self::nextInt($to - $from + 1) + $from;
    }

    public static function nextFloat(float $max = 1.0): float
    {
        $tmp = self::$last * self::IA + self::IC;
        self::$last = self::toUint32($tmp) % self::IM;
        return $max * self::$last / self::IM;
    }

    public static function checksum($data): int
    {
        $hash = 5381;
        if (is_string($data)) {
            for ($i = 0; $i < strlen($data); $i++) {
                $hash = (($hash << 5) + $hash) + ord($data[$i]);
                $hash = self::toUint32($hash);
            }
        } elseif (is_array($data)) {
            foreach ($data as $byte) {
                $hash = (($hash << 5) + $hash) + ($byte & 0xFF);
                $hash = self::toUint32($hash);
            }
        }
        return self::toUint32($hash);
    }

    public static function checksumFloat(float $v): int
    {
        $str = sprintf('%.7f', $v);
        return self::checksum($str);
    }

    public static function configInt(string $className, string $fieldName): int
    {
        $value = Config::get($className, $fieldName);
        if ($value === null) {
            echo "Config not found for {$className}, field: {$fieldName}\n";
            return 0;
        }
        return (int) $value;
    }

    public static function configString(string $className, string $fieldName): string
    {
        $value = Config::get($className, $fieldName);
        if ($value === null) {
            echo "Config not found for {$className}, field: {$fieldName}\n";
            return '';
        }
        return (string) $value;
    }
}

class Config
{
    private static array $config = [];

    public static function load(string $filename = '../run.js'): void
    {
        if (!file_exists($filename)) {
            echo 'Cannot open config file: ' . $filename . "\n";
            return;
        }

        $content = file_get_contents($filename);
        if ($content === false) {
            echo 'Cannot read config file: ' . $filename . "\n";
            return;
        }

        self::parse($content);
    }

    public static function parse(string $content): void
    {
        try {
            $json_array = json_decode($content, true, 512, JSON_THROW_ON_ERROR);
            self::$config = [];

            foreach ($json_array as $item) {
                if (isset($item['name'])) {
                    self::$config[$item['name']] = $item;
                }
            }
        } catch (JsonException $e) {
            echo 'Error parsing JSON config: ' . $e->getMessage() . "\n";
            self::$config = [];
        }
    }

    public static function get(string $className, string $fieldName, $default = null)
    {
        return self::$config[$className][$fieldName] ?? $default;
    }

    public static function has(string $className, string $fieldName): bool
    {
        return isset(self::$config[$className][$fieldName]);
    }

    public static function getAll(): array
    {
        return self::$config;
    }
}

abstract class Benchmark
{
    private array $configCache = [];

    abstract public function run(int $iterationId): void;
    abstract public function checksum(): int;
    abstract public function name(): string;

    public function prepare(): void {}

    public function warmupIterations(): int
    {
        $iters = $this->iterations();
        $configWarmup = Config::get($this->name(), 'warmup_iterations');
        if ($configWarmup !== null) {
            return (int) $configWarmup;
        }
        return max((int) ($iters * 0.2), 1);
    }

    public function warmup(): void
    {
        $prepareIters = $this->warmupIterations();
        for ($i = 0; $i < $prepareIters; $i++) {
            $this->run($i);
        }
    }

    public function runAll(): void
    {
        $iters = $this->iterations();
        for ($i = 0; $i < $iters; $i++) {
            $this->run($i);
        }
    }

    public function configVal(string $fieldName): int
    {
        $key = $this->name() . '.' . $fieldName;
        if (!isset($this->configCache[$key])) {
            $this->configCache[$key] = Helper::configInt($this->name(), $fieldName);
        }
        return $this->configCache[$key];
    }

    public function iterations(): int
    {
        return $this->configVal('iterations');
    }

    public function expectedChecksum(): int
    {
        return Helper::toUint32($this->configVal('checksum'));
    }

    public static function all(string $singleBench = '', string $configFile = '../run.js'): void
    {
        $summaryTime = 0.0;
        $ok = 0;
        $fails = 0;

        $availableBenches = self::getAvailableBenches();

        if (!file_exists($configFile)) {
            echo 'Cannot open config file: ' . $configFile . "\n";
            return;
        }

        $content = file_get_contents($configFile);
        if ($content === false) {
            echo 'Cannot read config file: ' . $configFile . "\n";
            return;
        }

        Config::parse($content);

        foreach (Config::getAll() as $benchName => $item) {
            if (!empty($singleBench) && stripos($benchName, $singleBench) === false) {
                continue;
            }

            if (isset($availableBenches[$benchName])) {
                echo $benchName . ': ';
                flush();

                $benchClass = $availableBenches[$benchName];
                $bench = new $benchClass();

                Helper::reset();
                $bench->prepare();
                $bench->warmup();
                Helper::reset();

                $start = microtime(true);
                $bench->runAll();
                $end = microtime(true);

                $duration = $end - $start;

                $check = $bench->checksum();
                $expect = $bench->expectedChecksum();

                if ($check === $expect) {
                    echo 'OK ';
                    $ok++;
                } else {
                    echo "ERR[actual={$check}, expected={$expect}] ";
                    $fails++;
                }

                echo 'in ' . number_format($duration, 3, '.', '') . "s\n";

                $summaryTime += $duration;

                usleep(10);
            } else {
                echo "Warning: Benchmark '{$benchName}' defined in config but not found in code\n";
            }
        }

        if ($ok + $fails > 0) {
            echo 'Summary: ' . sprintf('%.4fs, %d, %d, %d', $summaryTime, $ok + $fails, $ok, $fails) . "\n";
        }

        if ($fails > 0) {
            exit(1);
        }
    }

    private static function getAvailableBenches(): array
    {
        return [
            'Binarytrees::Obj' => BinarytreesObj::class,
            'Binarytrees::Arena' => BinarytreesArena::class,
            'Base64::Encode' => Base64Encode::class,
            'Base64::Decode' => Base64Decode::class,
            'Json::Generate' => JsonGenerate::class,
            'Json::ParseDom' => JsonParseDom::class,
            'Json::ParseMapping' => JsonParseMapping::class,
            'Template::Regex' => TemplateRegex::class,
            'Template::Parse' => TemplateParse::class,
            'Sort::Quick' => SortQuick::class,
            'Sort::Merge' => SortMerge::class,
            'Sort::Self' => SortSelf::class,
            'Hash::SHA256' => HashSHA256::class,
            'Hash::CRC32' => HashCRC32::class,
            'CLBG::Fannkuchredux' => Fannkuchredux::class,
            'CLBG::Mandelbrot' => Mandelbrot::class,
            'CLBG::Nbody' => Nbody::class,
            'CLBG::Spectralnorm' => Spectralnorm::class,
            'Distance::Jaro' => DistanceJaro::class,
            'Distance::NGram' => DistanceNGram::class,
            'Brainfuck::Array' => BrainfuckArray::class,
            'Brainfuck::Recursion' => BrainfuckRecursion::class,
            'Matmul::Single' => MatmulSingle::class,
            'Matmul::T4' => MatmulT4::class,
            'Matmul::T8' => MatmulT8::class,
            'Matmul::T16' => MatmulT16::class,
            'CSV::Parse' => CSVParse::class,
            'Calculator::Ast' => CalculatorAst::class,
            'Calculator::Interpreter' => CalculatorInterpreter::class,
            'Maze::Generator' => MazeGenerator::class,
            'Maze::BFS' => MazeBFS::class,
            'Maze::AStar' => MazeAStar::class,
            'Graph::BFS' => GraphBFS::class,
            'Graph::DFS' => GraphDFS::class,
            'Graph::AStar' => GraphAStar::class,
            'Compress::BWTEncode' => CompressBWTEncode::class,
            'Compress::BWTDecode' => CompressBWTDecode::class,
            'Compress::HuffEncode' => CompressHuffEncode::class,
            'Compress::HuffDecode' => CompressHuffDecode::class,
            'Compress::ArithEncode' => CompressArithEncode::class,
            'Compress::ArithDecode' => CompressArithDecode::class,
            'Compress::LZWEncode' => CompressLZWEncode::class,
            'Compress::LZWDecode' => CompressLZWDecode::class,
            'Etc::Sieve' => EtcSieve::class,
            'Etc::TextRaytracer' => EtcTextRaytracer::class,
            'Etc::NeuralNet' => EtcNeuralNet::class,
            'Etc::CacheSimulation' => EtcCacheSimulation::class,
            'Etc::GameOfLife' => EtcGameOfLife::class,
            'Etc::Words' => EtcWords::class,
            'Etc::LogParser' => EtcLogParser::class,
        ];
    }
}

class TreeNode
{
    public int $item;
    public ?TreeNode $left;
    public ?TreeNode $right;

    public function __construct(int $item)
    {
        $this->item = $item;
        $this->left = null;
        $this->right = null;
    }
}

class BinarytreesObj extends Benchmark
{
    private int $n;
    private int $result_val;

    public function __construct()
    {
        $this->n = $this->configVal('depth');
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Binarytrees::Obj';
    }

    private static function createTreeNode(int $item, int $depth): TreeNode
    {
        $node = new TreeNode($item);

        if ($depth > 0) {
            $shift = 1 << ($depth - 1);
            $node->left = self::createTreeNode($item - $shift, $depth - 1);
            $node->right = self::createTreeNode($item + $shift, $depth - 1);
        }

        return $node;
    }

    private static function sumTree(TreeNode $root): int
    {
        $total = 0;
        $stack = [$root];

        while (!empty($stack)) {
            $current = array_pop($stack);
            $total += $current->item + 1;

            if ($current->right !== null) {
                $stack[] = $current->right;
            }
            if ($current->left !== null) {
                $stack[] = $current->left;
            }
        }

        return $total & 0xFFFFFFFF;
    }

    public function run(int $iteration_id): void
    {
        $root = self::createTreeNode(0, $this->n);
        $this->result_val = ($this->result_val + self::sumTree($root)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class ArenaNode
{
    public int $item;
    public int $left;
    public int $right;

    public function __construct(int $item, int $left = -1, int $right = -1)
    {
        $this->item = $item;
        $this->left = $left;
        $this->right = $right;
    }
}

class BinarytreesArena extends Benchmark
{
    private int $n;
    private int $result_val;
    private array $arena = [];
    private int $arenaSize = 0;

    public function __construct()
    {
        $this->n = $this->configVal('depth');
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Binarytrees::Arena';
    }

    private function buildTree(int $item, int $depth): int
    {
        $idx = $this->arenaSize++;

        if (!isset($this->arena[$idx])) {
            $this->arena[$idx] = new ArenaNode($item);
        } else {
            $this->arena[$idx]->item = $item;
            $this->arena[$idx]->left = -1;
            $this->arena[$idx]->right = -1;
        }

        if ($depth > 0) {
            $shift = 1 << ($depth - 1);
            $leftIdx = $this->buildTree($item - $shift, $depth - 1);
            $rightIdx = $this->buildTree($item + $shift, $depth - 1);
            $node = $this->arena[$idx];
            $node->left = $leftIdx;
            $node->right = $rightIdx;
        }

        return $idx;
    }

    private function sumTree(int $rootIdx): int
    {
        $total = 0;
        $stack = [$rootIdx];

        while (!empty($stack)) {
            $idx = array_pop($stack);
            $node = $this->arena[$idx];
            $total += $node->item + 1;

            if ($node->right >= 0) {
                $stack[] = $node->right;
            }
            if ($node->left >= 0) {
                $stack[] = $node->left;
            }
        }

        return $total & 0xFFFFFFFF;
    }

    public function run(int $iteration_id): void
    {
        $this->arenaSize = 0;

        $rootIdx = $this->buildTree(0, $this->n);
        $this->result_val = ($this->result_val + $this->sumTree($rootIdx)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class Base64Encode extends Benchmark
{
    private int $n;
    private string $str;
    private string $str2;
    private int $result_val;

    public function __construct()
    {
        $this->n = $this->configVal('size');
        $this->str = '';
        $this->str2 = '';
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Base64::Encode';
    }

    public function prepare(): void
    {
        $this->str = str_repeat('a', $this->n);
        $this->str2 = base64_encode($this->str);
        $this->result_val = 0;
    }

    public function run(int $iteration_id): void
    {
        $this->str2 = base64_encode($this->str);
        $this->result_val = ($this->result_val + strlen($this->str2)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        $strPreview = substr($this->str, 0, 4);
        $str2Preview = substr($this->str2, 0, 4);
        return Helper::checksum("encode {$strPreview}... to {$str2Preview}...: {$this->result_val}");
    }
}

class Base64Decode extends Benchmark
{
    private int $n;
    private string $str2;
    private string $str3;
    private int $result_val;

    public function __construct()
    {
        $this->n = $this->configVal('size');
        $this->str2 = '';
        $this->str3 = '';
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Base64::Decode';
    }

    public function prepare(): void
    {
        $str = str_repeat('a', $this->n);
        $this->str2 = base64_encode($str);
        $this->str3 = base64_decode($this->str2);
        $this->result_val = 0;
    }

    public function run(int $iteration_id): void
    {
        $this->str3 = base64_decode($this->str2);
        $this->result_val = ($this->result_val + strlen($this->str3)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        $str2Preview = substr($this->str2, 0, 4);
        $str3Preview = substr($this->str3, 0, 4);
        return Helper::checksum("decode {$str2Preview}... to {$str3Preview}...: {$this->result_val}");
    }
}

class JsonCoordinate
{
    public float $x;
    public float $y;
    public float $z;
    public string $name;
    public array $opts;

    public function __construct(float $x, float $y, float $z, string $name)
    {
        $this->x = $x;
        $this->y = $y;
        $this->z = $z;
        $this->name = $name;
        $this->opts = ['1' => [1, true]];
    }
}

class JsonGenerate extends Benchmark
{
    public int $n;
    private array $data;
    public string $text;
    private int $result_val;

    public function __construct()
    {
        $this->n = $this->configVal('coords');
        $this->data = [];
        $this->text = '';
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Json::Generate';
    }

    public function prepare(): void
    {
        Helper::reset();
        $this->data = [];

        for ($i = 0; $i < $this->n; $i++) {
            $this->data[] = new JsonCoordinate(
                round(Helper::nextFloat(), 8),
                round(Helper::nextFloat(), 8),
                round(Helper::nextFloat(), 8),
                sprintf('%.7f %d', Helper::nextFloat(), Helper::nextInt(10000))
            );
        }

        $this->text = '';
        $this->result_val = 0;
    }

    public function run(int $iteration_id): void
    {
        $output = json_encode([
            'coordinates' => $this->data,
            'info' => 'some info',
        ], JSON_UNESCAPED_UNICODE);

        $this->text = $output;

        if (str_starts_with($output, '{"coordinates"')) {
            $this->result_val = ($this->result_val + 1) & 0xFFFFFFFF;
        }
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class JsonParseDom extends Benchmark
{
    private string $text;
    private int $result_val;

    public function __construct()
    {
        $this->text = '';
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Json::ParseDom';
    }

    public function prepare(): void
    {
        $gen = new JsonGenerate();
        $gen->n = $this->configVal('coords');
        $gen->prepare();
        $gen->run(0);
        $this->text = $gen->text;
        $this->result_val = 0;
    }

    private function calc(string $text): array
    {
        $jobj = json_decode($text, true);
        $coordinates = $jobj['coordinates'];
        $len = (float) count($coordinates);
        $x = $y = $z = 0.0;

        foreach ($coordinates as $coord) {
            $x += (float) $coord['x'];
            $y += (float) $coord['y'];
            $z += (float) $coord['z'];
        }

        return [$x / $len, $y / $len, $z / $len];
    }

    public function run(int $iteration_id): void
    {
        [$x, $y, $z] = $this->calc($this->text);
        $this->result_val = ($this->result_val + Helper::checksumFloat($x) + Helper::checksumFloat($y) + Helper::checksumFloat($z)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class JsonParseMapping extends Benchmark
{
    private string $text;
    private int $result_val;

    public function __construct()
    {
        $this->text = '';
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Json::ParseMapping';
    }

    public function prepare(): void
    {
        $gen = new JsonGenerate();
        $gen->n = $this->configVal('coords');
        $gen->prepare();
        $gen->run(0);
        $this->text = $gen->text;
        $this->result_val = 0;
    }

    private function calc(string $text): array
    {
        $data = json_decode($text);
        $coordinates = $data->coordinates;
        $len = (float) count($coordinates);
        $x = $y = $z = 0.0;

        foreach ($coordinates as $coord) {
            $x += (float) $coord->x;
            $y += (float) $coord->y;
            $z += (float) $coord->z;
        }

        return [$x / $len, $y / $len, $z / $len];
    }

    public function run(int $iteration_id): void
    {
        [$x, $y, $z] = $this->calc($this->text);
        $this->result_val = ($this->result_val + Helper::checksumFloat($x) + Helper::checksumFloat($y) + Helper::checksumFloat($z)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class TemplateRegex extends Benchmark
{
    protected int $count;
    protected int $checksum_val;
    protected string $text;
    protected string $rendered;
    protected array $vars;

    protected const FIRST_NAMES = ['John', 'Jane', 'Bob', 'Alice', 'Charlie', 'Diana', 'Sarah', 'Mike'];
    protected const LAST_NAMES = ['Smith', 'Johnson', 'Brown', 'Taylor', 'Wilson', 'Davis', 'Miller', 'Jones'];
    protected const CITIES = ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'San Francisco'];
    protected const LOREM = 'Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. ';

    public function __construct()
    {
        $this->count = 0;
        $this->checksum_val = 0;
        $this->text = '';
        $this->rendered = '';
        $this->vars = [];
    }

    public function name(): string
    {
        return 'Template::Regex';
    }

    public function prepare(): void
    {
        $this->count = $this->configVal('count');
        $this->checksum_val = 0;
        $this->vars = [];

        $s = '<html><body>';
        $s .= '<h1>{{TITLE}}</h1>';
        $this->vars['TITLE'] = 'Template title';
        $s .= '<p>';
        $s .= self::LOREM;
        $s .= '</p>';
        $s .= '<table>';

        for ($i = 0; $i < $this->count; $i++) {
            if ($i % 3 == 0) {
                $s .= '<!-- {comment} -->';
            }
            $s .= '<tr>';
            $s .= "<td>{{ FIRST_NAME{$i} }}</td>";
            $s .= "<td>{{LAST_NAME{$i}}}</td>";
            $s .= "<td>{{  CITY{$i}  }}</td>";
            $this->vars["FIRST_NAME{$i}"] = self::FIRST_NAMES[$i % count(self::FIRST_NAMES)];
            $this->vars["LAST_NAME{$i}"] = self::LAST_NAMES[$i % count(self::LAST_NAMES)];
            $this->vars["CITY{$i}"] = self::CITIES[$i % count(self::CITIES)];
            $s .= '<td>' . '{balance: ' . ($i % 100) . '}</td>';
            $s .= "</tr>\n";
        }

        $s .= '</table>';
        $s .= '</body></html>';

        $this->text = $s;
    }

    public function run(int $iteration_id): void
    {
        $this->rendered = preg_replace_callback(
            '/{{(.*?)}}/',
            function ($matches) {
                $key = trim($matches[1]);
                return $this->vars[$key] ?? '';
            },
            $this->text
        );
        $this->checksum_val = ($this->checksum_val + strlen($this->rendered)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return Helper::toUint32(($this->checksum_val + Helper::checksum($this->rendered)) & 0xFFFFFFFF);
    }
}

class TemplateParse extends TemplateRegex
{
    public function name(): string
    {
        return 'Template::Parse';
    }

    public function run(int $iteration_id): void
    {
        $text = $this->text;
        $textSize = strlen($text);
        $estimatedSize = (int) ($textSize * 1.5);
        $result = '';

        $i = 0;
        while ($i < $textSize) {
            if ($i + 1 < $textSize && $text[$i] === '{' && $text[$i + 1] === '{') {
                $j = $i + 2;
                while ($j + 1 < $textSize) {
                    if ($text[$j] === '}' && $text[$j + 1] === '}') {
                        break;
                    }
                    $j++;
                }

                if ($j + 1 < $textSize) {
                    $key = trim(substr($text, $i + 2, $j - $i - 2));
                    $result .= $this->vars[$key] ?? '';
                    $i = $j + 2;
                    continue;
                }
            }

            $result .= $text[$i];
            $i++;
        }

        $this->rendered = $result;
        $this->checksum_val = ($this->checksum_val + strlen($this->rendered)) & 0xFFFFFFFF;
    }
}

abstract class SortBenchmark extends Benchmark
{
    protected int $size;
    protected int $result_val;
    protected array $data;

    public function __construct()
    {
        $this->size = 0;
        $this->result_val = 0;
        $this->data = [];
    }

    public function prepare(): void
    {
        $this->size = $this->configVal('size');
        $this->result_val = 0;
        $this->data = [];

        Helper::reset();
        for ($i = 0; $i < $this->size; $i++) {
            $this->data[] = Helper::nextInt(1_000_000);
        }
    }

    abstract protected function test(): array;

    public function run(int $iteration_id): void
    {
        $this->result_val = ($this->result_val + $this->data[Helper::nextInt($this->size)]) & 0xFFFFFFFF;
        $t = $this->test();
        $this->result_val = ($this->result_val + $t[Helper::nextInt($this->size)]) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class SortQuick extends SortBenchmark
{
    public function name(): string
    {
        return 'Sort::Quick';
    }

    protected function test(): array
    {
        $arr = $this->data;
        $this->quickSort($arr, 0, count($arr) - 1);
        return $arr;
    }

    private function quickSort(array &$arr, int $low, int $high): void
    {
        if ($low >= $high) {
            return;
        }

        $pivot = $arr[(int) (($low + $high) / 2)];
        $i = $low;
        $j = $high;

        while ($i <= $j) {
            while ($arr[$i] < $pivot) {
                $i++;
            }
            while ($arr[$j] > $pivot) {
                $j--;
            }
            if ($i <= $j) {
                $tmp = $arr[$i];
                $arr[$i] = $arr[$j];
                $arr[$j] = $tmp;
                $i++;
                $j--;
            }
        }

        $this->quickSort($arr, $low, $j);
        $this->quickSort($arr, $i, $high);
    }
}

class SortMerge extends SortBenchmark
{
    public function name(): string
    {
        return 'Sort::Merge';
    }

    protected function test(): array
    {
        $arr = $this->data;
        $this->mergeSortInplace($arr);
        return $arr;
    }

    private function mergeSortInplace(array &$arr): void
    {
        $size = count($arr);
        $temp = array_fill(0, $size, 0);
        $this->mergeSortHelper($arr, $temp, 0, $size - 1);
    }

    private function mergeSortHelper(array &$arr, array &$temp, int $left, int $right): void
    {
        if ($left >= $right) {
            return;
        }

        $mid = (int) (($left + $right) / 2);
        $this->mergeSortHelper($arr, $temp, $left, $mid);
        $this->mergeSortHelper($arr, $temp, $mid + 1, $right);
        $this->merge($arr, $temp, $left, $mid, $right);
    }

    private function merge(array &$arr, array &$temp, int $left, int $mid, int $right): void
    {
        for ($i = $left; $i <= $right; $i++) {
            $temp[$i] = $arr[$i];
        }

        $i = $left;
        $j = $mid + 1;
        $k = $left;

        while ($i <= $mid && $j <= $right) {
            if ($temp[$i] <= $temp[$j]) {
                $arr[$k] = $temp[$i];
                $i++;
            } else {
                $arr[$k] = $temp[$j];
                $j++;
            }
            $k++;
        }

        while ($i <= $mid) {
            $arr[$k] = $temp[$i];
            $i++;
            $k++;
        }
    }
}

class SortSelf extends SortBenchmark
{
    public function name(): string
    {
        return 'Sort::Self';
    }

    protected function test(): array
    {
        $arr = $this->data;
        sort($arr);
        return $arr;
    }
}

abstract class BufferHashBenchmark extends Benchmark
{
    protected int $size;
    protected string $data;
    protected int $result_val;

    public function __construct()
    {
        $this->size = 0;
        $this->data = '';
        $this->result_val = 0;
    }

    public function prepare(): void
    {
        $this->size = $this->configVal('size');
        $this->result_val = 0;

        Helper::reset();
        $this->data = '';
        for ($i = 0; $i < $this->size; $i++) {
            $this->data .= chr(Helper::nextInt(256));
        }
    }

    abstract protected function test(): int;

    public function run(int $iteration_id): void
    {
        $this->result_val = ($this->result_val + $this->test()) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class HashSHA256 extends BufferHashBenchmark
{
    public function name(): string
    {
        return 'Hash::SHA256';
    }

    protected function test(): int
    {
        $data = $this->data;
        $len = strlen($data);

        $hashes = [
            0x6A09E667,
            0xBB67AE85,
            0x3C6EF372,
            0xA54FF53A,
            0x510E527F,
            0x9B05688C,
            0x1F83D9AB,
            0x5BE0CD19,
        ];

        for ($i = 0; $i < $len; $i++) {
            $byte = ord($data[$i]);
            $hashIdx = $i & 7;
            $hash = $hashes[$hashIdx];
            $hash = ((($hash << 5) & 0xFFFFFFFF) + $hash + $byte) & 0xFFFFFFFF;
            $hash = (($hash + ($hash << 10)) ^ ($hash >> 6)) & 0xFFFFFFFF;
            $hashes[$hashIdx] = $hash;
        }

        $h = $hashes[0];
        return (($h >> 24) & 0xFF)
            | (($h >> 16) & 0xFF) << 8
            | (($h >> 8) & 0xFF) << 16
            | ($h & 0xFF) << 24;
    }
}

class HashCRC32 extends BufferHashBenchmark
{
    public function name(): string
    {
        return 'Hash::CRC32';
    }

    protected function test(): int
    {
        $data = $this->data;
        $len = strlen($data);

        $crc = 0xFFFFFFFF;

        for ($i = 0; $i < $len; $i++) {
            $byte = ord($data[$i]);
            $crc = ($crc ^ $byte) & 0xFFFFFFFF;

            for ($j = 0; $j < 8; $j++) {
                if (($crc & 1) !== 0) {
                    $crc = (($crc >> 1) ^ 0xEDB88320) & 0xFFFFFFFF;
                } else {
                    $crc = ($crc >> 1) & 0xFFFFFFFF;
                }
            }
        }

        return ($crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
    }
}

class Fannkuchredux extends Benchmark
{
    private int $n;
    private int $result_val;

    public function __construct()
    {
        $this->n = $this->configVal('n');
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'CLBG::Fannkuchredux';
    }

    public function prepare(): void
    {
        $this->result_val = 0;
    }

    private function fannkuchredux(int $n): array
    {
        $perm1 = range(0, $n - 1);
        $perm = array_fill(0, $n, 0);
        $count = array_fill(0, $n, 0);
        $maxFlipsCount = $permCount = $checksum = 0;
        $r = $n;

        while (true) {
            while ($r > 1) {
                $count[$r - 1] = $r;
                $r--;
            }

            for ($i = 0; $i < $n; $i++) {
                $perm[$i] = $perm1[$i];
            }
            $flipsCount = 0;

            while (($k = $perm[0]) != 0) {
                $k2 = ($k + 1) >> 1;
                for ($i = 0; $i < $k2; $i++) {
                    $j = $k - $i;
                    $tmp = $perm[$i];
                    $perm[$i] = $perm[$j];
                    $perm[$j] = $tmp;
                }
                $flipsCount++;
            }

            if ($flipsCount > $maxFlipsCount) {
                $maxFlipsCount = $flipsCount;
            }
            $checksum += ($permCount % 2 == 0) ? $flipsCount : -$flipsCount;

            while (true) {
                if ($r == $n) {
                    return [$checksum, $maxFlipsCount];
                }

                $perm0 = $perm1[0];
                for ($i = 0; $i < $r; $i++) {
                    $perm1[$i] = $perm1[$i + 1];
                }
                $perm1[$r] = $perm0;
                $cntr = --$count[$r];
                if ($cntr > 0) {
                    break;
                }
                $r++;
            }
            $permCount++;
        }
    }

    public function run(int $iteration_id): void
    {
        [$a, $b] = $this->fannkuchredux($this->n);
        $this->result_val = ($this->result_val + $a * 100 + $b) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class Mandelbrot extends Benchmark
{
    private int $w;
    private int $h;
    private array $result_data;

    private const ITER = 50;
    private const LIMIT = 2.0;

    public function __construct()
    {
        $this->w = $this->configVal('w');
        $this->h = $this->configVal('h');
        $this->result_data = [];
    }

    public function name(): string
    {
        return 'CLBG::Mandelbrot';
    }

    public function prepare(): void
    {
        $this->result_data = [];
    }

    public function run(int $iteration_id): void
    {
        $w = $this->w;
        $h = $this->h;

        $header = "P4\n{$w} {$h}\n";
        foreach (str_split($header) as $char) {
            $this->result_data[] = ord($char);
        }

        $bitNum = 0;
        $byteAcc = 0;
        $iter = self::ITER;
        $limitSq = self::LIMIT * self::LIMIT;

        for ($y = 0; $y < $h; $y++) {
            $ci = (2.0 * $y / $h - 1.0);
            for ($x = 0; $x < $w; $x++) {
                $zr = $zi = $tr = $ti = 0.0;
                $cr = (2.0 * $x / $w - 1.5);

                $i = 0;
                while ($i < $iter && ($tr + $ti <= $limitSq)) {
                    $zi = 2.0 * $zr * $zi + $ci;
                    $zr = $tr - $ti + $cr;
                    $tr = $zr * $zr;
                    $ti = $zi * $zi;
                    $i++;
                }

                $byteAcc = ($byteAcc << 1) & 0xFF;
                if ($tr + $ti <= $limitSq) {
                    $byteAcc |= 1;
                }
                $bitNum++;

                if ($bitNum == 8) {
                    $this->result_data[] = $byteAcc;
                    $byteAcc = 0;
                    $bitNum = 0;
                } elseif ($x == $w - 1) {
                    $byteAcc = ($byteAcc << (8 - $bitNum)) & 0xFF;
                    $this->result_data[] = $byteAcc;
                    $byteAcc = 0;
                    $bitNum = 0;
                }
            }
        }
    }

    public function checksum(): int
    {
        return Helper::checksum($this->result_data);
    }
}

class NbodyPlanet
{
    public float $x;
    public float $y;
    public float $z;
    public float $vx;
    public float $vy;
    public float $vz;
    public float $mass;

    public function __construct(float $x, float $y, float $z, float $vx, float $vy, float $vz, float $mass)
    {
        $this->x = $x;
        $this->y = $y;
        $this->z = $z;
        $this->vx = $vx * Nbody::DAYS_PER_YEAR;
        $this->vy = $vy * Nbody::DAYS_PER_YEAR;
        $this->vz = $vz * Nbody::DAYS_PER_YEAR;
        $this->mass = $mass * Nbody::SOLAR_MASS;
    }
}

class Nbody extends Benchmark
{
    public const SOLAR_MASS = 4 * M_PI * M_PI;
    public const DAYS_PER_YEAR = 365.24;

    private float $v1;

    private array $bodies;

    public function __construct()
    {
        $this->v1 = 0.0;
        $this->bodies = [];
    }

    public function name(): string
    {
        return 'CLBG::Nbody';
    }

    public function prepare(): void
    {
        $this->bodies = [
            new NbodyPlanet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
            new NbodyPlanet(
                4.8414314424647209e0,
                -1.16032004402742839e0,
                -1.03622044471123109e-1,
                1.66007664274403694e-3,
                7.69901118419740425e-3,
                -6.90460016972063023e-5,
                9.54791938424326609e-4
            ),
            new NbodyPlanet(
                8.34336671824457987e0,
                4.12479856412430479e0,
                -4.03523417114321381e-1,
                -2.76742510726862411e-3,
                4.99852801234917238e-3,
                2.30417297573763929e-5,
                2.85885980666130812e-4
            ),
            new NbodyPlanet(
                1.2894369562139131e1,
                -1.51111514016986312e1,
                -2.23307578892655734e-1,
                2.96460137564761618e-3,
                2.3784717395948095e-3,
                -2.96589568540237556e-5,
                4.36624404335156298e-5
            ),
            new NbodyPlanet(
                1.53796971148509165e1,
                -2.59193146099879641e1,
                1.79258772950371181e-1,
                2.68067772490389322e-3,
                1.62824170038242295e-3,
                -9.5159225451971587e-5,
                5.15138902046611451e-5
            ),
        ];

        $this->offsetMomentum();
        $this->v1 = $this->energy();
    }

    private function offsetMomentum(): void
    {
        $px = $py = $pz = 0.0;

        foreach ($this->bodies as $b) {
            $px += $b->vx * $b->mass;
            $py += $b->vy * $b->mass;
            $pz += $b->vz * $b->mass;
        }

        $this->bodies[0]->vx = -$px / self::SOLAR_MASS;
        $this->bodies[0]->vy = -$py / self::SOLAR_MASS;
        $this->bodies[0]->vz = -$pz / self::SOLAR_MASS;
    }

    private function energy(): float
    {
        $e = 0.0;
        $nbodies = count($this->bodies);

        for ($i = 0; $i < $nbodies; $i++) {
            $b = $this->bodies[$i];
            $e += 0.5 * $b->mass * ($b->vx * $b->vx + $b->vy * $b->vy + $b->vz * $b->vz);

            for ($j = $i + 1; $j < $nbodies; $j++) {
                $b2 = $this->bodies[$j];
                $dx = $b->x - $b2->x;
                $dy = $b->y - $b2->y;
                $dz = $b->z - $b2->z;
                $distance = sqrt($dx * $dx + $dy * $dy + $dz * $dz);
                $e -= ($b->mass * $b2->mass) / $distance;
            }
        }

        return $e;
    }

    public function run(int $iteration_id): void
    {
        $bodies = $this->bodies;
        $nbodies = count($bodies);

        for ($step = 0; $step < 1000; $step++) {
            for ($i = 0; $i < $nbodies; $i++) {
                $b = $bodies[$i];

                for ($j = $i + 1; $j < $nbodies; $j++) {
                    $b2 = $bodies[$j];
                    $dx = $b->x - $b2->x;
                    $dy = $b->y - $b2->y;
                    $dz = $b->z - $b2->z;

                    $distance = sqrt($dx * $dx + $dy * $dy + $dz * $dz);
                    $mag = 0.01 / ($distance * $distance * $distance);
                    $bMassMag = $b->mass * $mag;
                    $b2MassMag = $b2->mass * $mag;

                    $b->vx -= $dx * $b2MassMag;
                    $b->vy -= $dy * $b2MassMag;
                    $b->vz -= $dz * $b2MassMag;
                    $b2->vx += $dx * $bMassMag;
                    $b2->vy += $dy * $bMassMag;
                    $b2->vz += $dz * $bMassMag;
                }

                $b->x += 0.01 * $b->vx;
                $b->y += 0.01 * $b->vy;
                $b->z += 0.01 * $b->vz;
            }
        }
    }

    public function checksum(): int
    {
        $v2 = $this->energy();
        return (Helper::checksumFloat($this->v1) << 5) & Helper::checksumFloat($v2);
    }
}

class Spectralnorm extends Benchmark
{
    private int $size;
    private array $u;
    private array $v;

    public function __construct()
    {
        $this->size = $this->configVal('size');
        $this->u = [];
        $this->v = [];
    }

    public function name(): string
    {
        return 'CLBG::Spectralnorm';
    }

    public function prepare(): void
    {
        $this->u = array_fill(0, $this->size, 1.0);
        $this->v = array_fill(0, $this->size, 1.0);
    }

    private function evalA(int $i, int $j): float
    {
        return 1.0 / (($i + $j) * ($i + $j + 1.0) / 2.0 + $i + 1.0);
    }

    private function evalAtimesU(array $u): array
    {
        $size = $this->size;
        $result = [];
        for ($i = 0; $i < $size; $i++) {
            $v = 0.0;
            for ($j = 0; $j < $size; $j++) {
                $v += $this->evalA($i, $j) * $u[$j];
            }
            $result[] = $v;
        }
        return $result;
    }

    private function evalAttimesU(array $u): array
    {
        $size = $this->size;
        $result = [];
        for ($i = 0; $i < $size; $i++) {
            $v = 0.0;
            for ($j = 0; $j < $size; $j++) {
                $v += $this->evalA($j, $i) * $u[$j];
            }
            $result[] = $v;
        }
        return $result;
    }

    private function evalAtAtimesU(array $u): array
    {
        return $this->evalAttimesU($this->evalAtimesU($u));
    }

    public function run(int $iteration_id): void
    {
        $this->v = $this->evalAtAtimesU($this->u);
        $this->u = $this->evalAtAtimesU($this->v);
    }

    public function checksum(): int
    {
        $vBv = $vv = 0.0;
        for ($i = 0; $i < $this->size; $i++) {
            $vBv += $this->u[$i] * $this->v[$i];
            $vv += $this->v[$i] * $this->v[$i];
        }
        return Helper::checksumFloat(sqrt($vBv / $vv));
    }
}

function generate_pair_strings(int $n, int $m): array
{
    $pairs = [];
    $chars = range('a', 'j');
    $charsCount = 10;

    for ($k = 0; $k < $n; $k++) {
        $len1 = Helper::nextInt($m) + 4;
        $len2 = Helper::nextInt($m) + 4;

        $str1 = '';
        for ($i = 0; $i < $len1; $i++) {
            $str1 .= $chars[Helper::nextInt($charsCount)];
        }

        $str2 = '';
        for ($i = 0; $i < $len2; $i++) {
            $str2 .= $chars[Helper::nextInt($charsCount)];
        }

        $pairs[] = [$str1, $str2];
    }

    return $pairs;
}

class DistanceJaro extends Benchmark
{
    private int $count;
    private int $size;
    private array $pairs;
    private int $result_val;

    public function __construct()
    {
        $this->count = $this->configVal('count');
        $this->size = $this->configVal('size');
        $this->pairs = [];
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Distance::Jaro';
    }

    public function prepare(): void
    {
        Helper::reset();
        $this->pairs = generate_pair_strings($this->count, $this->size);
        $this->result_val = 0;
    }

    private function jaro(string $s1, string $s2): float
    {
        $len1 = strlen($s1);
        $len2 = strlen($s2);

        if ($len1 == 0 || $len2 == 0) {
            return 0.0;
        }

        $matchDist = (int) (max($len1, $len2) / 2) - 1;
        if ($matchDist < 0) {
            $matchDist = 0;
        }

        $s1Matches = array_fill(0, $len1, false);
        $s2Matches = array_fill(0, $len2, false);

        $matches = 0;
        for ($i = 0; $i < $len1; $i++) {
            $start = max(0, $i - $matchDist);
            $fin = min($len2 - 1, $i + $matchDist);

            for ($j = $start; $j <= $fin; $j++) {
                if (!$s2Matches[$j] && $s1[$i] === $s2[$j]) {
                    $s1Matches[$i] = true;
                    $s2Matches[$j] = true;
                    $matches++;
                    break;
                }
            }
        }

        if ($matches == 0) {
            return 0.0;
        }

        $k = 0;
        $transpositions = 0;
        for ($i = 0; $i < $len1; $i++) {
            if ($s1Matches[$i]) {
                while ($k < $len2 && !$s2Matches[$k]) {
                    $k++;
                }
                if ($k < $len2) {
                    if ($s1[$i] !== $s2[$k]) {
                        $transpositions++;
                    }
                    $k++;
                }
            }
        }
        $transpositions = (int) ($transpositions / 2);

        $m = (float) $matches;
        return ($m / $len1 + $m / $len2 + ($m - $transpositions) / $m) / 3.0;
    }

    public function run(int $iteration_id): void
    {
        foreach ($this->pairs as [$s1, $s2]) {
            $this->result_val = ($this->result_val + (int) ($this->jaro($s1, $s2) * 1000)) & 0xFFFFFFFF;
        }
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class DistanceNGram extends Benchmark
{
    private int $count;
    private int $size;
    private array $pairs;
    private int $result_val;

    public function __construct()
    {
        $this->count = $this->configVal('count');
        $this->size = $this->configVal('size');
        $this->pairs = [];
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Distance::NGram';
    }

    public function prepare(): void
    {
        Helper::reset();
        $this->pairs = generate_pair_strings($this->count, $this->size);
        $this->result_val = 0;
    }

    private function ngram(string $s1, string $s2): float
    {
        $len1 = strlen($s1);
        $len2 = strlen($s2);

        $grams1 = [];

        for ($i = 0; $i <= $len1 - 4; $i++) {
            $gram = (ord($s1[$i]) << 24)
                | (ord($s1[$i + 1]) << 16)
                | (ord($s1[$i + 2]) << 8)
                | ord($s1[$i + 3]);
            $grams1[$gram] = ($grams1[$gram] ?? 0) + 1;
        }

        $grams2 = [];
        $intersection = 0;

        for ($i = 0; $i <= $len2 - 4; $i++) {
            $gram = (ord($s2[$i]) << 24)
                | (ord($s2[$i + 1]) << 16)
                | (ord($s2[$i + 2]) << 8)
                | ord($s2[$i + 3]);
            $grams2[$gram] = ($grams2[$gram] ?? 0) + 1;

            if (isset($grams1[$gram]) && $grams2[$gram] <= $grams1[$gram]) {
                $intersection++;
            }
        }

        $total = count($grams1) + count($grams2);
        return $total > 0 ? $intersection / $total : 0.0;
    }

    public function run(int $iteration_id): void
    {
        foreach ($this->pairs as [$s1, $s2]) {
            $this->result_val = ($this->result_val + (int) ($this->ngram($s1, $s2) * 1000)) & 0xFFFFFFFF;
        }
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class BFTape
{
    private array $tape;
    private int $pos = 0;
    private int $size;

    public function __construct()
    {
        $this->tape = array_fill(0, 30000, 0);
        $this->size = 30000;
    }

    public function get(): int
    {
        return $this->tape[$this->pos];
    }

    public function inc(): void
    {
        $this->tape[$this->pos] = ($this->tape[$this->pos] + 1) & 0xFF;
    }

    public function dec(): void
    {
        $this->tape[$this->pos] = ($this->tape[$this->pos] - 1) & 0xFF;
    }

    public function adv(): void
    {
        $this->pos++;
        if ($this->pos >= $this->size) {
            $this->tape[] = 0;
            $this->size++;
        }
    }

    public function dev(): void
    {
        $this->pos--;
        if ($this->pos < 0) {
            $this->pos = 0;
        }
    }
}

class BrainfuckArray extends Benchmark
{
    private string $programText;
    private string $warmupText;
    private int $result_val;

    public function __construct()
    {
        $this->programText = '';
        $this->warmupText = '';
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Brainfuck::Array';
    }

    public function prepare(): void
    {
        $className = $this->name();
        $this->programText = Helper::configString($className, 'program');
        $this->warmupText = Helper::configString($className, 'warmup_program');
        $this->result_val = 0;
    }

    public function warmup(): void
    {
        $prepareIters = $this->warmupIterations();
        for ($i = 0; $i < $prepareIters; $i++) {
            $this->runProgram($this->warmupText);
        }
    }

    public function run(int $iteration_id): void
    {
        $result = $this->runProgram($this->programText);
        if ($result !== null) {
            $this->result_val = ($this->result_val + $result) & 0xFFFFFFFF;
        }
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }

    private function runProgram(string $source): ?int
    {
        $commands = $this->parseCommands($source);
        if ($commands === null) {
            return null;
        }

        $jumps = $this->buildJumpArray($commands);
        if ($jumps === null) {
            return null;
        }

        return $this->execute($commands, $jumps);
    }

    private function parseCommands(string $source): ?array
    {
        $commands = [];
        $len = strlen($source);

        for ($i = 0; $i < $len; $i++) {
            $c = $source[$i];
            if ($c === '+' ||
                    $c === '-' ||
                    $c === '<' ||
                    $c === '>' ||
                    $c === '[' ||
                    $c === ']' ||
                    $c === '.' ||
                    $c === ',') {
                $commands[] = $c;
            }
        }

        return $commands;
    }

    private function buildJumpArray(array $commands): ?array
    {
        $size = count($commands);
        $jumps = array_fill(0, $size, 0);
        $stack = [];

        foreach ($commands as $i => $cmd) {
            if ($cmd === '[') {
                $stack[] = $i;
            } elseif ($cmd === ']') {
                if (empty($stack)) {
                    return null;
                }
                $start = array_pop($stack);
                $jumps[$start] = $i;
                $jumps[$i] = $start;
            }
        }

        return empty($stack) ? $jumps : null;
    }

    private function execute(array $commands, array $jumps): ?int
    {
        $tape = new BFTape();
        $pc = 0;
        $result = 0;
        $size = count($commands);

        while ($pc < $size) {
            $cmd = $commands[$pc];

            if ($cmd === '+') {
                $tape->inc();
            } elseif ($cmd === '-') {
                $tape->dec();
            } elseif ($cmd === '>') {
                $tape->adv();
            } elseif ($cmd === '<') {
                $tape->dev();
            } elseif ($cmd === '[') {
                if ($tape->get() === 0) {
                    $pc = $jumps[$pc];
                    continue;
                }
            } elseif ($cmd === ']') {
                if ($tape->get() !== 0) {
                    $pc = $jumps[$pc];
                    continue;
                }
            } elseif ($cmd === '.') {
                $result = (($result << 2) + $tape->get()) & 0xFFFFFFFF;
            }

            $pc++;
        }

        return $result;
    }
}

class BFTapeRecursion
{
    private array $tape;
    private int $pos;

    public function __construct()
    {
        $this->tape = array_fill(0, 30000, 0);
        $this->pos = 0;
    }

    public function get(): int
    {
        return $this->tape[$this->pos];
    }

    public function inc(): void
    {
        $this->tape[$this->pos] = ($this->tape[$this->pos] + 1) & 0xFF;
    }

    public function dec(): void
    {
        $this->tape[$this->pos] = ($this->tape[$this->pos] - 1) & 0xFF;
    }

    public function advance(): void
    {
        $this->pos++;
        if ($this->pos >= count($this->tape)) {
            $this->tape[] = 0;
        }
    }

    public function devance(): void
    {
        if ($this->pos > 0) {
            $this->pos--;
        }
    }
}

class BFOp
{
    const INC = 1;
    const DEC = 2;
    const ADVANCE = 3;
    const DEVANCE = 4;
    const PRINT = 5;
}

class BFProgram
{
    private array $ops;
    private int $result;

    public function __construct(string $code)
    {
        $chars = str_split($code);
        $i = 0;
        $this->ops = $this->parse($chars, $i);
        $this->result = 0;
    }

    public function getResult(): int
    {
        return $this->result;
    }

    public function run(): void
    {
        $tape = new BFTapeRecursion();
        $this->runOps($this->ops, $tape);
    }

    private function runOps(array $ops, BFTapeRecursion $tape): void
    {
        foreach ($ops as $op) {
            if ($op === BFOp::INC) {
                $tape->inc();
            } elseif ($op === BFOp::DEC) {
                $tape->dec();
            } elseif ($op === BFOp::ADVANCE) {
                $tape->advance();
            } elseif ($op === BFOp::DEVANCE) {
                $tape->devance();
            } elseif ($op === BFOp::PRINT) {
                $this->result = ($this->result << 2) + $tape->get();
            } elseif (is_array($op)) {
                while ($tape->get() !== 0) {
                    $this->runOps($op, $tape);
                }
            }
        }
    }

    private function parse(array $chars, int &$i): array
    {
        $ops = [];
        $len = count($chars);

        while ($i < $len) {
            $c = $chars[$i];

            if ($c === '+') {
                $ops[] = BFOp::INC;
            } elseif ($c === '-') {
                $ops[] = BFOp::DEC;
            } elseif ($c === '>') {
                $ops[] = BFOp::ADVANCE;
            } elseif ($c === '<') {
                $ops[] = BFOp::DEVANCE;
            } elseif ($c === '.') {
                $ops[] = BFOp::PRINT;
            } elseif ($c === '[') {
                $i++;
                $ops[] = $this->parse($chars, $i);
            } elseif ($c === ']') {
                break;
            }

            $i++;
        }

        return $ops;
    }
}

class BrainfuckRecursion extends Benchmark
{
    private string $text;
    private string $warmupText;
    private int $result_val;

    public function __construct()
    {
        $this->text = '';
        $this->warmupText = '';
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Brainfuck::Recursion';
    }

    public function prepare(): void
    {
        $className = $this->name();
        $this->text = Helper::configString($className, 'program');
        $this->warmupText = Helper::configString($className, 'warmup_program');
        $this->result_val = 0;
    }

    public function warmup(): void
    {
        $prepareIters = $this->warmupIterations();
        for ($i = 0; $i < $prepareIters; $i++) {
            $this->runText($this->warmupText);
        }
    }

    private function runText(string $text): int
    {
        $prog = new BFProgram($text);
        $prog->run();
        return $prog->getResult();
    }

    public function run(int $iteration_id): void
    {
        $this->result_val = ($this->result_val + $this->runText($this->text)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

function matgen(int $n, float $seed = 1.0): array
{
    $tmp = $seed / $n / $n;
    $a = [];
    for ($i = 0; $i < $n; $i++) {
        $row = [];
        for ($j = 0; $j < $n; $j++) {
            $row[] = $tmp * ($i - $j) * ($i + $j);
        }
        $a[] = $row;
    }
    return $a;
}

class MatmulSingle extends Benchmark
{
    protected int $n;
    protected array $a;
    protected array $b;
    protected int $result_val;

    public function __construct()
    {
        $this->n = 0;
        $this->a = [];
        $this->b = [];
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Matmul::Single';
    }

    public function prepare(): void
    {
        $this->n = $this->configVal('n');
        $this->a = matgen($this->n, 1.0);
        $this->b = matgen($this->n, 1.0);
        $this->result_val = 0;
    }

    protected function matmul(int $n, array $a, array $b): array
    {
        $t = array_fill(0, $n, array_fill(0, $n, 0.0));
        for ($i = 0; $i < $n; $i++) {
            for ($j = 0; $j < $n; $j++) {
                $t[$j][$i] = $b[$i][$j];
            }
        }

        $c = array_fill(0, $n, array_fill(0, $n, 0.0));
        for ($i = 0; $i < $n; $i++) {
            $ai = $a[$i];
            for ($j = 0; $j < $n; $j++) {
                $s = 0.0;
                $tj = $t[$j];
                for ($k = 0; $k < $n; $k++) {
                    $s += $ai[$k] * $tj[$k];
                }
                $c[$i][$j] = $s;
            }
        }

        return $c;
    }

    public function run(int $iteration_id): void
    {
        $c = $this->matmul($this->n, $this->a, $this->b);
        $mid = $this->n >> 1;
        $v = $c[$mid][$mid];
        $this->result_val = ($this->result_val + Helper::checksumFloat($v)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class MatmulT4 extends MatmulSingle
{
    public function name(): string
    {
        return 'Matmul::T4';
    }
}

class MatmulT8 extends MatmulSingle
{
    public function name(): string
    {
        return 'Matmul::T8';
    }
}

class MatmulT16 extends MatmulSingle
{
    public function name(): string
    {
        return 'Matmul::T16';
    }
}

class CSVPoint
{
    public float $x;
    public float $y;
    public float $z;

    public function __construct(float $x, float $y, float $z)
    {
        $this->x = $x;
        $this->y = $y;
        $this->z = $z;
    }
}

class CSVParse extends Benchmark
{
    private int $rows;
    private int $checksum_val;
    private string $data;

    public function __construct()
    {
        $this->rows = $this->configVal('rows');
        $this->checksum_val = 0;
        $this->data = '';
    }

    public function name(): string
    {
        return 'CSV::Parse';
    }

    public function prepare(): void
    {
        $this->checksum_val = 0;

        Helper::reset();

        $this->data = '';
        for ($i = 0; $i < $this->rows; $i++) {
            $c = chr(ord('A') + $i % 26);
            $x = Helper::nextFloat();
            $z = Helper::nextFloat();
            $y = Helper::nextFloat();

            $this->data .= '"' . 'point ' . $c . '\n, ""' . ($i % 100) . '"""' . ',';
            $this->data .= sprintf('%.10f', $x) . ',' . ',';
            $this->data .= sprintf('%.10f', $z) . ',';
            $this->data .= '"' . '[' . ($i % 2 == 0 ? 'true' : 'false') . '\n, ' . ($i % 100) . ']' . '"' . ',';
            $this->data .= sprintf('%.10f', $y) . "\n";
        }
    }

    private function parsePoints(string $csvData): array
    {
        $points = [];
        $fp = fopen('php://temp', 'r+');
        fwrite($fp, $csvData);
        rewind($fp);

        while (($row = fgetcsv($fp, 0, ',', '"', '\\')) !== false) {
            if (count($row) < 6 || $row[0] === null) {
                continue;
            }

            $points[] = new CSVPoint(
                (float) ($row[1] ?? 0),
                (float) ($row[5] ?? 0),
                (float) ($row[3] ?? 0)
            );
        }

        fclose($fp);
        return $points;
    }

    public function run(int $iteration_id): void
    {
        $points = $this->parsePoints($this->data);

        if (empty($points)) {
            return;
        }

        $xSum = $ySum = $zSum = 0.0;
        foreach ($points as $point) {
            $xSum += $point->x;
            $ySum += $point->y;
            $zSum += $point->z;
        }

        $count = count($points);
        $xAvg = $xSum / $count;
        $yAvg = $ySum / $count;
        $zAvg = $zSum / $count;

        $this->checksum_val = ($this->checksum_val + Helper::checksumFloat($xAvg) + Helper::checksumFloat($yAvg) + Helper::checksumFloat($zAvg)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->checksum_val & 0xFFFFFFFF;
    }
}

abstract class CalcNode {}

class CalcNumber extends CalcNode
{
    public int $value;

    public function __construct(int $value)
    {
        $this->value = $value;
    }
}

class CalcVariable extends CalcNode
{
    public string $name;

    public function __construct(string $name)
    {
        $this->name = $name;
    }
}

class CalcBinaryOp extends CalcNode
{
    public string $op;
    public CalcNode $left;
    public CalcNode $right;

    public function __construct(string $op, CalcNode $left, CalcNode $right)
    {
        $this->op = $op;
        $this->left = $left;
        $this->right = $right;
    }
}

class CalcAssignment extends CalcNode
{
    public string $var;
    public CalcNode $expr;

    public function __construct(string $var, CalcNode $expr)
    {
        $this->var = $var;
        $this->expr = $expr;
    }
}

class CalculatorParser
{
    private string $input;
    private int $pos;
    private int $len;
    private string $currentChar;
    public array $expressions;

    public function __construct(string $input)
    {
        $this->input = $input;
        $this->pos = 0;
        $this->len = strlen($input);
        $this->currentChar = $this->len > 0 ? $input[0] : "\0";
        $this->expressions = [];
    }

    private function advance(): void
    {
        $this->pos++;
        if ($this->pos >= $this->len) {
            $this->currentChar = "\0";
        } else {
            $this->currentChar = $this->input[$this->pos];
        }
    }

    private function skipWhitespace(): void
    {
        while ($this->currentChar !== "\0" &&
            ($this->currentChar === ' ' ||
                $this->currentChar === "\t" ||
                $this->currentChar === "\n" ||
                $this->currentChar === "\r")) {
            $this->advance();
        }
    }

    private function parseNumber(): CalcNumber
    {
        $v = 0;
        while ($this->currentChar !== "\0" && $this->currentChar >= '0' && $this->currentChar <= '9') {
            $v = $v * 10 + (ord($this->currentChar) - ord('0'));
            $this->advance();
        }
        return new CalcNumber($v);
    }

    private function parseVariable(): CalcNode
    {
        $start = $this->pos;
        while ($this->currentChar !== "\0" &&
            (($this->currentChar >= 'a' && $this->currentChar <= 'z') ||
                ($this->currentChar >= 'A' && $this->currentChar <= 'Z') ||
                ($this->currentChar >= '0' && $this->currentChar <= '9'))) {
            $this->advance();
        }

        $varName = substr($this->input, $start, $this->pos - $start);

        $this->skipWhitespace();
        if ($this->currentChar === '=') {
            $this->advance();
            $expr = $this->parseExpression();
            return new CalcAssignment($varName, $expr);
        }

        return new CalcVariable($varName);
    }

    private function parseFactor(): CalcNode
    {
        $this->skipWhitespace();
        if ($this->currentChar === "\0") {
            return new CalcNumber(0);
        }

        if ($this->currentChar >= '0' && $this->currentChar <= '9') {
            return $this->parseNumber();
        }

        if (($this->currentChar >= 'a' && $this->currentChar <= 'z') ||
                ($this->currentChar >= 'A' && $this->currentChar <= 'Z')) {
            return $this->parseVariable();
        }

        if ($this->currentChar === '(') {
            $this->advance();
            $node = $this->parseExpression();
            $this->skipWhitespace();
            if ($this->currentChar === ')') {
                $this->advance();
            }
            return $node;
        }

        $this->advance();
        return new CalcNumber(0);
    }

    private function parseTerm(): CalcNode
    {
        $node = $this->parseFactor();

        while (true) {
            $this->skipWhitespace();
            if ($this->currentChar === "\0")
                break;

            if ($this->currentChar === '*' || $this->currentChar === '/' || $this->currentChar === '%') {
                $op = $this->currentChar;
                $this->advance();
                $right = $this->parseFactor();
                $node = new CalcBinaryOp($op, $node, $right);
            } else {
                break;
            }
        }

        return $node;
    }

    private function parseExpression(): CalcNode
    {
        $node = $this->parseTerm();

        while (true) {
            $this->skipWhitespace();
            if ($this->currentChar === "\0")
                break;

            if ($this->currentChar === '+' || $this->currentChar === '-') {
                $op = $this->currentChar;
                $this->advance();
                $right = $this->parseTerm();
                $node = new CalcBinaryOp($op, $node, $right);
            } else {
                break;
            }
        }

        return $node;
    }

    public function parse(): void
    {
        $this->expressions = [];
        while ($this->currentChar !== "\0") {
            $this->skipWhitespace();
            if ($this->currentChar === "\0")
                break;
            $this->expressions[] = $this->parseExpression();
        }
    }
}

class CalcInt64
{
    private int $value;

    public function __construct(int|float|self $value = 0)
    {
        if ($value instanceof self) {
            $this->value = $value->value;
            return;
        }

        if (is_float($value)) {
            $value = (int) $value;
        }

        $this->value = $value;
    }

    public function add(self $other): self
    {
        return new self($this->wrap64(gmp_add($this->value, $other->value)));
    }

    public function sub(self $other): self
    {
        return new self($this->wrap64(gmp_sub($this->value, $other->value)));
    }

    public function mul(self $other): self
    {
        return new self($this->wrap64(gmp_mul($this->value, $other->value)));
    }

    public function floordiv(self $other): self
    {
        if ($other->value === 0)
            return new self(0);

        $a = $this->value;
        $b = $other->value;

        if (($a >= 0 && $b > 0) || ($a < 0 && $b < 0)) {
            $result = gmp_intval(gmp_div_q($a, $b));
        } else {
            $result = gmp_intval(gmp_neg(gmp_div_q(gmp_abs($a), gmp_abs($b))));
        }

        return new self($result);
    }

    public function mod(self $other): self
    {
        if ($other->value === 0)
            return new self(0);

        $divResult = $this->floordiv($other);
        $mul = gmp_mul($divResult->value, $other->value);
        $result = gmp_sub($this->value, $mul);

        return new self($this->wrap64($result));
    }

    public function toInt(): int
    {
        return $this->value;
    }

    private function wrap64(\GMP|int|string $value): int
    {
        if ($value instanceof \GMP) {
            $masked = gmp_and($value, gmp_init('0xFFFFFFFFFFFFFFFF'));

            $signBit = gmp_and($masked, gmp_init('0x8000000000000000'));
            if (gmp_cmp($signBit, 0) > 0) {
                $masked = gmp_sub($masked, gmp_init('0x10000000000000000'));
            }

            return (int) gmp_intval($masked);
        }

        return (int) $value;
    }
}

class CalcInterpreterEngine
{
    private array $variables = [];

    public function evaluate(CalcNode $node): CalcInt64
    {
        if ($node instanceof CalcNumber) {
            return new CalcInt64($node->value);
        } elseif ($node instanceof CalcVariable) {
            return $this->variables[$node->name] ?? new CalcInt64(0);
        } elseif ($node instanceof CalcBinaryOp) {
            $left = $this->evaluate($node->left);
            $right = $this->evaluate($node->right);

            return match ($node->op) {
                '+' => $left->add($right),
                '-' => $left->sub($right),
                '*' => $left->mul($right),
                '/' => $left->floordiv($right),
                '%' => $left->mod($right),
                default => new CalcInt64(0),
            };
        } elseif ($node instanceof CalcAssignment) {
            $value = $this->evaluate($node->expr);
            $this->variables[$node->var] = $value;
            return $value;
        }

        return new CalcInt64(0);
    }

    public function run(array $expressions): int
    {
        $result = new CalcInt64(0);
        foreach ($expressions as $expr) {
            $result = $this->evaluate($expr);
        }

        return $result->toInt() & 0xFFFFFFFF;
    }

    public function clear(): void
    {
        $this->variables = [];
    }
}

class CalculatorAst extends Benchmark
{
    public int $n;
    public string $text;
    public array $expressions;
    private int $result_val;

    public function __construct()
    {
        $this->n = $this->configVal('operations');
        $this->text = '';
        $this->expressions = [];
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Calculator::Ast';
    }

    public function setN(int $n): void
    {
        $this->n = $n;
    }

    private function generateRandomProgram(int $n): string
    {
        $lines = [];
        $lines[] = 'v0 = 1';

        for ($i = 1; $i <= 10; $i++) {
            $lines[] = "v{$i} = v" . ($i - 1) . " + {$i}";
        }

        for ($i = 0; $i < $n; $i++) {
            $v = $i + 10;
            $expr = 'v' . ($v - 1) . ' + ';
            $choice = Helper::nextInt(10);

            switch ($choice) {
                case 0:
                    $expr .= '(v' . ($v - 1) . " / 3) * 4 - {$i} / (3 + (18 - v" . ($v - 2) . ')) % v' . ($v - 3) . ' + 2 * ((9 - v' . ($v - 6) . ') * (v' . ($v - 5) . ' + 7))';
                    break;
                case 1:
                    $expr .= 'v' . ($v - 1) . ' + (v' . ($v - 2) . ' + v' . ($v - 3) . ') * v' . ($v - 4) . ' - (v' . ($v - 5) . ' / v' . ($v - 6) . ')';
                    break;
                case 2:
                    $expr .= '(3789 - (((v' . ($v - 7) . ')))) + 1';
                    break;
                case 3:
                    $expr .= '4/2 * (1-3) + v' . ($v - 9) . '/v' . ($v - 5);
                    break;
                case 4:
                    $expr .= '1+2+3+4+5+6+v' . ($v - 1);
                    break;
                case 5:
                    $expr .= '(99999 / v' . ($v - 3) . ')';
                    break;
                case 6:
                    $expr .= '0 + 0 - v' . ($v - 8);
                    break;
                case 7:
                    $expr .= '((((((((((v' . ($v - 6) . ')))))))))) * 2';
                    break;
                case 8:
                    $expr .= "{$i} * (v" . ($v - 1) . ' % 6) % 7';
                    break;
                case 9:
                    $expr .= '(1)/(0-v' . ($v - 5) . ') + (v' . ($v - 7) . ')';
                    break;
            }

            $lines[] = "v{$v} = {$expr}";
        }

        return implode("\n", $lines);
    }

    public function prepare(): void
    {
        $this->text = $this->generateRandomProgram($this->n);
        $this->expressions = [];
        $this->result_val = 0;
    }

    public function run(int $iteration_id): void
    {
        $parser = new CalculatorParser($this->text);
        $parser->parse();
        $this->expressions = $parser->expressions;

        $this->result_val = ($this->result_val + count($this->expressions)) & 0xFFFFFFFF;

        if (!empty($this->expressions)) {
            $last = $this->expressions[count($this->expressions) - 1];
            if ($last instanceof CalcAssignment) {
                $this->result_val = ($this->result_val + Helper::checksum($last->var)) & 0xFFFFFFFF;
            }
        }
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class CalculatorInterpreter extends Benchmark
{
    private int $n;
    private array $ast;
    private int $result_val;

    public function __construct()
    {
        $this->n = 0;
        $this->ast = [];
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Calculator::Interpreter';
    }

    public function prepare(): void
    {
        $this->n = $this->configVal('operations');

        $ast = new CalculatorAst();
        $ast->n = $this->n;
        $ast->prepare();
        $ast->run(0);
        $this->ast = $ast->expressions;

        $this->result_val = 0;
    }

    public function run(int $iteration_id): void
    {
        $interpreter = new CalcInterpreterEngine();
        $result = $interpreter->run($this->ast);
        $this->result_val = ($this->result_val + $result) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

enum CellKind: int
{
    case WALL = 0;
    case SPACE = 1;
    case START = 2;
    case FINISH = 3;
    case BORDER = 4;
    case PATH = 5;

    public function walkable(): bool
    {
        return $this === self::SPACE || $this === self::START || $this === self::FINISH;
    }
}

class Cell
{
    public CellKind $kind = CellKind::WALL;
    public array $neighbors = [];
    public int $x;
    public int $y;

    public function __construct(int $x, int $y)
    {
        $this->x = $x;
        $this->y = $y;
    }

    public function reset(): void
    {
        if ($this->kind === CellKind::SPACE) {
            $this->kind = CellKind::WALL;
        }
    }
}

class Maze
{
    public array $cells;
    public Cell $start;
    public Cell $finish;
    private int $w;
    private int $h;

    public function __construct(int $w, int $h)
    {
        $this->w = $w;
        $this->h = $h;
        $this->cells = [];

        for ($y = 0; $y < $h; $y++) {
            $row = [];
            for ($x = 0; $x < $w; $x++) {
                $row[] = new Cell($x, $y);
            }
            $this->cells[] = $row;
        }

        $this->start = $this->cells[1][1];
        $this->finish = $this->cells[$h - 2][$w - 2];
        $this->start->kind = CellKind::START;
        $this->finish->kind = CellKind::FINISH;

        $this->updateNeighbors();
    }

    public function updateNeighbors(): void
    {
        foreach ($this->cells as $y => $row) {
            foreach ($row as $x => $cell) {
                if ($x > 0 && $y > 0 && $x < $this->w - 1 && $y < $this->h - 1) {
                    $cell->neighbors = [
                        $this->cells[$y - 1][$x],
                        $this->cells[$y + 1][$x],
                        $this->cells[$y][$x + 1],
                        $this->cells[$y][$x - 1],
                    ];

                    for ($k = 0; $k < 4; $k++) {
                        $i = Helper::nextInt(4);
                        $j = Helper::nextInt(4);
                        if ($i !== $j) {
                            $tmp = $cell->neighbors[$i];
                            $cell->neighbors[$i] = $cell->neighbors[$j];
                            $cell->neighbors[$j] = $tmp;
                        }
                    }
                } else {
                    $cell->kind = CellKind::BORDER;
                }
            }
        }
    }

    public function reset(): void
    {
        foreach ($this->cells as $row) {
            foreach ($row as $cell) {
                $cell->reset();
            }
        }
        $this->start->kind = CellKind::START;
        $this->finish->kind = CellKind::FINISH;
    }

    public function dig(Cell $start): void
    {
        $q = [$start];
        while (!empty($q)) {
            $cell = array_pop($q);
            if ($this->countWalkableNeighbors($cell) === 1) {
                $cell->kind = CellKind::SPACE;
                foreach ($cell->neighbors as $n) {
                    if ($n->kind === CellKind::WALL) {
                        $q[] = $n;
                    }
                }
            }
        }
    }

    private function countWalkableNeighbors(Cell $cell): int
    {
        $count = 0;
        foreach ($cell->neighbors as $n) {
            if ($n->kind->walkable()) {
                $count++;
            }
        }
        return $count;
    }

    public function ensureOpenFinish(Cell $cell): void
    {
        $cell->kind = CellKind::SPACE;
        if ($this->countWalkableNeighbors($cell) > 1) {
            return;
        }
        foreach ($cell->neighbors as $n) {
            if ($n->kind === CellKind::WALL) {
                $this->ensureOpenFinish($n);
            }
        }
    }

    public function generate(): void
    {
        foreach ($this->start->neighbors as $n) {
            if ($n->kind === CellKind::WALL) {
                $this->dig($n);
            }
        }
        foreach ($this->finish->neighbors as $n) {
            if ($n->kind === CellKind::WALL) {
                $this->ensureOpenFinish($n);
            }
        }
    }

    public function middleCell(): Cell
    {
        return $this->cells[$this->h >> 1][$this->w >> 1];
    }

    public function checksum(): int
    {
        $hasher = 2166136261;
        $prime = 16777619;

        foreach ($this->cells as $y => $row) {
            foreach ($row as $x => $cell) {
                if ($cell->kind === CellKind::SPACE) {
                    $jSquared = ($x * $y) & 0xFFFFFFFF;
                    $hasher = (($hasher ^ $jSquared) * $prime) & 0xFFFFFFFF;
                }
            }
        }

        return $hasher;
    }
}

class MazeGenerator extends Benchmark
{
    private int $width;
    private int $height;
    private Maze $maze;
    private int $result_val;

    public function __construct()
    {
        $this->width = $this->configVal('w');
        $this->height = $this->configVal('h');
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Maze::Generator';
    }

    public function prepare(): void
    {
        $this->maze = new Maze($this->width, $this->height);
        $this->result_val = 0;
    }

    public function run(int $iteration_id): void
    {
        $this->maze->reset();
        $this->maze->generate();
        $this->result_val = ($this->result_val + $this->maze->middleCell()->kind->value) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return ($this->result_val + $this->maze->checksum()) & 0xFFFFFFFF;
    }
}

class MazeBFS extends Benchmark
{
    private int $width;
    private int $height;
    private Maze $maze;
    private array $path;
    private int $result_val;

    public function __construct()
    {
        $this->width = $this->configVal('w');
        $this->height = $this->configVal('h');
        $this->path = [];
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Maze::BFS';
    }

    public function prepare(): void
    {
        $this->maze = new Maze($this->width, $this->height);
        $this->maze->generate();
        $this->path = [];
        $this->result_val = 0;
    }

    private function bfs(Cell $start, Cell $target): array
    {
        if ($start === $target) {
            return [$start];
        }

        $queue = [0];
        $queueHead = 0;
        $visited = array_fill(0, $this->height * $this->width, false);
        $path = [[$start, -1]];

        $visited[$start->y * $this->width + $start->x] = true;

        while ($queueHead < count($queue)) {
            $pathId = $queue[$queueHead++];
            [$cell, $prev] = $path[$pathId];

            foreach ($cell->neighbors as $neighbor) {
                if ($neighbor === $target) {
                    $res = [$target];
                    $current = $pathId;
                    while ($current >= 0) {
                        $res[] = $path[$current][0];
                        $current = $path[$current][1];
                    }
                    return array_reverse($res);
                }

                $idx = $neighbor->y * $this->width + $neighbor->x;
                if ($neighbor->kind->walkable() && !$visited[$idx]) {
                    $visited[$idx] = true;
                    $path[] = [$neighbor, $pathId];
                    $queue[] = count($path) - 1;
                }
            }
        }

        return [];
    }

    public function run(int $iteration_id): void
    {
        $this->path = $this->bfs($this->maze->start, $this->maze->finish);
        $this->result_val = ($this->result_val + count($this->path)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        $mid = count($this->path) >> 1;
        if (isset($this->path[$mid])) {
            $v = $this->path[$mid];
            return ($this->result_val + $v->x * $v->y) & 0xFFFFFFFF;
        }
        return $this->result_val & 0xFFFFFFFF;
    }
}

class MazePriorityQueue
{
    private array $heap = [];
    private int $size = 0;
    private array $bestPriority;

    public function __construct(int $maxSize)
    {
        $this->bestPriority = array_fill(0, $maxSize, PHP_INT_MAX);
    }

    public function isEmpty(): bool
    {
        return $this->size === 0;
    }

    public function push(int $vertex, int $priority): void
    {
        if ($priority >= $this->bestPriority[$vertex]) {
            return;
        }

        $this->bestPriority[$vertex] = $priority;

        if ($this->size >= count($this->heap)) {
            $this->heap[] = [$vertex, $priority];
        } else {
            $this->heap[$this->size] = [$vertex, $priority];
        }

        $i = $this->size;
        $this->size++;

        while ($i > 0) {
            $parent = ($i - 1) >> 1;
            if ($this->heap[$parent][1] <= $priority)
                break;
            $this->heap[$i] = $this->heap[$parent];
            $i = $parent;
        }
        $this->heap[$i] = [$vertex, $priority];
    }

    public function pop(): array
    {
        $min = $this->heap[0];
        $this->size--;

        if ($this->size > 0) {
            $last = $this->heap[$this->size];
            $i = 0;

            while (true) {
                $left = 2 * $i + 1;
                $right = 2 * $i + 2;
                $smallest = $i;

                if ($left < $this->size && $this->heap[$left][1] < $this->heap[$smallest][1]) {
                    $smallest = $left;
                }
                if ($right < $this->size && $this->heap[$right][1] < $this->heap[$smallest][1]) {
                    $smallest = $right;
                }

                if ($smallest === $i)
                    break;

                $this->heap[$i] = $this->heap[$smallest];
                $i = $smallest;
            }

            $this->heap[$i] = $last;
        }

        return $min;
    }
}

class MazeAStar extends Benchmark
{
    private int $width;
    private int $height;
    private Maze $maze;
    private array $path;
    private int $result_val;

    public function __construct()
    {
        $this->width = $this->configVal('w');
        $this->height = $this->configVal('h');
        $this->path = [];
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Maze::AStar';
    }

    public function prepare(): void
    {
        $this->maze = new Maze($this->width, $this->height);
        $this->maze->generate();
        $this->path = [];
        $this->result_val = 0;
    }

    private function heuristic(Cell $a, Cell $b): int
    {
        return abs($a->x - $b->x) + abs($a->y - $b->y);
    }

    private function astar(Cell $start, Cell $target): array
    {
        if ($start === $target) {
            return [$start];
        }

        $width = $this->width;
        $height = $this->height;
        $size = $width * $height;

        $startIdx = $start->y * $width + $start->x;
        $targetIdx = $target->y * $width + $target->x;

        $cameFrom = array_fill(0, $size, -1);
        $gScore = array_fill(0, $size, PHP_INT_MAX);

        $openSet = new MazePriorityQueue($size);

        $gScore[$startIdx] = 0;
        $openSet->push($startIdx, $this->heuristic($start, $target));

        while (!$openSet->isEmpty()) {
            [$currentIdx, $_] = $openSet->pop();

            if ($currentIdx === $targetIdx) {
                return $this->reconstructPath($cameFrom, $currentIdx);
            }

            $currentY = intdiv($currentIdx, $width);
            $currentX = $currentIdx % $width;
            $current = $this->maze->cells[$currentY][$currentX];
            $currentG = $gScore[$currentIdx];

            foreach ($current->neighbors as $neighbor) {
                if (!$neighbor->kind->walkable())
                    continue;

                $neighborIdx = $neighbor->y * $width + $neighbor->x;
                $tentativeG = $currentG + 1;

                if ($tentativeG < $gScore[$neighborIdx]) {
                    $cameFrom[$neighborIdx] = $currentIdx;
                    $gScore[$neighborIdx] = $tentativeG;
                    $newF = $tentativeG + $this->heuristic($neighbor, $target);

                    $openSet->push($neighborIdx, $newF);
                }
            }
        }

        return [];
    }

    private function reconstructPath(array $cameFrom, int $currentIdx): array
    {
        $path = [];
        while ($currentIdx !== -1) {
            $y = intdiv($currentIdx, $this->width);
            $x = $currentIdx % $this->width;
            $path[] = $this->maze->cells[$y][$x];
            $currentIdx = $cameFrom[$currentIdx];
        }
        return array_reverse($path);
    }

    public function run(int $iteration_id): void
    {
        $this->path = $this->astar($this->maze->start, $this->maze->finish);
        $this->result_val = ($this->result_val + count($this->path)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        $mid = count($this->path) >> 1;
        if (isset($this->path[$mid])) {
            $v = $this->path[$mid];
            return ($this->result_val + $v->x * $v->y) & 0xFFFFFFFF;
        }
        return $this->result_val & 0xFFFFFFFF;
    }
}

class Graph
{
    public int $vertices;
    public int $jumps;
    public int $jumpLen;
    public array $adj;

    public function __construct(int $vertices, int $jumps = 3, int $jumpLen = 100)
    {
        $this->vertices = $vertices;
        $this->jumps = $jumps;
        $this->jumpLen = $jumpLen;
        $this->adj = array_fill(0, $vertices, []);
    }

    public function addEdge(int $u, int $v): void
    {
        $this->adj[$u][] = $v;
        $this->adj[$v][] = $u;
    }

    public function generateRandom(): void
    {
        for ($i = 1; $i < $this->vertices; $i++) {
            $this->addEdge($i, $i - 1);
        }

        for ($v = 0; $v < $this->vertices; $v++) {
            $t = Helper::nextInt($this->jumps);
            for ($k = 0; $k < $t; $k++) {
                $offset = Helper::nextInt($this->jumpLen) - intdiv($this->jumpLen, 2);
                $u = $v + $offset;

                if ($u >= 0 && $u < $this->vertices && $u != $v) {
                    $this->addEdge($v, $u);
                }
            }
        }
    }
}

abstract class GraphPathBenchmark extends Benchmark
{
    protected Graph $graph;
    protected int $result_val;

    public function __construct()
    {
        $vertices = $this->configVal('vertices');
        $jumps = $this->configVal('jumps');
        $jumpLen = $this->configVal('jump_len');
        $this->graph = new Graph($vertices, $jumps, $jumpLen);
        $this->result_val = 0;
    }

    public function prepare(): void
    {
        Helper::reset();
        $this->graph->generateRandom();
        $this->result_val = 0;
    }

    abstract protected function test(): int;

    public function run(int $iteration_id): void
    {
        $this->result_val = ($this->result_val + $this->test()) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class GraphBFS extends GraphPathBenchmark
{
    public function name(): string
    {
        return 'Graph::BFS';
    }

    protected function test(): int
    {
        return $this->bfsShortestPath(0, $this->graph->vertices - 1);
    }

    private function bfsShortestPath(int $start, int $target): int
    {
        if ($start === $target)
            return 0;

        $vertices = $this->graph->vertices;
        $visited = array_fill(0, $vertices, 0);
        $queue = [[$start, 0]];
        $queueHead = 0;

        $visited[$start] = 1;

        while ($queueHead < count($queue)) {
            [$v, $dist] = $queue[$queueHead++];

            foreach ($this->graph->adj[$v] as $neighbor) {
                if ($neighbor === $target) {
                    return $dist + 1;
                }

                if ($visited[$neighbor] === 0) {
                    $visited[$neighbor] = 1;
                    $queue[] = [$neighbor, $dist + 1];
                }
            }
        }

        return -1;
    }
}

class GraphDFS extends GraphPathBenchmark
{
    public function name(): string
    {
        return 'Graph::DFS';
    }

    protected function test(): int
    {
        return $this->dfsShortestPath(0, $this->graph->vertices - 1);
    }

    private function dfsShortestPath(int $start, int $target): int
    {
        if ($start === $target)
            return 0;

        $vertices = $this->graph->vertices;
        $visited = array_fill(0, $vertices, 0);
        $stack = [[$start, 0]];
        $bestPath = PHP_INT_MAX;

        while (!empty($stack)) {
            [$v, $dist] = array_pop($stack);

            if ($visited[$v] === 1 || $dist >= $bestPath)
                continue;
            $visited[$v] = 1;

            foreach ($this->graph->adj[$v] as $neighbor) {
                if ($neighbor === $target) {
                    if ($dist + 1 < $bestPath) {
                        $bestPath = $dist + 1;
                    }
                } elseif ($visited[$neighbor] === 0) {
                    $stack[] = [$neighbor, $dist + 1];
                }
            }
        }

        return $bestPath === PHP_INT_MAX ? -1 : $bestPath;
    }
}

class GraphPriorityQueue
{
    private array $heap = [];
    private int $size = 0;

    public function isEmpty(): bool
    {
        return $this->size === 0;
    }

    public function push(int $vertex, int $priority): void
    {
        if ($this->size >= count($this->heap)) {
            $this->heap[] = [$vertex, $priority];
        } else {
            $this->heap[$this->size] = [$vertex, $priority];
        }

        $i = $this->size;
        $this->size++;

        while ($i > 0) {
            $parent = ($i - 1) >> 1;
            if ($this->heap[$parent][1] <= $priority)
                break;
            $this->heap[$i] = $this->heap[$parent];
            $i = $parent;
        }
        $this->heap[$i] = [$vertex, $priority];
    }

    public function pop(): array
    {
        $min = $this->heap[0];
        $this->size--;

        if ($this->size > 0) {
            $last = $this->heap[$this->size];
            $i = 0;

            while (true) {
                $left = 2 * $i + 1;
                $right = 2 * $i + 2;
                $smallest = $i;

                if ($left < $this->size && $this->heap[$left][1] < $this->heap[$smallest][1]) {
                    $smallest = $left;
                }
                if ($right < $this->size && $this->heap[$right][1] < $this->heap[$smallest][1]) {
                    $smallest = $right;
                }

                if ($smallest === $i)
                    break;

                $this->heap[$i] = $this->heap[$smallest];
                $i = $smallest;
            }

            $this->heap[$i] = $last;
        }

        return $min;
    }
}

class GraphAStar extends GraphPathBenchmark
{
    public function name(): string
    {
        return 'Graph::AStar';
    }

    protected function test(): int
    {
        return $this->astarShortestPath(0, $this->graph->vertices - 1);
    }

    private function heuristic(int $v, int $target): int
    {
        return $target - $v;
    }

    private function astarShortestPath(int $start, int $target): int
    {
        if ($start === $target)
            return 0;

        $vertices = $this->graph->vertices;

        $gScore = array_fill(0, $vertices, PHP_INT_MAX);
        $gScore[$start] = 0;

        $openSet = new GraphPriorityQueue();
        $openSet->push($start, $this->heuristic($start, $target));

        $inOpenSet = array_fill(0, $vertices, false);
        $inOpenSet[$start] = true;

        $closed = array_fill(0, $vertices, false);

        while (!$openSet->isEmpty()) {
            [$current, $_] = $openSet->pop();

            $closed[$current] = true;
            $inOpenSet[$current] = false;

            if ($current === $target) {
                return $gScore[$current];
            }

            foreach ($this->graph->adj[$current] as $neighbor) {
                if ($closed[$neighbor])
                    continue;

                $tentativeG = $gScore[$current] + 1;

                if ($tentativeG < $gScore[$neighbor]) {
                    $gScore[$neighbor] = $tentativeG;
                    $f = $tentativeG + $this->heuristic($neighbor, $target);

                    if (!$inOpenSet[$neighbor]) {
                        $openSet->push($neighbor, $f);
                        $inOpenSet[$neighbor] = true;
                    }
                }
            }
        }

        return -1;
    }
}

function generateCompressTestData(int $size): string
{
    $pattern = 'ABRACADABRA';
    $data = '';
    for ($i = 0; $i < $size; $i++) {
        $data .= $pattern[$i % strlen($pattern)];
    }
    return $data;
}

class CompressBWTEncode extends Benchmark
{
    public int $size;
    public string $testData;
    public string $transformed;
    public int $originalIdx;
    private int $result_val;

    public function __construct()
    {
        $this->size = $this->configVal('size');
        $this->testData = '';
        $this->transformed = '';
        $this->originalIdx = 0;
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Compress::BWTEncode';
    }

    public function prepare(): void
    {
        $this->testData = generateCompressTestData($this->size);
        $this->result_val = 0;
    }

    private function bwtTransform(string $input): array
    {
        $n = strlen($input);
        if ($n === 0)
            return ['', 0];

        $counts = array_fill(0, 256, 0);
        for ($i = 0; $i < $n; $i++) {
            ++$counts[ord($input[$i])];
        }

        $positions = array_fill(0, 256, 0);
        $total = 0;
        for ($i = 0; $i < 256; $i++) {
            $positions[$i] = $total;
            $total += $counts[$i];
        }

        $sa = array_fill(0, $n, 0);
        $tempCounts = array_fill(0, 256, 0);
        for ($i = 0; $i < $n; $i++) {
            $byte = ord($input[$i]);
            $sa[$positions[$byte] + $tempCounts[$byte]] = $i;
            ++$tempCounts[$byte];
        }

        if ($n > 1) {
            $rank = array_fill(0, $n, 0);
            $currentRank = 0;
            $prevChar = ord($input[$sa[0]]);

            for ($i = 0; $i < $n; $i++) {
                $idx = $sa[$i];
                $char = ord($input[$idx]);
                if ($char !== $prevChar) {
                    ++$currentRank;
                    $prevChar = $char;
                }
                $rank[$idx] = $currentRank;
            }

            $k = 1;
            while ($k < $n) {
                $suffixes = $sa;
                $rank1s = [];
                $rank2s = [];

                foreach ($sa as $suffix) {
                    $rank1s[] = $rank[$suffix];
                    $rank2s[] = $rank[($suffix + $k) % $n];
                }

                array_multisort(
                    $rank1s, SORT_ASC, SORT_NUMERIC,
                    $rank2s, SORT_ASC, SORT_NUMERIC,
                    $suffixes
                );
                $sa = $suffixes;

                $newRank = array_fill(0, $n, 0);
                for ($i = 1; $i < $n; $i++) {
                    $prev = $sa[$i - 1];
                    $curr = $sa[$i];
                    $newRank[$curr] = $newRank[$prev]
                        + (($rank[$prev] !== $rank[$curr] ||
                            $rank[($prev + $k) % $n] !== $rank[($curr + $k) % $n]) ? 1 : 0);
                }

                $rank = $newRank;
                $k <<= 1;
            }
        }

        $transformed = '';
        $originalIdx = 0;
        $lastChar = $input[$n - 1];

        foreach ($sa as $i => $suffix) {
            if ($suffix === 0) {
                $transformed .= $lastChar;
                $originalIdx = $i;
            } else {
                $transformed .= $input[$suffix - 1];
            }
        }

        return [$transformed, $originalIdx];
    }

    public function run(int $iteration_id): void
    {
        [$this->transformed, $this->originalIdx] = $this->bwtTransform($this->testData);
        $this->result_val = ($this->result_val + strlen($this->transformed)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class CompressBWTDecode extends Benchmark
{
    private int $size;
    private string $testData;
    private string $bwtData;
    private int $originalIdx;
    private string $inverted;
    private int $result_val;

    public function __construct()
    {
        $this->size = $this->configVal('size');
        $this->testData = '';
        $this->bwtData = '';
        $this->originalIdx = 0;
        $this->inverted = '';
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Compress::BWTDecode';
    }

    public function prepare(): void
    {
        $enc = new CompressBWTEncode();
        $enc->size = $this->size;
        $enc->prepare();
        $enc->run(0);

        $this->testData = $enc->testData;
        $this->bwtData = $enc->transformed;
        $this->originalIdx = $enc->originalIdx;
        $this->result_val = 0;
    }

    private function bwtInverse(string $bwt, int $originalIdx): string
    {
        $n = strlen($bwt);
        if ($n === 0)
            return '';

        $counts = array_fill(0, 256, 0);
        for ($i = 0; $i < $n; $i++) {
            ++$counts[ord($bwt[$i])];
        }

        $positions = array_fill(0, 256, 0);
        $total = 0;
        for ($i = 0; $i < 256; $i++) {
            $positions[$i] = $total;
            $total += $counts[$i];
        }

        $next = array_fill(0, $n, 0);
        $tempCounts = array_fill(0, 256, 0);

        for ($i = 0; $i < $n; $i++) {
            $byte = ord($bwt[$i]);
            $next[$positions[$byte] + $tempCounts[$byte]] = $i;
            ++$tempCounts[$byte];
        }

        $result = '';
        $idx = $originalIdx;
        for ($i = 0; $i < $n; $i++) {
            $idx = $next[$idx];
            $result .= $bwt[$idx];
        }

        return $result;
    }

    public function run(int $iteration_id): void
    {
        $this->inverted = $this->bwtInverse($this->bwtData, $this->originalIdx);
        $this->result_val = ($this->result_val + strlen($this->inverted)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        if ($this->inverted === $this->testData) {
            $this->result_val = ($this->result_val + 100000) & 0xFFFFFFFF;
        }
        return $this->result_val & 0xFFFFFFFF;
    }
}

class HuffmanNode
{
    public int $frequency;
    public int $byte_val;
    public bool $is_leaf;
    public ?HuffmanNode $left;
    public ?HuffmanNode $right;

    public function __construct(int $frequency, int $byte_val, bool $is_leaf)
    {
        $this->frequency = $frequency;
        $this->byte_val = $byte_val;
        $this->is_leaf = $is_leaf;
        $this->left = null;
        $this->right = null;
    }
}

class HuffmanCodes
{
    public array $code_lengths;
    public array $codes;

    public function __construct()
    {
        $this->code_lengths = array_fill(0, 256, 0);
        $this->codes = array_fill(0, 256, 0);
    }
}

class EncodedResult
{
    public string $data;
    public int $bit_count;
    public array $frequencies;

    public function __construct(string $data, int $bit_count, array $frequencies)
    {
        $this->data = $data;
        $this->bit_count = $bit_count;
        $this->frequencies = $frequencies;
    }
}

class CompressHuffEncode extends Benchmark
{
    public int $size;
    public string $testData;
    public EncodedResult $encoded;
    private int $result_val;

    public function __construct()
    {
        $this->size = $this->configVal('size');
        $this->testData = '';
        $this->encoded = new EncodedResult('', 0, []);
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Compress::HuffEncode';
    }

    public function prepare(): void
    {
        $this->testData = generateCompressTestData($this->size);
        $this->result_val = 0;
    }

    public static function buildHuffmanTree(array $frequencies): ?HuffmanNode
    {
        $nodes = [];
        foreach ($frequencies as $byte => $freq) {
            if ($freq > 0) {
                $nodes[] = new HuffmanNode($freq, $byte, true);
            }
        }

        usort($nodes, fn($a, $b) => $a->frequency - $b->frequency);

        if (count($nodes) === 1) {
            $node = $nodes[0];
            $root = new HuffmanNode($node->frequency, 0, false);
            $root->left = $node;
            $root->right = new HuffmanNode(0, 0, true);
            return $root;
        }

        while (count($nodes) > 1) {
            $left = array_shift($nodes);
            $right = array_shift($nodes);

            $parent = new HuffmanNode(
                $left->frequency + $right->frequency,
                0,
                false
            );
            $parent->left = $left;
            $parent->right = $right;

            $inserted = false;
            foreach ($nodes as $i => $node) {
                if ($node->frequency >= $parent->frequency) {
                    array_splice($nodes, $i, 0, [$parent]);
                    $inserted = true;
                    break;
                }
            }
            if (!$inserted) {
                $nodes[] = $parent;
            }
        }

        return $nodes[0] ?? null;
    }

    public static function buildHuffmanCodes(HuffmanNode $node, int $code, int $length, HuffmanCodes $codes): void
    {
        if ($node->is_leaf) {
            if ($length > 0 || $node->byte_val != 0) {
                $idx = $node->byte_val;
                $codes->code_lengths[$idx] = $length;
                $codes->codes[$idx] = $code;
            }
        } else {
            if ($node->left !== null) {
                self::buildHuffmanCodes($node->left, $code << 1, $length + 1, $codes);
            }
            if ($node->right !== null) {
                self::buildHuffmanCodes($node->right, ($code << 1) | 1, $length + 1, $codes);
            }
        }
    }

    public function run(int $iteration_id): void
    {
        $frequencies = array_fill(0, 256, 0);
        $n = strlen($this->testData);
        for ($i = 0; $i < $n; $i++) {
            $frequencies[ord($this->testData[$i])]++;
        }

        $tree = self::buildHuffmanTree($frequencies);

        $huffmanCodes = new HuffmanCodes();

        if ($tree !== null) {
            self::buildHuffmanCodes($tree, 0, 0, $huffmanCodes);
        }

        $result = '';
        $currentByte = 0;
        $bitPos = 0;
        $totalBits = 0;

        for ($i = 0; $i < $n; $i++) {
            $byte = ord($this->testData[$i]);
            $code = $huffmanCodes->codes[$byte];
            $length = $huffmanCodes->code_lengths[$byte];

            for ($j = $length - 1; $j >= 0; $j--) {
                if ($code & (1 << $j)) {
                    $currentByte |= 1 << (7 - $bitPos);
                }
                $bitPos++;
                $totalBits++;

                if ($bitPos === 8) {
                    $result .= pack('C', $currentByte);
                    $currentByte = 0;
                    $bitPos = 0;
                }
            }
        }

        if ($bitPos > 0) {
            $result .= pack('C', $currentByte);
        }

        $this->encoded = new EncodedResult($result, $totalBits, $frequencies);
        $this->result_val = ($this->result_val + strlen($result)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class CompressHuffDecode extends Benchmark
{
    private int $size;
    private string $testData;
    private EncodedResult $encoded;
    private string $decoded;
    private int $result_val;

    public function __construct()
    {
        $this->size = $this->configVal('size');
        $this->testData = '';
        $this->encoded = new EncodedResult('', 0, []);
        $this->decoded = '';
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Compress::HuffDecode';
    }

    public function prepare(): void
    {
        $this->size = $this->configVal('size');

        $enc = new CompressHuffEncode();
        $enc->size = $this->size;
        $enc->prepare();
        $enc->run(0);

        $this->testData = $enc->testData;
        $this->encoded = $enc->encoded;
        $this->result_val = 0;
    }

    private function huffmanDecode(string $data, HuffmanNode $root, int $bitCount): string
    {
        $result = '';
        $currentNode = $root;
        $bitsProcessed = 0;
        $dataLen = strlen($data);

        for ($i = 0; $i < $dataLen && $bitsProcessed < $bitCount; $i++) {
            $byteVal = unpack('C', $data[$i])[1];

            for ($bitPos = 7; $bitPos >= 0 && $bitsProcessed < $bitCount; $bitPos--) {
                $bit = (($byteVal >> $bitPos) & 1) === 1;
                $bitsProcessed++;

                $currentNode = $bit ? $currentNode->right : $currentNode->left;

                if ($currentNode->is_leaf) {
                    if ($currentNode->byte_val != 0) {
                        $result .= pack('C', $currentNode->byte_val);
                    }
                    $currentNode = $root;
                }
            }
        }

        return $result;
    }

    public function run(int $iteration_id): void
    {
        $tree = CompressHuffEncode::buildHuffmanTree($this->encoded->frequencies);

        if ($tree !== null) {
            $this->decoded = $this->huffmanDecode(
                $this->encoded->data,
                $tree,
                $this->encoded->bit_count
            );
            $this->result_val = ($this->result_val + strlen($this->decoded)) & 0xFFFFFFFF;
        }
    }

    public function checksum(): int
    {
        if ($this->decoded === $this->testData) {
            $this->result_val = ($this->result_val + 100000) & 0xFFFFFFFF;
        }
        return $this->result_val & 0xFFFFFFFF;
    }
}

class ArithEncodedResult
{
    public string $data;
    public array $frequencies;

    public function __construct(string $data, array $frequencies)
    {
        $this->data = $data;
        $this->frequencies = $frequencies;
    }
}

class ArithFreqTable
{
    public int $total;
    public array $low;
    public array $high;

    public function __construct(array $frequencies)
    {
        $this->total = array_sum($frequencies);
        $this->low = array_fill(0, 256, 0);
        $this->high = array_fill(0, 256, 0);

        $cum = 0;
        for ($i = 0; $i < 256; $i++) {
            $this->low[$i] = $cum;
            $cum += $frequencies[$i];
            $this->high[$i] = $cum;
        }
    }
}

class BitOutputStream
{
    private int $buffer = 0;
    private int $bitPos = 0;
    private array $bytes = [];
    private int $bitsWritten = 0;

    public function writeBit(int $bit): void
    {
        $this->buffer = ($this->buffer << 1) | ($bit & 1);
        $this->bitPos++;
        $this->bitsWritten++;

        if ($this->bitPos === 8) {
            $this->bytes[] = $this->buffer;
            $this->buffer = 0;
            $this->bitPos = 0;
        }
    }

    public function flush(): string
    {
        if ($this->bitPos > 0) {
            $this->buffer <<= 8 - $this->bitPos;
            $this->bytes[] = $this->buffer;
        }
        $result = '';
        foreach ($this->bytes as $byte) {
            $result .= pack('C', $byte);
        }
        return $result;
    }

    public function getBitsWritten(): int
    {
        return $this->bitsWritten;
    }
}

class BitInputStream
{
    private string $bytes;
    private int $bytesLen;
    private int $bytePos = 0;
    private int $bitPos = 0;
    private int $currentByte = 0;

    public function __construct(string $bytes)
    {
        $this->bytes = $bytes;
        $this->bytesLen = strlen($bytes);
        if ($this->bytesLen > 0) {
            $this->currentByte = ord($bytes[0]);
        }
    }

    public function readBit(): int
    {
        if ($this->bitPos === 8) {
            $this->bytePos++;
            $this->bitPos = 0;
            if ($this->bytePos < $this->bytesLen) {
                $this->currentByte = ord($this->bytes[$this->bytePos]);
            } else {
                $this->currentByte = 0;
            }
        }

        $bit = ($this->currentByte >> (7 - $this->bitPos)) & 1;
        $this->bitPos++;
        return $bit;
    }
}

class CompressArithEncode extends Benchmark
{
    public int $size;
    public string $testData;
    public ArithEncodedResult $encoded;
    private int $result_val;

    public function __construct()
    {
        $this->size = $this->configVal('size');
        $this->testData = '';
        $this->encoded = new ArithEncodedResult('', []);
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Compress::ArithEncode';
    }

    public function prepare(): void
    {
        $this->testData = generateCompressTestData($this->size);
        $this->result_val = 0;
    }

    private function arithEncode(string $data): ArithEncodedResult
    {
        $frequencies = array_fill(0, 256, 0);
        $n = strlen($data);
        for ($i = 0; $i < $n; $i++) {
            $frequencies[ord($data[$i])]++;
        }

        $freqTable = new ArithFreqTable($frequencies);

        $low = 0;
        $high = 0xFFFFFFFF;
        $pending = 0;
        $output = new BitOutputStream();

        for ($i = 0; $i < $n; $i++) {
            $idx = ord($data[$i]);
            $range = $high - $low + 1;

            $high = $low + intdiv($range * $freqTable->high[$idx], $freqTable->total) - 1;
            $low = $low + intdiv($range * $freqTable->low[$idx], $freqTable->total);

            while (true) {
                if ($high < 0x80000000) {
                    $output->writeBit(0);
                    for ($k = 0; $k < $pending; $k++) {
                        $output->writeBit(1);
                    }
                    $pending = 0;
                } elseif ($low >= 0x80000000) {
                    $output->writeBit(1);
                    for ($k = 0; $k < $pending; $k++) {
                        $output->writeBit(0);
                    }
                    $pending = 0;
                    $low -= 0x80000000;
                    $high -= 0x80000000;
                } elseif ($low >= 0x40000000 && $high < 0xC0000000) {
                    $pending++;
                    $low -= 0x40000000;
                    $high -= 0x40000000;
                } else {
                    break;
                }

                $low = ($low << 1) & 0xFFFFFFFF;
                $high = (($high << 1) | 1) & 0xFFFFFFFF;
            }
        }

        $pending++;
        if ($low < 0x40000000) {
            $output->writeBit(0);
            for ($k = 0; $k < $pending; $k++) {
                $output->writeBit(1);
            }
        } else {
            $output->writeBit(1);
            for ($k = 0; $k < $pending; $k++) {
                $output->writeBit(0);
            }
        }

        $encodedData = $output->flush();
        return new ArithEncodedResult($encodedData, $frequencies);
    }

    public function run(int $iteration_id): void
    {
        $this->encoded = $this->arithEncode($this->testData);
        $this->result_val = ($this->result_val + strlen($this->encoded->data)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class CompressArithDecode extends Benchmark
{
    private int $size;
    private string $testData;
    private ArithEncodedResult $encoded;
    private string $decoded;
    private int $result_val;

    public function __construct()
    {
        $this->size = $this->configVal('size');
        $this->testData = '';
        $this->encoded = new ArithEncodedResult('', []);
        $this->decoded = '';
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Compress::ArithDecode';
    }

    public function prepare(): void
    {
        $this->size = $this->configVal('size');

        $enc = new CompressArithEncode();
        $enc->size = $this->size;
        $enc->prepare();
        $enc->run(0);

        $this->testData = $enc->testData;
        $this->encoded = $enc->encoded;
        $this->result_val = 0;
    }

    private function arithDecode(ArithEncodedResult $encoded): string
    {
        $frequencies = $encoded->frequencies;
        $total = array_sum($frequencies);

        if ($total === 0)
            return '';

        $dataSize = $total;
        $lowTable = array_fill(0, 256, 0);
        $highTable = array_fill(0, 256, 0);

        $cum = 0;
        for ($i = 0; $i < 256; $i++) {
            $lowTable[$i] = $cum;
            $cum += $frequencies[$i];
            $highTable[$i] = $cum;
        }

        $input = new BitInputStream($encoded->data);

        $value = 0;
        for ($i = 0; $i < 32; $i++) {
            $value = ($value << 1) | $input->readBit();
        }

        $low = 0;
        $high = 0xFFFFFFFF;
        $result = '';

        for ($j = 0; $j < $dataSize; $j++) {
            $range = $high - $low + 1;
            $scaled = intdiv(($value - $low + 1) * $total - 1, $range);

            $left = 0;
            $right = 256;
            while ($left < $right) {
                $mid = ($left + $right) >> 1;
                if ($highTable[$mid] <= $scaled) {
                    $left = $mid + 1;
                } else {
                    $right = $mid;
                }
            }
            $symbol = $left;

            $result .= pack('C', $symbol);

            $high = $low + intdiv($range * $highTable[$symbol], $total) - 1;
            $low = $low + intdiv($range * $lowTable[$symbol], $total);

            while (true) {
                if ($high >= 0x80000000 &&
                        $low < 0x80000000 &&
                        ($low < 0x40000000 || $high >= 0xC0000000)) {
                    break;
                }

                if ($high < 0x80000000) {
                } elseif ($low >= 0x80000000) {
                    $value -= 0x80000000;
                    $low -= 0x80000000;
                    $high -= 0x80000000;
                } elseif ($low >= 0x40000000 && $high < 0xC0000000) {
                    $value -= 0x40000000;
                    $low -= 0x40000000;
                    $high -= 0x40000000;
                }

                $low = ($low << 1) & 0xFFFFFFFF;
                $high = (($high << 1) | 1) & 0xFFFFFFFF;
                $value = (($value << 1) | $input->readBit()) & 0xFFFFFFFF;
            }
        }

        return $result;
    }

    public function run(int $iteration_id): void
    {
        $this->decoded = $this->arithDecode($this->encoded);
        $this->result_val = ($this->result_val + strlen($this->decoded)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        if ($this->decoded === $this->testData) {
            $this->result_val = ($this->result_val + 100000) & 0xFFFFFFFF;
        }
        return $this->result_val & 0xFFFFFFFF;
    }
}

class CompressLZWEncode extends Benchmark
{
    public int $size;
    public string $testData;
    public string $encodedData;
    private int $result_val;

    public function __construct()
    {
        $this->size = $this->configVal('size');
        $this->testData = '';
        $this->encodedData = '';
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Compress::LZWEncode';
    }

    public function prepare(): void
    {
        $this->testData = generateCompressTestData($this->size);
        $this->result_val = 0;
    }

    public function run(int $iteration_id): void
    {
        $input = $this->testData;
        $n = strlen($input);
        if ($n === 0)
            return;

        $dict = [];
        for ($i = 0; $i < 256; $i++) {
            $dict[chr($i)] = $i;
        }

        $nextCode = 256;
        $result = '';
        $current = $input[0];

        for ($i = 1; $i < $n; $i++) {
            $nextChar = $input[$i];
            $newStr = $current . $nextChar;

            if (isset($dict[$newStr])) {
                $current = $newStr;
            } else {
                $code = $dict[$current];
                $result .= pack('n', $code);

                $dict[$newStr] = $nextCode++;
                $current = $nextChar;
            }
        }

        $code = $dict[$current];
        $result .= pack('n', $code);

        $this->encodedData = $result;
        $this->result_val = ($this->result_val + strlen($result)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->result_val & 0xFFFFFFFF;
    }
}

class CompressLZWDecode extends Benchmark
{
    private int $size;
    private string $testData;
    private string $encodedData;
    private string $decoded;
    private int $result_val;

    public function __construct()
    {
        $this->size = $this->configVal('size');
        $this->testData = '';
        $this->encodedData = '';
        $this->decoded = '';
        $this->result_val = 0;
    }

    public function name(): string
    {
        return 'Compress::LZWDecode';
    }

    public function prepare(): void
    {
        $this->size = $this->configVal('size');

        $enc = new CompressLZWEncode();
        $enc->size = $this->size;
        $enc->prepare();
        $enc->run(0);

        $this->testData = $enc->testData;
        $this->encodedData = $enc->encodedData;
        $this->result_val = 0;
    }

    public function run(int $iteration_id): void
    {
        $data = $this->encodedData;
        $dataLen = strlen($data);
        if ($dataLen === 0)
            return;

        $dict = [];
        for ($i = 0; $i < 256; $i++) {
            $dict[] = chr($i);
        }

        $result = '';
        $pos = 0;

        $oldCode = unpack('n', substr($data, $pos, 2))[1];
        $pos += 2;

        $oldStr = $dict[$oldCode];
        $result .= $oldStr;

        $nextCode = 256;
        $dictCount = 256;

        while ($pos < $dataLen - 1) {
            $newCode = unpack('n', substr($data, $pos, 2))[1];
            $pos += 2;

            if ($newCode < $dictCount) {
                $newStr = $dict[$newCode];
            } elseif ($newCode === $nextCode) {
                $newStr = $oldStr . $oldStr[0];
            } else {
                break;
            }

            $result .= $newStr;
            $dict[] = $oldStr . $newStr[0];
            $nextCode++;
            $dictCount++;
            $oldStr = $newStr;
        }

        $this->decoded = $result;
        $this->result_val = ($this->result_val + strlen($result)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        if ($this->decoded === $this->testData) {
            $this->result_val = ($this->result_val + 100000) & 0xFFFFFFFF;
        }
        return $this->result_val & 0xFFFFFFFF;
    }
}

class EtcSieve extends Benchmark
{
    private int $limit;
    private int $checksum_val;

    public function __construct()
    {
        $this->limit = 0;
        $this->checksum_val = 0;
    }

    public function name(): string
    {
        return 'Etc::Sieve';
    }

    public function prepare(): void
    {
        $this->limit = $this->configVal('limit');
        $this->checksum_val = 0;
    }

    public function run(int $iteration_id): void
    {
        $limit = $this->limit;
        $primes = array_fill(0, $limit + 1, 1);
        $primes[0] = $primes[1] = 0;

        $sqrtLimit = (int) sqrt($limit);

        for ($p = 2; $p <= $sqrtLimit; $p++) {
            if ($primes[$p] === 1) {
                for ($multiple = $p * $p; $multiple <= $limit; $multiple += $p) {
                    $primes[$multiple] = 0;
                }
            }
        }

        $lastPrime = 2;
        $count = 1;

        for ($n = 3; $n <= $limit; $n += 2) {
            if ($primes[$n] === 1) {
                $lastPrime = $n;
                $count++;
            }
        }

        $this->checksum_val = ($this->checksum_val + $lastPrime + $count) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->checksum_val & 0xFFFFFFFF;
    }
}

class RTColor
{
    public float $r;
    public float $g;
    public float $b;

    public function __construct(float $r, float $g, float $b)
    {
        $this->r = $r;
        $this->g = $g;
        $this->b = $b;
    }

    public function scale(float $s): self
    {
        return new self($this->r * $s, $this->g * $s, $this->b * $s);
    }

    public function add(self $other): self
    {
        return new self($this->r + $other->r, $this->g + $other->g, $this->b + $other->b);
    }
}

class RTVector
{
    public float $x;
    public float $y;
    public float $z;

    public function __construct(float $x, float $y, float $z)
    {
        $this->x = $x;
        $this->y = $y;
        $this->z = $z;
    }

    public function scale(float $s): self
    {
        return new self($this->x * $s, $this->y * $s, $this->z * $s);
    }

    public function add(self $other): self
    {
        return new self($this->x + $other->x, $this->y + $other->y, $this->z + $other->z);
    }

    public function sub(self $other): self
    {
        return new self($this->x - $other->x, $this->y - $other->y, $this->z - $other->z);
    }

    public function dot(self $other): float
    {
        return $this->x * $other->x + $this->y * $other->y + $this->z * $other->z;
    }

    public function magnitude(): float
    {
        return sqrt($this->dot($this));
    }

    public function normalize(): self
    {
        return $this->scale(1.0 / $this->magnitude());
    }
}

class RTSphere
{
    public RTVector $center;
    public float $radius;
    public RTColor $color;

    public function __construct(RTVector $center, float $radius, RTColor $color)
    {
        $this->center = $center;
        $this->radius = $radius;
        $this->color = $color;
    }

    public function getNormal(RTVector $pt): RTVector
    {
        return $pt->sub($this->center)->normalize();
    }
}

class EtcTextRaytracer extends Benchmark
{
    private int $w;
    private int $h;
    private int $res;

    private const LUT = ['.', '-', '+', '*', 'X', 'M'];

    private const WHITE = null;

    private static ?RTColor $white = null;
    private static ?RTColor $red = null;
    private static ?RTColor $green = null;
    private static ?RTColor $blue = null;
    private static ?RTVector $lightPos = null;
    private static ?RTColor $lightColor = null;
    private static array $scene = [];

    public function __construct()
    {
        $this->w = $this->configVal('w');
        $this->h = $this->configVal('h');
        $this->res = 0;
    }

    public function name(): string
    {
        return 'Etc::TextRaytracer';
    }

    public function prepare(): void
    {
        $this->res = 0;

        self::$white = new RTColor(1.0, 1.0, 1.0);
        self::$red = new RTColor(1.0, 0.0, 0.0);
        self::$green = new RTColor(0.0, 1.0, 0.0);
        self::$blue = new RTColor(0.0, 0.0, 1.0);
        self::$lightPos = new RTVector(0.7, -1.0, 1.7);
        self::$lightColor = new RTColor(1.0, 1.0, 1.0);

        self::$scene = [
            new RTSphere(new RTVector(-1.0, 0.0, 3.0), 0.3, self::$red),
            new RTSphere(new RTVector(0.0, 0.0, 3.0), 0.8, self::$green),
            new RTSphere(new RTVector(1.0, 0.0, 3.0), 0.4, self::$blue),
        ];
    }

    private function intersectSphere(RTVector $rayOrig, RTVector $rayDir, RTSphere $sphere): ?float
    {
        $l = $sphere->center->sub($rayOrig);
        $tca = $l->dot($rayDir);
        if ($tca < 0.0)
            return null;

        $d2 = $l->dot($l) - $tca * $tca;
        $r2 = $sphere->radius * $sphere->radius;
        if ($d2 > $r2)
            return null;

        $thc = sqrt($r2 - $d2);
        $t0 = $tca - $thc;

        if ($t0 > 10000)
            return null;

        return $t0;
    }

    private function clamp(float $x, float $a, float $b): float
    {
        if ($x < $a)
            return $a;
        if ($x > $b)
            return $b;
        return $x;
    }

    public function run(int $iteration_id): void
    {
        $res = 0;
        $fw = (float) $this->w;
        $fh = (float) $this->h;

        for ($j = 0; $j < $this->h; $j++) {
            for ($i = 0; $i < $this->w; $i++) {
                $fi = (float) $i;
                $fj = (float) $j;

                $rayOrig = new RTVector(0.0, 0.0, 0.0);
                $rayDir = (new RTVector(
                    ($fi - $fw / 2.0) / $fw,
                    ($fj - $fh / 2.0) / $fh,
                    1.0
                ))->normalize();

                $hitObj = null;
                $hitVal = null;

                foreach (self::$scene as $obj) {
                    $ret = $this->intersectSphere($rayOrig, $rayDir, $obj);
                    if ($ret !== null) {
                        $hitObj = $obj;
                        $hitVal = $ret;
                        break;
                    }
                }

                if ($hitObj !== null) {
                    $pi = $rayOrig->add($rayDir->scale($hitVal));
                    $n = $hitObj->getNormal($pi);
                    $lightDir = self::$lightPos->sub($pi)->normalize();

                    $lam1 = $lightDir->dot($n);
                    $lam2 = $this->clamp($lam1, 0.0, 1.0);

                    $color = self::$lightColor->scale($lam2 * 0.5)->add($hitObj->color->scale(0.3));

                    $col = ($color->r + $color->g + $color->b) / 3.0;
                    $idx = (int) ($col * 6.0);
                    if ($idx < 0)
                        $idx = 0;
                    if ($idx >= 6)
                        $idx = 5;

                    $pixel = self::LUT[$idx];
                } else {
                    $pixel = ' ';
                }

                $res = ($res + ord($pixel)) & 0xFFFFFFFF;
            }
        }

        $this->res = ($this->res + $res) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->res & 0xFFFFFFFF;
    }
}

class NNSynapse
{
    public NNNeuron $sourceNeuron;
    public NNNeuron $destNeuron;
    public float $weight;
    public float $prevWeight;

    public function __construct(NNNeuron $sourceNeuron, NNNeuron $destNeuron)
    {
        $this->sourceNeuron = $sourceNeuron;
        $this->destNeuron = $destNeuron;
        $this->weight = Helper::nextFloat() * 2 - 1;
        $this->prevWeight = $this->weight;
    }
}

class NNNeuron
{
    const LEARNING_RATE = 1.0;
    const MOMENTUM = 0.3;

    public float $threshold;
    public float $prevThreshold;
    public array $synapsesIn;
    public array $synapsesOut;
    public float $output;
    public float $error;

    public function __construct()
    {
        $t = Helper::nextFloat() * 2 - 1;
        $this->threshold = $t;
        $this->prevThreshold = $t;
        $this->synapsesIn = [];
        $this->synapsesOut = [];
        $this->output = 0.0;
        $this->error = 0.0;
    }

    public function calculateOutput(): void
    {
        $activation = 0.0;
        foreach ($this->synapsesIn as $synapse) {
            $activation += $synapse->weight * $synapse->sourceNeuron->output;
        }
        $activation -= $this->threshold;
        $this->output = 1.0 / (1.0 + exp(-$activation));
    }

    public function derivative(): float
    {
        return $this->output * (1.0 - $this->output);
    }

    public function outputTrain(float $rate, float $target): void
    {
        $this->error = ($target - $this->output) * $this->derivative();
        $this->updateWeights($rate);
    }

    public function hiddenTrain(float $rate): void
    {
        $errorSum = 0.0;
        foreach ($this->synapsesOut as $synapse) {
            $errorSum += $synapse->destNeuron->error * $synapse->prevWeight;
        }
        $this->error = $errorSum * $this->derivative();
        $this->updateWeights($rate);
    }

    private function updateWeights(float $rate): void
    {
        foreach ($this->synapsesIn as $synapse) {
            $tempWeight = $synapse->weight;
            $synapse->weight +=
                ($rate * self::LEARNING_RATE * $this->error * $synapse->sourceNeuron->output)
                + (self::MOMENTUM * ($synapse->weight - $synapse->prevWeight));
            $synapse->prevWeight = $tempWeight;
        }

        $tempThreshold = $this->threshold;
        $this->threshold +=
            ($rate * self::LEARNING_RATE * $this->error * -1.0)
            + (self::MOMENTUM * ($this->threshold - $this->prevThreshold));
        $this->prevThreshold = $tempThreshold;
    }
}

class NNNeuralNetwork
{
    public array $inputLayer;

    public array $hiddenLayer;

    public array $outputLayer;

    public function __construct(int $inputs, int $hidden, int $outputs)
    {
        $this->inputLayer = [];
        for ($i = 0; $i < $inputs; $i++) {
            $this->inputLayer[] = new NNNeuron();
        }

        $this->hiddenLayer = [];
        for ($i = 0; $i < $hidden; $i++) {
            $this->hiddenLayer[] = new NNNeuron();
        }

        $this->outputLayer = [];
        for ($i = 0; $i < $outputs; $i++) {
            $this->outputLayer[] = new NNNeuron();
        }

        foreach ($this->inputLayer as $source) {
            foreach ($this->hiddenLayer as $dest) {
                $synapse = new NNSynapse($source, $dest);
                $source->synapsesOut[] = $synapse;
                $dest->synapsesIn[] = $synapse;
            }
        }

        foreach ($this->hiddenLayer as $source) {
            foreach ($this->outputLayer as $dest) {
                $synapse = new NNSynapse($source, $dest);
                $source->synapsesOut[] = $synapse;
                $dest->synapsesIn[] = $synapse;
            }
        }
    }

    public function train(array $inputs, array $targets): void
    {
        $this->feedForward($inputs);

        foreach ($this->outputLayer as $i => $neuron) {
            $neuron->outputTrain(0.3, $targets[$i]);
        }

        foreach ($this->hiddenLayer as $neuron) {
            $neuron->hiddenTrain(0.3);
        }
    }

    public function feedForward(array $inputs): void
    {
        foreach ($this->inputLayer as $i => $neuron) {
            $neuron->output = $inputs[$i];
        }

        foreach ($this->hiddenLayer as $neuron) {
            $neuron->calculateOutput();
        }

        foreach ($this->outputLayer as $neuron) {
            $neuron->calculateOutput();
        }
    }

    public function currentOutputs(): array
    {
        $outputs = [];
        foreach ($this->outputLayer as $neuron) {
            $outputs[] = $neuron->output;
        }
        return $outputs;
    }
}

class EtcNeuralNet extends Benchmark
{
    private NNNeuralNetwork $xor;

    public function __construct()
    {
        $this->xor = new NNNeuralNetwork(0, 0, 0);
    }

    public function name(): string
    {
        return 'Etc::NeuralNet';
    }

    public function prepare(): void
    {
        $this->xor = new NNNeuralNetwork(2, 10, 1);
    }

    private const INPUT_00 = [0.0, 0.0];
    private const INPUT_01 = [0.0, 1.0];
    private const INPUT_10 = [1.0, 0.0];
    private const INPUT_11 = [1.0, 1.0];
    private const TARGET_0 = [0.0];
    private const TARGET_1 = [1.0];

    public function run(int $iteration_id): void
    {
        $xor = $this->xor;

        for ($k = 0; $k < 1000; $k++) {
            $xor->train(self::INPUT_00, self::TARGET_0);
            $xor->train(self::INPUT_10, self::TARGET_1);
            $xor->train(self::INPUT_01, self::TARGET_1);
            $xor->train(self::INPUT_11, self::TARGET_0);
        }
    }

    public function checksum(): int
    {
        $outputs = [];

        $this->xor->feedForward(self::INPUT_00);
        $outputs = array_merge($outputs, $this->xor->currentOutputs());

        $this->xor->feedForward(self::INPUT_01);
        $outputs = array_merge($outputs, $this->xor->currentOutputs());

        $this->xor->feedForward(self::INPUT_10);
        $outputs = array_merge($outputs, $this->xor->currentOutputs());

        $this->xor->feedForward(self::INPUT_11);
        $outputs = array_merge($outputs, $this->xor->currentOutputs());

        $total = array_sum($outputs);
        return Helper::checksumFloat($total);
    }
}

class CacheNode
{
    public string $key;
    public string $value;
    public ?CacheNode $prev;
    public ?CacheNode $next;

    public function __construct(string $key, string $value)
    {
        $this->key = $key;
        $this->value = $value;
        $this->prev = null;
        $this->next = null;
    }
}

class LRUCache
{
    private int $capacity;
    private array $cache;
    private ?CacheNode $head;
    private ?CacheNode $tail;
    private int $size;

    public function __construct(int $capacity)
    {
        $this->capacity = $capacity;
        $this->cache = [];
        $this->head = null;
        $this->tail = null;
        $this->size = 0;
    }

    public function get(string $key): ?string
    {
        $node = $this->cache[$key] ?? null;
        if ($node === null) {
            return null;
        }
        $this->moveToFront($node);
        return $node->value;
    }

    public function put(string $key, string $value): void
    {
        $node = $this->cache[$key] ?? null;
        if ($node !== null) {
            $node->value = $value;
            $this->moveToFront($node);
            return;
        }

        if ($this->size >= $this->capacity) {
            $this->removeOldest();
        }

        $node = new CacheNode($key, $value);
        $this->cache[$key] = $node;
        $this->addToFront($node);
        $this->size++;
    }

    public function getSize(): int
    {
        return $this->size;
    }

    private function moveToFront(CacheNode $node): void
    {
        if ($node === $this->head) {
            return;
        }

        if ($node->prev !== null) {
            $node->prev->next = $node->next;
        }
        if ($node->next !== null) {
            $node->next->prev = $node->prev;
        }

        if ($node === $this->tail) {
            $this->tail = $node->prev;
        }

        $node->prev = null;
        $node->next = $this->head;
        if ($this->head !== null) {
            $this->head->prev = $node;
        }
        $this->head = $node;

        if ($this->tail === null) {
            $this->tail = $node;
        }
    }

    private function addToFront(CacheNode $node): void
    {
        $node->next = $this->head;
        if ($this->head !== null) {
            $this->head->prev = $node;
        }
        $this->head = $node;
        if ($this->tail === null) {
            $this->tail = $node;
        }
    }

    private function removeOldest(): void
    {
        if ($this->tail === null) {
            return;
        }

        $oldest = $this->tail;
        unset($this->cache[$oldest->key]);

        if ($oldest->prev !== null) {
            $oldest->prev->next = null;
            $this->tail = $oldest->prev;
        } else {
            $this->head = null;
            $this->tail = null;
        }

        $this->size--;
    }
}

class EtcCacheSimulation extends Benchmark
{
    private int $valuesSize;
    private ?LRUCache $cache;
    private int $hits;
    private int $misses;
    private int $result;

    public function __construct()
    {
        $this->valuesSize = 0;
        $this->cache = null;
        $this->hits = 0;
        $this->misses = 0;
        $this->result = 5432;
    }

    public function name(): string
    {
        return 'Etc::CacheSimulation';
    }

    public function prepare(): void
    {
        $this->valuesSize = $this->configVal('values');
        $cacheSize = $this->configVal('size');
        $this->cache = new LRUCache($cacheSize);
        $this->hits = 0;
        $this->misses = 0;
        $this->result = 5432;
    }

    public function run(int $iteration_id): void
    {
        for ($i = 0; $i < 1000; $i++) {
            $key = 'item_' . Helper::nextInt($this->valuesSize);

            if ($this->cache->get($key) !== null) {
                $this->hits++;
                $this->cache->put($key, "updated_{$iteration_id}");
            } else {
                $this->misses++;
                $this->cache->put($key, "new_{$iteration_id}");
            }
        }
    }

    public function checksum(): int
    {
        $this->result = (($this->result << 5) + $this->hits) & 0xFFFFFFFF;
        $this->result = (($this->result << 5) + $this->misses) & 0xFFFFFFFF;
        $this->result = (($this->result << 5) + $this->cache->getSize()) & 0xFFFFFFFF;
        return $this->result & 0xFFFFFFFF;
    }
}

class GOLCell
{
    public bool $alive;

    public array $neighbors;

    private bool $nextState;

    public function __construct(bool $alive = false)
    {
        $this->alive = $alive;
        $this->neighbors = [];
        $this->nextState = false;
    }

    public function addNeighbor(GOLCell $cell): void
    {
        $this->neighbors[] = $cell;
    }

    public function computeNextState(): void
    {
        $aliveNeighbors = 0;
        foreach ($this->neighbors as $neighbor) {
            if ($neighbor->alive)
                $aliveNeighbors++;
        }

        $this->nextState = $this->alive
            ? ($aliveNeighbors === 2 || $aliveNeighbors === 3)
            : ($aliveNeighbors === 3);
    }

    public function update(): void
    {
        $this->alive = $this->nextState;
    }
}

class GOLGrid
{
    public int $width;
    public int $height;
    public array $cells;

    public function __construct(int $width, int $height)
    {
        $this->width = $width;
        $this->height = $height;
        $this->cells = [];

        for ($y = 0; $y < $height; $y++) {
            $row = [];
            for ($x = 0; $x < $width; $x++) {
                $row[] = new GOLCell();
            }
            $this->cells[] = $row;
        }

        $this->linkNeighbors();
    }

    private function linkNeighbors(): void
    {
        for ($y = 0; $y < $this->height; $y++) {
            for ($x = 0; $x < $this->width; $x++) {
                $cell = $this->cells[$y][$x];

                for ($dy = -1; $dy <= 1; $dy++) {
                    for ($dx = -1; $dx <= 1; $dx++) {
                        if ($dx === 0 && $dy === 0)
                            continue;

                        $ny = ($y + $dy + $this->height) % $this->height;
                        $nx = ($x + $dx + $this->width) % $this->width;

                        $cell->addNeighbor($this->cells[$ny][$nx]);
                    }
                }
            }
        }
    }

    public function nextGeneration(): void
    {
        foreach ($this->cells as $row) {
            foreach ($row as $cell) {
                $cell->computeNextState();
            }
        }

        foreach ($this->cells as $row) {
            foreach ($row as $cell) {
                $cell->update();
            }
        }
    }

    public function countAlive(): int
    {
        $count = 0;
        foreach ($this->cells as $row) {
            foreach ($row as $cell) {
                if ($cell->alive)
                    $count++;
            }
        }
        return $count;
    }

    public function computeHash(): int
    {
        $hash = 2166136261;
        $prime = 16777619;

        foreach ($this->cells as $row) {
            foreach ($row as $cell) {
                $alive = $cell->alive ? 1 : 0;
                $hash = (($hash ^ $alive) * $prime) & 0xFFFFFFFF;
            }
        }

        return $hash;
    }
}

class EtcGameOfLife extends Benchmark
{
    private int $width;
    private int $height;
    private GOLGrid $grid;

    public function __construct()
    {
        $this->width = $this->configVal('w');
        $this->height = $this->configVal('h');
        $this->grid = new GOLGrid($this->width, $this->height);
    }

    public function name(): string
    {
        return 'Etc::GameOfLife';
    }

    public function prepare(): void
    {
        Helper::reset();
        foreach ($this->grid->cells as $row) {
            foreach ($row as $cell) {
                if (Helper::nextFloat(1.0) < 0.1) {
                    $cell->alive = true;
                }
            }
        }
    }

    public function run(int $iteration_id): void
    {
        $this->grid->nextGeneration();
    }

    public function checksum(): int
    {
        return ($this->grid->computeHash() + $this->grid->countAlive()) & 0xFFFFFFFF;
    }
}

class EtcWords extends Benchmark
{
    private int $words;
    private int $wordLen;
    private string $text;
    private int $checksum_val;

    public function __construct()
    {
        $this->words = $this->configVal('words');
        $this->wordLen = $this->configVal('word_len');
        $this->text = '';
        $this->checksum_val = 0;
    }

    public function name(): string
    {
        return 'Etc::Words';
    }

    public function prepare(): void
    {
        $this->checksum_val = 0;

        $chars = range('a', 'z');
        $charsCount = 26;
        $this->text = '';
        Helper::reset();

        for ($i = 0; $i < $this->words; $i++) {
            $wlen = Helper::nextInt($this->wordLen) + Helper::nextInt(3) + 3;
            for ($j = 0; $j < $wlen; $j++) {
                $this->text .= $chars[Helper::nextInt($charsCount)];
            }
            if ($i !== $this->words - 1) {
                $this->text .= ' ';
            }
        }
    }

    public function run(int $iteration_id): void
    {
        $frequencies = [];
        foreach (explode(' ', $this->text) as $w) {
            $frequencies[$w] = ($frequencies[$w] ?? 0) + 1;
        }

        arsort($frequencies);
        $maxWord = array_key_first($frequencies);
        $maxCount = $frequencies[$maxWord];

        $this->checksum_val = ($this->checksum_val + $maxCount + Helper::checksum($maxWord) + count($frequencies)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->checksum_val & 0xFFFFFFFF;
    }
}

class EtcLogParser extends Benchmark
{
    private int $linesCount;
    private string $log;
    private int $checksum_val;
    private array $patterns;

    public function __construct()
    {
        $this->linesCount = $this->configVal('lines_count');
        $this->log = '';
        $this->checksum_val = 0;
        $this->patterns = [
            'errors' => '/ [5][0-9]{2} | [4][0-9]{2} /',
            'bots' => '/bot|crawler|scanner|spider|indexing|crawl|robot|spider/i',
            'suspicious' => '/etc\/passwd|wp-admin|\.\.\//i',
            'ips' => '/\d+\.\d+\.\d+\.35/',
            'api_calls' => '/\/api\/[^ "]+/',
            'post_requests' => '/POST [^ ]* HTTP/',
            'auth_attempts' => '/\/login|\/signin/i',
            'methods' => '/get|post|put/i',
            'emails' => '/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/',
            'passwords' => '/password=[^&\s"]+/',
            'tokens' => '/token=[^&\s"]+|api[_-]?key=[^&\s"]+/',
            'sessions' => '/session[_-]?id=[^&\s"]+/',
            'peak_hours' => '/\[\d+\/\w+\/\d+:1[3-7]:\d+:\d+ [+\-]\d+\]/',
        ];
    }

    public function name(): string
    {
        return 'Etc::LogParser';
    }

    public function prepare(): void
    {
        $this->checksum_val = 0;

        $ips = array_map(fn($i) => "192.168.1.{$i}", range(1, 255));
        $ipsCount = 255;
        $methods = ['GET', 'POST', 'PUT', 'DELETE'];
        $methodsCount = 4;
        $paths = ['/index.html', '/api/users', '/admin', '/images/logo.png', '/etc/passwd', '/wp-admin/setup.php'];
        $pathsCount = 6;
        $statuses = [200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503];
        $statusesCount = 11;
        $agents = ['Mozilla/5.0', 'Googlebot/2.1', 'curl/7.68.0', 'scanner/2.0'];
        $agentsCount = 4;
        $users = ['john', 'jane', 'alex', 'sarah', 'mike', 'anna', 'david', 'elena'];
        $usersCount = 8;
        $domains = ['example.com', 'gmail.com', 'yahoo.com', 'hotmail.com', 'company.org', 'mail.ru'];
        $domainsCount = 6;

        $this->log = '';
        for ($i = 0; $i < $this->linesCount; $i++) {
            $ip = $ips[$i % $ipsCount];
            $method = $methods[$i % $methodsCount];

            if ($i % 3 === 0) {
                $path = '/login?email=' . $users[$i % $usersCount] . ($i % 100) . '@' . $domains[$i % $domainsCount]
                    . '&password=secret' . ($i % 10000);
            } elseif ($i % 5 === 0) {
                $path = '/api/data?token=' . str_repeat('abcdef123456', ($i % 3) + 1);
            } elseif ($i % 7 === 0) {
                $path = '/user/profile?session_id=sess_' . dechex($i * 12345);
            } else {
                $path = $paths[$i % $pathsCount];
            }

            $status = $statuses[$i % $statusesCount];
            $agent = $agents[$i % $agentsCount];
            $ref = $domains[$i % $domainsCount];
            $day = $i % 31;
            $hour = ($i % 60);

            $this->log .= "{$ip} - - [{$day}/Oct/2023:{$hour}:55:36 +0000] \"{$method} {$path} HTTP/1.1\" {$status} 2326 \"http://{$ref}\" \"{$agent}\"\n";
        }
    }

    public function run(int $iteration_id): void
    {
        $matches = [];
        foreach ($this->patterns as $name => $regex) {
            $matches[$name] = preg_match_all($regex, $this->log);
        }
        $this->checksum_val = ($this->checksum_val + array_sum($matches)) & 0xFFFFFFFF;
    }

    public function checksum(): int
    {
        return $this->checksum_val & 0xFFFFFFFF;
    }
}

function main(int $argc, array $argv): int
{
    $now = (int) (microtime(true) * 1000);
    echo 'start: ' . $now . "\n";

    $configFile = '../run.js';
    if ($argc > 1) {
        $configFile = $argv[1];
        Config::load($argv[1]);
    } else {
        Config::load();
    }

    if ($argc > 2) {
        Benchmark::all($argv[2], $configFile);
    } else {
        Benchmark::all('', $configFile);
    }

    file_put_contents('/tmp/recompile_marker', 'RECOMPILE_MARKER_0');

    return 0;
}

if (php_sapi_name() === 'cli' && isset($argv)) {
    exit(main($argc, $argv));
}

?>