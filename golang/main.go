package main

import (
	"bufio"
	"bytes"
	"container/heap"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math"
	"math/big"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"runtime"
)

// ========== Глобальные переменные и утилиты ==========
var (
	INPUT  = make(map[string]string)
	EXPECT = make(map[string]int64)
)

const (
	IM   = int64(139968)
	IA   = int64(3877)
	IC   = int64(29573)
	INIT = int64(42)
)

func min(a int, b int) int {
	if a < b {
		return a
	} else {
		return b
	}
}

func max(a int, b int) int {
	if a > b {
		return a
	} else {
		return b
	}
}

type Helper struct{}

var (
	last   = INIT
	global = &last
)

func Reset() {
	last = INIT
}

func NextInt(max int) int {
	*global = (*global*IA + IC) % IM
	return int(float64(*global) / float64(IM) * float64(max))
}

func NextIntRange(from, to int) int {
	return NextInt(to-from+1) + from
}

func NextFloat(max float64) float64 {
	*global = (*global*IA + IC) % IM
	return max * float64(*global) / float64(IM)
}

// Добавь отладку в Helper.checksum или аналог:
func debugChecksum(v string) {
	if os.Getenv("DEBUG") == "1" {
		fmt.Printf("checksum: %q\n", v)
	}
}

func Checksum(v string) uint32 {
	// debugChecksum(v)
	hash := uint32(5381)
	for i := 0; i < len(v); i++ {
		hash = ((hash << 5) + hash) + uint32(v[i])
	}
	return hash
}

func ChecksumBytes(v []byte) uint32 {
	hash := uint32(5381)
	for _, b := range v {
		hash = ((hash << 5) + hash) + uint32(b)
	}
	return hash
}

func ChecksumFloat64(v float64) uint32 {
	return Checksum(fmt.Sprintf("%.7f", v))
}

func LoadConfig(filename string) {
	if filename == "" {
		filename = "../test.txt"
	}

	file, err := os.Open(filename)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}
		parts := strings.Split(line, "|")
		if len(parts) != 3 {
			continue
		}
		INPUT[parts[0]] = parts[1]
		val, _ := strconv.ParseInt(parts[2], 10, 64)
		EXPECT[parts[0]] = val
	}
}

func GetIterations(classname string) int {
	if val, ok := INPUT[classname]; ok {
		i, _ := strconv.Atoi(val)
		return int(i)
	} else {
		return 0
	}
}

// ========== Интерфейс и базовый класс ==========
type Benchmark interface {
	Run()
	Result() uint32
	Prepare()
	Iterations() int
}

func RunBenchmarks(singleBench string) {
	results := make(map[string]float64)
	summaryTime := 0.0
	ok := 0
	fails := 0

	// Список всех бенчмарков
	benchmarks := []struct {
		name  string
		bench Benchmark
	}{
		{"Pidigits", &Pidigits{}},
		{"Binarytrees", &Binarytrees{}},
		{"BrainfuckHashMap", &BrainfuckHashMap{}},
		{"BrainfuckRecursion", &BrainfuckRecursion{}},
		{"Fannkuchredux", &Fannkuchredux{}},
		{"Fasta", &Fasta{}},
		{"Knuckeotide", &Knuckeotide{}},
		{"Mandelbrot", &Mandelbrot{}},
		{"Matmul", &Matmul{}},
		{"Matmul4T", &Matmul4T{}},
		{"Matmul8T", &Matmul8T{}},
		{"Matmul16T", &Matmul16T{}},
		{"Nbody", &Nbody{}},
		{"RegexDna", &RegexDna{}},
		{"Revcomp", &Revcomp{}},
		{"Spectralnorm", &Spectralnorm{}},
		{"Base64Encode", &Base64Encode{}},
		{"Base64Decode", &Base64Decode{}},
		{"JsonGenerate", &JsonGenerate{n: GetIterations("JsonGenerate")}},
		{"JsonParseDom", &JsonParseDom{}},
		{"JsonParseMapping", &JsonParseMapping{}},
		{"Primes", &Primes{}},
		{"Noise", &Noise{}},
		{"TextRaytracer", &TextRaytracer{}},
		{"NeuralNet", &NeuralNet{}},
		{"SortQuick", &SortQuick{SortBenchmark{name: "SortQuick"}}},
		{"SortMerge", &SortMerge{SortBenchmark{name: "SortMerge"}}},
		{"SortSelf", &SortSelf{SortBenchmark{name: "SortSelf"}}},
		{"GraphPathBFS", &GraphPathBFS{GraphPathBenchmark{name: "GraphPathBFS"}}},
		{"GraphPathDFS", &GraphPathDFS{GraphPathBenchmark{name: "GraphPathDFS"}}},
		{"GraphPathDijkstra", &GraphPathDijkstra{GraphPathBenchmark{name: "GraphPathDijkstra"}}},
		{"BufferHashSHA256", &BufferHashSHA256{BufferHashBenchmark{name: "BufferHashSHA256"}}},
		{"BufferHashCRC32", &BufferHashCRC32{BufferHashBenchmark{name: "BufferHashCRC32"}}},
		{"CacheSimulation", &CacheSimulation{}},
		{"CalculatorAst", &CalculatorAst{n: GetIterations("CalculatorAst")}},
		{"CalculatorInterpreter", &CalculatorInterpreter{}},

		{"GameOfLife", &GameOfLife{}},
		{"MazeGenerator", &MazeGenerator{}},
		{"AStarPathfinder", &AStarPathfinder{}},
		{"Compression", &Compression{}},
	}

	for _, b := range benchmarks {
		if singleBench != "" && b.name != singleBench {
			continue
		}

		// Пропускаем исключенные бенчмарки
		if b.name == "SortBenchmark" || b.name == "BufferHashBenchmark" || b.name == "GraphPathBenchmark" {
			continue
		}

		fmt.Printf("%s: ", b.name)

		Reset()
		b.bench.Prepare()

		start := time.Now()
		b.bench.Run()
		elapsed := time.Since(start).Seconds()
		results[b.name] = elapsed

		// runtime.GC()
		// time.Sleep(10 * time.Millisecond)
		// runtime.GC()

		result := b.bench.Result()
		expected := uint32(EXPECT[b.name])

		if result == expected {
			fmt.Printf("OK ")
			ok++
		} else {
			fmt.Printf("ERR[actual=%d, expected=%d] ", result, expected)
			fails++
		}

		fmt.Printf("in %.3fs\n", elapsed)
		summaryTime += elapsed
	}

	// Сохраняем результаты
	jsonData, _ := json.Marshal(results)
	os.WriteFile("/tmp/results.js", jsonData, 0644)

	fmt.Printf("Summary: %.4fs, %d, %d, %d\n", summaryTime, ok+fails, ok, fails)

	os.WriteFile("/tmp/recompile_marker", []byte("RECOMPILE_MARKER_0"), 0644)
	if fails > 0 {
		os.Exit(1)
	}
}

// ========== Реализации бенчмарков ==========

// 1. Pidigits
type Pidigits struct {
	nn     int
	result strings.Builder
}

func (p *Pidigits) Prepare() {
	p.nn = GetIterations("Pidigits")
}

func (p *Pidigits) Iterations() int { return p.nn }

func (p *Pidigits) Run() {
	i := 0
	k := 0
	ns := big.NewInt(0)
	a := big.NewInt(0)
	t := big.NewInt(0)
	u := big.NewInt(0)
	k1 := 1
	n := big.NewInt(1)
	d := big.NewInt(1)

	for {
		k++
		t.Lsh(n, 1)
		n.Mul(n, big.NewInt(int64(k)))
		k1 += 2
		a.Add(a, t)
		a.Mul(a, big.NewInt(int64(k1)))
		d.Mul(d, big.NewInt(int64(k1)))

		if a.Cmp(n) >= 0 {
			temp := new(big.Int).Mul(n, big.NewInt(3))
			temp.Add(temp, a)
			t.QuoRem(temp, d, u)
			u.Add(u, n)

			if d.Cmp(u) > 0 {
				ns.Mul(ns, big.NewInt(10))
				ns.Add(ns, t)
				i++

				if i%10 == 0 {
					str := ns.String()
					if len(str) > 10 {
						str = str[len(str)-10:]
					}
					str = fmt.Sprintf("%010s", str)
					p.result.WriteString(fmt.Sprintf("%s\t:%d\n", str, i))
					ns.SetInt64(0)
				}
				if i >= p.nn {
					break
				}

				dt := new(big.Int).Mul(d, t)
				a.Sub(a, dt)
				a.Mul(a, big.NewInt(10))
				n.Mul(n, big.NewInt(10))
			}
		}
	}
}

func (p *Pidigits) Result() uint32 {
	return Checksum(p.result.String())
}

// 2. Binarytrees
type TreeNode struct {
	left  *TreeNode
	right *TreeNode
	item  int
}

func TreeNodeCreate(item, depth int) *TreeNode {
	return NewTreeNode(item, depth-1)
}

func NewTreeNode(item, depth int) *TreeNode {
	node := &TreeNode{item: item}
	if depth > 0 {
		node.left = NewTreeNode(2*item-1, depth-1)
		node.right = NewTreeNode(2*item, depth-1)
	}
	return node
}

func (t *TreeNode) Check() int {
	if t.left == nil || t.right == nil {
		return t.item
	}
	return t.left.Check() - t.right.Check() + t.item
}

type Binarytrees struct {
	n      int
	result int
}

func (b *Binarytrees) Prepare() {
	b.n = GetIterations("Binarytrees")
}

func (b *Binarytrees) Iterations() int { return b.n }

func (b *Binarytrees) Run() {
	minDepth := 4
	maxDepth := minDepth + 2
	if b.n > maxDepth {
		maxDepth = b.n
	}
	stretchDepth := maxDepth + 1

	b.result += TreeNodeCreate(0, stretchDepth).Check()

	for depth := minDepth; depth <= maxDepth; depth += 2 {
		iterations := 1 << (maxDepth - depth + minDepth)
		for i := 1; i <= iterations; i++ {
			b.result += TreeNodeCreate(i, depth).Check()
			b.result += TreeNodeCreate(-i, depth).Check()
		}
	}
}

func (b *Binarytrees) Result() uint32 {
	return uint32(b.result)
}

// 3. BrainfuckHashMap
type Tape struct {
	tape []int32
	pos  int32
}

func NewTape() *Tape {
	return &Tape{tape: []int32{0}, pos: 0}
}

func (t *Tape) Get() int32 {
	return t.tape[t.pos]
}

func (t *Tape) Inc() {
	t.tape[t.pos]++
}

func (t *Tape) Dec() {
	t.tape[t.pos]--
}

func (t *Tape) Advance() {
	t.pos++
	if t.pos >= int32(len(t.tape)) {
		t.tape = append(t.tape, 0)
	}
}

func (t *Tape) Devance() {
	if t.pos > 0 {
		t.pos--
	}
}

type Program struct {
	chars      []byte
	bracketMap map[int]int
}

func NewProgram(text string) *Program {
	chars := make([]byte, 0)
	bracketMap := make(map[int]int)
	leftStack := make([]int, 0)
	pc := 0

	for _, char := range text {
		if strings.ContainsRune("[]<>+-,.", char) {
			chars = append(chars, byte(char))
			if char == '[' {
				leftStack = append(leftStack, pc)
			} else if char == ']' && len(leftStack) > 0 {
				left := leftStack[len(leftStack)-1]
				leftStack = leftStack[:len(leftStack)-1]
				right := pc
				bracketMap[left] = right
				bracketMap[right] = left
			}
			pc++
		}
	}

	return &Program{chars: chars, bracketMap: bracketMap}
}

func (p *Program) Run() int64 {
	result := int64(0)
	tape := NewTape()
	pc := 0

	for pc < len(p.chars) {
		switch p.chars[pc] {
		case '+':
			tape.Inc()
		case '-':
			tape.Dec()
		case '>':
			tape.Advance()
		case '<':
			tape.Devance()
		case '[':
			if tape.Get() == 0 {
				pc = p.bracketMap[pc]
			}
		case ']':
			if tape.Get() != 0 {
				pc = p.bracketMap[pc]
			}
		case '.':
			result = (result << 2) + int64(tape.Get())
		}
		pc++
	}

	return result
}

type BrainfuckHashMap struct {
	text   string
	result int64
}

func (b *BrainfuckHashMap) Prepare() {
	b.text = INPUT["BrainfuckHashMap"]
}

func (b *BrainfuckHashMap) Iterations() int { return 0 }

func (b *BrainfuckHashMap) Run() {
	b.result = NewProgram(b.text).Run()
}

func (b *BrainfuckHashMap) Result() uint32 {
	return uint32(b.result)
}

// 4. BrainfuckRecursion
type Op interface{}

type IncOp struct{ val int32 }
type MoveOp struct{ val int32 }
type PrintOp struct{}
type LoopOp struct{ ops []Op }

type Program2 struct {
	ops    []Op
	result int64
}

func NewProgram2(code string) *Program2 {
	runes := []rune(code)
	i := 0
	ops := parseProgram(&i, runes)
	return &Program2{ops: ops}
}

func parseProgram(pos *int, runes []rune) []Op {
	res := make([]Op, 0)

	for *pos < len(runes) {
		c := runes[*pos]
		*pos++

		switch c {
		case '+':
			res = append(res, IncOp{val: 1})
		case '-':
			res = append(res, IncOp{val: -1})
		case '>':
			res = append(res, MoveOp{val: 1})
		case '<':
			res = append(res, MoveOp{val: -1})
		case '.':
			res = append(res, PrintOp{})
		case '[':
			loopOps := parseProgram(pos, runes)
			res = append(res, LoopOp{ops: loopOps})
		case ']':
			return res
		}
	}

	return res
}

func (p *Program2) Run() {
	tape := &Tape2{tape: []byte{0}}
	p.runOps(p.ops, tape)
}

func (p *Program2) runOps(ops []Op, tape *Tape2) {
	for _, op := range ops {
		switch o := op.(type) {
		case IncOp:
			tape.Inc(o.val)
		case MoveOp:
			tape.Move(o.val)
		case PrintOp:
			p.result = (p.result << 2) + int64(tape.Get())
		case LoopOp:
			for tape.Get() != 0 {
				p.runOps(o.ops, tape)
			}
		}
	}
}

type Tape2 struct {
	tape []byte
	pos  int32
}

func (t *Tape2) Get() byte {
	return t.tape[t.pos]
}

func (t *Tape2) Inc(x int32) {
	t.tape[t.pos] += byte(x)
}

func (t *Tape2) Move(x int32) {
	t.pos += x
	for t.pos >= int32(len(t.tape)) {
		t.tape = append(t.tape, 0)
	}
}

type BrainfuckRecursion struct {
	text   string
	result int64
}

func (b *BrainfuckRecursion) Prepare() {
	b.text = INPUT["BrainfuckRecursion"]
}

func (b *BrainfuckRecursion) Iterations() int { return 0 }

func (b *BrainfuckRecursion) Run() {
	program := NewProgram2(b.text)
	program.Run()
	b.result = program.result
}

func (b *BrainfuckRecursion) Result() uint32 {
	return uint32(b.result)
}

// 5. Fannkuchredux
type Fannkuchredux struct {
	n      int
	result int64
}

func (f *Fannkuchredux) Prepare() {
	f.n = GetIterations("Fannkuchredux")
}

func (f *Fannkuchredux) Iterations() int { return f.n }

func (f *Fannkuchredux) fannkuchredux(n int) (int, int) {
	perm1 := make([]int, n)
	for i := range perm1 {
		perm1[i] = i
	}

	perm := make([]int, n)
	count := make([]int, n)
	maxFlipsCount := 0
	permCount := 0
	checksum := 0
	r := n

	for {
		for r > 1 {
			count[r-1] = r
			r--
		}

		copy(perm, perm1)
		flipsCount := 0

		k := perm[0]
		for k != 0 {
			k2 := (k + 1) >> 1
			for i := 0; i < k2; i++ {
				j := k - i
				perm[i], perm[j] = perm[j], perm[i]
			}
			flipsCount++
			k = perm[0]
		}

		if flipsCount > maxFlipsCount {
			maxFlipsCount = flipsCount
		}

		if permCount%2 == 0 {
			checksum += flipsCount
		} else {
			checksum -= flipsCount
		}

		for {
			if r == n {
				return checksum, maxFlipsCount
			}

			perm0 := perm1[0]
			for i := 0; i < r; i++ {
				perm1[i], perm1[i+1] = perm1[i+1], perm1[i]
			}
			perm1[r] = perm0

			count[r]--
			if count[r] > 0 {
				break
			}
			r++
		}
		permCount++
	}
}

func (f *Fannkuchredux) Run() {
	a, b := f.fannkuchredux(f.n)
	f.result = int64(a)*100 + int64(b)
}

func (f *Fannkuchredux) Result() uint32 {
	return uint32(f.result)
}

// 6. Fasta
type Fasta struct {
	n      int
	result strings.Builder
}

func (f *Fasta) Prepare() {
	f.n = GetIterations("Fasta")
}

func (f *Fasta) Iterations() int { return f.n }

type Gene struct {
	char byte
	prob float64
}

func (f *Fasta) selectRandom(genelist []Gene) byte {
	r := NextFloat(1.0)
	if r < genelist[0].prob {
		return genelist[0].char
	}

	lo := 0
	hi := len(genelist) - 1

	for hi > lo+1 {
		i := (hi + lo) / 2
		if r < genelist[i].prob {
			hi = i
		} else {
			lo = i
		}
	}
	return genelist[hi].char
}

func (f *Fasta) makeRandomFasta(id, desc string, genelist []Gene, n int) {
	const LINE_LENGTH = 60

	f.result.WriteString(fmt.Sprintf(">%s %s\n", id, desc))
	todo := n

	for todo > 0 {
		m := LINE_LENGTH
		if todo < LINE_LENGTH {
			m = todo
		}

		buffer := make([]byte, m)
		for i := 0; i < m; i++ {
			buffer[i] = f.selectRandom(genelist)
		}
		f.result.Write(buffer)
		f.result.WriteByte('\n')
		todo -= LINE_LENGTH
	}
}

func (f *Fasta) makeRepeatFasta(id, desc, s string, n int) {
	const LINE_LENGTH = 60

	f.result.WriteString(fmt.Sprintf(">%s %s\n", id, desc))
	todo := n
	k := 0
	kn := len(s)

	for todo > 0 {
		m := LINE_LENGTH
		if todo < LINE_LENGTH {
			m = todo
		}

		for m >= kn-k {
			f.result.WriteString(s[k:])
			m -= kn - k
			k = 0
		}

		f.result.WriteString(s[k : k+m])
		f.result.WriteByte('\n')
		k += m
		todo -= LINE_LENGTH
	}
}

func (f *Fasta) Run() {
	iub := []Gene{
		{'a', 0.27}, {'c', 0.39}, {'g', 0.51}, {'t', 0.78}, {'B', 0.8}, {'D', 0.8200000000000001},
		{'H', 0.8400000000000001}, {'K', 0.8600000000000001}, {'M', 0.8800000000000001},
		{'N', 0.9000000000000001}, {'R', 0.9200000000000002}, {'S', 0.9400000000000002},
		{'V', 0.9600000000000002}, {'W', 0.9800000000000002}, {'Y', 1.0000000000000002},
	}

	homo := []Gene{
		{'a', 0.302954942668}, {'c', 0.5009432431601}, {'g', 0.6984905497992}, {'t', 1.0},
	}

	alu := "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

	f.makeRepeatFasta("ONE", "Homo sapiens alu", alu, f.n*2)
	f.makeRandomFasta("TWO", "IUB ambiguity codes", iub, f.n*3)
	f.makeRandomFasta("THREE", "Homo sapiens frequency", homo, f.n*5)
}

func (f *Fasta) Result() uint32 {
	return Checksum(f.result.String())
}

// 7. Knuckeotide
type Knuckeotide struct {
	seq    string
	result strings.Builder
}

func (k *Knuckeotide) Prepare() {
	if nstr, ok := INPUT["Knuckeotide"]; ok {
		n, _ := strconv.Atoi(nstr)
		f := &Fasta{}
		f.Prepare()
		f.n = n // because Fasta redefine it
		f.Run()
		res := f.result.String()

		seq := strings.Builder{}
		three := false

		for _, line := range strings.Split(res, "\n") {
			if strings.HasPrefix(line, ">THREE") {
				three = true
				continue
			}
			if three {
				seq.WriteString(strings.TrimSpace(line))
			}
		}
		k.seq = seq.String()
	}
}

func (k *Knuckeotide) Iterations() int { return 0 }

func (k *Knuckeotide) frequency(seq string, length int) (int, map[string]int) {
	n := len(seq) - length + 1
	table := make(map[string]int)

	for i := 0; i < n; i++ {
		sub := seq[i : i+length]
		table[sub]++
	}

	return n, table
}

func (k *Knuckeotide) sortByFreq(seq string, length int) {
	n, table := k.frequency(seq, length)

	type kv struct {
		key   string
		value int
	}

	pairs := make([]kv, 0, len(table))
	for k, v := range table {
		pairs = append(pairs, kv{k, v})
	}

	sort.Slice(pairs, func(i, j int) bool {
		if pairs[i].value == pairs[j].value {
			return pairs[i].key < pairs[j].key
		}
		return pairs[i].value > pairs[j].value
	})

	for _, pair := range pairs {
		percent := float64(pair.value*100) / float64(n)
		k.result.WriteString(fmt.Sprintf("%s %.3f\n", strings.ToUpper(pair.key), percent))
	}
	k.result.WriteByte('\n')
}

func (k *Knuckeotide) findSeq(seq, s string) {
	_, table := k.frequency(seq, len(s))
	count := table[strings.ToLower(s)]
	k.result.WriteString(fmt.Sprintf("%d\t%s\n", count, strings.ToUpper(s)))
}

func (k *Knuckeotide) Run() {
	for i := 1; i <= 2; i++ {
		k.sortByFreq(k.seq, i)
	}

	for _, s := range []string{"ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt"} {
		k.findSeq(k.seq, s)
	}
}

func (k *Knuckeotide) Result() uint32 {
	return Checksum(k.result.String())
}

// 8. Mandelbrot
type Mandelbrot struct {
	n      int
	result bytes.Buffer
}

func (m *Mandelbrot) Prepare() {
	m.n = GetIterations("Mandelbrot")
}

func (m *Mandelbrot) Iterations() int { return m.n }

func (m *Mandelbrot) Run() {
	const ITER = 50
	const LIMIT = 2.0

	w := m.n
	h := m.n

	m.result.WriteString(fmt.Sprintf("P4\n%d %d\n", w, h))

	bitNum := 0
	byteAcc := byte(0)

	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			zr, zi, tr, ti := 0.0, 0.0, 0.0, 0.0
			cr := 2.0*float64(x)/float64(w) - 1.5
			ci := 2.0*float64(y)/float64(h) - 1.0

			i := 0
			for i < ITER && tr+ti <= LIMIT*LIMIT {
				zi = 2.0*zr*zi + ci
				zr = tr - ti + cr
				tr = zr * zr
				ti = zi * zi
				i++
			}

			byteAcc <<= 1
			if tr+ti <= LIMIT*LIMIT {
				byteAcc |= 0x01
			}
			bitNum++

			if bitNum == 8 {
				m.result.WriteByte(byteAcc)
				byteAcc = 0
				bitNum = 0
			} else if x == w-1 {
				byteAcc <<= uint(8 - w%8)
				m.result.WriteByte(byteAcc)
				byteAcc = 0
				bitNum = 0
			}
		}
	}
}

func (m *Mandelbrot) Result() uint32 {
	return ChecksumBytes(m.result.Bytes())
}

// 9. Matmul
type Matmul struct {
	n      int
	result uint32
}

func (m *Matmul) Prepare() {
	m.n = GetIterations("Matmul")
}

func (m *Matmul) Iterations() int { return m.n }

func (m *Matmul) matgen(n int) [][]float64 {
	tmp := 1.0 / float64(n) / float64(n)
	a := make([][]float64, n)
	for i := range a {
		a[i] = make([]float64, n)
		for j := range a[i] {
			a[i][j] = tmp * float64(i-j) * float64(i+j)
		}
	}
	return a
}

func (m *Matmul) matmul(a, b [][]float64) [][]float64 {
	mSize := len(a)
	n := len(a[0])
	p := len(b[0])

	b2 := make([][]float64, n)
	for i := range b2 {
		b2[i] = make([]float64, p)
		for j := range b2[i] {
			b2[i][j] = b[j][i]
		}
	}

	c := make([][]float64, mSize)
	for i := range c {
		c[i] = make([]float64, p)
		ai := a[i]
		for j := range c[i] {
			s := 0.0
			b2j := b2[j]
			for k := range b2j {
				s += ai[k] * b2j[k]
			}
			c[i][j] = s
		}
	}
	return c
}

func (m *Matmul) Run() {
	a := m.matgen(m.n)
	b := m.matgen(m.n)
	c := m.matmul(a, b)
	m.result = ChecksumFloat64(c[m.n>>1][m.n>>1])
}

func (m *Matmul) Result() uint32 {
	return m.result
}

type Matmul4T struct {
	n      int
	result uint32
}

func (m *Matmul4T) Prepare() {
	m.n = GetIterations("Matmul4T")
}

func (m *Matmul4T) Iterations() int { return m.n }

func (m *Matmul4T) matgen(n int) [][]float64 {
	tmp := 1.0 / float64(n) / float64(n)
	a := make([][]float64, n)
	for i := range a {
		a[i] = make([]float64, n)
		for j := range a[i] {
			a[i][j] = tmp * float64(i-j) * float64(i+j)
		}
	}
	return a
}

func (m *Matmul4T) matmulParallel(a, b [][]float64) [][]float64 {
	size := len(a)

	// Транспонируем b
	bT := make([][]float64, size)
	for i := range bT {
		bT[i] = make([]float64, size)
		for j := 0; j < size; j++ {
			bT[i][j] = b[j][i]
		}
	}

	// Умножение матриц
	c := make([][]float64, size)
	for i := range c {
		c[i] = make([]float64, size)
	}

	// Явно устанавливаем GOMAXPROCS
	runtime.GOMAXPROCS(4)

	var wg sync.WaitGroup
	numWorkers := 4
	// rowsPerWorker := (size + numWorkers - 1) / numWorkers

	// Используем канал для распределения работы
	workCh := make(chan int, size)

	// Запускаем воркеров
	for w := 0; w < numWorkers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()

			for i := range workCh {
				ai := a[i]
				ci := c[i]

				for j := 0; j < size; j++ {
					sum := 0.0
					bTj := bT[j]

					for k := 0; k < size; k++ {
						sum += ai[k] * bTj[k]
					}

					ci[j] = sum
				}
			}
		}()
	}

	// Отправляем работу
	for i := 0; i < size; i++ {
		workCh <- i
	}
	close(workCh)

	wg.Wait()
	return c
}

func (m *Matmul4T) Run() {
	a := m.matgen(m.n)
	b := m.matgen(m.n)
	c := m.matmulParallel(a, b)
	m.result = ChecksumFloat64(c[m.n>>1][m.n>>1])
}

func (m *Matmul4T) Result() uint32 {
	return m.result
}

// ----------- Matmul8t ----------------------

type Matmul8T struct {
	n      int
	result uint32
}

func (m *Matmul8T) Prepare() {
	m.n = GetIterations("Matmul8T")
}

func (m *Matmul8T) Iterations() int { return m.n }

func (m *Matmul8T) matgen(n int) [][]float64 {
	tmp := 1.0 / float64(n) / float64(n)
	a := make([][]float64, n)
	for i := range a {
		a[i] = make([]float64, n)
		for j := range a[i] {
			a[i][j] = tmp * float64(i-j) * float64(i+j)
		}
	}
	return a
}

func (m *Matmul8T) matmulParallel(a, b [][]float64) [][]float64 {
	size := len(a)

	// Транспонируем b
	bT := make([][]float64, size)
	for i := range bT {
		bT[i] = make([]float64, size)
		for j := 0; j < size; j++ {
			bT[i][j] = b[j][i]
		}
	}

	// Умножение матриц
	c := make([][]float64, size)
	for i := range c {
		c[i] = make([]float64, size)
	}

	// Явно устанавливаем GOMAXPROCS
	runtime.GOMAXPROCS(8)

	var wg sync.WaitGroup
	numWorkers := 8
	// rowsPerWorker := (size + numWorkers - 1) / numWorkers

	// Используем канал для распределения работы
	workCh := make(chan int, size)

	// Запускаем воркеров
	for w := 0; w < numWorkers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()

			for i := range workCh {
				ai := a[i]
				ci := c[i]

				for j := 0; j < size; j++ {
					sum := 0.0
					bTj := bT[j]

					for k := 0; k < size; k++ {
						sum += ai[k] * bTj[k]
					}

					ci[j] = sum
				}
			}
		}()
	}

	// Отправляем работу
	for i := 0; i < size; i++ {
		workCh <- i
	}
	close(workCh)

	wg.Wait()
	return c
}

func (m *Matmul8T) Run() {
	a := m.matgen(m.n)
	b := m.matgen(m.n)
	c := m.matmulParallel(a, b)
	m.result = ChecksumFloat64(c[m.n>>1][m.n>>1])
}

func (m *Matmul8T) Result() uint32 {
	return m.result
}

// ------------------- Matmul 16 ----------------

type Matmul16T struct {
	n      int
	result uint32
}

func (m *Matmul16T) Prepare() {
	m.n = GetIterations("Matmul16T")
}

func (m *Matmul16T) Iterations() int { return m.n }

func (m *Matmul16T) matgen(n int) [][]float64 {
	tmp := 1.0 / float64(n) / float64(n)
	a := make([][]float64, n)
	for i := range a {
		a[i] = make([]float64, n)
		for j := range a[i] {
			a[i][j] = tmp * float64(i-j) * float64(i+j)
		}
	}
	return a
}

func (m *Matmul16T) matmulParallel(a, b [][]float64) [][]float64 {
	size := len(a)

	// Транспонируем b
	bT := make([][]float64, size)
	for i := range bT {
		bT[i] = make([]float64, size)
		for j := 0; j < size; j++ {
			bT[i][j] = b[j][i]
		}
	}

	// Умножение матриц
	c := make([][]float64, size)
	for i := range c {
		c[i] = make([]float64, size)
	}

	// Явно устанавливаем GOMAXPROCS
	runtime.GOMAXPROCS(16)

	var wg sync.WaitGroup
	numWorkers := 16
	// rowsPerWorker := (size + numWorkers - 1) / numWorkers

	// Используем канал для распределения работы
	workCh := make(chan int, size)

	// Запускаем воркеров
	for w := 0; w < numWorkers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()

			for i := range workCh {
				ai := a[i]
				ci := c[i]

				for j := 0; j < size; j++ {
					sum := 0.0
					bTj := bT[j]

					for k := 0; k < size; k++ {
						sum += ai[k] * bTj[k]
					}

					ci[j] = sum
				}
			}
		}()
	}

	// Отправляем работу
	for i := 0; i < size; i++ {
		workCh <- i
	}
	close(workCh)

	wg.Wait()
	return c
}

func (m *Matmul16T) Run() {
	a := m.matgen(m.n)
	b := m.matgen(m.n)
	c := m.matmulParallel(a, b)
	m.result = ChecksumFloat64(c[m.n>>1][m.n>>1])
}

func (m *Matmul16T) Result() uint32 {
	return m.result
}


// 10. Nbody
type Planet struct {
	x, y, z    float64
	vx, vy, vz float64
	mass       float64
}

func NewPlanet(x, y, z, vx, vy, vz, mass float64) *Planet {
	return &Planet{
		x: x, y: y, z: z,
		vx:   vx * 365.24,
		vy:   vy * 365.24,
		vz:   vz * 365.24,
		mass: mass * 4 * math.Pi * math.Pi,
	}
}

func (p *Planet) MoveFromI(bodies []*Planet, nbodies int, dt float64, start int) {
	for i := start; i < nbodies; i++ {
		b2 := bodies[i]
		dx := p.x - b2.x
		dy := p.y - b2.y
		dz := p.z - b2.z

		distance := math.Sqrt(dx*dx + dy*dy + dz*dz)
		mag := dt / (distance * distance * distance)
		bMassMag := p.mass * mag
		b2MassMag := b2.mass * mag

		p.vx -= dx * b2MassMag
		p.vy -= dy * b2MassMag
		p.vz -= dz * b2MassMag
		b2.vx += dx * bMassMag
		b2.vy += dy * bMassMag
		b2.vz += dz * bMassMag
	}

	p.x += dt * p.vx
	p.y += dt * p.vy
	p.z += dt * p.vz
}

type Nbody struct {
	n      int
	result uint32
	body   []*Planet
}

func (n *Nbody) Prepare() {
	n.n = GetIterations("Nbody")

	n.body = []*Planet{
		NewPlanet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
		NewPlanet(
			4.84143144246472090e+00,
			-1.16032004402742839e+00,
			-1.03622044471123109e-01,
			1.66007664274403694e-03,
			7.69901118419740425e-03,
			-6.90460016972063023e-05,
			9.54791938424326609e-04,
		),
		NewPlanet(
			8.34336671824457987e+00,
			4.12479856412430479e+00,
			-4.03523417114321381e-01,
			-2.76742510726862411e-03,
			4.99852801234917238e-03,
			2.30417297573763929e-05,
			2.85885980666130812e-04,
		),
		NewPlanet(
			1.28943695621391310e+01,
			-1.51111514016986312e+01,
			-2.23307578892655734e-01,
			2.96460137564761618e-03,
			2.37847173959480950e-03,
			-2.96589568540237556e-05,
			4.36624404335156298e-05,
		),
		NewPlanet(
			1.53796971148509165e+01,
			-2.59193146099879641e+01,
			1.79258772950371181e-01,
			2.68067772490389322e-03,
			1.62824170038242295e-03,
			-9.51592254519715870e-05,
			5.15138902046611451e-05,
		),
	}
}

func (n *Nbody) Iterations() int { return n.n }

func (n *Nbody) offsetMomentum() {
	px, py, pz := 0.0, 0.0, 0.0

	for _, b := range n.body {
		px += b.vx * b.mass
		py += b.vy * b.mass
		pz += b.vz * b.mass
	}

	b := n.body[0]
	b.vx = -px / (4 * math.Pi * math.Pi)
	b.vy = -py / (4 * math.Pi * math.Pi)
	b.vz = -pz / (4 * math.Pi * math.Pi)
}

func (n *Nbody) energy() float64 {
	e := 0.0
	nbodies := len(n.body)

	for i := 0; i < nbodies; i++ {
		b := n.body[i]
		e += 0.5 * b.mass * (b.vx*b.vx + b.vy*b.vy + b.vz*b.vz)
		for j := i + 1; j < nbodies; j++ {
			b2 := n.body[j]
			dx := b.x - b2.x
			dy := b.y - b2.y
			dz := b.z - b2.z
			distance := math.Sqrt(dx*dx + dy*dy + dz*dz)
			e -= (b.mass * b2.mass) / distance
		}
	}
	return e
}

func (n *Nbody) Run() {
	n.offsetMomentum()
	v1 := n.energy()

	nbodies := len(n.body)
	dt := 0.01

	for i := 0; i < n.n; i++ {
		for j := 0; j < nbodies; j++ {
			n.body[j].MoveFromI(n.body, nbodies, dt, j+1)
		}
	}

	v2 := n.energy()
	n.result = ChecksumFloat64(v1) << 5 & ChecksumFloat64(v2)
}

func (n *Nbody) Result() uint32 {
	return n.result
}

// 11. RegexDna
type RegexDna struct {
	seq    string
	ilen   int
	clen   int
	result strings.Builder
}

func (r *RegexDna) Prepare() {
	if nstr, ok := INPUT["RegexDna"]; ok {
		n, _ := strconv.Atoi(nstr)
		f := &Fasta{}
		f.Prepare()
		f.n = n // because Fasta redefine it
		f.Run()
		res := f.result.String()

		seq := strings.Builder{}
		r.ilen = 0

		for _, line := range strings.Split(res, "\n") {
			if line == "" {
				continue
			}
			r.ilen += len(line) + 1
			if !strings.HasPrefix(line, ">") {
				seq.WriteString(strings.TrimSpace(line))
			}
		}

		r.seq = seq.String()
		r.clen = len(r.seq)
	}
}

func (r *RegexDna) Iterations() int { return 0 }

func (r *RegexDna) Run() {
	patterns := []string{
		"agggtaaa|tttaccct",
		"[cgt]gggtaaa|tttaccc[acg]",
		"a[act]ggtaaa|tttacc[agt]t",
		"ag[act]gtaaa|tttac[agt]ct",
		"agg[act]taaa|ttta[agt]cct",
		"aggg[acg]aaa|ttt[cgt]ccct",
		"agggt[cgt]aa|tt[acg]accct",
		"agggta[cgt]a|t[acg]taccct",
		"agggtaa[cgt]|[acg]ttaccct",
	}

	for _, pattern := range patterns {
		count := 0
		re := regexp.MustCompile(pattern)
		matches := re.FindAllStringIndex(r.seq, -1)
		count = len(matches)
		r.result.WriteString(fmt.Sprintf("%s %d\n", pattern, count))
	}

	replacer := strings.NewReplacer(
		"B", "(c|g|t)",
		"D", "(a|g|t)",
		"H", "(a|c|t)",
		"K", "(g|t)",
		"M", "(a|c)",
		"N", "(a|c|g|t)",
		"R", "(a|g)",
		"S", "(c|t)",
		"V", "(a|c|g)",
		"W", "(a|t)",
		"Y", "(c|t)",
	)

	seq2 := replacer.Replace(r.seq)
	r.result.WriteString(fmt.Sprintf("\n%d\n%d\n%d\n", r.ilen, r.clen, len(seq2)))
}

func (r *RegexDna) Result() uint32 {
	return Checksum(r.result.String())
}

// 12. Revcomp
type Revcomp struct {
	input  string
	result strings.Builder
}

func (r *Revcomp) Prepare() {
	if nstr, ok := INPUT["Revcomp"]; ok {
		n, _ := strconv.Atoi(nstr)
		f := &Fasta{}
		f.Prepare()
		f.n = n // because Fasta redefine it
		f.Run()
		r.input = f.result.String()
	}
}

func (r *Revcomp) Iterations() int { return 0 }

func (r *Revcomp) revcomp(seq string) {
	runes := []rune(seq)
	for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
		runes[i], runes[j] = runes[j], runes[i]
	}

	complement := map[rune]rune{
		'w': 'W', 's': 'S', 'a': 'T', 't': 'A', 'u': 'A',
		'g': 'C', 'c': 'G', 'y': 'R', 'r': 'Y', 'k': 'M',
		'm': 'K', 'b': 'V', 'd': 'H', 'h': 'D', 'v': 'B',
		'n': 'N',
		'A': 'T', 'T': 'A', 'U': 'A', 'G': 'C', 'C': 'G',
		'Y': 'R', 'R': 'Y', 'K': 'M', 'M': 'K', 'B': 'V',
		'D': 'H', 'H': 'D', 'V': 'B', 'N': 'N',
		'W': 'W', 'S': 'S',
	}

	for i, ch := range runes {
		if comp, ok := complement[ch]; ok {
			runes[i] = comp
		}
	}

	result := string(runes)
	for i := 0; i < len(result); i += 60 {
		end := i + 60
		if end > len(result) {
			end = len(result)
		}
		r.result.WriteString(result[i:end])
		r.result.WriteByte('\n')
	}
}

func (r *Revcomp) Run() {
	seq := strings.Builder{}
	lines := strings.Split(r.input, "\n")

	for i := 0; i < len(lines); i++ {
		line := lines[i]
		if strings.HasPrefix(line, ">") {
			if seq.Len() > 0 {
				r.revcomp(seq.String())
				seq.Reset()
			}
			r.result.WriteString(line)
			r.result.WriteByte('\n')
		} else {
			seq.WriteString(strings.TrimSpace(line))
		}
	}

	if seq.Len() > 0 {
		r.revcomp(seq.String())
	}
}

func (r *Revcomp) Result() uint32 {
	return Checksum(r.result.String())
}

// 13. Spectralnorm
type Spectralnorm struct {
	n      int
	result uint32
}

func (s *Spectralnorm) Prepare() {
	s.n = GetIterations("Spectralnorm")
}

func (s *Spectralnorm) Iterations() int { return s.n }

func (s *Spectralnorm) evalA(i, j int) float64 {
	return 1.0 / (float64((i+j)*(i+j+1))/2.0 + float64(i) + 1.0)
}

func (s *Spectralnorm) evalA_times_u(u []float64) []float64 {
	n := len(u)
	v := make([]float64, n)

	for i := 0; i < n; i++ {
		sum := 0.0
		for j := 0; j < n; j++ {
			sum += s.evalA(i, j) * u[j]
		}
		v[i] = sum
	}
	return v
}

func (s *Spectralnorm) evalAt_times_u(u []float64) []float64 {
	n := len(u)
	v := make([]float64, n)

	for i := 0; i < n; i++ {
		sum := 0.0
		for j := 0; j < n; j++ {
			sum += s.evalA(j, i) * u[j]
		}
		v[i] = sum
	}
	return v
}

func (s *Spectralnorm) evalAtA_times_u(u []float64) []float64 {
	return s.evalAt_times_u(s.evalA_times_u(u))
}

func (s *Spectralnorm) Run() {
	u := make([]float64, s.n)
	for i := range u {
		u[i] = 1.0
	}
	v := make([]float64, s.n)

	for i := 0; i < 10; i++ {
		v = s.evalAtA_times_u(u)
		u = s.evalAtA_times_u(v)
	}

	vBv := 0.0
	vv := 0.0
	for i := 0; i < s.n; i++ {
		vBv += u[i] * v[i]
		vv += v[i] * v[i]
	}

	s.result = ChecksumFloat64(math.Sqrt(vBv / vv))
}

func (s *Spectralnorm) Result() uint32 {
	return s.result
}

// 15. Base64Encode
type Base64Encode struct {
	n      int
	str    string
	str2   string
	result uint32
}

func (b *Base64Encode) Prepare() {
	b.n = GetIterations("Base64Encode")
	b.str = strings.Repeat("a", b.n)
	b.str2 = base64.StdEncoding.EncodeToString([]byte(b.str))
}

func (b *Base64Encode) Iterations() int { return b.n }

func (b *Base64Encode) Run() {
	const TRIES = 8192
	sEncoded := 0

	for i := 0; i < TRIES; i++ {
		encoded := base64.StdEncoding.EncodeToString([]byte(b.str))
		sEncoded += len(encoded)
	}

	resultStr := fmt.Sprintf("encode %s... to %s...: %d\n",
		b.str[:min(4, len(b.str))],
		b.str2[:min(4, len(b.str2))],
		sEncoded)

	b.result = Checksum(resultStr)
}

func (b *Base64Encode) Result() uint32 {
	return b.result
}

// 16. Base64Decode
type Base64Decode struct {
	n      int
	str    string
	str2   string
	str3   []byte
	result uint32
}

func (b *Base64Decode) Prepare() {
	b.n = GetIterations("Base64Decode")
	b.str = strings.Repeat("a", b.n)
	b.str2 = base64.StdEncoding.EncodeToString([]byte(b.str))
	b.str3, _ = base64.StdEncoding.DecodeString(b.str2)
}

func (b *Base64Decode) Iterations() int { return b.n }

func (b *Base64Decode) Run() {
	const TRIES = 8192
	sDecoded := 0

	for i := 0; i < TRIES; i++ {
		decoded, _ := base64.StdEncoding.DecodeString(b.str2)
		sDecoded += len(decoded)
	}

	resultStr := fmt.Sprintf("decode %s... to %s...: %d\n",
		b.str2[:min(4, len(b.str2))],
		b.str3[:min(4, len(b.str3))],
		sDecoded)

	b.result = Checksum(resultStr)
}

func (b *Base64Decode) Result() uint32 {
	return b.result
}

// Primes

type Primes struct {
	n      int
	result uint32
}

func (p *Primes) Prepare() {
	p.n = GetIterations("Primes")
}

func (p *Primes) Iterations() int { return p.n }

// Оптимизированная структура Node
type Node struct {
	children [10]*Node // Массив вместо map
	terminal bool
}

// Оптимизированное решето Эратосфена
func generatePrimes(limit int) []int {
	if limit < 2 {
		return nil
	}

	// Используем []byte вместо []bool для лучшей производительности
	isPrime := make([]byte, limit+1)
	for i := 2; i <= limit; i++ {
		isPrime[i] = 1
	}

	sqrtLimit := int(math.Sqrt(float64(limit)))

	// Классическое решето Эратосфена
	for p := 2; p <= sqrtLimit; p++ {
		if isPrime[p] == 1 {
			for multiple := p * p; multiple <= limit; multiple += p {
				isPrime[multiple] = 0
			}
		}
	}

	// Предварительное выделение с оценкой количества простых чисел
	estimatedCount := 0
	if limit > 1000 {
		estimatedCount = int(float64(limit) / (math.Log(float64(limit)) - 1.1))
	}
	if estimatedCount < 1000 {
		estimatedCount = 1000
	}

	primes := make([]int, 0, estimatedCount)

	// Добавляем 2 отдельно
	if limit >= 2 {
		primes = append(primes, 2)
	}

	// Только нечетные числа
	for p := 3; p <= limit; p += 2 {
		if isPrime[p] == 1 {
			primes = append(primes, p)
		}
	}

	return primes
}

// Быстрое построение trie
func buildTrie(primes []int) *Node {
	root := &Node{}

	// Временный буфер для цифр
	digits := make([]byte, 0, 12)

	for _, prime := range primes {
		node := root

		// Быстрое преобразование числа в цифры
		digits = digits[:0]
		temp := prime
		for temp > 0 {
			digits = append(digits, byte('0'+(temp%10)))
			temp /= 10
		}

		// Вставляем цифры в обратном порядке
		for i := len(digits) - 1; i >= 0; i-- {
			digit := int(digits[i] - '0')

			if node.children[digit] == nil {
				node.children[digit] = &Node{}
			}
			node = node.children[digit]
		}
		node.terminal = true
	}

	return root
}

// BFS поиск (быстрее чем DFS в стеке)
func findWithPrefix(trie *Node, prefix int) []int {
	// Находим узел префикса
	node := trie

	// Разбираем префикс на цифры
	prefixDigits := make([]int, 0, 12)
	prefixValue := 0
	temp := prefix

	for temp > 0 {
		prefixDigits = append(prefixDigits, temp%10)
		temp /= 10
	}

	// Переходим от старшей цифры к младшей
	for i := len(prefixDigits) - 1; i >= 0; i-- {
		digit := prefixDigits[i]
		prefixValue = prefixValue*10 + digit

		if node.children[digit] == nil {
			return nil
		}
		node = node.children[digit]
	}

	// BFS поиск
	results := make([]int, 0, 10000)
	type queueItem struct {
		node   *Node
		number int
	}

	queue := make([]queueItem, 0, 10000)
	queue = append(queue, queueItem{node, prefixValue})

	for front := 0; front < len(queue); front++ {
		current := queue[front]

		if current.node.terminal {
			results = append(results, current.number)
		}

		// Проверяем все цифры 0-9
		for digit := 0; digit < 10; digit++ {
			if child := current.node.children[digit]; child != nil {
				queue = append(queue, queueItem{
					node:   child,
					number: current.number*10 + digit,
				})
			}
		}
	}

	// Сортировка (вставками для небольших массивов)
	for i := 1; i < len(results); i++ {
		key := results[i]
		j := i - 1

		for j >= 0 && results[j] > key {
			results[j+1] = results[j]
			j--
		}
		results[j+1] = key
	}

	return results
}

func (p *Primes) Run() {
	const PREFIX = 32338

	// 1. Генерация простых чисел
	primes := generatePrimes(p.n)

	// 2. Построение префиксного дерева
	trie := buildTrie(primes)

	// 3. Поиск по префиксу
	results := findWithPrefix(trie, PREFIX)

	// 4. Вычисление результата
	p.result = 5432
	p.result += uint32(len(results))

	for _, r := range results {
		p.result += uint32(r)
	}
}

func (p *Primes) Result() uint32 {
	return p.result
}

// 18. JsonGenerate
type Coordinate struct {
	X    float64                   `json:"x"`
	Y    float64                   `json:"y"`
	Z    float64                   `json:"z"`
	Name string                    `json:"name"`
	Opts map[string][2]interface{} `json:"opts"`
}

type JsonGenerate struct {
	n    int
	data []Coordinate
	text strings.Builder
}

func (j *JsonGenerate) Prepare() {
	j.data = make([]Coordinate, j.n)
	for i := 0; i < j.n; i++ {
		j.data[i] = Coordinate{
			X:    round(NextFloat(1.0), 8),
			Y:    round(NextFloat(1.0), 8),
			Z:    round(NextFloat(1.0), 8),
			Name: fmt.Sprintf("%.7f %d", NextFloat(1.0), NextInt(10000)),
			Opts: map[string][2]interface{}{
				"1": {1, true},
			},
		}
	}
}

func round(val float64, precision int) float64 {
	ratio := math.Pow(10, float64(precision))
	return math.Round(val*ratio) / ratio
}

func (j *JsonGenerate) Iterations() int { return j.n }

func (j *JsonGenerate) Run() {
	type Response struct {
		Coordinates []Coordinate `json:"coordinates"`
		Info        string       `json:"info"`
	}

	resp := Response{
		Coordinates: j.data,
		Info:        "some info",
	}

	data, _ := json.Marshal(resp)
	j.text.Write(data)
}

func (j *JsonGenerate) Result() uint32 {
	return 1
}

// 19. JsonParseDom
type JsonParseDom struct {
	text   string
	result uint32
}

func (j *JsonParseDom) Prepare() {
	gen := &JsonGenerate{n: GetIterations("JsonParseDom")}
	gen.Prepare()
	gen.Run()
	j.text = gen.text.String()
}

func (j *JsonParseDom) Iterations() int { return 0 }

func (j *JsonParseDom) calc(text string) (float64, float64, float64) {
	var data map[string]interface{}
	json.Unmarshal([]byte(text), &data)

	coordinates := data["coordinates"].([]interface{})
	length := float64(len(coordinates))
	x, y, z := 0.0, 0.0, 0.0

	for _, coord := range coordinates {
		c := coord.(map[string]interface{})
		x += c["x"].(float64)
		y += c["y"].(float64)
		z += c["z"].(float64)
	}

	return x / length, y / length, z / length
}

func (j *JsonParseDom) Run() {
	x, y, z := j.calc(j.text)
	j.result = ChecksumFloat64(x) + ChecksumFloat64(y) + ChecksumFloat64(z)
}

func (j *JsonParseDom) Result() uint32 {
	return j.result
}

// 20. JsonParseMapping
type JsonParseMapping struct {
	text   string
	result uint32
}

func (j *JsonParseMapping) Prepare() {
	gen := &JsonGenerate{n: GetIterations("JsonParseMapping")}
	gen.Prepare()
	gen.Run()
	j.text = gen.text.String()
}

func (j *JsonParseMapping) Iterations() int { return 0 }

func (j *JsonParseMapping) calc(text string) (float64, float64, float64) {
	var data struct {
		Coordinates []struct {
			X float64 `json:"x"`
			Y float64 `json:"y"`
			Z float64 `json:"z"`
		} `json:"coordinates"`
	}

	json.Unmarshal([]byte(text), &data)

	length := float64(len(data.Coordinates))
	x, y, z := 0.0, 0.0, 0.0

	for _, coord := range data.Coordinates {
		x += coord.X
		y += coord.Y
		z += coord.Z
	}

	return x / length, y / length, z / length
}

func (j *JsonParseMapping) Run() {
	x, y, z := j.calc(j.text)
	j.result = ChecksumFloat64(x) + ChecksumFloat64(y) + ChecksumFloat64(z)
}

func (j *JsonParseMapping) Result() uint32 {
	return j.result
}

// 21. Noise
type Vec2 struct {
	X, Y float64
}

type Noise2DContext struct {
	rgradients   [64]Vec2
	permutations [64]int
}

func NewNoise2DContext() *Noise2DContext {
	ctx := &Noise2DContext{}

	for i := range ctx.rgradients {
		v := NextFloat(math.Pi * 2.0)
		ctx.rgradients[i] = Vec2{math.Cos(v), math.Sin(v)}
	}

	for i := range ctx.permutations {
		ctx.permutations[i] = i
	}

	for i := 0; i < 64; i++ {
		a := NextInt(64)
		b := NextInt(64)
		ctx.permutations[a], ctx.permutations[b] = ctx.permutations[b], ctx.permutations[a]
	}

	return ctx
}

func (n *Noise2DContext) GetGradient(x, y int) Vec2 {
	idx := n.permutations[x&63] + n.permutations[y&63]
	return n.rgradients[idx&63]
}

func (n *Noise2DContext) GetGradients(x, y int) ([4]Vec2, [4]Vec2) {
	x0f := math.Floor(float64(x))
	y0f := math.Floor(float64(y))
	x0 := int(x0f)
	y0 := int(y0f)
	x1 := x0 + 1
	y1 := y0 + 1

	gradients := [4]Vec2{
		n.GetGradient(x0, y0),
		n.GetGradient(x1, y0),
		n.GetGradient(x0, y1),
		n.GetGradient(x1, y1),
	}

	origins := [4]Vec2{
		{x0f + 0.0, y0f + 0.0},
		{x0f + 1.0, y0f + 0.0},
		{x0f + 0.0, y0f + 1.0},
		{x0f + 1.0, y0f + 1.0},
	}

	return gradients, origins
}

func lerp(a, b, v float64) float64 {
	return a*(1.0-v) + b*v
}

func smooth(v float64) float64 {
	return v * v * (3.0 - 2.0*v)
}

func gradient(orig, grad, p Vec2) float64 {
	sp := Vec2{p.X - orig.X, p.Y - orig.Y}
	return grad.X*sp.X + grad.Y*sp.Y
}

func (n *Noise2DContext) Get(x, y float64) float64 {
	p := Vec2{x, y}
	gradients, origins := n.GetGradients(int(x), int(y))

	v0 := gradient(origins[0], gradients[0], p)
	v1 := gradient(origins[1], gradients[1], p)
	v2 := gradient(origins[2], gradients[2], p)
	v3 := gradient(origins[3], gradients[3], p)

	fx := smooth(x - origins[0].X)
	vx0 := lerp(v0, v1, fx)
	vx1 := lerp(v2, v3, fx)

	fy := smooth(y - origins[0].Y)
	return lerp(vx0, vx1, fy)
}

type Noise struct {
	n   int
	res uint64
}

func (n *Noise) Prepare() {
	n.n = GetIterations("Noise")
}

func (n *Noise) Iterations() int { return n.n }

func (n *Noise) noise() uint64 {
	const SIZE = 64
	pixels := make([][]float64, SIZE)
	for i := range pixels {
		pixels[i] = make([]float64, SIZE)
	}

	n2d := NewNoise2DContext()

	for i := 0; i < 100; i++ {
		for y := 0; y < SIZE; y++ {
			for x := 0; x < SIZE; x++ {
				v := n2d.Get(float64(x)*0.1, float64(y+(i*128))*0.1)*0.5 + 0.5
				pixels[y][x] = v
			}
		}
	}

	res := uint64(0)
	SYM := []rune{' ', '░', '▒', '▓', '█', '█'}

	for y := 0; y < SIZE; y++ {
		for x := 0; x < SIZE; x++ {
			v := pixels[y][x]
			idx := int(v / 0.2)
			if idx >= len(SYM) {
				idx = len(SYM) - 1
			}
			res += uint64(SYM[idx])
		}
	}

	return res
}

func (n *Noise) Run() {
	for i := 0; i < n.n; i++ {
		n.res += n.noise()
	}
}

func (n *Noise) Result() uint32 {
	return uint32(n.res)
}

// 23. TextRaytracer
type Vector struct {
	X, Y, Z float64
}

func (v Vector) Scale(s float64) Vector {
	return Vector{v.X * s, v.Y * s, v.Z * s}
}

func (v Vector) Add(other Vector) Vector {
	return Vector{v.X + other.X, v.Y + other.Y, v.Z + other.Z}
}

func (v Vector) Sub(other Vector) Vector {
	return Vector{v.X - other.X, v.Y - other.Y, v.Z - other.Z}
}

func (v Vector) Dot(other Vector) float64 {
	return v.X*other.X + v.Y*other.Y + v.Z*other.Z
}

func (v Vector) Magnitude() float64 {
	return math.Sqrt(v.Dot(v))
}

func (v Vector) Normalize() Vector {
	return v.Scale(1.0 / v.Magnitude())
}

type Ray struct {
	Orig, Dir Vector
}

type Color struct {
	R, G, B float64
}

func (c Color) Scale(s float64) Color {
	return Color{c.R * s, c.G * s, c.B * s}
}

func (c Color) Add(other Color) Color {
	return Color{c.R + other.R, c.G + other.G, c.B + other.B}
}

type Sphere2 struct {
	Center Vector
	Radius float64
	Color  Color
}

func (s Sphere2) GetNormal(pt Vector) Vector {
	return pt.Sub(s.Center).Normalize()
}

type Light2 struct {
	Position Vector
	Color    Color
}

type Hit struct {
	Obj   Sphere2
	Value float64
}

var (
	WHITE2 = Color{1.0, 1.0, 1.0}
	RED2   = Color{1.0, 0.0, 0.0}
	GREEN2 = Color{0.0, 1.0, 0.0}
	BLUE2  = Color{0.0, 0.0, 1.0}
)

var LIGHT12 = Light2{Vector{0.7, -1.0, 1.7}, WHITE2}

var SCENE2 = []Sphere2{
	{Vector{-1.0, 0.0, 3.0}, 0.3, RED2},
	{Vector{0.0, 0.0, 3.0}, 0.8, GREEN2},
	{Vector{1.0, 0.0, 3.0}, 0.4, BLUE2},
}

var LUT = []rune{'.', '-', '+', '*', 'X', 'M'}

type TextRaytracer struct {
	w, h int
	res  uint64
}

func (t *TextRaytracer) Prepare() {
	t.w = GetIterations("TextRaytracer")

	t.h = t.w
}

func (t *TextRaytracer) Iterations() int { return t.w }

func (t *TextRaytracer) shadePixel(ray Ray, obj Sphere2, tval float64) int {
	pi := ray.Orig.Add(ray.Dir.Scale(tval))
	color := t.diffuseShading(pi, obj, LIGHT12)
	col := (color.R + color.G + color.B) / 3.0
	return int(col * 6.0)
}

func (t *TextRaytracer) intersectSphere(ray Ray, center Vector, radius float64) float64 {
	l := center.Sub(ray.Orig)
	tca := l.Dot(ray.Dir)
	if tca < 0.0 {
		return -1
	}

	d2 := l.Dot(l) - tca*tca
	r2 := radius * radius
	if d2 > r2 {
		return -1
	}

	thc := math.Sqrt(r2 - d2)
	t0 := tca - thc

	if t0 > 10000 {
		return -1
	}

	return t0
}

func clamp(x, a, b float64) float64 {
	if x < a {
		return a
	}
	if x > b {
		return b
	}
	return x
}

func (t *TextRaytracer) diffuseShading(pi Vector, obj Sphere2, light Light2) Color {
	n := obj.GetNormal(pi)
	lam1 := light.Position.Sub(pi).Normalize().Dot(n)
	lam2 := clamp(lam1, 0.0, 1.0)
	return light.Color.Scale(lam2 * 0.5).Add(obj.Color.Scale(0.3))
}

func (t *TextRaytracer) Run() {
	res := uint64(0)

	for j := 0; j < t.h; j++ {
		for i := 0; i < t.w; i++ {
			fw, fi, fj, fh := float64(t.w), float64(i), float64(j), float64(t.h)

			ray := Ray{
				Orig: Vector{0.0, 0.0, 0.0},
				Dir:  Vector{(fi - fw/2.0) / fw, (fj - fh/2.0) / fh, 1.0}.Normalize(),
			}

			var hit *Hit

			for _, obj := range SCENE2 {
				ret := t.intersectSphere(ray, obj.Center, obj.Radius)
				if ret > 0 {
					hit = &Hit{obj, ret}
					break
				}
			}

			var pixel rune
			if hit != nil {
				pixel = LUT[t.shadePixel(ray, hit.Obj, hit.Value)]
			} else {
				pixel = ' '
			}

			res += uint64(pixel)
		}
	}

	t.res = res
}

func (t *TextRaytracer) Result() uint32 {
	return uint32(t.res)
}

// 24. NeuralNet
type Synapse struct {
	weight       float64
	prevWeight   float64
	sourceNeuron *Neuron2
	destNeuron   *Neuron2
}

func NewSynapse(source, dest *Neuron2) *Synapse {
	val := NextFloat(2) - 1
	return &Synapse{
		weight:       val,
		prevWeight:   val,
		sourceNeuron: source,
		destNeuron:   dest,
	}
}

type Neuron2 struct {
	synapsesIn    []*Synapse
	synapsesOut   []*Synapse
	threshold     float64
	prevThreshold float64
	error         float64
	output        float64
}

func NewNeuron2() *Neuron2 {
	val := NextFloat(2) - 1
	return &Neuron2{
		threshold:     val,
		prevThreshold: val,
	}
}

func (n *Neuron2) CalculateOutput() {
	activation := 0.0
	for _, synapse := range n.synapsesIn {
		activation += synapse.weight * synapse.sourceNeuron.output
	}
	activation -= n.threshold
	n.output = 1.0 / (1.0 + math.Exp(-activation))
}

func (n *Neuron2) Derivative() float64 {
	return n.output * (1 - n.output)
}

func (n *Neuron2) OutputTrain(rate, target float64) {
	n.error = (target - n.output) * n.Derivative()
	n.UpdateWeights(rate)
}

func (n *Neuron2) HiddenTrain(rate float64) {
	sum := 0.0
	for _, synapse := range n.synapsesOut {
		sum += synapse.prevWeight * synapse.destNeuron.error
	}
	n.error = sum * n.Derivative()
	n.UpdateWeights(rate)
}

func (n *Neuron2) UpdateWeights(rate float64) {
	const LEARNING_RATE = 1.0
	const MOMENTUM = 0.3

	for _, synapse := range n.synapsesIn {
		tempWeight := synapse.weight
		synapse.weight += (rate * LEARNING_RATE * n.error * synapse.sourceNeuron.output) +
			(MOMENTUM * (synapse.weight - synapse.prevWeight))
		synapse.prevWeight = tempWeight
	}

	tempThreshold := n.threshold
	n.threshold += (rate * LEARNING_RATE * n.error * -1) +
		(MOMENTUM * (n.threshold - n.prevThreshold))
	n.prevThreshold = tempThreshold
}

type NeuralNetwork2 struct {
	inputLayer  []*Neuron2
	hiddenLayer []*Neuron2
	outputLayer []*Neuron2
}

func NewNeuralNetwork(inputs, hidden, outputs int) *NeuralNetwork2 {
	nn := &NeuralNetwork2{
		inputLayer:  make([]*Neuron2, inputs),
		hiddenLayer: make([]*Neuron2, hidden),
		outputLayer: make([]*Neuron2, outputs),
	}

	for i := range nn.inputLayer {
		nn.inputLayer[i] = NewNeuron2()
	}
	for i := range nn.hiddenLayer {
		nn.hiddenLayer[i] = NewNeuron2()
	}
	for i := range nn.outputLayer {
		nn.outputLayer[i] = NewNeuron2()
	}

	for _, source := range nn.inputLayer {
		for _, dest := range nn.hiddenLayer {
			synapse := NewSynapse(source, dest)
			source.synapsesOut = append(source.synapsesOut, synapse)
			dest.synapsesIn = append(dest.synapsesIn, synapse)
		}
	}

	for _, source := range nn.hiddenLayer {
		for _, dest := range nn.outputLayer {
			synapse := NewSynapse(source, dest)
			source.synapsesOut = append(source.synapsesOut, synapse)
			dest.synapsesIn = append(dest.synapsesIn, synapse)
		}
	}

	return nn
}

func (nn *NeuralNetwork2) Train(inputs, targets []float64) {
	nn.FeedForward(inputs)

	for i, neuron := range nn.outputLayer {
		neuron.OutputTrain(0.3, targets[i])
	}

	for _, neuron := range nn.hiddenLayer {
		neuron.HiddenTrain(0.3)
	}
}

func (nn *NeuralNetwork2) FeedForward(inputs []float64) {
	for i, neuron := range nn.inputLayer {
		neuron.output = inputs[i]
	}

	for _, neuron := range nn.hiddenLayer {
		neuron.CalculateOutput()
	}

	for _, neuron := range nn.outputLayer {
		neuron.CalculateOutput()
	}
}

func (nn *NeuralNetwork2) CurrentOutputs() []float64 {
	outputs := make([]float64, len(nn.outputLayer))
	for i, neuron := range nn.outputLayer {
		outputs[i] = neuron.output
	}
	return outputs
}

type NeuralNet struct {
	n   int
	res []float64
}

func (n *NeuralNet) Prepare() {
	n.n = GetIterations("NeuralNet")
}

func (n *NeuralNet) Iterations() int { return n.n }

func (n *NeuralNet) Run() {
	xor := NewNeuralNetwork(2, 10, 1)

	for i := 0; i < n.n; i++ {
		xor.Train([]float64{0, 0}, []float64{0})
		xor.Train([]float64{1, 0}, []float64{1})
		xor.Train([]float64{0, 1}, []float64{1})
		xor.Train([]float64{1, 1}, []float64{0})
	}

	xor.FeedForward([]float64{0, 0})
	n.res = append(n.res, xor.CurrentOutputs()...)
	xor.FeedForward([]float64{0, 1})
	n.res = append(n.res, xor.CurrentOutputs()...)
	xor.FeedForward([]float64{1, 0})
	n.res = append(n.res, xor.CurrentOutputs()...)
	xor.FeedForward([]float64{1, 1})
	n.res = append(n.res, xor.CurrentOutputs()...)
}

func (n *NeuralNet) Result() uint32 {
	sum := 0.0
	for _, r := range n.res {
		sum += r
	}
	return ChecksumFloat64(sum)
}

// 25-27. SortBenchmark базовый класс и реализации
type SortBenchmark struct {
	data   []int
	n      int
	result uint32
	name   string
}

func (s *SortBenchmark) Prepare() {
	s.n = GetIterations(s.name)
	s.data = make([]int, 100000)
	for i := 0; i < len(s.data); i++ {
		s.data[i] = NextInt(1_000_000)
	}
}

func (s *SortBenchmark) Iterations() int { return s.n }

func (s *SortBenchmark) checkNElements(arr []int, n int) string {
	step := len(arr) / n
	var builder strings.Builder
	builder.WriteString("[")
	for index := 0; index < len(arr); index += step {
		builder.WriteString(fmt.Sprintf("%d:%d,", index, arr[index]))
	}
	builder.WriteString("]\n")
	return builder.String()
}

type SortQuick struct {
	SortBenchmark
}

func (s *SortQuick) Run() {
	verify := s.checkNElements(s.data, 10)

	for i := 0; i < s.n-1; i++ {
		arr := make([]int, len(s.data))
		copy(arr, s.data)
		s.quickSort(arr, 0, len(arr)-1)
		s.result += uint32(arr[len(s.data)/2])
	}

	arr := make([]int, len(s.data))
	copy(arr, s.data)
	s.quickSort(arr, 0, len(arr)-1)

	verify += s.checkNElements(s.data, 10)
	verify += s.checkNElements(arr, 10)

	s.result += Checksum(verify)
}

func (s *SortQuick) quickSort(arr []int, low, high int) {
	if low >= high {
		return
	}

	pivot := arr[(low+high)/2]
	i, j := low, high

	for i <= j {
		for arr[i] < pivot {
			i++
		}
		for arr[j] > pivot {
			j--
		}
		if i <= j {
			arr[i], arr[j] = arr[j], arr[i]
			i++
			j--
		}
	}

	s.quickSort(arr, low, j)
	s.quickSort(arr, i, high)
}

func (s *SortQuick) Result() uint32 {
	return s.result
}

type SortMerge struct {
	SortBenchmark
}

func (s *SortMerge) Run() {
	verify := s.checkNElements(s.data, 10)

	for i := 0; i < s.n-1; i++ {
		arr := make([]int, len(s.data))
		copy(arr, s.data)
		s.mergeSortInplace(arr)
		s.result += uint32(arr[len(s.data)/2])
	}

	arr := make([]int, len(s.data))
	copy(arr, s.data)
	s.mergeSortInplace(arr)

	verify += s.checkNElements(s.data, 10)
	verify += s.checkNElements(arr, 10)

	s.result += Checksum(verify)
}

func (s *SortMerge) mergeSortInplace(arr []int) {
	temp := make([]int, len(arr))
	s.mergeSortHelper(arr, temp, 0, len(arr)-1)
}

func (s *SortMerge) mergeSortHelper(arr, temp []int, left, right int) {
	if left >= right {
		return
	}

	mid := (left + right) / 2
	s.mergeSortHelper(arr, temp, left, mid)
	s.mergeSortHelper(arr, temp, mid+1, right)
	s.merge(arr, temp, left, mid, right)
}

func (s *SortMerge) merge(arr, temp []int, left, mid, right int) {
	for i := left; i <= right; i++ {
		temp[i] = arr[i]
	}

	i, j, k := left, mid+1, left

	for i <= mid && j <= right {
		if temp[i] <= temp[j] {
			arr[k] = temp[i]
			i++
		} else {
			arr[k] = temp[j]
			j++
		}
		k++
	}

	for i <= mid {
		arr[k] = temp[i]
		i++
		k++
	}
}

func (s *SortMerge) Result() uint32 {
	return s.result
}

type SortSelf struct {
	SortBenchmark
}

func (s *SortSelf) Run() {
	verify := s.checkNElements(s.data, 10)

	for i := 0; i < s.n-1; i++ {
		arr := make([]int, len(s.data))
		copy(arr, s.data)
		sort.Ints(arr)
		s.result += uint32(arr[len(s.data)/2])
	}

	arr := make([]int, len(s.data))
	copy(arr, s.data)
	sort.Ints(arr)

	verify += s.checkNElements(s.data, 10)
	verify += s.checkNElements(arr, 10)

	s.result += Checksum(verify)
}

func (s *SortSelf) Result() uint32 {
	return s.result
}

// 28-30. GraphPathBenchmark базовый класс и реализации
type Graph struct {
	vertices   int
	components int
	adj        [][]int
}

func NewGraph(vertices, components int) *Graph {
	adj := make([][]int, vertices)
	for i := range adj {
		adj[i] = make([]int, 0)
	}
	return &Graph{vertices: vertices, components: components, adj: adj}
}

func (g *Graph) AddEdge(u, v int) {
	g.adj[u] = append(g.adj[u], v)
	g.adj[v] = append(g.adj[v], u)
}

func (g *Graph) GenerateRandom() {
	componentSize := g.vertices / g.components

	for c := 0; c < g.components; c++ {
		startIdx := c * componentSize
		endIdx := (c + 1) * componentSize
		if c == g.components-1 {
			endIdx = g.vertices
		}

		for i := startIdx + 1; i < endIdx; i++ {
			parent := startIdx + NextInt(i-startIdx)
			g.AddEdge(i, parent)
		}

		for i := 0; i < componentSize*2; i++ {
			u := startIdx + NextInt(endIdx-startIdx)
			v := startIdx + NextInt(endIdx-startIdx)
			if u != v {
				g.AddEdge(u, v)
			}
		}
	}
}

func (g *Graph) SameComponent(u, v int) bool {
	componentSize := g.vertices / g.components
	return (u / componentSize) == (v / componentSize)
}

type GraphPathBenchmark struct {
	n_pairs int
	graph   *Graph
	pairs   [][2]int
	result  int64
	name    string
}

func (g *GraphPathBenchmark) Prepare() {
	g.n_pairs = GetIterations(g.name)
	vertices := g.n_pairs * 10
	components := max(10, vertices/10000)
	g.graph = NewGraph(vertices, components)
	g.graph.GenerateRandom()
	g.pairs = g.generatePairs(g.n_pairs)
}

func (g *GraphPathBenchmark) Iterations() int { return g.n_pairs }

func (g *GraphPathBenchmark) generatePairs(n int) [][2]int {
	pairs := make([][2]int, n)
	componentSize := g.graph.vertices / 10

	for i := 0; i < n; i++ {
		if NextInt(100) < 70 {

			component := NextInt(10)
			start := component*componentSize + NextInt(componentSize)
			for {
				end := component*componentSize + NextInt(componentSize)
				if end != start {

					pairs[i] = [2]int{start, end}
					break
				}
			}
		} else {
			c1 := NextInt(10)
			c2 := NextInt(10)
			for c2 == c1 {
				c2 = NextInt(10)
			}
			start := c1*componentSize + NextInt(componentSize)
			end := c2*componentSize + NextInt(componentSize)
			pairs[i] = [2]int{start, end}
		}
	}

	return pairs
}

type GraphPathBFS struct {
	GraphPathBenchmark
}

func (g *GraphPathBFS) Run() {
	totalLength := int64(0)

	for _, pair := range g.pairs {
		start, end := pair[0], pair[1]
		length := g.bfsShortestPath(start, end)
		totalLength += int64(length)
	}

	g.result = totalLength
}

func (g *GraphPathBFS) bfsShortestPath(start, target int) int {
	if start == target {
		return 0
	}

	visited := make([]byte, g.graph.vertices)
	queue := [][2]int{{start, 0}}

	visited[start] = 1

	for len(queue) > 0 {
		v, dist := queue[0][0], queue[0][1]
		queue = queue[1:]

		for _, neighbor := range g.graph.adj[v] {
			if neighbor == target {
				return dist + 1
			}

			if visited[neighbor] == 0 {
				visited[neighbor] = 1
				queue = append(queue, [2]int{neighbor, dist + 1})
			}
		}
	}

	return -1
}

func (g *GraphPathBFS) Result() uint32 {
	return uint32(g.result)
}

type GraphPathDFS struct {
	GraphPathBenchmark
}

func (g *GraphPathDFS) Run() {
	totalLength := int64(0)

	for _, pair := range g.pairs {
		start, end := pair[0], pair[1]
		length := g.dfsFindPath(start, end)
		totalLength += int64(length)
	}

	g.result = totalLength
}

func (g *GraphPathDFS) dfsFindPath(start, target int) int {
	if start == target {
		return 0
	}

	visited := make([]byte, g.graph.vertices)
	stack := [][2]int{{start, 0}}
	bestPath := int(^uint(0) >> 1)

	for len(stack) > 0 {
		v, dist := stack[len(stack)-1][0], stack[len(stack)-1][1]
		stack = stack[:len(stack)-1]

		if visited[v] == 1 || dist >= bestPath {
			continue
		}
		visited[v] = 1

		for _, neighbor := range g.graph.adj[v] {
			if neighbor == target {
				if dist+1 < bestPath {
					bestPath = dist + 1
				}
			} else if visited[neighbor] == 0 {
				stack = append(stack, [2]int{neighbor, dist + 1})
			}
		}
	}

	if bestPath == int(^uint(0)>>1) {
		return -1
	}
	return bestPath
}

func (g *GraphPathDFS) Result() uint32 {
	return uint32(g.result)
}

type GraphPathDijkstra struct {
	GraphPathBenchmark
}

func (g *GraphPathDijkstra) Run() {
	totalLength := int64(0)

	for _, pair := range g.pairs {
		start, end := pair[0], pair[1]
		length := g.dijkstraShortestPath(start, end)
		totalLength += int64(length)
	}

	g.result = totalLength
}

func (g *GraphPathDijkstra) dijkstraShortestPath(start, target int) int {
	if start == target {
		return 0
	}

	const INF = int(^uint(0) >> 1)
	dist := make([]int, g.graph.vertices)
	visited := make([]byte, g.graph.vertices)

	for i := range dist {
		dist[i] = INF
	}
	dist[start] = 0

	iteration := 0
	maxIterations := g.graph.vertices

	for iteration < maxIterations {
		iteration++

		u := -1
		minDist := INF

		for v := 0; v < g.graph.vertices; v++ {
			if visited[v] == 0 && dist[v] < minDist {
				minDist = dist[v]
				u = v
			}
		}

		if u == -1 || minDist == INF || u == target {
			if u == target {
				return minDist
			}
			return -1
		}

		visited[u] = 1

		for _, v := range g.graph.adj[u] {
			if dist[u] != INF && dist[u]+1 < dist[v] {
				dist[v] = dist[u] + 1
			}
		}
	}

	return -1
}

func (g *GraphPathDijkstra) Result() uint32 {
	return uint32(g.result)
}

// 31-32. BufferHashBenchmark базовый класс и реализации
type BufferHashBenchmark struct {
	data   []byte
	n      int
	result uint32
	name   string
}

func (b *BufferHashBenchmark) Prepare() {
	b.n = GetIterations(b.name)
	b.data = make([]byte, 1_000_000)
	for i := 0; i < len(b.data); i++ {
		b.data[i] = byte(NextInt(256))
	}
}

func (b *BufferHashBenchmark) Iterations() int { return b.n }

type BufferHashSHA256 struct {
	BufferHashBenchmark
}

func (b *BufferHashSHA256) test() uint32 {
	hashes := [8]uint32{
		0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
		0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
	}

	for i, byteVal := range b.data {
		hashIdx := i % 8
		hash := hashes[hashIdx]
		hash = ((hash << 5) + hash) + uint32(byteVal)
		hash = (hash + (hash << 10)) ^ (hash >> 6)
		hashes[hashIdx] = hash
	}

	result := make([]byte, 32)
	for i := 0; i < 8; i++ {
		hash := hashes[i]
		result[i*4] = byte(hash >> 24)
		result[i*4+1] = byte(hash >> 16)
		result[i*4+2] = byte(hash >> 8)
		result[i*4+3] = byte(hash)
	}

	return uint32(result[0]) | uint32(result[1])<<8 |
		uint32(result[2])<<16 | uint32(result[3])<<24
}

func (b *BufferHashSHA256) Run() {
	for i := 0; i < b.n; i++ {
		b.result += b.test()
	}
}

func (b *BufferHashSHA256) Result() uint32 {
	return b.result
}

type BufferHashCRC32 struct {
	BufferHashBenchmark
}

func (b *BufferHashCRC32) test() uint32 {
	crc := uint32(0xFFFFFFFF)

	for _, byteVal := range b.data {
		crc = crc ^ uint32(byteVal)
		for j := 0; j < 8; j++ {
			if (crc & 1) != 0 {
				crc = (crc >> 1) ^ 0xEDB88320
			} else {
				crc = crc >> 1
			}
		}
	}

	return crc ^ 0xFFFFFFFF
}

func (b *BufferHashCRC32) Run() {
	for i := 0; i < b.n; i++ {
		b.result += b.test()
	}
}

func (b *BufferHashCRC32) Result() uint32 {
	return b.result
}

// 33. CacheSimulation
type LRUCache struct {
	capacity int
	cache    map[string]*node
	head     *node
	tail     *node
	size     int
}

type node struct {
	key   string
	value string
	prev  *node
	next  *node
}

func NewLRUCache(capacity int) *LRUCache {
	return &LRUCache{
		capacity: capacity,
		cache:    make(map[string]*node),
	}
}

func (c *LRUCache) Get(key string) (string, bool) {
	if n, ok := c.cache[key]; ok {
		c.moveToFront(n)
		return n.value, true
	}
	return "", false
}

func (c *LRUCache) Put(key, value string) {
	// Проверяем существующий элемент
	if n, ok := c.cache[key]; ok {
		n.value = value
		c.moveToFront(n)
		return
	}

	// Удаляем самый старый если достигли capacity
	if c.size >= c.capacity {
		c.removeOldest()
	}

	// Создаем новый узел
	n := &node{
		key:   key,
		value: value,
	}

	// Добавляем в мапу
	c.cache[key] = n

	// Добавляем в начало списка
	c.addToFront(n)
	c.size++
}

func (c *LRUCache) Size() int {
	return c.size
}

func (c *LRUCache) moveToFront(n *node) {
	// Если уже в начале, ничего не делаем
	if n == c.head {
		return
	}

	// Удаляем из текущей позиции
	if n.prev != nil {
		n.prev.next = n.next
	}
	if n.next != nil {
		n.next.prev = n.prev
	}

	// Обновляем tail если нужно
	if n == c.tail {
		c.tail = n.prev
	}

	// Вставляем в начало
	n.prev = nil
	n.next = c.head
	if c.head != nil {
		c.head.prev = n
	}
	c.head = n

	// Если список был пустой, обновляем tail
	if c.tail == nil {
		c.tail = n
	}
}

func (c *LRUCache) addToFront(n *node) {
	n.next = c.head
	if c.head != nil {
		c.head.prev = n
	}
	c.head = n
	if c.tail == nil {
		c.tail = n
	}
}

func (c *LRUCache) removeOldest() {
	if c.tail == nil {
		return
	}

	oldest := c.tail

	// Удаляем из мапы
	delete(c.cache, oldest.key)

	// Удаляем из списка
	if oldest.prev != nil {
		oldest.prev.next = nil
	}
	c.tail = oldest.prev

	// Обновляем head если нужно
	if c.head == oldest {
		c.head = nil
	}

	c.size--
}

type CacheSimulation struct {
	operations int
	result     uint32
}

func (c *CacheSimulation) Prepare() {
	c.operations = GetIterations("CacheSimulation")
	if c.operations == 0 {
		c.operations = 100
	}
	c.operations *= 1000
}

func (c *CacheSimulation) Iterations() int { return c.operations }

func (c *CacheSimulation) Run() {
	cache := NewLRUCache(1000)
	hits := 0
	misses := 0

	// Используем буферы для строк, чтобы избежать лишних аллокаций
	keyBuf := make([]byte, 0, 32)
	valueBuf := make([]byte, 0, 32)

	for i := 0; i < c.operations; i++ {
		// Собираем ключ более эффективно
		keyBuf = keyBuf[:0]
		keyBuf = append(keyBuf, "item_"...)
		keyBuf = strconv.AppendInt(keyBuf, int64(NextInt(2000)), 10)
		key := string(keyBuf)

		if _, ok := cache.Get(key); ok {
			hits++
			// Обновляем значение
			valueBuf = valueBuf[:0]
			valueBuf = append(valueBuf, "updated_"...)
			valueBuf = strconv.AppendInt(valueBuf, int64(i), 10)
			cache.Put(key, string(valueBuf))
		} else {
			misses++
			valueBuf = valueBuf[:0]
			valueBuf = append(valueBuf, "new_"...)
			valueBuf = strconv.AppendInt(valueBuf, int64(i), 10)
			cache.Put(key, string(valueBuf))
		}
	}

	// Используем strings.Builder для построения результата
	var result strings.Builder
	result.Grow(64)
	result.WriteString("hits:")
	result.WriteString(strconv.Itoa(hits))
	result.WriteString("|misses:")
	result.WriteString(strconv.Itoa(misses))
	result.WriteString("|size:")
	result.WriteString(strconv.Itoa(cache.Size()))

	c.result = Checksum(result.String())
}

func (c *CacheSimulation) Result() uint32 {
	return c.result
}

// 35. CalculatorAst
type AstNode interface{}

type NumberNode struct {
	value int64
}

type VariableNode struct {
	name string
}

type BinaryOpNode struct {
	op    byte
	left  AstNode
	right AstNode
}

type AssignmentNode struct {
	varName string
	expr    AstNode
}

type Parser struct {
	input   string
	pos     int
	len     int
	current byte
}

func NewParser(input string) *Parser {
	p := &Parser{
		input: input,
		len:   len(input),
	}
	if p.len > 0 {
		p.current = input[0]
	}
	return p
}

func (p *Parser) parse() []AstNode {
	nodes := make([]AstNode, 0)
	for p.pos < p.len {
		p.skipWhitespace()
		if p.pos >= p.len {
			break
		}
		node := p.parseExpression()
		if node != nil {
			nodes = append(nodes, node)
		}

		// Пропускаем переводы строк и точки с запятой
		p.skipWhitespace()
		for p.pos < p.len && (p.current == '\n' || p.current == ';') {
			p.advance()
			p.skipWhitespace()
		}
	}
	return nodes
}

func (p *Parser) parseExpression() AstNode {
	node := p.parseTerm()

	for p.pos < p.len {
		p.skipWhitespace()
		if p.pos >= p.len {
			break
		}

		if p.current == '+' || p.current == '-' {
			op := p.current
			p.advance()
			right := p.parseTerm()
			node = BinaryOpNode{op: op, left: node, right: right}
		} else {
			break
		}
	}

	return node
}

func (p *Parser) parseTerm() AstNode {
	node := p.parseFactor()

	for p.pos < p.len {
		p.skipWhitespace()
		if p.pos >= p.len {
			break
		}

		if p.current == '*' || p.current == '/' || p.current == '%' {
			op := p.current
			p.advance()
			right := p.parseFactor()
			node = BinaryOpNode{op: op, left: node, right: right}
		} else {
			break
		}
	}

	return node
}

func (p *Parser) parseFactor() AstNode {
	p.skipWhitespace()
	if p.pos >= p.len {
		return NumberNode{value: 0}
	}

	switch {
	case p.current >= '0' && p.current <= '9':
		return p.parseNumber()
	case (p.current >= 'a' && p.current <= 'z') || (p.current >= 'A' && p.current <= 'Z'):
		return p.parseVariable()
	case p.current == '(':
		p.advance()
		node := p.parseExpression()
		p.skipWhitespace()
		if p.current == ')' {
			p.advance()
		}
		return node
	default:
		return NumberNode{value: 0}
	}
}

func (p *Parser) parseNumber() AstNode {
	start := p.pos
	for p.pos < p.len && p.current >= '0' && p.current <= '9' {
		p.advance()
	}
	val, _ := strconv.ParseInt(p.input[start:p.pos], 10, 64)
	return NumberNode{value: val}
}

func (p *Parser) parseVariable() AstNode {
	start := p.pos
	for p.pos < p.len && ((p.current >= 'a' && p.current <= 'z') ||
		(p.current >= 'A' && p.current <= 'Z') ||
		(p.current >= '0' && p.current <= '9')) {
		p.advance()
	}
	varName := p.input[start:p.pos]

	p.skipWhitespace()
	if p.current == '=' {
		p.advance()
		expr := p.parseExpression()
		return AssignmentNode{varName: varName, expr: expr}
	}

	return VariableNode{name: varName}
}

func (p *Parser) advance() {
	p.pos++
	if p.pos >= p.len {
		p.current = 0
	} else {
		p.current = p.input[p.pos]
	}
}

func (p *Parser) skipWhitespace() {
	for p.pos < p.len && (p.current == ' ' || p.current == '\t' ||
		p.current == '\n' || p.current == '\r') {
		p.advance()
	}
}

type CalculatorAst struct {
	n           int
	result      int64
	text        string
	expressions []AstNode
}

func (c *CalculatorAst) generateRandomProgram(n int) string {
	var builder strings.Builder
	builder.WriteString("v0 = 1\n")

	for i := 0; i < 10; i++ {
		v := i + 1
		builder.WriteString(fmt.Sprintf("v%d = v%d + %d\n", v, v-1, v))
	}

	for i := 0; i < n; i++ {
		v := i + 10
		builder.WriteString(fmt.Sprintf("v%d = v%d + ", v, v-1))

		switch NextInt(10) {
		case 0:
			builder.WriteString(fmt.Sprintf(
				"(v%d / 3) * 4 - %d / (3 + (18 - v%d)) %% v%d + 2 * ((9 - v%d) * (v%d + 7))",
				v-1, i, v-2, v-3, v-6, v-5))
		case 1:
			builder.WriteString(fmt.Sprintf(
				"v%d + (v%d + v%d) * v%d - (v%d / v%d)",
				v-1, v-2, v-3, v-4, v-5, v-6))
		case 2:
			builder.WriteString(fmt.Sprintf("(3789 - (((v%d)))) + 1", v-7))
		case 3:
			builder.WriteString(fmt.Sprintf("4/2 * (1-3) + v%d/v%d", v-9, v-5))
		case 4:
			builder.WriteString(fmt.Sprintf("1+2+3+4+5+6+v%d", v-1))
		case 5:
			builder.WriteString(fmt.Sprintf("(99999 / v%d)", v-3))
		case 6:
			builder.WriteString(fmt.Sprintf("0 + 0 - v%d", v-8))
		case 7:
			builder.WriteString(fmt.Sprintf("((((((((((v%d)))))))))) * 2", v-6))
		case 8:
			builder.WriteString(fmt.Sprintf("%d * (v%d%%6)%%7", i, v-1))
		case 9:
			builder.WriteString(fmt.Sprintf("(1)/(0-v%d) + (v%d)", v-5, v-7))
		}
		builder.WriteString("\n")
	}

	return builder.String()
}

func (c *CalculatorAst) Prepare() {
	c.text = c.generateRandomProgram(c.n)
}

func (c *CalculatorAst) Iterations() int { return c.n }

func (c *CalculatorAst) Run() {
	parser := NewParser(c.text)
	c.expressions = parser.parse()
	c.result += int64(len(c.expressions))
}

func (c *CalculatorAst) Result() uint32 {
	return uint32(c.result)
}

func (c *CalculatorAst) GetExpressions() []AstNode {
	return c.expressions
}

// 36. CalculatorInterpreter

// Вспомогательные функции для деления (как в Crystal/C++)
func simpleDiv(a, b int64) int64 {
	if b == 0 {
		return 0
	}
	// Простое деление с округлением к нулю
	if (a >= 0 && b > 0) || (a < 0 && b < 0) {
		return a / b // одинаковые знаки
	} else {
		return -(abs(a) / abs(b)) // разные знаки
	}
}

func simpleMod(a, b int64) int64 {
	if b == 0 {
		return 0
	}
	return a - simpleDiv(a, b)*b
}

func abs(x int64) int64 {
	if x < 0 {
		return -x
	}
	return x
}

type Interpreter struct {
	variables map[string]int64
}

func NewInterpreter() *Interpreter {
	return &Interpreter{
		variables: make(map[string]int64),
	}
}

func (i *Interpreter) evaluate(node AstNode) int64 {
	switch n := node.(type) {
	case NumberNode:
		return n.value
	case VariableNode:
		if val, ok := i.variables[n.name]; ok {
			return val
		}
		return 0
	case BinaryOpNode:
		left := i.evaluate(n.left)
		right := i.evaluate(n.right)

		switch n.op {
		case '+':
			return left + right
		case '-':
			return left - right
		case '*':
			return left * right
		case '/':
			return simpleDiv(left, right)
		case '%':
			return simpleMod(left, right)
		default:
			return 0
		}
	case AssignmentNode:
		value := i.evaluate(n.expr)
		i.variables[n.varName] = value
		return value
	default:
		return 0
	}
}

func (i *Interpreter) run(expressions []AstNode) int64 {
	var result int64 = 0
	for _, expr := range expressions {
		result = i.evaluate(expr)
	}
	return result
}

func (i *Interpreter) clear() {
	i.variables = make(map[string]int64)
}

type CalculatorInterpreter struct {
	n      int
	ast    []AstNode
	result int64
}

func (c *CalculatorInterpreter) Prepare() {
	astBench := &CalculatorAst{n: GetIterations("CalculatorInterpreter")}
	astBench.Prepare()
	astBench.Run()
	c.ast = astBench.GetExpressions()
}

func (c *CalculatorInterpreter) Iterations() int { return c.n }

func (c *CalculatorInterpreter) Run() {
	var total int64 = 0
	for i := 0; i < 100; i++ {
		interpreter := NewInterpreter()
		result := interpreter.run(c.ast)
		total += result
	}
	c.result = total
}

func (c *CalculatorInterpreter) Result() uint32 {
	return uint32(c.result)
}

type GameOfLife struct {
	result uint64
	width  int
	height int
	grid   *grid
}

type grid struct {
	width  int
	height int
	cells  [][]Cell
}

type Cell int

const (
	Dead Cell = iota
	Alive
)

func NewGrid(width, height int) *grid {
	cells := make([][]Cell, height)
	for y := 0; y < height; y++ {
		cells[y] = make([]Cell, width)
	}
	return &grid{width, height, cells}
}

func (g *grid) get(x, y int) Cell {
	return g.cells[y][x]
}

func (g *grid) set(x, y int, cell Cell) {
	g.cells[y][x] = cell
}

func (g *grid) countNeighbors(x, y int) int {
	count := 0

	for dy := -1; dy <= 1; dy++ {
		for dx := -1; dx <= 1; dx++ {
			if dx == 0 && dy == 0 {
				continue
			}

			// Тороидальные координаты
			nx := (x + dx) % g.width
			ny := (y + dy) % g.height
			if nx < 0 {
				nx += g.width
			}
			if ny < 0 {
				ny += g.height
			}

			if g.cells[ny][nx] == Alive {
				count++
			}
		}
	}

	return count
}

func (g *grid) nextGeneration() *grid {
	nextGrid := NewGrid(g.width, g.height)

	for y := 0; y < g.height; y++ {
		for x := 0; x < g.width; x++ {
			neighbors := g.countNeighbors(x, y)
			current := g.cells[y][x]

			var nextState Cell = Dead
			if current == Alive {
				if neighbors == 2 || neighbors == 3 {
					nextState = Alive
				}
			} else {
				if neighbors == 3 {
					nextState = Alive
				}
			}

			nextGrid.cells[y][x] = nextState
		}
	}

	return nextGrid
}

func (g *grid) aliveCount() int {
	count := 0
	for y := 0; y < g.height; y++ {
		for x := 0; x < g.width; x++ {
			if g.cells[y][x] == Alive {
				count++
			}
		}
	}
	return count
}

func (g *grid) computeHash() uint64 {
	var hasher uint64 = 0
	for y := 0; y < g.height; y++ {
		for x := 0; x < g.width; x++ {
			// Простой хэш - сдвиг и XOR
			hasher = (hasher << 1)
			if g.cells[y][x] == Alive {
				hasher ^= 1
			} else {
				hasher ^= 0
			}
		}
	}
	return hasher
}

func (g *GameOfLife) Prepare() {
	g.width = 256
	g.height = 256
	g.grid = NewGrid(g.width, g.height)
	// Инициализация случайными клетками
	for y := 0; y < g.height; y++ {
		for x := 0; x < g.width; x++ {
			if NextFloat(1.0) < 0.1 {
				g.grid.set(x, y, Alive)
			}
		}
	}
}

func (g *GameOfLife) Iterations() int { return GetIterations("GameOfLife") }

func (g *GameOfLife) Run() {
	// Основной цикл симуляции
	iters := g.Iterations()
	for i := 0; i < iters; i++ {
		g.grid = g.grid.nextGeneration()
	}

	g.result = uint64(g.grid.aliveCount())
}

func (g *GameOfLife) Result() uint32 {
	return uint32(g.result)
}

type MazeGenerator struct {
	result uint64
	width  int
	height int
}

type PCell int

const (
	Wall PCell = iota
	Path
)

type maze struct {
	width  int
	height int
	cells  [][]PCell
}

func newMaze(width, height int) *maze {
	if width < 5 {
		width = 5
	}
	if height < 5 {
		height = 5
	}

	cells := make([][]PCell, height)
	for y := 0; y < height; y++ {
		cells[y] = make([]PCell, width)
		// Инициализация не нужна - Wall = 0
	}

	return &maze{width, height, cells}
}

func (m *maze) set(x, y int, cell PCell) {
	m.cells[y][x] = cell
}

func (m *maze) divide(x1, y1, x2, y2 int) {
	width := x2 - x1
	height := y2 - y1

	if width < 2 || height < 2 {
		return
	}

	widthForWall := max(width-2, 0)
	heightForWall := max(height-2, 0)
	widthForHole := max(width-1, 0)
	heightForHole := max(height-1, 0)

	if widthForWall == 0 || heightForWall == 0 ||
		widthForHole == 0 || heightForHole == 0 {
		return
	}

	if width > height {
		// Вертикальная стена
		wallRange := max(widthForWall/2, 1)
		wallOffset := 0
		if wallRange > 0 {
			wallOffset = NextInt(wallRange) * 2
		}
		wallX := x1 + 2 + wallOffset

		holeRange := max(heightForHole/2, 1)
		holeOffset := 0
		if holeRange > 0 {
			holeOffset = NextInt(holeRange) * 2
		}
		holeY := y1 + 1 + holeOffset

		if wallX > x2 || holeY > y2 {
			return
		}

		for y := y1; y <= y2; y++ {
			if y != holeY {
				m.set(wallX, y, Wall)
			}
		}

		if wallX > x1+1 {
			m.divide(x1, y1, wallX-1, y2)
		}
		if wallX+1 < x2 {
			m.divide(wallX+1, y1, x2, y2)
		}
	} else {
		// Горизонтальная стена
		wallRange := max(heightForWall/2, 1)
		wallOffset := 0
		if wallRange > 0 {
			wallOffset = NextInt(wallRange) * 2
		}
		wallY := y1 + 2 + wallOffset

		holeRange := max(widthForHole/2, 1)
		holeOffset := 0
		if holeRange > 0 {
			holeOffset = NextInt(holeRange) * 2
		}
		holeX := x1 + 1 + holeOffset

		if wallY > y2 || holeX > x2 {
			return
		}

		for x := x1; x <= x2; x++ {
			if x != holeX {
				m.set(x, wallY, Wall)
			}
		}

		if wallY > y1+1 {
			m.divide(x1, y1, x2, wallY-1)
		}
		if wallY+1 < y2 {
			m.divide(x1, wallY+1, x2, y2)
		}
	}
}

func (m *maze) isConnectedImpl(startX, startY, goalX, goalY int) bool {
	if startX >= m.width || startY >= m.height ||
		goalX >= m.width || goalY >= m.height {
		return false
	}

	visited := make([][]bool, m.height)
	for y := 0; y < m.height; y++ {
		visited[y] = make([]bool, m.width)
	}

	queue := make([][2]int, 0, m.width*m.height/4)
	queue = append(queue, [2]int{startX, startY})
	visited[startY][startX] = true

	head := 0

	for head < len(queue) {
		x, y := queue[head][0], queue[head][1]
		head++

		if x == goalX && y == goalY {
			return true
		}

		// Верх
		if y > 0 && m.cells[y-1][x] == Path && !visited[y-1][x] {
			visited[y-1][x] = true
			queue = append(queue, [2]int{x, y - 1})
		}

		// Право
		if x+1 < m.width && m.cells[y][x+1] == Path && !visited[y][x+1] {
			visited[y][x+1] = true
			queue = append(queue, [2]int{x + 1, y})
		}

		// Низ
		if y+1 < m.height && m.cells[y+1][x] == Path && !visited[y+1][x] {
			visited[y+1][x] = true
			queue = append(queue, [2]int{x, y + 1})
		}

		// Лево
		if x > 0 && m.cells[y][x-1] == Path && !visited[y][x-1] {
			visited[y][x-1] = true
			queue = append(queue, [2]int{x - 1, y})
		}
	}

	return false
}

func (m *maze) generate() {
	if m.width < 5 || m.height < 5 {
		for x := 0; x < m.width; x++ {
			m.cells[m.height/2][x] = Path
		}
		return
	}

	m.divide(0, 0, m.width-1, m.height-1)
}

func (m *maze) toBoolGrid() [][]bool {
	result := make([][]bool, m.height)
	for y := 0; y < m.height; y++ {
		row := make([]bool, m.width)
		for x := 0; x < m.width; x++ {
			row[x] = (m.cells[y][x] == Path)
		}
		result[y] = row
	}
	return result
}

func (m *maze) isConnected(startX, startY, goalX, goalY int) bool {
	return m.isConnectedImpl(startX, startY, goalX, goalY)
}

func generateWalkableMaze(width, height int) [][]bool {
	m := newMaze(width, height)
	m.generate()

	startX, startY := 1, 1
	goalX, goalY := width-2, height-2

	if !m.isConnected(startX, startY, goalX, goalY) {
		for x := 0; x < m.width; x++ {
			for y := 0; y < m.height; y++ {
				if x == 1 || y == 1 || x == width-2 || y == height-2 {
					m.cells[y][x] = Path
				}
			}
		}
	}

	return m.toBoolGrid()
}

func (mg *MazeGenerator) Prepare() {
	mg.width = 1001
	mg.height = 1001
}

func (mg *MazeGenerator) Iterations() int { return GetIterations("MazeGenerator") }

func (mg *MazeGenerator) Run() {
	var checksum uint64 = 0

	iters := mg.Iterations()
	for i := 0; i < iters; i++ {
		boolGrid := generateWalkableMaze(mg.width, mg.height)

		for y := 0; y < len(boolGrid); y++ {
			row := boolGrid[y]
			for x := 0; x < len(row); x++ {
				if !row[x] {
					checksum += uint64(x * y)
				}
			}
		}
	}

	mg.result = checksum
}

func (mg *MazeGenerator) Result() uint32 {
	return uint32(mg.result)
}

type AStarPathfinder struct {
	result         uint64
	startX, startY int
	goalX, goalY   int
	width, height  int
	mazeGrid       [][]bool
}

type Heuristic interface {
	distance(aX, aY, bX, bY int) int
}

type ManhattanHeuristic struct{}

func (h ManhattanHeuristic) distance(aX, aY, bX, bY int) int {
	dx := aX - bX
	if dx < 0 {
		dx = -dx
	}
	dy := aY - bY
	if dy < 0 {
		dy = -dy
	}
	return (dx + dy) * 1000
}

type EuclideanHeuristic struct{}

func (h EuclideanHeuristic) distance(aX, aY, bX, bY int) int {
	dx := float64(aX - bX)
	dy := float64(aY - bY)
	return int(math.Sqrt(dx*dx+dy*dy) * 1000.0)
}

type ChebyshevHeuristic struct{}

func (h ChebyshevHeuristic) distance(aX, aY, bX, bY int) int {
	dx := aX - bX
	if dx < 0 {
		dx = -dx
	}
	dy := aY - bY
	if dy < 0 {
		dy = -dy
	}
	if dx > dy {
		return dx * 1000
	}
	return dy * 1000
}

type PNode struct {
	X, Y   int
	fScore int
	index  int
}

type PriorityQueue []*PNode

func (pq PriorityQueue) Len() int { return len(pq) }

func (pq PriorityQueue) Less(i, j int) bool {
	if pq[i].fScore != pq[j].fScore {
		return pq[i].fScore < pq[j].fScore
	}
	if pq[i].Y != pq[j].Y {
		return pq[i].Y < pq[j].Y
	}
	return pq[i].X < pq[j].X
}

func (pq PriorityQueue) Swap(i, j int) {
	pq[i], pq[j] = pq[j], pq[i]
	pq[i].index = i
	pq[j].index = j
}

func (pq *PriorityQueue) Push(x interface{}) {
	n := len(*pq)
	node := x.(*PNode)
	node.index = n
	*pq = append(*pq, node)
}

func (pq *PriorityQueue) Pop() interface{} {
	old := *pq
	n := len(old)
	node := old[n-1]
	old[n-1] = nil
	node.index = -1
	*pq = old[0 : n-1]
	return node
}

func (apf *AStarPathfinder) generateWalkableMaze(width, height int) [][]bool {
	return generateWalkableMaze(width, height)
}

func (apf *AStarPathfinder) ensureMazeGrid() [][]bool {
	if apf.mazeGrid == nil {
		apf.mazeGrid = apf.generateWalkableMaze(apf.width, apf.height)
	}
	return apf.mazeGrid
}

func (apf *AStarPathfinder) findPath(heuristic Heuristic, allowDiagonal bool) [][2]int {
	grid := apf.ensureMazeGrid()

	gScores := make([][]int, apf.height)
	cameFrom := make([][][2]int, apf.height)
	for y := 0; y < apf.height; y++ {
		gScores[y] = make([]int, apf.width)
		cameFrom[y] = make([][2]int, apf.width)
		for x := 0; x < apf.width; x++ {
			gScores[y][x] = math.MaxInt32
			cameFrom[y][x] = [2]int{-1, -1}
		}
	}

	pq := make(PriorityQueue, 0)
	heap.Init(&pq)

	gScores[apf.startY][apf.startX] = 0
	heap.Push(&pq, &PNode{
		X:      apf.startX,
		Y:      apf.startY,
		fScore: heuristic.distance(apf.startX, apf.startY, apf.goalX, apf.goalY),
	})

	directions := [][2]int{{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
	if allowDiagonal {
		directions = append(directions,
			[2]int{-1, -1}, [2]int{1, -1}, [2]int{1, 1}, [2]int{-1, 1})
	}

	diagonalCost := 1414
	if !allowDiagonal {
		diagonalCost = 1000
	}

	for pq.Len() > 0 {
		current := heap.Pop(&pq).(*PNode)

		if current.X == apf.goalX && current.Y == apf.goalY {
			path := make([][2]int, 0)
			x, y := current.X, current.Y

			for x != apf.startX || y != apf.startY {
				path = append(path, [2]int{x, y})
				prev := cameFrom[y][x]
				x, y = prev[0], prev[1]
			}

			path = append(path, [2]int{apf.startX, apf.startY})

			// Reverse the path
			for i, j := 0, len(path)-1; i < j; i, j = i+1, j-1 {
				path[i], path[j] = path[j], path[i]
			}

			return path
		}

		currentG := gScores[current.Y][current.X]

		for _, dir := range directions {
			dx, dy := dir[0], dir[1]
			nx, ny := current.X+dx, current.Y+dy

			if nx < 0 || nx >= apf.width || ny < 0 || ny >= apf.height {
				continue
			}
			if !grid[ny][nx] {
				continue
			}

			moveCost := 1000
			if dx != 0 && dy != 0 {
				moveCost = diagonalCost
			}
			tentativeG := currentG + moveCost

			if tentativeG < gScores[ny][nx] {
				cameFrom[ny][nx] = [2]int{current.X, current.Y}
				gScores[ny][nx] = tentativeG

				fScore := tentativeG + heuristic.distance(nx, ny, apf.goalX, apf.goalY)
				heap.Push(&pq, &PNode{
					X:      nx,
					Y:      ny,
					fScore: fScore,
				})
			}
		}
	}

	return nil
}

func (apf *AStarPathfinder) estimateNodesExplored(heuristic Heuristic, allowDiagonal bool) int {
	grid := apf.ensureMazeGrid()

	gScores := make([][]int, apf.height)
	for y := 0; y < apf.height; y++ {
		gScores[y] = make([]int, apf.width)
		for x := 0; x < apf.width; x++ {
			gScores[y][x] = math.MaxInt32
		}
	}

	pq := make(PriorityQueue, 0)
	heap.Init(&pq)
	closed := make([][]bool, apf.height)
	for y := 0; y < apf.height; y++ {
		closed[y] = make([]bool, apf.width)
	}

	gScores[apf.startY][apf.startX] = 0
	heap.Push(&pq, &PNode{
		X:      apf.startX,
		Y:      apf.startY,
		fScore: heuristic.distance(apf.startX, apf.startY, apf.goalX, apf.goalY),
	})

	directions := [][2]int{{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
	if allowDiagonal {
		directions = append(directions,
			[2]int{-1, -1}, [2]int{1, -1}, [2]int{1, 1}, [2]int{-1, 1})
	}

	nodesExplored := 0

	for pq.Len() > 0 {
		current := heap.Pop(&pq).(*PNode)

		if current.X == apf.goalX && current.Y == apf.goalY {
			break
		}

		if closed[current.Y][current.X] {
			continue
		}

		closed[current.Y][current.X] = true
		nodesExplored++

		currentG := gScores[current.Y][current.X]

		for _, dir := range directions {
			dx, dy := dir[0], dir[1]
			nx, ny := current.X+dx, current.Y+dy

			if nx < 0 || nx >= apf.width || ny < 0 || ny >= apf.height {
				continue
			}
			if !grid[ny][nx] {
				continue
			}

			moveCost := 1000
			if dx != 0 && dy != 0 {
				moveCost = 1414
			}
			tentativeG := currentG + moveCost

			if tentativeG < gScores[ny][nx] {
				gScores[ny][nx] = tentativeG

				fScore := tentativeG + heuristic.distance(nx, ny, apf.goalX, apf.goalY)
				heap.Push(&pq, &PNode{
					X:      nx,
					Y:      ny,
					fScore: fScore,
				})
			}
		}
	}

	return nodesExplored
}

func (apf *AStarPathfinder) benchmarkDifferentApproaches() (int, int, int) {
	heuristics := []Heuristic{
		ManhattanHeuristic{},
		EuclideanHeuristic{},
		ChebyshevHeuristic{},
	}

	totalPathsFound := 0
	totalPathLength := 0
	totalNodesExplored := 0

	for _, heuristic := range heuristics {
		path := apf.findPath(heuristic, false)
		if path != nil {
			totalPathsFound++
			totalPathLength += len(path)
			totalNodesExplored += apf.estimateNodesExplored(heuristic, false)
		}
	}

	return totalPathsFound, totalPathLength, totalNodesExplored
}

func (apf *AStarPathfinder) Prepare() {
	width := GetIterations("AStarPathfinder")
	height := GetIterations("AStarPathfinder")
	apf.width = width
	apf.height = height
	apf.startX = 1
	apf.startY = 1
	apf.goalX = width - 2
	apf.goalY = height - 2
	apf.ensureMazeGrid()
}

func (apf *AStarPathfinder) Iterations() int { return GetIterations("AStarPathfinder") }

func (apf *AStarPathfinder) Run() {
	totalPathsFound := 0
	totalPathLength := 0
	totalNodesExplored := 0

	iters := 10
	for i := 0; i < iters; i++ {
		pathsFound, pathLength, nodesExplored := apf.benchmarkDifferentApproaches()

		totalPathsFound += pathsFound
		totalPathLength += pathLength
		totalNodesExplored += nodesExplored
	}

	pathsChecksum := ChecksumFloat64(float64(totalPathsFound))
	lengthChecksum := ChecksumFloat64(float64(totalPathLength))
	nodesChecksum := ChecksumFloat64(float64(totalNodesExplored))

	apf.result = uint64(pathsChecksum) ^
		(uint64(lengthChecksum) << 16) ^
		(uint64(nodesChecksum) << 32)
}

func (apf *AStarPathfinder) Result() uint32 {
	return uint32(apf.result)
}

// ==================== BWT для Compression ====================
type CompressionBWTResult struct {
	transformed []byte
	originalIdx int
}

// ==================== BWT для Compression (ХОРОШАЯ РЕАЛИЗАЦИЯ) ====================

func compressionBWTTransform(input []byte) CompressionBWTResult {
	n := len(input)
	if n == 0 {
		return CompressionBWTResult{[]byte{}, 0}
	}

	// 1. Создаём удвоенную строку для простого сравнения подстрок
	doubled := make([]byte, n*2)
	copy(doubled, input)
	copy(doubled[n:], input)

	// 2. Создаём и сортируем суффиксный массив
	sa := make([]int, n)
	for i := 0; i < n; i++ {
		sa[i] = i
	}

	// 3. Фаза 0: сортировка по первому символу (Radix sort)
	// Группируем по первому символу
	buckets := make([][]int, 256)
	for _, idx := range sa {
		firstChar := input[idx]
		buckets[firstChar] = append(buckets[firstChar], idx)
	}

	// Собираем обратно
	pos := 0
	for b := 0; b < 256; b++ {
		for _, idx := range buckets[b] {
			sa[pos] = idx
			pos++
		}
	}

	// 4. Фаза 1: сортировка по парам символов
	if n > 1 {
		// Присваиваем ранги по первому символу
		rank := make([]int, n)
		currentRank := 0
		prevChar := input[sa[0]]
		for i := 0; i < n; i++ {
			idx := sa[i]
			if input[idx] != prevChar {
				currentRank++
				prevChar = input[idx]
			}
			rank[idx] = currentRank
		}

		// Сортируем по парам (ранг[i], ранг[i+1])
		k := 1
		for k < n {
			// Создаём пары
			pairs := make([][2]int, n)
			for i := 0; i < n; i++ {
				pairs[i] = [2]int{rank[i], rank[(i+k)%n]}
			}

			// Сортируем индексы по парам
			sort.Slice(sa, func(i, j int) bool {
				a, b := sa[i], sa[j]
				if pairs[a][0] != pairs[b][0] {
					return pairs[a][0] < pairs[b][0]
				}
				return pairs[a][1] < pairs[b][1]
			})

			// Обновляем ранги
			newRank := make([]int, n)
			newRank[sa[0]] = 0
			for i := 1; i < n; i++ {
				prevPair := pairs[sa[i-1]]
				currPair := pairs[sa[i]]
				if prevPair[0] != currPair[0] || prevPair[1] != currPair[1] {
					newRank[sa[i]] = newRank[sa[i-1]] + 1
				} else {
					newRank[sa[i]] = newRank[sa[i-1]]
				}
			}

			rank = newRank
			k *= 2
		}
	}

	// 5. Собираем BWT результат
	transformed := make([]byte, n)
	originalIdx := 0

	for i, suffix := range sa {
		// Последний символ вращения - символ перед суффиксом
		if suffix == 0 {
			transformed[i] = input[n-1]
			originalIdx = i
		} else {
			transformed[i] = input[suffix-1]
		}
	}

	return CompressionBWTResult{transformed, originalIdx}
}

// Обратное BWT преобразование для Compression
func compressionBWTInverse(bwtResult CompressionBWTResult) []byte {
	bwt := bwtResult.transformed
	n := len(bwt)

	if n == 0 {
		return []byte{}
	}

	// 1. Подсчитываем частоты символов
	counts := make([]int, 256)
	for _, b := range bwt {
		counts[b]++
	}

	// 2. Вычисляем стартовые позиции для каждого символа
	positions := make([]int, 256)
	total := 0
	for i := 0; i < 256; i++ {
		positions[i] = total
		total += counts[i]
	}

	// 3. Строим массив next (LF-маппинг)
	next := make([]int, n)
	tempCounts := make([]int, 256)

	for i, b := range bwt {
		byteIdx := int(b)
		pos := positions[byteIdx] + tempCounts[byteIdx]
		next[pos] = i
		tempCounts[byteIdx]++
	}

	// 4. Восстанавливаем исходную строку
	result := make([]byte, n)
	idx := bwtResult.originalIdx

	for i := 0; i < n; i++ {
		idx = next[idx]
		result[i] = bwt[idx]
	}

	return result
}

// ==================== Huffman для Compression ====================
type CompressionHuffmanNode struct {
	frequency int
	byteVal   byte
	isLeaf    bool
	left      *CompressionHuffmanNode
	right     *CompressionHuffmanNode
	index     int // Для heap.Interface
}

// PriorityQueue для Compression Huffman
type CompressionPriorityQueue []*CompressionHuffmanNode

func (pq CompressionPriorityQueue) Len() int { return len(pq) }

func (pq CompressionPriorityQueue) Less(i, j int) bool {
	return pq[i].frequency < pq[j].frequency
}

func (pq CompressionPriorityQueue) Swap(i, j int) {
	pq[i], pq[j] = pq[j], pq[i]
	pq[i].index = i
	pq[j].index = j
}

func (pq *CompressionPriorityQueue) Push(x interface{}) {
	n := len(*pq)
	node := x.(*CompressionHuffmanNode)
	node.index = n
	*pq = append(*pq, node)
}

func (pq *CompressionPriorityQueue) Pop() interface{} {
	old := *pq
	n := len(old)
	node := old[n-1]
	node.index = -1
	*pq = old[0 : n-1]
	return node
}

// Построение дерева Huffman для Compression
func buildCompressionHuffmanTree(frequencies []int) *CompressionHuffmanNode {
	pq := make(CompressionPriorityQueue, 0)
	heap.Init(&pq)

	for i, freq := range frequencies {
		if freq > 0 {
			heap.Push(&pq, &CompressionHuffmanNode{
				frequency: freq,
				byteVal:   byte(i),
				isLeaf:    true,
			})
		}
	}

	// Если только один символ, создаём искусственный узел
	if pq.Len() == 1 {
		node := heap.Pop(&pq).(*CompressionHuffmanNode)
		root := &CompressionHuffmanNode{
			frequency: node.frequency,
			isLeaf:    false,
		}
		root.left = node
		root.right = &CompressionHuffmanNode{
			frequency: 0,
			byteVal:   0,
			isLeaf:    true,
		}
		return root
	}

	// Строим дерево
	for pq.Len() > 1 {
		left := heap.Pop(&pq).(*CompressionHuffmanNode)
		right := heap.Pop(&pq).(*CompressionHuffmanNode)

		parent := &CompressionHuffmanNode{
			frequency: left.frequency + right.frequency,
			isLeaf:    false,
			left:      left,
			right:     right,
		}

		heap.Push(&pq, parent)
	}

	return heap.Pop(&pq).(*CompressionHuffmanNode)
}

// Структура для хранения Compression Huffman кодов
type CompressionHuffmanCodes struct {
	codeLengths [256]int
	codes       [256]int // храним код как int
}

// Построение кодов Compression Huffman
func buildCompressionHuffmanCodes(node *CompressionHuffmanNode, code int, length int, huffmanCodes *CompressionHuffmanCodes) {
	if node.isLeaf {
		if length > 0 || node.byteVal != 0 {
			idx := int(node.byteVal)
			huffmanCodes.codeLengths[idx] = length
			huffmanCodes.codes[idx] = code
		}
	} else {
		if node.left != nil {
			buildCompressionHuffmanCodes(node.left, code<<1, length+1, huffmanCodes)
		}
		if node.right != nil {
			buildCompressionHuffmanCodes(node.right, (code<<1)|1, length+1, huffmanCodes)
		}
	}
}

// Результат кодирования Compression
type CompressionEncodedResult struct {
	data     []byte
	bitCount int
}

// Кодирование Compression Huffman
func huffmanEncodeCompression(data []byte, huffmanCodes *CompressionHuffmanCodes) CompressionEncodedResult {
	// Предварительное выделение с запасом
	result := make([]byte, len(data)*2)
	currentByte := byte(0)
	bitPos := 0
	byteIndex := 0
	totalBits := 0

	for _, b := range data {
		idx := int(b)
		code := huffmanCodes.codes[idx]
		length := huffmanCodes.codeLengths[idx]

		// Копируем биты из code
		for i := length - 1; i >= 0; i-- {
			if (code & (1 << i)) != 0 {
				currentByte |= 1 << (7 - bitPos)
			}
			bitPos++
			totalBits++

			if bitPos == 8 {
				result[byteIndex] = currentByte
				byteIndex++
				currentByte = 0
				bitPos = 0
			}
		}
	}

	// Последний неполный байт
	if bitPos > 0 {
		result[byteIndex] = currentByte
		byteIndex++
	}

	return CompressionEncodedResult{result[:byteIndex], totalBits}
}

// Декодирование Compression Huffman
func huffmanDecodeCompression(encoded []byte, root *CompressionHuffmanNode, bitCount int) []byte {
	result := make([]byte, 0, bitCount/4+1)
	currentNode := root
	bitsProcessed := 0
	byteIndex := 0

	for bitsProcessed < bitCount && byteIndex < len(encoded) {
		byteVal := encoded[byteIndex]
		byteIndex++

		for bitPos := 7; bitPos >= 0 && bitsProcessed < bitCount; bitPos-- {
			bit := ((byteVal >> bitPos) & 1) == 1
			bitsProcessed++

			if bit {
				currentNode = currentNode.right
			} else {
				currentNode = currentNode.left
			}

			if currentNode.isLeaf {
				if currentNode.byteVal != 0 {
					result = append(result, currentNode.byteVal)
				}
				currentNode = root
			}
		}
	}

	return result
}

// ==================== Компрессор ====================
type CompressionCompressedData struct {
	bwtResult        CompressionBWTResult
	frequencies      [256]int
	encodedBits      []byte
	originalBitCount int
}

// Сжатие
func compressData(data []byte) CompressionCompressedData {
	// 1. BWT преобразование
	bwtResult := compressionBWTTransform(data)

	// 2. Подсчёт частот
	var frequencies [256]int
	for _, b := range bwtResult.transformed {
		frequencies[b]++
	}

	// 3. Построение дерева Huffman
	huffmanTree := buildCompressionHuffmanTree(frequencies[:])

	// 4. Построение кодов
	var huffmanCodes CompressionHuffmanCodes
	buildCompressionHuffmanCodes(huffmanTree, 0, 0, &huffmanCodes)

	// 5. Кодирование
	encoded := huffmanEncodeCompression(bwtResult.transformed, &huffmanCodes)

	return CompressionCompressedData{
		bwtResult:        bwtResult,
		frequencies:      frequencies,
		encodedBits:      encoded.data,
		originalBitCount: encoded.bitCount,
	}
}

// Распаковка
func decompressData(compressed CompressionCompressedData) []byte {
	// 1. Восстанавливаем дерево Huffman
	huffmanTree := buildCompressionHuffmanTree(compressed.frequencies[:])

	// 2. Декодирование Huffman
	decoded := huffmanDecodeCompression(
		compressed.encodedBits,
		huffmanTree,
		compressed.originalBitCount,
	)

	// 3. Обратное BWT
	bwtResult := CompressionBWTResult{
		transformed: decoded,
		originalIdx: compressed.bwtResult.originalIdx,
	}

	return compressionBWTInverse(bwtResult)
}

// ==================== Бенчмарк Compression ====================
type Compression struct {
	iterations int
	result     int64
	testData   []byte
}

func NewCompressionBenchmark() *Compression {
	iterations := GetIterations("Compression")
	return &Compression{
		iterations: iterations,
		result:     0,
	}
}

// Генерация тестовых данных
func (c *Compression) generateTestData(size int) []byte {
	pattern := []byte("ABRACADABRA")
	data := make([]byte, size)

	for i := 0; i < size; i++ {
		data[i] = pattern[i%len(pattern)]
	}

	return data
}

func (c *Compression) Prepare() {
	c.iterations = GetIterations("Compression")
	c.result = 0
	c.testData = c.generateTestData(c.iterations)
}

func (c *Compression) Iterations() int {
	return c.iterations
}

func (c *Compression) Run() {
	var totalChecksum uint32

	for i := 0; i < 5; i++ {
		// Компрессия
		compressed := compressData(c.testData)

		// Декомпрессия
		decompressed := decompressData(compressed)

		// Подсчёт checksum
		checksum := ChecksumBytes(decompressed)

		totalChecksum = totalChecksum + uint32(len(compressed.encodedBits))
		totalChecksum = totalChecksum + checksum
	}

	c.result = int64(totalChecksum)
}

func (c *Compression) Result() uint32 {
	return uint32(c.result & 0xFFFFFFFF)
}

// ========== main функция ==========
func main() {
	if len(os.Args) > 1 {
		LoadConfig(os.Args[1])
	} else {
		LoadConfig("")
	}

	if len(os.Args) > 2 {
		RunBenchmarks(os.Args[2])
	} else {
		RunBenchmarks("")
	}
}
