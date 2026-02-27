package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math"
	"math/big"
	"os"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

type CfgNumber struct {
	IntValue    int64
	StringValue string
	IsInt       bool
}

func (n *CfgNumber) UnmarshalJSON(data []byte) error {
	str := string(data)

	if i, err := strconv.ParseInt(str, 10, 64); err == nil {
		n.IntValue = i
		n.IsInt = true
		return nil
	}

	n.StringValue = str
	n.IsInt = false
	return nil
}

var (
	CONFIG = make(map[string]map[string]CfgNumber)
)

const (
	IM   = int64(139968)
	IA   = int64(3877)
	IC   = int64(29573)
	INIT = int64(42)
)

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
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

func NextFloat(max float64) float64 {
	*global = (*global*IA + IC) % IM
	return max * float64(*global) / float64(IM)
}

func Checksum(v string) uint32 {
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
		filename = "../test.js"
	}

	data, err := os.ReadFile(filename)
	if err != nil {
		panic(err)
	}

	err = json.Unmarshal(data, &CONFIG)
	if err != nil {
		panic(err)
	}
}

func configI64(class_name, field_name string) int64 {
	if cfg, ok := CONFIG[class_name]; ok {
		if n, ok := cfg[field_name]; ok {
			if n.IsInt {
				return n.IntValue
			} else {
				panic(fmt.Sprintf("Config for %s, not found i64 field: %s, found %s", class_name, field_name, n.StringValue))
			}
		}
		panic(fmt.Sprintf("Config for %s, not found i64 field: %s", class_name, field_name))
	}
	panic(fmt.Sprintf("Config not found class %s", class_name))
}

func configS(class_name, field_name string) string {
	if cfg, ok := CONFIG[class_name]; ok {
		if n, ok := cfg[field_name]; ok {
			if !n.IsInt {
				return n.StringValue
			} else {
				panic(fmt.Sprintf("Config for %s, not found string field: %s, found %d", class_name, field_name, n.IntValue))
			}
		}
		panic(fmt.Sprintf("Config for %s, not found string field: %s", class_name, field_name))
	}
	panic(fmt.Sprintf("Config not found class %s", class_name))
}

type Benchmark interface {
	Prepare()
	Run(int)
	Name() string
	Warmup(Benchmark)
	Checksum() uint32
	Iterations() int
	WarmupIterations() int
	ExpectedChecksum() int64
}

type BaseBenchmark struct {
	className string
}

func (b *BaseBenchmark) ConfigVal(field string) int64 {
	return configI64(b.className, field)
}

func (b *BaseBenchmark) ConfigStr(field string) string {
	return configS(b.className, field)
}

func (b *BaseBenchmark) WarmupIterations() int {
	if cfg, ok := CONFIG[b.className]; ok {
		if n, ok := cfg["warmup_iterations"]; ok {
			if n.IsInt {
				return int(n.IntValue)
			}
		}
	}

	iter := b.Iterations()
	warmup := int(float64(iter) * 0.2)
	if warmup < 1 {
		warmup = 1
	}
	return warmup
}

func Warmup(bench Benchmark) {
	bench.Warmup(bench)
}

func (b *BaseBenchmark) Prepare() {
}

func (b *BaseBenchmark) Name() string {
	return b.className
}

func (b *BaseBenchmark) Warmup(bench Benchmark) {
	wi := b.WarmupIterations()
	for i := 0; i < wi; i++ {
		bench.Run(i)
	}
}

func (b *BaseBenchmark) Run(iteration_id int) {
}

func (b *BaseBenchmark) Checksum() uint32 {
	return 0
}

func (b *BaseBenchmark) Iterations() int {
	return int(b.ConfigVal("iterations"))
}

func RunAll(bench Benchmark) {
	for i := 0; i < bench.Iterations(); i++ {
		bench.Run(i)
	}
}

func (b *BaseBenchmark) ExpectedChecksum() int64 {
	return b.ConfigVal("checksum")
}

func RunBenchmarks(singleBench string) {
	fmt.Printf("start: %d\n", time.Now().UnixMilli())

	results := make(map[string]float64)
	summaryTime := 0.0
	ok := 0
	fails := 0

	singleBench = strings.ToLower(singleBench)

	allBenches := []Benchmark{
		&Pidigits{BaseBenchmark: BaseBenchmark{className: "CLBG::Pidigits"}},
		&BinarytreesObj{BaseBenchmark: BaseBenchmark{className: "Binarytrees::Obj"}},
		&BinarytreesArena{BaseBenchmark: BaseBenchmark{className: "Binarytrees::Arena"}},
		&BrainfuckArray{BaseBenchmark: BaseBenchmark{className: "Brainfuck::Array"}},
		&BrainfuckRecursion{BaseBenchmark: BaseBenchmark{className: "Brainfuck::Recursion"}},
		&Fannkuchredux{BaseBenchmark: BaseBenchmark{className: "CLBG::Fannkuchredux"}},
		&Fasta{BaseBenchmark: BaseBenchmark{className: "CLBG::Fasta"}},
		&Knuckeotide{BaseBenchmark: BaseBenchmark{className: "CLBG::Knuckeotide"}},
		&Mandelbrot{BaseBenchmark: BaseBenchmark{className: "CLBG::Mandelbrot"}},
		&Matmul1T{BaseMatmul{BaseBenchmark: BaseBenchmark{className: "Matmul::Single"}}},
		&Matmul4T{BaseMatmul{BaseBenchmark: BaseBenchmark{className: "Matmul::T4"}}},
		&Matmul8T{BaseMatmul{BaseBenchmark: BaseBenchmark{className: "Matmul::T8"}}},
		&Matmul16T{BaseMatmul{BaseBenchmark: BaseBenchmark{className: "Matmul::T16"}}},
		&Nbody{BaseBenchmark: BaseBenchmark{className: "CLBG::Nbody"}},
		&RegexDna{BaseBenchmark: BaseBenchmark{className: "CLBG::RegexDna"}},
		&Revcomp{BaseBenchmark: BaseBenchmark{className: "CLBG::Revcomp"}},
		&Spectralnorm{BaseBenchmark: BaseBenchmark{className: "CLBG::Spectralnorm"}},
		&Base64Encode{BaseBenchmark: BaseBenchmark{className: "Base64::Encode"}},
		&Base64Decode{BaseBenchmark: BaseBenchmark{className: "Base64::Decode"}},
		&JsonGenerate{BaseBenchmark: BaseBenchmark{className: "Json::Generate"}},
		&JsonParseDom{BaseBenchmark: BaseBenchmark{className: "Json::ParseDom"}},
		&JsonParseMapping{BaseBenchmark: BaseBenchmark{className: "Json::ParseMapping"}},
		&Sieve{BaseBenchmark: BaseBenchmark{className: "Etc::Sieve"}},
		&TextRaytracer{BaseBenchmark: BaseBenchmark{className: "Etc::TextRaytracer"}},
		&NeuralNet{BaseBenchmark: BaseBenchmark{className: "Etc::NeuralNet"}},
		&SortQuick{BaseBenchmark: BaseBenchmark{className: "Sort::Quick"}},
		&SortMerge{BaseBenchmark: BaseBenchmark{className: "Sort::Merge"}},
		&SortSelf{BaseBenchmark: BaseBenchmark{className: "Sort::Self"}},
		&GraphPathBFS{BaseBenchmark: BaseBenchmark{className: "Graph::BFS"}},
		&GraphPathDFS{BaseBenchmark: BaseBenchmark{className: "Graph::DFS"}},
		&GraphPathAStar{BaseBenchmark: BaseBenchmark{className: "Graph::AStar"}},
		&BufferHashSHA256{BaseBenchmark: BaseBenchmark{className: "Hash::SHA256"}},
		&BufferHashCRC32{BaseBenchmark: BaseBenchmark{className: "Hash::CRC32"}},
		&CacheSimulation{BaseBenchmark: BaseBenchmark{className: "Etc::CacheSimulation"}},
		&CalculatorAst{BaseBenchmark: BaseBenchmark{className: "Calculator::Ast"}},
		&CalculatorInterpreter{BaseBenchmark: BaseBenchmark{className: "Calculator::Interpreter"}},
		&GameOfLife{BaseBenchmark: BaseBenchmark{className: "Etc::GameOfLife"}},
		&MazeGenerator{BaseBenchmark: BaseBenchmark{className: "Maze::Generator"}},
		&MazeBFS{BaseBenchmark: BaseBenchmark{className: "Maze::BFS"}},
		&MazeAStar{BaseBenchmark: BaseBenchmark{className: "Maze::AStar"}},
		&BWTEncode{BaseBenchmark: BaseBenchmark{className: "Compress::BWTEncode"}},
		&BWTDecode{BaseBenchmark: BaseBenchmark{className: "Compress::BWTDecode"}},
		&HuffEncode{BaseBenchmark: BaseBenchmark{className: "Compress::HuffEncode"}},
		&HuffDecode{BaseBenchmark: BaseBenchmark{className: "Compress::HuffDecode"}},
		&ArithEncode{BaseBenchmark: BaseBenchmark{className: "Compress::ArithEncode"}},
		&ArithDecode{BaseBenchmark: BaseBenchmark{className: "Compress::ArithDecode"}},
		&LZWEncode{BaseBenchmark: BaseBenchmark{className: "Compress::LZWEncode"}},
		&LZWDecode{BaseBenchmark: BaseBenchmark{className: "Compress::LZWDecode"}},
		&Jaro{BaseBenchmark: BaseBenchmark{className: "Distance::Jaro"}},
		&NGram{BaseBenchmark: BaseBenchmark{className: "Distance::NGram"}},
		&Words{BaseBenchmark: BaseBenchmark{className: "Etc::Words"}},
	}

	for _, bench := range allBenches {
		className := bench.Name()

		if className == "SortBenchmark" || className == "BufferHashBenchmark" || className == "GraphPathBenchmark" {
			continue
		}

		if singleBench != "" && !strings.Contains(strings.ToLower(className), singleBench) {
			continue
		}

		fmt.Printf("%s: ", className)

		Reset()
		bench.Prepare()
		Warmup(bench)
		runtime.GC()

		Reset()

		start := time.Now()
		RunAll(bench)
		elapsed := time.Since(start).Seconds()
		results[className] = elapsed

		chks := bench.Checksum()
		expected := uint32(bench.ExpectedChecksum())

		if chks == expected {
			fmt.Printf("OK ")
			ok++
		} else {
			fmt.Printf("ERR[actual=%d, expected=%d] ", chks, expected)
			fails++
		}

		runtime.GC()

		fmt.Printf("in %.3fs\n", elapsed)
		summaryTime += elapsed
	}

	jsonData, _ := json.Marshal(results)
	os.WriteFile("/tmp/results.js", jsonData, 0644)

	fmt.Printf("Summary: %.4fs, %d, %d, %d\n", summaryTime, ok+fails, ok, fails)

	os.WriteFile("/tmp/recompile_marker", []byte("RECOMPILE_MARKER_0"), 0644)
	if fails > 0 {
		os.Exit(1)
	}
}

type Pidigits struct {
	BaseBenchmark
	nn     int
	result strings.Builder
}

func (p *Pidigits) Prepare() {
	p.nn = int(p.ConfigVal("amount"))
}

func (p *Pidigits) Run(iteration_id int) {
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

func (p *Pidigits) Checksum() uint32 {
	return Checksum(p.result.String())
}

type TreeNodeObj struct {
	left  *TreeNodeObj
	right *TreeNodeObj
	item  int
}

func NewTreeNodeObj(item, depth int) *TreeNodeObj {
	node := &TreeNodeObj{item: item}
	if depth > 0 {
		shift := 1 << (depth - 1)
		node.left = NewTreeNodeObj(item-shift, depth-1)
		node.right = NewTreeNodeObj(item+shift, depth-1)
	}
	return node
}

func (t *TreeNodeObj) Sum() uint32 {
	total := uint32(t.item) + 1
	if t.left != nil {
		total += t.left.Sum()
	}
	if t.right != nil {
		total += t.right.Sum()
	}
	return total
}

type BinarytreesObj struct {
	BaseBenchmark
	n      int64
	result uint32
}

func (b *BinarytreesObj) Prepare() {
	b.n = b.ConfigVal("depth")
	b.result = 0
}

func (b *BinarytreesObj) Run(iteration_id int) {
	root := NewTreeNodeObj(0, int(b.n))
	b.result += root.Sum()

}

func (b *BinarytreesObj) Checksum() uint32 {
	return b.result
}

type TreeNodeArena struct {
	item  int
	left  int
	right int
}

type TreeArena struct {
	nodes []TreeNodeArena
}

func NewTreeArena() *TreeArena {
	return &TreeArena{
		nodes: make([]TreeNodeArena, 0),
	}
}

func (a *TreeArena) Build(item, depth int) int {
	idx := len(a.nodes)
	a.nodes = append(a.nodes, TreeNodeArena{item: item, left: -1, right: -1})

	if depth > 0 {
		shift := 1 << (depth - 1)
		leftIdx := a.Build(item-shift, depth-1)
		rightIdx := a.Build(item+shift, depth-1)
		a.nodes[idx].left = leftIdx
		a.nodes[idx].right = rightIdx
	}

	return idx
}

func (a *TreeArena) Sum(idx int) uint32 {
	node := a.nodes[idx]
	total := uint32(node.item) + 1

	if node.left >= 0 {
		total += a.Sum(node.left)
	}
	if node.right >= 0 {
		total += a.Sum(node.right)
	}

	return total
}

type BinarytreesArena struct {
	BaseBenchmark
	n      int64
	result uint32
}

func (b *BinarytreesArena) Prepare() {
	b.n = b.ConfigVal("depth")
	b.result = 0
}

func (b *BinarytreesArena) Run(iteration_id int) {
	arena := NewTreeArena()
	rootIdx := arena.Build(0, int(b.n))
	b.result += arena.Sum(rootIdx)
}

func (b *BinarytreesArena) Checksum() uint32 {
	return b.result
}

type Tape struct {
	tape []byte
	pos  int
}

func NewTape() Tape {
	return Tape{tape: make([]byte, 30000), pos: 0}
}

func (t *Tape) Get() byte { return t.tape[t.pos] }

func (t *Tape) Inc() {
	t.tape[t.pos] = t.tape[t.pos] + 1
}

func (t *Tape) Dec() {
	t.tape[t.pos] = t.tape[t.pos] - 1
}

func (t *Tape) Advance() {
	t.pos++
	if t.pos >= len(t.tape) {
		t.tape = append(t.tape, 0)
	}
}

func (t *Tape) Devance() {
	if t.pos > 0 {
		t.pos--
	}
}

type Program struct {
	commands []byte
	jumps    []int
}

func NewProgram(text string) *Program {

	commands := make([]byte, 0, len(text))
	for i := 0; i < len(text); i++ {
		c := text[i]

		switch c {
		case '[', ']', '<', '>', '+', '-', ',', '.':
			commands = append(commands, c)
		}
	}

	jumps := make([]int, len(commands))
	stack := make([]int, 0, len(commands)/2)

	for i, cmd := range commands {
		switch cmd {
		case '[':
			stack = append(stack, i)
		case ']':
			if len(stack) > 0 {
				start := stack[len(stack)-1]
				stack = stack[:len(stack)-1]
				jumps[start] = i
				jumps[i] = start
			}
		}
	}

	return &Program{commands: commands, jumps: jumps}
}

func (p *Program) Run() int64 {
	result := int64(0)
	tape := NewTape()
	pc := 0
	cmds := p.commands
	jumps := p.jumps

	for pc < len(cmds) {
		switch cmds[pc] {
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
				pc = jumps[pc]
				continue
			}
		case ']':
			if tape.Get() != 0 {
				pc = jumps[pc]
				continue
			}
		case '.':
			result = (result << 2) + int64(tape.Get())
		}
		pc++
	}
	return result
}

type BrainfuckArray struct {
	BaseBenchmark
	programText string
	warmupText  string
	result      uint32
}

func (b *BrainfuckArray) Name() string {
	return "Brainfuck::Array"
}

func (b *BrainfuckArray) Prepare() {
	b.programText = b.ConfigStr("program")
	b.warmupText = b.ConfigStr("warmup_program")
	b.result = 0
}

func (b *BrainfuckArray) _Run(text string) int64 {
	return NewProgram(text).Run()
}

func (b *BrainfuckArray) Warmup(bench Benchmark) {
	wi := b.WarmupIterations()
	for i := 0; i < wi; i++ {
		b._Run(b.warmupText)
	}
}

func (b *BrainfuckArray) Run(iteration_id int) {
	runResult := b._Run(b.programText)
	b.result += uint32(runResult)
}

func (b *BrainfuckArray) Checksum() uint32 {
	return b.result
}

type Op interface{}
type IncOp struct{}
type DecOp struct{}
type NextOp struct{}
type PrevOp struct{}
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
			res = append(res, IncOp{})
		case '-':
			res = append(res, DecOp{})
		case '>':
			res = append(res, NextOp{})
		case '<':
			res = append(res, PrevOp{})
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
	tape := Tape2{tape: make([]byte, 30000)}
	p.result = 0
	p.runOps(p.ops, &tape)
}

func (p *Program2) runOps(ops []Op, tape *Tape2) {
	for _, op := range ops {
		switch o := op.(type) {
		case IncOp:
			tape.Inc()
		case DecOp:
			tape.Dec()
		case NextOp:
			tape.Next()
		case PrevOp:
			tape.Prev()
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
	pos  int
}

func NewTape2() *Tape2 {
	return &Tape2{
		tape: make([]byte, 30000),
		pos:  0,
	}
}

func (t *Tape2) Get() byte {
	return t.tape[t.pos]
}

func (t *Tape2) Inc() {
	t.tape[t.pos]++
}

func (t *Tape2) Dec() {
	t.tape[t.pos]--
}

func (t *Tape2) Next() {
	t.pos++
	if t.pos >= len(t.tape) {
		t.tape = append(t.tape, 0)
	}
}

func (t *Tape2) Prev() {
	if t.pos > 0 {
		t.pos--
	}
}

type BrainfuckRecursion struct {
	BaseBenchmark
	text   string
	result uint32
}

func (b *BrainfuckRecursion) Name() string {
	return "Brainfuck::Recursion"
}

func (b *BrainfuckRecursion) Prepare() {
	b.text = b.ConfigStr("program")
	b.result = 0
}

func (b *BrainfuckRecursion) _Run(text string) int64 {
	prog := NewProgram2(text)
	prog.Run()
	return prog.result
}

func (b *BrainfuckRecursion) Warmup(bench Benchmark) {
	warmupProgram := b.ConfigStr("warmup_program")
	wi := b.WarmupIterations()
	for i := 0; i < wi; i++ {
		b._Run(warmupProgram)
	}
}

func (b *BrainfuckRecursion) Run(iteration_id int) {
	result := b._Run(b.text)
	b.result = (b.result + uint32(result)) & 0xFFFFFFFF
}

func (b *BrainfuckRecursion) Checksum() uint32 {
	return b.result
}

type Fannkuchredux struct {
	BaseBenchmark
	n      int64
	result uint32
}

func (f *Fannkuchredux) Prepare() {
	f.n = f.ConfigVal("n")
}

func (f *Fannkuchredux) fannkuchredux(n int) (int, int) {
	var perm1 [32]int
	for i := range perm1[:n] {
		perm1[i] = i
	}
	var perm [32]int
	var count [32]int
	maxFlipsCount := 0
	permCount := 0
	checksum := 0
	r := n

	for {
		for r > 1 {
			count[r-1] = r
			r--
		}

		copy(perm[:n], perm1[:n])
		flipsCount := 0

		k := perm[0]
		for k != 0 {

			i := 0
			j := k
			for i < j {
				perm[i], perm[j] = perm[j], perm[i]
				i++
				j--
			}
			flipsCount++
			k = perm[0]
		}

		if flipsCount > maxFlipsCount {
			maxFlipsCount = flipsCount
		}

		if permCount&1 == 0 {
			checksum += flipsCount
		} else {
			checksum -= flipsCount
		}

		for {
			if r == n {
				return checksum, maxFlipsCount
			}

			first := perm1[0]
			copy(perm1[:r], perm1[1:r+1])
			perm1[r] = first

			count[r]--
			if count[r] > 0 {
				break
			}
			r++
		}
		permCount++
	}
}

func (f *Fannkuchredux) Run(iteration_id int) {
	a, b := f.fannkuchredux(int(f.n))
	f.result += uint32(a)*100 + uint32(b)
}

func (f *Fannkuchredux) Checksum() uint32 {
	return f.result
}

type Gene struct {
	char byte
	prob float64
}

type Fasta struct {
	BaseBenchmark
	n      int64
	result strings.Builder
}

func (f *Fasta) Prepare() {
	f.n = f.ConfigVal("n")
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

func (f *Fasta) Run(iteration_id int) {
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

	f.makeRepeatFasta("ONE", "Homo sapiens alu", alu, int(f.n)*2)
	f.makeRandomFasta("TWO", "IUB ambiguity codes", iub, int(f.n)*3)
	f.makeRandomFasta("THREE", "Homo sapiens frequency", homo, int(f.n)*5)
}

func (f *Fasta) Checksum() uint32 {
	return Checksum(f.result.String())
}

type Knuckeotide struct {
	BaseBenchmark
	seq    string
	result strings.Builder
}

func (k *Knuckeotide) Prepare() {
	f := &Fasta{BaseBenchmark: BaseBenchmark{className: "CLBG::Knuckeotide"}}
	f.n = k.ConfigVal("n")
	f.Prepare()
	f.Run(0)
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

func (k *Knuckeotide) Run(iteration_id int) {
	for i := 1; i <= 2; i++ {
		k.sortByFreq(k.seq, i)
	}

	for _, s := range []string{"ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt"} {
		k.findSeq(k.seq, s)
	}
}

func (k *Knuckeotide) Checksum() uint32 {
	return Checksum(k.result.String())
}

type Mandelbrot struct {
	BaseBenchmark
	w      int64
	h      int64
	result bytes.Buffer
}

func (m *Mandelbrot) Prepare() {
	m.w = m.ConfigVal("w")
	m.h = m.ConfigVal("h")
}

func (m *Mandelbrot) Run(iteration_id int) {
	const ITER = 50
	const LIMIT = 2.0

	w := int(m.w)
	h := int(m.h)

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

func (m *Mandelbrot) Checksum() uint32 {
	return ChecksumBytes(m.result.Bytes())
}

func matgen(n int) [][]float64 {
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

func transpose(b [][]float64) [][]float64 {
	n := len(b)
	bT := make([][]float64, n)
	for i := range bT {
		bT[i] = make([]float64, n)
		for j := 0; j < n; j++ {
			bT[i][j] = b[j][i]
		}
	}
	return bT
}

func matmulSequential(a, b [][]float64) [][]float64 {
	n := len(a)
	bT := transpose(b)

	c := make([][]float64, n)
	for i := range c {
		c[i] = make([]float64, n)
		ai := a[i]
		ci := c[i]

		for j := 0; j < n; j++ {
			s := 0.0
			bTj := bT[j]

			for k := 0; k < n; k++ {
				s += ai[k] * bTj[k]
			}
			ci[j] = s
		}
	}
	return c
}

func matmulParallel(a, b [][]float64, numThreads int) [][]float64 {
	n := len(a)
	bT := transpose(b)

	c := make([][]float64, n)
	for i := range c {
		c[i] = make([]float64, n)
	}

	runtime.GOMAXPROCS(numThreads)

	var wg sync.WaitGroup
	workCh := make(chan int, n)

	for w := 0; w < numThreads; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range workCh {
				ai := a[i]
				ci := c[i]
				for j := 0; j < n; j++ {
					sum := 0.0
					bTj := bT[j]

					for k := 0; k < n; k++ {
						sum += ai[k] * bTj[k]
					}
					ci[j] = sum
				}
			}
		}()
	}

	for i := 0; i < n; i++ {
		workCh <- i
	}
	close(workCh)

	wg.Wait()
	return c
}

type BaseMatmul struct {
	BaseBenchmark
	n      int64
	result uint32
	a      [][]float64
	b      [][]float64
}

func (m *BaseMatmul) Prepare() {
	m.n = m.ConfigVal("n")
	n := int(m.n)
	m.a = matgen(n)
	m.b = matgen(n)
}

type Matmul1T struct {
	BaseMatmul
}

func (m *Matmul1T) Run(iteration_id int) {
	c := matmulSequential(m.a, m.b)
	m.result += ChecksumFloat64(c[m.n>>1][m.n>>1])
}

func (m *Matmul1T) Checksum() uint32 {
	return m.result
}

func (m *Matmul1T) name() string {
	return "Matmul::Single"
}

type Matmul4T struct {
	BaseMatmul
}

func (m *Matmul4T) Run(iteration_id int) {
	c := matmulParallel(m.a, m.b, 4)
	m.result += ChecksumFloat64(c[m.n>>1][m.n>>1])
}

func (m *Matmul4T) Checksum() uint32 {
	return m.result
}

func (m *Matmul4T) name() string {
	return "Matmul::T4"
}

type Matmul8T struct {
	BaseMatmul
}

func (m *Matmul8T) Run(iteration_id int) {
	c := matmulParallel(m.a, m.b, 8)
	m.result += ChecksumFloat64(c[m.n>>1][m.n>>1])
}

func (m *Matmul8T) Checksum() uint32 {
	return m.result
}

func (m *Matmul8T) name() string {
	return "Matmul::T8"
}

type Matmul16T struct {
	BaseMatmul
}

func (m *Matmul16T) Run(iteration_id int) {
	c := matmulParallel(m.a, m.b, 16)
	m.result += ChecksumFloat64(c[m.n>>1][m.n>>1])
}

func (m *Matmul16T) Checksum() uint32 {
	return m.result
}

func (m *Matmul16T) name() string {
	return "Matmul::T16"
}

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

func (p *Planet) MoveFromI(bodies []*Planet, dt float64, start int) {
	for i := start; i < len(bodies); i++ {
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
	BaseBenchmark
	body []*Planet
	v1   float64
}

func (n *Nbody) Prepare() {
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
	n.offsetMomentum()
	n.v1 = n.energy()
}

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

func (n *Nbody) Run(iteration_id int) {
	for k := 0; k < 1000; k += 1 {
		for i, b := range n.body {
			b.MoveFromI(n.body, 0.01, i+1)
		}
	}
}

func (n *Nbody) Checksum() uint32 {
	v2 := n.energy()
	return (ChecksumFloat64(n.v1) << 5) & ChecksumFloat64(v2)
}

type RegexDna struct {
	BaseBenchmark
	seq    string
	ilen   int
	clen   int
	result strings.Builder
}

func (r *RegexDna) Prepare() {
	f := &Fasta{BaseBenchmark: BaseBenchmark{className: "CLBG::RegexDna"}}
	f.n = r.ConfigVal("n")
	f.Prepare()
	f.Run(0)
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

func (r *RegexDna) Run(iteration_id int) {
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

func (r *RegexDna) Checksum() uint32 {
	return Checksum(r.result.String())
}

type Revcomp struct {
	BaseBenchmark
	input  string
	result uint32
}

func (r *Revcomp) Prepare() {
	f := &Fasta{BaseBenchmark: BaseBenchmark{className: "CLBG::Revcomp"}}
	f.n = r.ConfigVal("n")
	f.Prepare()
	f.Run(0)
	input := f.result.String()

	seq := strings.Builder{}

	for _, line := range strings.Split(input, "\n") {
		if strings.HasPrefix(line, ">") {
			seq.WriteString("\n---\n")
		} else {
			seq.WriteString(strings.TrimSpace(line))
		}
	}
	r.input = seq.String()
	r.result = 0
}

func (r *Revcomp) revcomp(seq string) string {

	bytes := []byte(seq)
	n := len(bytes)

	for i, j := 0, n-1; i < j; i, j = i+1, j-1 {
		bytes[i], bytes[j] = bytes[j], bytes[i]
	}

	var lookup [256]byte
	for i := range lookup {
		lookup[i] = byte(i)
	}

	from := "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
	to := "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"
	for i := 0; i < len(from); i++ {
		lookup[from[i]] = to[i]
	}

	for i := range bytes {
		bytes[i] = lookup[bytes[i]]
	}

	var result strings.Builder
	result.Grow(n + (n / 60) + 1)

	for i := 0; i < n; i += 60 {
		end := i + 60
		if end > n {
			end = n
		}
		result.Write(bytes[i:end])
		result.WriteByte('\n')
	}

	return result.String()
}

func (r *Revcomp) Run(iteration_id int) {
	r.result += Checksum(r.revcomp(r.input))
}

func (r *Revcomp) Checksum() uint32 {
	return r.result
}

type Spectralnorm struct {
	BaseBenchmark
	size   int64
	result uint32
	u      []float64
	v      []float64
}

func (s *Spectralnorm) Prepare() {
	s.size = s.ConfigVal("size")
	s.u = make([]float64, s.size)
	s.v = make([]float64, s.size)
	for i := range s.u {
		s.u[i] = 1.0
		s.v[i] = 1.0
	}
}

func (s *Spectralnorm) evalA(i, j int) float64 {
	return 1.0 / (float64((i+j)*(i+j+1))/2.0 + float64(i) + 1.0)
}

func (s *Spectralnorm) evalA_times_u(u []float64) []float64 {
	n := len(u)
	v := make([]float64, n)

	for i := range v {
		sum := 0.0
		for j, uj := range u {
			sum += s.evalA(i, j) * uj
		}
		v[i] = sum
	}

	return v
}

func (s *Spectralnorm) evalAt_times_u(u []float64) []float64 {
	n := len(u)
	v := make([]float64, n)

	for i := range v {
		sum := 0.0
		for j, uj := range u {
			sum += s.evalA(j, i) * uj
		}
		v[i] = sum
	}
	return v
}

func (s *Spectralnorm) evalAtA_times_u(u []float64) []float64 {
	return s.evalAt_times_u(s.evalA_times_u(u))
}

func (s *Spectralnorm) Run(iteration_id int) {
	s.v = s.evalAtA_times_u(s.u)
	s.u = s.evalAtA_times_u(s.v)
}

func (s *Spectralnorm) Checksum() uint32 {
	vBv := 0.0
	vv := 0.0
	for i := 0; i < int(s.size); i++ {
		vBv += s.u[i] * s.v[i]
		vv += s.v[i] * s.v[i]
	}
	return ChecksumFloat64(math.Sqrt(vBv / vv))
}

type Base64Encode struct {
	BaseBenchmark
	n      int64
	bytes  []byte
	str2   string
	result uint32
}

func (b *Base64Encode) Prepare() {
	b.n = b.ConfigVal("size")
	b.bytes = []byte(strings.Repeat("a", int(b.n)))
}

func (b *Base64Encode) Run(iteration_id int) {
	b.str2 = base64.StdEncoding.EncodeToString(b.bytes)
	b.result += uint32(len(b.str2))
}

func (b *Base64Encode) Checksum() uint32 {
	resultStr := fmt.Sprintf("encode %s... to %s...: %d",
		string(b.bytes[:min(4, len(b.bytes))]),
		b.str2[:min(4, len(b.str2))],
		b.result)
	return Checksum(resultStr)
}

type Base64Decode struct {
	BaseBenchmark
	n      int64
	str2   string
	bytes  []byte
	result uint32
}

func (b *Base64Decode) Prepare() {
	b.n = b.ConfigVal("size")
	str := strings.Repeat("a", int(b.n))
	b.str2 = base64.StdEncoding.EncodeToString([]byte(str))
}

func (b *Base64Decode) Run(iteration_id int) {
	b.bytes, _ = base64.StdEncoding.DecodeString(b.str2)
	b.result += uint32(len(b.bytes))
}

func (b *Base64Decode) Checksum() uint32 {
	resultStr := fmt.Sprintf("decode %s... to %s...: %d",
		b.str2[:min(4, len(b.str2))],
		string(b.bytes[:min(4, len(b.bytes))]),
		b.result)
	return Checksum(resultStr)
}

type Sieve struct {
	BaseBenchmark
	limit    int64
	checksum uint32
}

func (s *Sieve) Prepare() {
	s.limit = s.ConfigVal("limit")
	s.checksum = 0
}

func (s *Sieve) Run(iteration_id int) {
	lim := int(s.limit)
	primes := make([]byte, lim+1)
	for i := 0; i <= lim; i++ {
		primes[i] = 1
	}
	primes[0] = 0
	primes[1] = 0

	sqrtLimit := int(math.Sqrt(float64(lim)))

	for p := 2; p <= sqrtLimit; p++ {
		if primes[p] == 1 {
			for multiple := p * p; multiple <= lim; multiple += p {
				primes[multiple] = 0
			}
		}
	}

	lastPrime := 2
	count := 1

	for n := 3; n <= lim; n += 2 {
		if primes[n] == 1 {
			lastPrime = n
			count++
		}
	}

	s.checksum += uint32(lastPrime + count)
}

func (s *Sieve) Checksum() uint32 {
	return s.checksum
}

type Coordinate struct {
	X    float64                   `json:"x"`
	Y    float64                   `json:"y"`
	Z    float64                   `json:"z"`
	Name string                    `json:"name"`
	Opts map[string][2]interface{} `json:"opts"`
}

type JsonGenerate struct {
	BaseBenchmark
	n      int64
	data   []Coordinate
	text   []byte
	result uint32
}

func round(val float64, precision int) float64 {
	ratio := math.Pow(10, float64(precision))
	return math.Round(val*ratio) / ratio
}

func (j *JsonGenerate) Prepare() {
	j.n = j.ConfigVal("coords")
	j.data = make([]Coordinate, j.n)
	for i := 0; i < int(j.n); i++ {
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

func (j *JsonGenerate) Run(iteration_id int) {
	type Response struct {
		Coordinates []Coordinate `json:"coordinates"`
		Info        string       `json:"info"`
	}

	resp := Response{
		Coordinates: j.data,
		Info:        "some info",
	}

	j.text, _ = json.Marshal(resp)

	if len(j.text) >= 15 && string(j.text[:15]) == "{\"coordinates\":" {
		j.result++
	}
}

func (j *JsonGenerate) Checksum() uint32 {
	return j.result
}

type JsonParseDom struct {
	BaseBenchmark
	text   []byte
	result uint32
}

func (j *JsonParseDom) Prepare() {
	gen := &JsonGenerate{BaseBenchmark: BaseBenchmark{className: "Json::ParseDom"}}
	gen.n = j.ConfigVal("coords")
	gen.Prepare()
	gen.Run(0)
	j.text = gen.text
}

func (j *JsonParseDom) calc() (float64, float64, float64) {
	var data map[string]interface{}
	json.Unmarshal(j.text, &data)

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

func (j *JsonParseDom) Run(iteration_id int) {
	x, y, z := j.calc()
	j.result += ChecksumFloat64(x) + ChecksumFloat64(y) + ChecksumFloat64(z)
}

func (j *JsonParseDom) Checksum() uint32 {
	return j.result
}

type JsonParseMapping struct {
	BaseBenchmark
	text   []byte
	result uint32
}

func (j *JsonParseMapping) Prepare() {
	gen := &JsonGenerate{BaseBenchmark: BaseBenchmark{className: "Json::ParseMapping"}}
	gen.n = j.ConfigVal("coords")
	gen.Prepare()
	gen.Run(0)
	j.text = gen.text
}

func (j *JsonParseMapping) calc() (float64, float64, float64) {
	var data struct {
		Coordinates []struct {
			X float64 `json:"x"`
			Y float64 `json:"y"`
			Z float64 `json:"z"`
		} `json:"coordinates"`
	}

	json.Unmarshal(j.text, &data)

	length := float64(len(data.Coordinates))
	x, y, z := 0.0, 0.0, 0.0

	for _, coord := range data.Coordinates {
		x += coord.X
		y += coord.Y
		z += coord.Z
	}

	return x / length, y / length, z / length
}

func (j *JsonParseMapping) Run(iteration_id int) {
	x, y, z := j.calc()
	j.result += ChecksumFloat64(x) + ChecksumFloat64(y) + ChecksumFloat64(z)
}

func (j *JsonParseMapping) Checksum() uint32 {
	return j.result
}

type TextRaytracer struct {
	BaseBenchmark
	w, h   int32
	result uint32
}

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
	mag := v.Magnitude()
	if mag == 0.0 {
		return Vector{0, 0, 0}
	}
	return v.Scale(1.0 / mag)
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

var (
	WHITE2  = Color{1.0, 1.0, 1.0}
	RED2    = Color{1.0, 0.0, 0.0}
	GREEN2  = Color{0.0, 1.0, 0.0}
	BLUE2   = Color{0.0, 0.0, 1.0}
	LIGHT12 = Light2{Vector{0.7, -1.0, 1.7}, WHITE2}
	LUT     = []byte{'.', '-', '+', '*', 'X', 'M'}
)

var SCENE2 = []Sphere2{
	{Vector{-1.0, 0.0, 3.0}, 0.3, RED2},
	{Vector{0.0, 0.0, 3.0}, 0.8, GREEN2},
	{Vector{1.0, 0.0, 3.0}, 0.4, BLUE2},
}

func (t *TextRaytracer) Prepare() {
	t.w = int32(t.ConfigVal("w"))
	t.h = int32(t.ConfigVal("h"))
}

func (t *TextRaytracer) shadePixel(ray Ray, obj Sphere2, tval float64) int {
	pi := ray.Orig.Add(ray.Dir.Scale(tval))
	color := t.diffuseShading(pi, obj, LIGHT12)
	col := (color.R + color.G + color.B) / 3.0
	idx := int(col * 6.0)
	if idx < 0 {
		idx = 0
	}
	if idx >= 6 {
		idx = 5
	}
	return idx
}

func (t *TextRaytracer) intersectSphere(ray Ray, center Vector, radius float64) (float64, bool) {
	l := center.Sub(ray.Orig)
	tca := l.Dot(ray.Dir)
	if tca < 0.0 {
		return 0, false
	}

	d2 := l.Dot(l) - tca*tca
	r2 := radius * radius
	if d2 > r2 {
		return 0, false
	}

	thc := math.Sqrt(r2 - d2)
	t0 := tca - thc
	if t0 > 10000.0 {
		return 0, false
	}

	return t0, true
}

func (t *TextRaytracer) clamp(x, a, b float64) float64 {
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
	lightDir := light.Position.Sub(pi).Normalize()
	lam1 := lightDir.Dot(n)
	lam2 := t.clamp(lam1, 0.0, 1.0)
	return light.Color.Scale(lam2 * 0.5).Add(obj.Color.Scale(0.3))
}

func (t *TextRaytracer) Run(iteration_id int) {
	fw := float64(t.w)
	fh := float64(t.h)

	for j := int32(0); j < t.h; j++ {
		for i := int32(0); i < t.w; i++ {
			fi := float64(i)
			fj := float64(j)

			ray := Ray{
				Orig: Vector{0.0, 0.0, 0.0},
				Dir:  Vector{(fi - fw/2.0) / fw, (fj - fh/2.0) / fh, 1.0}.Normalize(),
			}

			var tval float64
			var hitObj Sphere2
			found := false

			for idx := 0; idx < len(SCENE2); idx++ {
				if inter, ok := t.intersectSphere(ray, SCENE2[idx].Center, SCENE2[idx].Radius); ok {
					tval = inter
					hitObj = SCENE2[idx]
					found = true
					break
				}
			}

			pixel := byte(' ')
			if found {
				idx := t.shadePixel(ray, hitObj, tval)
				pixel = LUT[idx]
			}

			t.result += uint32(pixel)
		}
	}
}

func (t *TextRaytracer) Checksum() uint32 {
	return t.result
}

type Synapse struct {
	weight       float64
	prevWeight   float64
	sourceNeuron *Neuron
	destNeuron   *Neuron
}

func NewSynapse(source, dest *Neuron) *Synapse {

	val := NextFloat(1)*2 - 1
	return &Synapse{
		weight:       val,
		prevWeight:   val,
		sourceNeuron: source,
		destNeuron:   dest,
	}
}

type Neuron struct {
	synapsesIn    []*Synapse
	synapsesOut   []*Synapse
	threshold     float64
	prevThreshold float64
	error         float64
	output        float64
}

func NewNeuron() *Neuron {

	val := NextFloat(1)*2 - 1
	return &Neuron{
		threshold:     val,
		prevThreshold: val,
		output:        0.0,
		error:         0.0,
	}
}

func (n *Neuron) CalculateOutput() {
	activation := 0.0
	for _, synapse := range n.synapsesIn {
		activation += synapse.weight * synapse.sourceNeuron.output
	}
	activation -= n.threshold
	n.output = 1.0 / (1.0 + math.Exp(-activation))
}

func (n *Neuron) Derivative() float64 {
	return n.output * (1 - n.output)
}

func (n *Neuron) OutputTrain(rate, target float64) {
	n.error = (target - n.output) * n.Derivative()
	n.UpdateWeights(rate)
}

func (n *Neuron) HiddenTrain(rate float64) {
	sum := 0.0
	for _, synapse := range n.synapsesOut {
		sum += synapse.prevWeight * synapse.destNeuron.error
	}
	n.error = sum * n.Derivative()
	n.UpdateWeights(rate)
}

func (n *Neuron) UpdateWeights(rate float64) {
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

func (n *Neuron) AddSynapseIn(synapse *Synapse) {
	n.synapsesIn = append(n.synapsesIn, synapse)
}

func (n *Neuron) AddSynapseOut(synapse *Synapse) {
	n.synapsesOut = append(n.synapsesOut, synapse)
}

func (n *Neuron) SetOutput(val float64) {
	n.output = val
}

func (n *Neuron) GetOutput() float64 {
	return n.output
}

type NeuralNetwork struct {
	inputLayer  []*Neuron
	hiddenLayer []*Neuron
	outputLayer []*Neuron
	synapses    []*Synapse
}

func NewNeuralNetwork(inputs, hidden, outputs int) *NeuralNetwork {
	nn := &NeuralNetwork{
		inputLayer:  make([]*Neuron, inputs),
		hiddenLayer: make([]*Neuron, hidden),
		outputLayer: make([]*Neuron, outputs),
	}

	for i := range nn.inputLayer {
		nn.inputLayer[i] = NewNeuron()
	}
	for i := range nn.hiddenLayer {
		nn.hiddenLayer[i] = NewNeuron()
	}
	for i := range nn.outputLayer {
		nn.outputLayer[i] = NewNeuron()
	}

	for _, source := range nn.inputLayer {
		for _, dest := range nn.hiddenLayer {
			synapse := NewSynapse(source, dest)
			source.AddSynapseOut(synapse)
			dest.AddSynapseIn(synapse)
			nn.synapses = append(nn.synapses, synapse)
		}
	}

	for _, source := range nn.hiddenLayer {
		for _, dest := range nn.outputLayer {
			synapse := NewSynapse(source, dest)
			source.AddSynapseOut(synapse)
			dest.AddSynapseIn(synapse)
			nn.synapses = append(nn.synapses, synapse)
		}
	}

	return nn
}

func (nn *NeuralNetwork) Train(inputs, targets []float64) {
	nn.FeedForward(inputs)

	for i, neuron := range nn.outputLayer {
		neuron.OutputTrain(0.3, targets[i])
	}

	for _, neuron := range nn.hiddenLayer {
		neuron.HiddenTrain(0.3)
	}
}

func (nn *NeuralNetwork) FeedForward(inputs []float64) {
	for i, neuron := range nn.inputLayer {
		neuron.SetOutput(inputs[i])
	}

	for _, neuron := range nn.hiddenLayer {
		neuron.CalculateOutput()
	}

	for _, neuron := range nn.outputLayer {
		neuron.CalculateOutput()
	}
}

func (nn *NeuralNetwork) CurrentOutputs() []float64 {
	outputs := make([]float64, len(nn.outputLayer))
	for i, neuron := range nn.outputLayer {
		outputs[i] = neuron.GetOutput()
	}
	return outputs
}

type NeuralNet struct {
	BaseBenchmark
	res    []float64
	xorNet *NeuralNetwork
}

var (
	input00 = []float64{0, 0}
	input01 = []float64{0, 1}
	input10 = []float64{1, 0}
	input11 = []float64{1, 1}
	target0 = []float64{0}
	target1 = []float64{1}
)

func (n *NeuralNet) Prepare() {
	n.xorNet = NewNeuralNetwork(2, 10, 1)
}

func (n *NeuralNet) Run(iteration_id int) {
	for i := 0; i < 1000; i++ {
		n.xorNet.Train(input00, target0)
		n.xorNet.Train(input10, target1)
		n.xorNet.Train(input01, target1)
		n.xorNet.Train(input11, target0)
	}
}

func (n *NeuralNet) Checksum() uint32 {
	n.xorNet.FeedForward(input00)
	outputs1 := n.xorNet.CurrentOutputs()

	n.xorNet.FeedForward(input01)
	outputs2 := n.xorNet.CurrentOutputs()

	n.xorNet.FeedForward(input10)
	outputs3 := n.xorNet.CurrentOutputs()

	n.xorNet.FeedForward(input11)
	outputs4 := n.xorNet.CurrentOutputs()

	allOutputs := make([]float64, 0, 4)
	allOutputs = append(allOutputs, outputs1...)
	allOutputs = append(allOutputs, outputs2...)
	allOutputs = append(allOutputs, outputs3...)
	allOutputs = append(allOutputs, outputs4...)

	sum := 0.0
	for _, v := range allOutputs {
		sum += v
	}

	return ChecksumFloat64(sum)
}

type SortBenchmark struct {
	BaseBenchmark
	data   []int
	result uint32
}

type SortQuick struct {
	BaseBenchmark
	data   []int
	result uint32
}

func (s *SortQuick) Prepare() {
	size := int(s.ConfigVal("size"))
	s.data = make([]int, size)
	for i := 0; i < size; i++ {
		s.data[i] = NextInt(1_000_000)
	}
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

func (s *SortQuick) Run(iteration_id int) {
	s.result += uint32(s.data[NextInt(len(s.data))])
	arr := make([]int, len(s.data))
	copy(arr, s.data)
	s.quickSort(arr, 0, len(arr)-1)
	s.result += uint32(arr[NextInt(len(arr))])
}

func (s *SortQuick) Checksum() uint32 {
	return s.result
}

type SortMerge struct {
	BaseBenchmark
	data   []int
	result uint32
}

func (s *SortMerge) Prepare() {
	size := int(s.ConfigVal("size"))
	s.data = make([]int, size)
	for i := 0; i < size; i++ {
		s.data[i] = NextInt(1_000_000)
	}
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
	copy(temp[left:right+1], arr[left:right+1])

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

func (s *SortMerge) Run(iteration_id int) {
	s.result += uint32(s.data[NextInt(len(s.data))])
	arr := make([]int, len(s.data))
	copy(arr, s.data)
	s.mergeSortInplace(arr)
	s.result += uint32(arr[NextInt(len(arr))])
}

func (s *SortMerge) Checksum() uint32 {
	return s.result
}

type SortSelf struct {
	BaseBenchmark
	data   []int
	result uint32
}

func (s *SortSelf) Prepare() {
	size := int(s.ConfigVal("size"))
	s.data = make([]int, size)
	for i := 0; i < size; i++ {
		s.data[i] = NextInt(1_000_000)
	}
}

func (s *SortSelf) Run(iteration_id int) {
	s.result += uint32(s.data[NextInt(len(s.data))])
	arr := make([]int, len(s.data))
	copy(arr, s.data)
	sort.Ints(arr)
	s.result += uint32(arr[NextInt(len(arr))])
}

func (s *SortSelf) Checksum() uint32 {
	return s.result
}

type Graph struct {
	vertices int
	jumps    int
	jumpLen  int
	adj      [][]int
}

func NewGraph(vertices, jumps, jumpLen int) *Graph {
	adj := make([][]int, vertices)
	for i := range adj {
		adj[i] = make([]int, 0)
	}
	return &Graph{
		vertices: vertices,
		jumps:    jumps,
		jumpLen:  jumpLen,
		adj:      adj,
	}
}

func (g *Graph) AddEdge(u, v int) {
	g.adj[u] = append(g.adj[u], v)
	g.adj[v] = append(g.adj[v], u)
}

func (g *Graph) GenerateRandom() {

	for i := 1; i < g.vertices; i++ {
		g.AddEdge(i, i-1)
	}

	for v := 0; v < g.vertices; v++ {
		numJumps := NextInt(g.jumps)
		for j := 0; j < numJumps; j++ {
			offset := NextInt(g.jumpLen) - g.jumpLen/2
			u := v + offset

			if u >= 0 && u < g.vertices && u != v {
				g.AddEdge(v, u)
			}
		}
	}
}

type GraphPathBFS struct {
	BaseBenchmark
	graph  *Graph
	result uint32
}

func (g *GraphPathBFS) Prepare() {
	vertices := int(g.ConfigVal("vertices"))
	jumps := int(g.ConfigVal("jumps"))
	jumpLen := int(g.ConfigVal("jump_len"))

	g.graph = NewGraph(vertices, jumps, jumpLen)
	g.graph.GenerateRandom()
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

func (g *GraphPathBFS) Run(iteration_id int) {
	length := g.bfsShortestPath(0, g.graph.vertices-1)
	g.result += uint32(length)
}

func (g *GraphPathBFS) Checksum() uint32 {
	return g.result
}

type GraphPathDFS struct {
	BaseBenchmark
	graph  *Graph
	result uint32
}

func (g *GraphPathDFS) Prepare() {
	vertices := int(g.ConfigVal("vertices"))
	jumps := int(g.ConfigVal("jumps"))
	jumpLen := int(g.ConfigVal("jump_len"))

	g.graph = NewGraph(vertices, jumps, jumpLen)
	g.graph.GenerateRandom()
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

func (g *GraphPathDFS) Run(iteration_id int) {
	length := g.dfsFindPath(0, g.graph.vertices-1)
	g.result += uint32(length)
}

func (g *GraphPathDFS) Checksum() uint32 {
	return g.result
}

type GraphPriorityQueueItem struct {
	vertex   int
	priority int
}

type GraphPriorityQueue struct {
	items []GraphPriorityQueueItem
}

func NewGraphPriorityQueue(capacity int) *GraphPriorityQueue {
	return &GraphPriorityQueue{
		items: make([]GraphPriorityQueueItem, 0, capacity),
	}
}

func (pq *GraphPriorityQueue) Push(vertex, priority int) {
	pq.items = append(pq.items, GraphPriorityQueueItem{vertex, priority})
	pq.siftUp(len(pq.items) - 1)
}

func (pq *GraphPriorityQueue) Pop() (int, int) {
	min := pq.items[0]
	pq.items[0] = pq.items[len(pq.items)-1]
	pq.items = pq.items[:len(pq.items)-1]
	pq.siftDown(0)
	return min.vertex, min.priority
}

func (pq *GraphPriorityQueue) Len() int {
	return len(pq.items)
}

func (pq *GraphPriorityQueue) siftUp(i int) {
	for i > 0 {
		parent := (i - 1) / 2
		if pq.items[parent].priority <= pq.items[i].priority {
			break
		}
		pq.items[parent], pq.items[i] = pq.items[i], pq.items[parent]
		i = parent
	}
}

func (pq *GraphPriorityQueue) siftDown(i int) {
	n := len(pq.items)
	for {
		left := 2*i + 1
		right := 2*i + 2
		smallest := i

		if left < n && pq.items[left].priority < pq.items[smallest].priority {
			smallest = left
		}
		if right < n && pq.items[right].priority < pq.items[smallest].priority {
			smallest = right
		}
		if smallest == i {
			break
		}
		pq.items[i], pq.items[smallest] = pq.items[smallest], pq.items[i]
		i = smallest
	}
}

type GraphPathAStar struct {
	BaseBenchmark
	graph  *Graph
	result uint32
}

func (g *GraphPathAStar) Prepare() {
	vertices := int(g.ConfigVal("vertices"))
	jumps := int(g.ConfigVal("jumps"))
	jumpLen := int(g.ConfigVal("jump_len"))

	g.graph = NewGraph(vertices, jumps, jumpLen)
	g.graph.GenerateRandom()
}

func (g *GraphPathAStar) heuristic(v, target int) int {
	return target - v
}

func (g *GraphPathAStar) aStarShortestPath(start, target int) int {
	if start == target {
		return 0
	}

	const INF = int(^uint(0) >> 1)
	gScore := make([]int, g.graph.vertices)
	fScore := make([]int, g.graph.vertices)
	closed := make([]byte, g.graph.vertices)

	for i := range gScore {
		gScore[i] = INF
		fScore[i] = INF
	}
	gScore[start] = 0
	fScore[start] = g.heuristic(start, target)

	openSet := NewGraphPriorityQueue(g.graph.vertices)
	inOpenSet := make([]byte, g.graph.vertices)

	openSet.Push(start, fScore[start])
	inOpenSet[start] = 1

	for openSet.Len() > 0 {
		current, _ := openSet.Pop()
		inOpenSet[current] = 0

		if current == target {
			return gScore[current]
		}

		closed[current] = 1

		for _, neighbor := range g.graph.adj[current] {
			if closed[neighbor] == 1 {
				continue
			}

			tentativeG := gScore[current] + 1

			if tentativeG < gScore[neighbor] {
				gScore[neighbor] = tentativeG
				fScore[neighbor] = tentativeG + g.heuristic(neighbor, target)

				if inOpenSet[neighbor] == 0 {
					openSet.Push(neighbor, fScore[neighbor])
					inOpenSet[neighbor] = 1
				}
			}
		}
	}

	return -1
}

func (g *GraphPathAStar) Run(iteration_id int) {
	length := g.aStarShortestPath(0, g.graph.vertices-1)
	g.result += uint32(length)
}

func (g *GraphPathAStar) Checksum() uint32 {
	return g.result
}

type BufferHashSHA256 struct {
	BaseBenchmark
	data   []byte
	result uint32
}

func (b *BufferHashSHA256) Prepare() {
	size := int(b.ConfigVal("size"))
	b.data = make([]byte, size)
	for i := 0; i < size; i++ {
		b.data[i] = byte(NextInt(256))
	}
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

func (b *BufferHashSHA256) Run(iteration_id int) {
	b.result += b.test()
}

func (b *BufferHashSHA256) Checksum() uint32 {
	return b.result
}

type BufferHashCRC32 struct {
	BaseBenchmark
	data   []byte
	result uint32
}

func (b *BufferHashCRC32) Prepare() {
	size := int(b.ConfigVal("size"))
	b.data = make([]byte, size)
	for i := 0; i < size; i++ {
		b.data[i] = byte(NextInt(256))
	}
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

func (b *BufferHashCRC32) Run(iteration_id int) {
	b.result += b.test()
}

func (b *BufferHashCRC32) Checksum() uint32 {
	return b.result
}

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
	if n, ok := c.cache[key]; ok {
		n.value = value
		c.moveToFront(n)
		return
	}

	if c.size >= c.capacity {
		c.removeOldest()
	}

	n := &node{
		key:   key,
		value: value,
	}

	c.cache[key] = n
	c.addToFront(n)
	c.size++
}

func (c *LRUCache) Size() int {
	return c.size
}

func (c *LRUCache) moveToFront(n *node) {
	if n == c.head {
		return
	}

	if n.prev != nil {
		n.prev.next = n.next
	}
	if n.next != nil {
		n.next.prev = n.prev
	}

	if n == c.tail {
		c.tail = n.prev
	}

	n.prev = nil
	n.next = c.head
	if c.head != nil {
		c.head.prev = n
	}
	c.head = n

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
	delete(c.cache, oldest.key)

	if oldest.prev != nil {
		oldest.prev.next = nil
	}
	c.tail = oldest.prev

	if c.head == oldest {
		c.head = nil
	}

	c.size--
}

type CacheSimulation struct {
	BaseBenchmark
	cache  *LRUCache
	hits   int
	misses int
	result uint32
}

func (c *CacheSimulation) Prepare() {
	c.cache = NewLRUCache(int(c.ConfigVal("size")))
	c.result = 5432
}

func (c *CacheSimulation) Run(iteration_id int) {
	for k := 0; k < 1000; k += 1 {
		key := fmt.Sprintf("item_%d", NextInt(int(c.ConfigVal("values"))))
		if _, ok := c.cache.Get(key); ok {
			c.hits += 1
			c.cache.Put(key, fmt.Sprintf("updated_%d", iteration_id))
		} else {
			c.misses += 1
			c.cache.Put(key, fmt.Sprintf("new_%d", iteration_id))
		}
	}
}

func (c *CacheSimulation) Checksum() uint32 {
	c.result = (c.result << 5) + uint32(c.hits)
	c.result = (c.result << 5) + uint32(c.misses)
	c.result = (c.result << 5) + uint32(c.cache.Size())
	return c.result
}

type AstNode interface{}
type NumberNode struct{ value int64 }
type VariableNode struct{ name string }
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
	BaseBenchmark
	n           int64
	result      uint32
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
	c.n = c.ConfigVal("operations")
	c.text = c.generateRandomProgram(int(c.n))
}

func (c *CalculatorAst) Run(iteration_id int) {
	parser := NewParser(c.text)
	c.expressions = parser.parse()
	c.result += uint32(len(c.expressions))
	if len(c.expressions) > 0 {
		lastExpr := c.expressions[len(c.expressions)-1]
		if assign, ok := lastExpr.(AssignmentNode); ok {
			c.result += uint32(Checksum(assign.varName))
		}
	}
}

func (c *CalculatorAst) Checksum() uint32 {
	return c.result
}

func simpleDiv(a, b int64) int64 {
	if b == 0 {
		return 0
	}
	if (a >= 0 && b > 0) || (a < 0 && b < 0) {
		return a / b
	} else {
		return -(abs(a) / abs(b))
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

type CalculatorInterpreter struct {
	BaseBenchmark
	ast    []AstNode
	result uint32
}

func (c *CalculatorInterpreter) Prepare() {
	astBench := &CalculatorAst{BaseBenchmark: BaseBenchmark{className: "Calculator::Interpreter"}}
	astBench.n = c.ConfigVal("operations")
	astBench.Prepare()
	astBench.Run(0)
	c.ast = astBench.expressions
}

func (c *CalculatorInterpreter) Run(iteration_id int) {
	interpreter := NewInterpreter()
	result := interpreter.run(c.ast)
	c.result += uint32(result)
}

func (c *CalculatorInterpreter) Checksum() uint32 {
	return c.result
}

type Cell struct {
	Alive     bool
	NextState bool
	Neighbors []*Cell
}

func NewCell() *Cell {
	return &Cell{
		Neighbors: make([]*Cell, 0, 8),
	}
}

func (c *Cell) AddNeighbor(neighbor *Cell) {
	c.Neighbors = append(c.Neighbors, neighbor)
}

func (c *Cell) ComputeNextState() {
	aliveNeighbors := 0
	for _, n := range c.Neighbors {
		if n.Alive {
			aliveNeighbors++
		}
	}

	if c.Alive {
		c.NextState = aliveNeighbors == 2 || aliveNeighbors == 3
	} else {
		c.NextState = aliveNeighbors == 3
	}
}

func (c *Cell) Update() {
	c.Alive = c.NextState
}

type Grid struct {
	width  int
	height int
	cells  [][]*Cell
}

func NewGrid(width, height int) *Grid {
	cells := make([][]*Cell, height)
	for y := 0; y < height; y++ {
		cells[y] = make([]*Cell, width)
		for x := 0; x < width; x++ {
			cells[y][x] = NewCell()
		}
	}

	grid := &Grid{
		width:  width,
		height: height,
		cells:  cells,
	}
	grid.linkNeighbors()
	return grid
}

func (g *Grid) linkNeighbors() {
	for y := 0; y < g.height; y++ {
		for x := 0; x < g.width; x++ {
			cell := g.cells[y][x]

			for dy := -1; dy <= 1; dy++ {
				for dx := -1; dx <= 1; dx++ {
					if dx == 0 && dy == 0 {
						continue
					}

					ny := (y + dy + g.height) % g.height
					nx := (x + dx + g.width) % g.width

					cell.AddNeighbor(g.cells[ny][nx])
				}
			}
		}
	}
}

func (g *Grid) NextGeneration() {

	for _, row := range g.cells {
		for _, cell := range row {
			cell.ComputeNextState()
		}
	}

	for _, row := range g.cells {
		for _, cell := range row {
			cell.Update()
		}
	}
}

func (g *Grid) CountAlive() int {
	count := 0
	for _, row := range g.cells {
		for _, cell := range row {
			if cell.Alive {
				count++
			}
		}
	}
	return count
}

func (g *Grid) ComputeHash() uint32 {
	const (
		FNV_OFFSET_BASIS uint32 = 2166136261
		FNV_PRIME        uint32 = 16777619
	)

	hash := FNV_OFFSET_BASIS
	for _, row := range g.cells {
		for _, cell := range row {
			var alive uint32 = 0
			if cell.Alive {
				alive = 1
			}
			hash = (hash ^ alive) * FNV_PRIME
		}
	}
	return hash
}

type GameOfLife struct {
	BaseBenchmark
	grid *Grid
}

func (g *GameOfLife) Prepare() {
	width := int(g.ConfigVal("w"))
	height := int(g.ConfigVal("h"))
	g.grid = NewGrid(width, height)

	for _, row := range g.grid.cells {
		for _, cell := range row {
			if NextFloat(1.0) < 0.1 {
				cell.Alive = true
			}
		}
	}
}

func (g *GameOfLife) Run(iterationId int) {
	g.grid.NextGeneration()
}

func (g *GameOfLife) Checksum() uint32 {
	return g.grid.ComputeHash() + uint32(g.grid.CountAlive())
}

type MazeCellKind int

const (
	Wall MazeCellKind = iota
	Space
	Start
	Finish
	Border
	Path
)

func (k MazeCellKind) IsWalkable() bool {
	return k == Space || k == Start || k == Finish
}

type MazeCell struct {
	Kind      MazeCellKind
	Neighbors []*MazeCell
	X, Y      int
}

func NewMazeCell(x, y int) *MazeCell {
	return &MazeCell{
		Kind:      Wall,
		Neighbors: make([]*MazeCell, 0, 4),
		X:         x,
		Y:         y,
	}
}

func (c *MazeCell) AddNeighbor(cell *MazeCell) {
	c.Neighbors = append(c.Neighbors, cell)
}

func (c *MazeCell) Reset() {
	if c.Kind == Space {
		c.Kind = Wall
	}
}

type Maze struct {
	Width  int
	Height int
	Cells  [][]*MazeCell
	Start  *MazeCell
	Finish *MazeCell
}

func NewMaze(width, height int) *Maze {
	if width < 5 {
		width = 5
	}
	if height < 5 {
		height = 5
	}

	cells := make([][]*MazeCell, height)
	for y := 0; y < height; y++ {
		cells[y] = make([]*MazeCell, width)
		for x := 0; x < width; x++ {
			cells[y][x] = NewMazeCell(x, y)
		}
	}

	maze := &Maze{
		Width:  width,
		Height: height,
		Cells:  cells,
	}

	maze.Start = cells[1][1]
	maze.Finish = cells[height-2][width-2]
	maze.Start.Kind = Start
	maze.Finish.Kind = Finish

	return maze
}

func (m *Maze) UpdateNeighbors() {

	for y := 0; y < m.Height; y++ {
		for x := 0; x < m.Width; x++ {
			m.Cells[y][x].Neighbors = m.Cells[y][x].Neighbors[:0]
		}
	}

	for y := 0; y < m.Height; y++ {
		for x := 0; x < m.Width; x++ {
			cell := m.Cells[y][x]

			if x > 0 && y > 0 && x < m.Width-1 && y < m.Height-1 {
				cell.AddNeighbor(m.Cells[y-1][x])
				cell.AddNeighbor(m.Cells[y+1][x])
				cell.AddNeighbor(m.Cells[y][x+1])
				cell.AddNeighbor(m.Cells[y][x-1])

				for t := 0; t < 4; t++ {
					i := NextInt(4)
					j := NextInt(4)
					if i != j && i < len(cell.Neighbors) && j < len(cell.Neighbors) {
						cell.Neighbors[i], cell.Neighbors[j] = cell.Neighbors[j], cell.Neighbors[i]
					}
				}
			} else {
				cell.Kind = Border
			}
		}
	}
}

func (m *Maze) Reset() {
	for y := 0; y < m.Height; y++ {
		for x := 0; x < m.Width; x++ {
			m.Cells[y][x].Reset()
		}
	}
	m.Start.Kind = Start
	m.Finish.Kind = Finish
}

func (m *Maze) Dig(startCell *MazeCell) {
	stack := make([]*MazeCell, 0, m.Width*m.Height)
	stack = append(stack, startCell)

	for len(stack) > 0 {
		cell := stack[len(stack)-1]
		stack = stack[:len(stack)-1]

		walkable := 0
		for _, n := range cell.Neighbors {
			if n.Kind.IsWalkable() {
				walkable++
			}
		}

		if walkable != 1 {
			continue
		}

		cell.Kind = Space

		for _, n := range cell.Neighbors {
			if n.Kind == Wall {
				stack = append(stack, n)
			}
		}
	}
}

func (m *Maze) EnsureOpenFinish(startCell *MazeCell) {
	stack := make([]*MazeCell, 0, m.Width*m.Height)
	stack = append(stack, startCell)

	for len(stack) > 0 {
		cell := stack[len(stack)-1]
		stack = stack[:len(stack)-1]

		cell.Kind = Space

		walkable := 0
		for _, n := range cell.Neighbors {
			if n.Kind.IsWalkable() {
				walkable++
			}
		}

		if walkable > 1 {
			continue
		}

		for _, n := range cell.Neighbors {
			if n.Kind == Wall {
				stack = append(stack, n)
			}
		}
	}
}

func (m *Maze) Generate() {
	for _, n := range m.Start.Neighbors {
		if n.Kind == Wall {
			m.Dig(n)
		}
	}

	for _, n := range m.Finish.Neighbors {
		if n.Kind == Wall {
			m.EnsureOpenFinish(n)
		}
	}
}

func (m *Maze) MiddleCell() *MazeCell {
	return m.Cells[m.Height/2][m.Width/2]
}

func (m *Maze) Checksum() uint32 {
	hasher := uint32(2166136261)
	prime := uint32(16777619)

	for y := 0; y < m.Height; y++ {
		for x := 0; x < m.Width; x++ {
			if m.Cells[y][x].Kind == Space {
				val := uint32(x * y)
				hasher = (hasher ^ val) * prime
			}
		}
	}
	return hasher
}

type MazeGenerator struct {
	BaseBenchmark
	width     int
	height    int
	maze      *Maze
	resultVal uint32
}

func (m *MazeGenerator) Prepare() {
	m.width = int(m.ConfigVal("w"))
	m.height = int(m.ConfigVal("h"))
	m.maze = NewMaze(m.width, m.height)
	m.maze.UpdateNeighbors()
	m.resultVal = 0
}

func (m *MazeGenerator) Run(iteration_id int) {
	m.maze.Reset()
	m.maze.Generate()
	m.resultVal += uint32(m.maze.MiddleCell().Kind)
}

func (m *MazeGenerator) Checksum() uint32 {
	return m.resultVal + m.maze.Checksum()
}

type MazeBFS struct {
	BaseBenchmark
	width     int
	height    int
	maze      *Maze
	resultVal uint32
	path      []*MazeCell
}

func (m *MazeBFS) Prepare() {
	m.width = int(m.ConfigVal("w"))
	m.height = int(m.ConfigVal("h"))
	m.maze = NewMaze(m.width, m.height)
	m.maze.UpdateNeighbors()
	m.maze.Generate()
	m.resultVal = 0
	m.path = nil
}

func (m *MazeBFS) bfs(start, target *MazeCell) []*MazeCell {
	if start == target {
		return []*MazeCell{start}
	}

	type PathNode struct {
		cell   *MazeCell
		parent int
	}

	visited := make([][]bool, m.height)
	for i := range visited {
		visited[i] = make([]bool, m.width)
	}

	queue := []int{0}
	pathNodes := []PathNode{{start, -1}}
	visited[start.Y][start.X] = true

	for len(queue) > 0 {
		pathId := queue[0]
		queue = queue[1:]
		cell := pathNodes[pathId].cell

		for _, neighbor := range cell.Neighbors {
			if neighbor == target {
				result := []*MazeCell{target}
				cur := pathId
				for cur >= 0 {
					result = append(result, pathNodes[cur].cell)
					cur = pathNodes[cur].parent
				}

				for i, j := 0, len(result)-1; i < j; i, j = i+1, j-1 {
					result[i], result[j] = result[j], result[i]
				}
				return result
			}

			if neighbor.Kind.IsWalkable() && !visited[neighbor.Y][neighbor.X] {
				visited[neighbor.Y][neighbor.X] = true
				pathNodes = append(pathNodes, PathNode{neighbor, pathId})
				queue = append(queue, len(pathNodes)-1)
			}
		}
	}
	return nil
}

func (m *MazeBFS) midCellChecksum(path []*MazeCell) uint32 {
	if len(path) == 0 {
		return 0
	}
	cell := path[len(path)/2]
	return uint32(cell.X * cell.Y)
}

func (m *MazeBFS) Run(iteration_id int) {
	m.path = m.bfs(m.maze.Start, m.maze.Finish)
	if m.path != nil {
		m.resultVal += uint32(len(m.path))
	}
}

func (m *MazeBFS) Checksum() uint32 {
	return m.resultVal + m.midCellChecksum(m.path)
}

type MazeAStar struct {
	BaseBenchmark
	width     int
	height    int
	maze      *Maze
	resultVal uint32
	path      []*MazeCell
}

func (m *MazeAStar) Prepare() {
	m.width = int(m.ConfigVal("w"))
	m.height = int(m.ConfigVal("h"))
	m.maze = NewMaze(m.width, m.height)
	m.maze.UpdateNeighbors()
	m.maze.Generate()
	m.resultVal = 0
	m.path = nil
}

func (m *MazeAStar) heuristic(a, b *MazeCell) int {
	return absint(a.X-b.X) + absint(a.Y-b.Y)
}

func absint(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

func (m *MazeAStar) idx(y, x int) int {
	return y*m.width + x
}

func (m *MazeAStar) astar(start, target *MazeCell) []*MazeCell {
	if start == target {
		return []*MazeCell{start}
	}

	size := m.width * m.height

	cameFrom := make([]int, size)
	gScore := make([]int, size)
	bestF := make([]int, size)
	for i := 0; i < size; i++ {
		cameFrom[i] = -1
		gScore[i] = int(^uint(0) >> 1)
		bestF[i] = int(^uint(0) >> 1)
	}

	startIdx := m.idx(start.Y, start.X)
	targetIdx := m.idx(target.Y, target.X)

	type Item struct {
		priority int
		vertex   int
	}
	openSet := make([]Item, 0)

	gScore[startIdx] = 0
	fStart := m.heuristic(start, target)
	openSet = append(openSet, Item{fStart, startIdx})
	bestF[startIdx] = fStart

	for len(openSet) > 0 {

		minIdx := 0
		for i := 1; i < len(openSet); i++ {
			if openSet[i].priority < openSet[minIdx].priority {
				minIdx = i
			}
		}
		current := openSet[minIdx]

		openSet[minIdx] = openSet[len(openSet)-1]
		openSet = openSet[:len(openSet)-1]

		currentIdx := current.vertex

		if currentIdx == targetIdx {
			result := make([]*MazeCell, 0)
			cur := currentIdx
			for cur != -1 {
				y := cur / m.width
				x := cur % m.width
				result = append(result, m.maze.Cells[y][x])
				cur = cameFrom[cur]
			}

			for i, j := 0, len(result)-1; i < j; i, j = i+1, j-1 {
				result[i], result[j] = result[j], result[i]
			}
			return result
		}

		currentY := currentIdx / m.width
		currentX := currentIdx % m.width
		currentCell := m.maze.Cells[currentY][currentX]
		currentG := gScore[currentIdx]

		for _, neighbor := range currentCell.Neighbors {
			if !neighbor.Kind.IsWalkable() {
				continue
			}

			neighborIdx := m.idx(neighbor.Y, neighbor.X)
			tentativeG := currentG + 1

			if tentativeG < gScore[neighborIdx] {
				cameFrom[neighborIdx] = currentIdx
				gScore[neighborIdx] = tentativeG
				fNew := tentativeG + m.heuristic(neighbor, target)

				if fNew < bestF[neighborIdx] {
					bestF[neighborIdx] = fNew
					openSet = append(openSet, Item{fNew, neighborIdx})
				}
			}
		}
	}
	return nil
}

func (m *MazeAStar) midCellChecksum(path []*MazeCell) uint32 {
	if len(path) == 0 {
		return 0
	}
	cell := path[len(path)/2]
	return uint32(cell.X * cell.Y)
}

func (m *MazeAStar) Run(iteration_id int) {
	m.path = m.astar(m.maze.Start, m.maze.Finish)
	if m.path != nil {
		m.resultVal += uint32(len(m.path))
	}
}

func (m *MazeAStar) Checksum() uint32 {
	return m.resultVal + m.midCellChecksum(m.path)
}

func generateTestData(size int64) []byte {
	pattern := []byte("ABRACADABRA")
	data := make([]byte, size)
	patternLen := int64(len(pattern))

	for i := int64(0); i < size; i++ {
		data[i] = pattern[i%patternLen]
	}

	return data
}

type BWTResult struct {
	transformed []byte
	originalIdx int
}

type BWTEncode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	bwtResult BWTResult
	resultVal uint32
}

func (b *BWTEncode) Name() string {
	return "Compress::BWTEncode"
}

func (b *BWTEncode) Prepare() {
	b.sizeVal = b.ConfigVal("size")
	b.testData = generateTestData(b.sizeVal)
	b.resultVal = 0
}

func (b *BWTEncode) Run(iterationId int) {
	b.bwtResult = b.bwtTransform(b.testData)
	b.resultVal += uint32(len(b.bwtResult.transformed))
}

func (b *BWTEncode) Checksum() uint32 {
	return b.resultVal
}

func (b *BWTEncode) bwtTransform(input []byte) BWTResult {
	n := len(input)
	if n == 0 {
		return BWTResult{[]byte{}, 0}
	}

	counts := [256]int{}
	for i := 0; i < n; i++ {
		counts[input[i]]++
	}

	positions := [256]int{}
	total := 0
	for i := 0; i < 256; i++ {
		positions[i] = total
		total += counts[i]
		counts[i] = 0
	}

	sa := make([]int, n)
	for i := 0; i < n; i++ {
		byteVal := input[i]
		pos := positions[byteVal] + counts[byteVal]
		sa[pos] = i
		counts[byteVal]++
	}

	if n > 1 {
		rank := make([]int, n)
		currentRank := 0
		prevChar := input[sa[0]]

		for i := 0; i < n; i++ {
			idx := sa[i]
			currChar := input[idx]
			if currChar != prevChar {
				currentRank++
				prevChar = currChar
			}
			rank[idx] = currentRank
		}

		k := 1
		for k < n {

			sort.Slice(sa, func(i, j int) bool {
				a, b := sa[i], sa[j]
				ra, rb := rank[a], rank[b]
				if ra != rb {
					return ra < rb
				}
				return rank[(a+k)%n] < rank[(b+k)%n]
			})

			newRank := make([]int, n)
			newRank[sa[0]] = 0
			for i := 1; i < n; i++ {
				prevIdx := sa[i-1]
				currIdx := sa[i]
				if rank[prevIdx] == rank[currIdx] &&
					rank[(prevIdx+k)%n] == rank[(currIdx+k)%n] {
					newRank[currIdx] = newRank[prevIdx]
				} else {
					newRank[currIdx] = newRank[prevIdx] + 1
				}
			}

			rank = newRank
			k *= 2
		}
	}

	transformed := make([]byte, n)
	originalIdx := 0

	for i, suffix := range sa {
		if suffix == 0 {
			transformed[i] = input[n-1]
			originalIdx = i
		} else {
			transformed[i] = input[suffix-1]
		}
	}

	return BWTResult{transformed, originalIdx}
}

type BWTDecode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	inverted  []byte
	bwtResult BWTResult
	resultVal uint32
}

func (b *BWTDecode) Name() string {
	return "Compress::BWTDecode"
}

func (b *BWTDecode) Prepare() {
	b.sizeVal = b.ConfigVal("size")
	encoder := &BWTEncode{BaseBenchmark: BaseBenchmark{className: "Compress::BWTDecode"}}
	encoder.Prepare()
	encoder.Run(0)
	b.testData = encoder.testData
	b.bwtResult = encoder.bwtResult
	b.resultVal = 0
}

func (b *BWTDecode) Run(iterationId int) {
	b.inverted = b.bwtInverse(b.bwtResult)
	b.resultVal += uint32(len(b.inverted))
}

func (b *BWTDecode) Checksum() uint32 {
	res := b.resultVal
	if bytes.Equal(b.inverted, b.testData) {
		res += 100000
	}
	return res
}

func (b *BWTDecode) bwtInverse(bwtResult BWTResult) []byte {
	bwt := bwtResult.transformed
	n := len(bwt)

	if n == 0 {
		return []byte{}
	}

	counts := [256]int{}
	for _, b := range bwt {
		counts[b]++
	}

	positions := [256]int{}
	total := 0
	for i := 0; i < 256; i++ {
		positions[i] = total
		total += counts[i]
	}

	next := make([]int, n)
	tempCounts := [256]int{}

	for i, b := range bwt {
		byteIdx := int(b)
		pos := positions[byteIdx] + tempCounts[byteIdx]
		next[pos] = i
		tempCounts[byteIdx]++
	}

	result := make([]byte, n)
	idx := bwtResult.originalIdx

	for i := 0; i < n; i++ {
		idx = next[idx]
		result[i] = bwt[idx]
	}

	return result
}

type HuffmanNode struct {
	frequency int
	byteVal   byte
	isLeaf    bool
	left      *HuffmanNode
	right     *HuffmanNode
}

type HuffmanCodes struct {
	codeLengths [256]int
	codes       [256]int
}

type EncodedResult struct {
	data        []byte
	bitCount    int
	frequencies [256]int
}

type HuffEncode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	encoded   EncodedResult
	resultVal uint32
}

func (h *HuffEncode) Name() string {
	return "Compress::HuffEncode"
}

func (h *HuffEncode) Prepare() {
	h.sizeVal = h.ConfigVal("size")
	if h.sizeVal == 0 {
		h.sizeVal = 1000
	}
	h.testData = generateTestData(h.sizeVal)
	h.resultVal = 0
}

func buildHuffmanTree(frequencies *[256]int) *HuffmanNode {
	nodes := make([]*HuffmanNode, 0)

	for i := 0; i < 256; i++ {
		if frequencies[i] > 0 {
			nodes = append(nodes, &HuffmanNode{
				frequency: frequencies[i],
				byteVal:   byte(i),
				isLeaf:    true,
				left:      nil,
				right:     nil,
			})
		}
	}

	for i := 0; i < len(nodes)-1; i++ {
		for j := i + 1; j < len(nodes); j++ {
			if nodes[i].frequency > nodes[j].frequency {
				nodes[i], nodes[j] = nodes[j], nodes[i]
			}
		}
	}

	if len(nodes) == 1 {
		node := nodes[0]
		root := &HuffmanNode{
			frequency: node.frequency,
			byteVal:   0,
			isLeaf:    false,
			left:      node,
			right: &HuffmanNode{
				frequency: 0,
				byteVal:   0,
				isLeaf:    true,
			},
		}
		return root
	}

	for len(nodes) > 1 {
		left := nodes[0]
		right := nodes[1]
		nodes = nodes[2:]

		parent := &HuffmanNode{
			frequency: left.frequency + right.frequency,
			byteVal:   0,
			isLeaf:    false,
			left:      left,
			right:     right,
		}

		pos := 0
		for pos < len(nodes) && nodes[pos].frequency < parent.frequency {
			pos++
		}

		if pos == len(nodes) {
			nodes = append(nodes, parent)
		} else {
			nodes = append(nodes[:pos], append([]*HuffmanNode{parent}, nodes[pos:]...)...)
		}
	}

	return nodes[0]
}

func buildHuffmanCodes(node *HuffmanNode, code int, length int, codes *HuffmanCodes) {
	if node == nil {
		return
	}

	if node.isLeaf {
		if length > 0 || node.byteVal != 0 {
			idx := int(node.byteVal)
			codes.codeLengths[idx] = length
			codes.codes[idx] = code
		}
	} else {
		if node.left != nil {
			buildHuffmanCodes(node.left, code<<1, length+1, codes)
		}
		if node.right != nil {
			buildHuffmanCodes(node.right, (code<<1)|1, length+1, codes)
		}
	}
}

func (h *HuffEncode) huffmanEncode(data []byte, codes *HuffmanCodes) EncodedResult {
	result := make([]byte, 0, len(data)*2)
	currentByte := byte(0)
	bitPos := 0
	totalBits := 0

	for _, b := range data {
		idx := int(b)
		code := codes.codes[idx]
		length := codes.codeLengths[idx]

		if length <= 0 {
			continue
		}

		for i := length - 1; i >= 0; i-- {
			if (code & (1 << i)) != 0 {
				currentByte |= 1 << (7 - bitPos)
			}
			bitPos++
			totalBits++

			if bitPos == 8 {
				result = append(result, currentByte)
				currentByte = 0
				bitPos = 0
			}
		}
	}

	if bitPos > 0 {
		result = append(result, currentByte)
	}

	return EncodedResult{
		data:     result,
		bitCount: totalBits,
	}
}

func (h *HuffEncode) Run(iterationId int) {
	var frequencies [256]int
	for _, b := range h.testData {
		frequencies[b]++
	}

	tree := buildHuffmanTree(&frequencies)

	var codes HuffmanCodes
	buildHuffmanCodes(tree, 0, 0, &codes)

	encoded := h.huffmanEncode(h.testData, &codes)
	encoded.frequencies = frequencies
	h.encoded = encoded

	h.resultVal += uint32(len(encoded.data))
}

func (h *HuffEncode) Checksum() uint32 {
	return h.resultVal
}

type HuffDecode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	decoded   []byte
	encoded   EncodedResult
	resultVal uint32
}

func (h *HuffDecode) Name() string {
	return "Compress::HuffDecode"
}

func (h *HuffDecode) huffmanDecode(encoded []byte, root *HuffmanNode, bitCount int) []byte {
	if root == nil || len(encoded) == 0 {
		return []byte{}
	}

	result := make([]byte, bitCount)
	resultSize := 0

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
				result[resultSize] = currentNode.byteVal
				resultSize++
				currentNode = root
			}
		}
	}

	return result[:resultSize]
}

func (h *HuffDecode) Prepare() {
	h.sizeVal = h.ConfigVal("size")
	h.testData = generateTestData(h.sizeVal)
	h.resultVal = 0

	encoder := &HuffEncode{}
	encoder.sizeVal = h.sizeVal
	encoder.testData = h.testData
	encoder.Run(0)
	h.encoded = encoder.encoded
}

func (h *HuffDecode) Run(iterationId int) {
	tree := buildHuffmanTree(&h.encoded.frequencies)
	h.decoded = h.huffmanDecode(h.encoded.data, tree, h.encoded.bitCount)
	h.resultVal += uint32(len(h.decoded))
}

func (h *HuffDecode) Checksum() uint32 {
	res := h.resultVal
	if len(h.decoded) == len(h.testData) {
		equal := true
		for i := 0; i < len(h.decoded); i++ {
			if h.decoded[i] != h.testData[i] {
				equal = false
				break
			}
		}
		if equal {
			res += 100000
		}
	}
	return res
}

type ArithFreqTable struct {
	total int
	low   [256]int
	high  [256]int
}

func NewArithFreqTable(frequencies [256]int) *ArithFreqTable {
	ft := &ArithFreqTable{total: 0}

	for _, f := range frequencies {
		ft.total += f
	}

	cum := 0
	for i := 0; i < 256; i++ {
		ft.low[i] = cum
		cum += frequencies[i]
		ft.high[i] = cum
	}

	return ft
}

type BitOutputStream struct {
	buffer      int
	bitPos      int
	bytes       []byte
	bitsWritten int
}

func NewBitOutputStream() *BitOutputStream {
	return &BitOutputStream{
		buffer:      0,
		bitPos:      0,
		bytes:       make([]byte, 0, 1024),
		bitsWritten: 0,
	}
}

func (b *BitOutputStream) WriteBit(bit int) {
	b.buffer = (b.buffer << 1) | (bit & 1)
	b.bitPos++
	b.bitsWritten++

	if b.bitPos == 8 {
		b.bytes = append(b.bytes, byte(b.buffer))
		b.buffer = 0
		b.bitPos = 0
	}
}

func (b *BitOutputStream) Flush() []byte {
	if b.bitPos > 0 {
		b.buffer <<= (8 - b.bitPos)
		b.bytes = append(b.bytes, byte(b.buffer))
	}
	return b.bytes
}

type ArithEncodedResult struct {
	data        []byte
	bitCount    int
	frequencies [256]int
}

type ArithEncode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	encoded   ArithEncodedResult
	resultVal uint32
}

func (a *ArithEncode) Name() string {
	return "Compress::ArithEncode"
}

func (a *ArithEncode) Prepare() {
	a.sizeVal = a.ConfigVal("size")
	a.testData = generateTestData(a.sizeVal)
	a.resultVal = 0
}

func (a *ArithEncode) Run(iterationId int) {
	a.encoded = a.arithEncode(a.testData)
	a.resultVal += uint32(len(a.encoded.data))
}

func (a *ArithEncode) Checksum() uint32 {
	return a.resultVal
}

func (a *ArithEncode) arithEncode(data []byte) ArithEncodedResult {
	frequencies := [256]int{}
	for _, b := range data {
		frequencies[b]++
	}

	freqTable := NewArithFreqTable(frequencies)

	low := uint64(0)
	high := uint64(0xFFFFFFFF)
	pending := 0
	output := NewBitOutputStream()

	for _, b := range data {
		idx := int(b)
		range_ := high - low + 1

		high = low + (range_ * uint64(freqTable.high[idx]) / uint64(freqTable.total)) - 1
		low = low + (range_ * uint64(freqTable.low[idx]) / uint64(freqTable.total))

		for {
			if high < 0x80000000 {
				output.WriteBit(0)
				for i := 0; i < pending; i++ {
					output.WriteBit(1)
				}
				pending = 0
			} else if low >= 0x80000000 {
				output.WriteBit(1)
				for i := 0; i < pending; i++ {
					output.WriteBit(0)
				}
				pending = 0
				low -= 0x80000000
				high -= 0x80000000
			} else if low >= 0x40000000 && high < 0xC0000000 {
				pending++
				low -= 0x40000000
				high -= 0x40000000
			} else {
				break
			}

			low <<= 1
			high = (high << 1) | 1
			high &= 0xFFFFFFFF
		}
	}

	pending++
	if low < 0x40000000 {
		output.WriteBit(0)
		for i := 0; i < pending; i++ {
			output.WriteBit(1)
		}
	} else {
		output.WriteBit(1)
		for i := 0; i < pending; i++ {
			output.WriteBit(0)
		}
	}

	return ArithEncodedResult{
		data:        output.Flush(),
		bitCount:    output.bitsWritten,
		frequencies: frequencies,
	}
}

type BitInputStream struct {
	bytes       []byte
	bytePos     int
	bitPos      int
	currentByte byte
}

func NewBitInputStream(bytes []byte) *BitInputStream {
	current := byte(0)
	if len(bytes) > 0 {
		current = bytes[0]
	}
	return &BitInputStream{
		bytes:       bytes,
		bytePos:     0,
		bitPos:      0,
		currentByte: current,
	}
}

func (b *BitInputStream) ReadBit() int {
	if b.bitPos == 8 {
		b.bytePos++
		b.bitPos = 0
		if b.bytePos < len(b.bytes) {
			b.currentByte = b.bytes[b.bytePos]
		} else {
			b.currentByte = 0
		}
	}

	bit := int((b.currentByte >> (7 - b.bitPos)) & 1)
	b.bitPos++
	return bit
}

type ArithDecode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	decoded   []byte
	encoded   ArithEncodedResult
	resultVal uint32
}

func (a *ArithDecode) Name() string {
	return "Compress::ArithDecode"
}

func (a *ArithDecode) Prepare() {
	a.sizeVal = a.ConfigVal("size")
	encoder := &ArithEncode{BaseBenchmark: BaseBenchmark{className: "Compress::ArithDecode"}}
	encoder.Prepare()
	encoder.Run(0)
	a.testData = encoder.testData
	a.encoded = encoder.encoded
	a.resultVal = 0
}

func (a *ArithDecode) Run(iterationId int) {
	a.decoded = a.arithDecode(a.encoded)
	a.resultVal += uint32(len(a.decoded))
}

func (a *ArithDecode) Checksum() uint32 {
	res := a.resultVal
	if bytes.Equal(a.decoded, a.testData) {
		res += 100000
	}
	return res
}

func (a *ArithDecode) arithDecode(encoded ArithEncodedResult) []byte {
	frequencies := encoded.frequencies
	total := 0
	for _, f := range frequencies {
		total += f
	}
	dataSize := total

	lowTable := [256]int{}
	highTable := [256]int{}
	cum := 0
	for i := 0; i < 256; i++ {
		lowTable[i] = cum
		cum += frequencies[i]
		highTable[i] = cum
	}

	result := make([]byte, dataSize)
	input := NewBitInputStream(encoded.data)

	value := uint64(0)
	for i := 0; i < 32; i++ {
		value = (value << 1) | uint64(input.ReadBit())
	}

	low := uint64(0)
	high := uint64(0xFFFFFFFF)

	for j := 0; j < dataSize; j++ {
		range_ := high - low + 1
		scaled := ((value-low+1)*uint64(total) - 1) / range_

		symbol := 0
		for symbol < 255 && uint64(highTable[symbol]) <= scaled {
			symbol++
		}

		result[j] = byte(symbol)

		high = low + (range_ * uint64(highTable[symbol]) / uint64(total)) - 1
		low = low + (range_ * uint64(lowTable[symbol]) / uint64(total))

		for {
			if high < 0x80000000 {

			} else if low >= 0x80000000 {
				value -= 0x80000000
				low -= 0x80000000
				high -= 0x80000000
			} else if low >= 0x40000000 && high < 0xC0000000 {
				value -= 0x40000000
				low -= 0x40000000
				high -= 0x40000000
			} else {
				break
			}

			low <<= 1
			high = (high << 1) | 1
			value = (value << 1) | uint64(input.ReadBit())
		}
	}

	return result
}

type LZWResult struct {
	data     []byte
	dictSize int
}

type LZWEncode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	encoded   LZWResult
	resultVal uint32
}

func (l *LZWEncode) Name() string {
	return "Compress::LZWEncode"
}

func (l *LZWEncode) Prepare() {
	l.sizeVal = l.ConfigVal("size")
	l.testData = generateTestData(l.sizeVal)
	l.resultVal = 0
}

func (l *LZWEncode) Run(iterationId int) {
	l.encoded = l.lzwEncode(l.testData)
	l.resultVal += uint32(len(l.encoded.data))
}

func (l *LZWEncode) Checksum() uint32 {
	return l.resultVal
}

func (l *LZWEncode) lzwEncode(input []byte) LZWResult {
	if len(input) == 0 {
		return LZWResult{[]byte{}, 256}
	}

	dict := make(map[string]int, 4096)
	for i := 0; i < 256; i++ {
		dict[string([]byte{byte(i)})] = i
	}

	nextCode := 256
	result := make([]byte, 0, len(input)*2)

	current := string([]byte{input[0]})

	for i := 1; i < len(input); i++ {
		nextChar := string([]byte{input[i]})
		newStr := current + nextChar

		if _, ok := dict[newStr]; ok {
			current = newStr
		} else {
			code := dict[current]
			result = append(result, byte((code>>8)&0xFF))
			result = append(result, byte(code&0xFF))

			dict[newStr] = nextCode
			nextCode++
			current = nextChar
		}
	}

	code := dict[current]
	result = append(result, byte((code>>8)&0xFF))
	result = append(result, byte(code&0xFF))

	return LZWResult{result, nextCode}
}

type LZWDecode struct {
	BaseBenchmark
	sizeVal   int64
	testData  []byte
	decoded   []byte
	encoded   LZWResult
	resultVal uint32
}

func (l *LZWDecode) Name() string {
	return "Compress::LZWDecode"
}

func (l *LZWDecode) Prepare() {
	l.sizeVal = l.ConfigVal("size")
	encoder := &LZWEncode{BaseBenchmark: BaseBenchmark{className: "Compress::LZWDecode"}}
	encoder.Prepare()
	encoder.Run(0)
	l.testData = encoder.testData
	l.encoded = encoder.encoded
	l.resultVal = 0
}

func (l *LZWDecode) Run(iterationId int) {
	l.decoded = l.lzwDecode(l.encoded)
	l.resultVal += uint32(len(l.decoded))
}

func (l *LZWDecode) Checksum() uint32 {
	res := l.resultVal
	if bytes.Equal(l.decoded, l.testData) {
		res += 100000
	}
	return res
}

func (l *LZWDecode) lzwDecode(encoded LZWResult) []byte {
	if len(encoded.data) == 0 {
		return []byte{}
	}

	dict := make([]string, 256, 4096)
	for i := 0; i < 256; i++ {
		dict[i] = string(byte(i))
	}

	data := encoded.data
	result := make([]byte, 0, len(data)*2)
	pos := 0

	oldCode := int(data[pos])<<8 | int(data[pos+1])
	pos += 2

	oldStr := dict[oldCode]
	result = append(result, oldStr...)

	nextCode := 256

	for pos < len(data) {

		newCode := int(data[pos])<<8 | int(data[pos+1])
		pos += 2

		var newStr string
		if newCode < nextCode {
			newStr = dict[newCode]
		} else if newCode == nextCode {

			newStr = oldStr + string(oldStr[0])
		} else {
			panic("LZW decode error")
		}

		result = append(result, newStr...)

		dict = append(dict, oldStr+string(newStr[0]))
		nextCode++

		oldStr = newStr
	}

	return result
}

func generatePairStrings(n, m int) []struct {
	s1 string
	s2 string
} {
	pairs := make([]struct {
		s1 string
		s2 string
	}, n)
	chars := "abcdefghij"

	for i := 0; i < n; i++ {
		len1 := int(NextInt(m)) + 4
		len2 := int(NextInt(m)) + 4

		var sb1 strings.Builder
		var sb2 strings.Builder
		sb1.Grow(len1)
		sb2.Grow(len2)

		for j := 0; j < len1; j++ {
			sb1.WriteByte(chars[NextInt(10)])
		}
		for j := 0; j < len2; j++ {
			sb2.WriteByte(chars[NextInt(10)])
		}

		pairs[i] = struct {
			s1 string
			s2 string
		}{sb1.String(), sb2.String()}
	}

	return pairs
}

type Jaro struct {
	BaseBenchmark
	count int
	size  int
	pairs []struct {
		s1 string
		s2 string
	}
	result uint32
}

func (j *Jaro) Prepare() {
	j.count = int(j.ConfigVal("count"))
	j.size = int(j.ConfigVal("size"))
	j.pairs = generatePairStrings(j.count, j.size)
	j.result = 0
}

func (j *Jaro) jaro(s1, s2 string) float64 {

	bytes1 := []byte(s1)
	bytes2 := []byte(s2)

	len1 := len(bytes1)
	len2 := len(bytes2)

	if len1 == 0 || len2 == 0 {
		return 0.0
	}

	matchDist := max(len1, len2)/2 - 1
	if matchDist < 0 {
		matchDist = 0
	}

	s1Matches := make([]bool, len1)
	s2Matches := make([]bool, len2)

	matches := 0
	for i := 0; i < len1; i++ {
		start := max(0, i-matchDist)
		end := min(len2-1, i+matchDist)

		for j := start; j <= end; j++ {
			if !s2Matches[j] && bytes1[i] == bytes2[j] {
				s1Matches[i] = true
				s2Matches[j] = true
				matches++
				break
			}
		}
	}

	if matches == 0 {
		return 0.0
	}

	transpositions := 0
	k := 0
	for i := 0; i < len1; i++ {
		if s1Matches[i] {
			for k < len2 && !s2Matches[k] {
				k++
			}
			if k < len2 {
				if bytes1[i] != bytes2[k] {
					transpositions++
				}
				k++
			}
		}
	}
	transpositions /= 2

	m := float64(matches)
	return (m/float64(len1) + m/float64(len2) + (m-float64(transpositions))/m) / 3.0
}

func (j *Jaro) Run(iterationID int) {
	for _, pair := range j.pairs {
		j.result += uint32(j.jaro(pair.s1, pair.s2) * 1000)
	}
}

func (j *Jaro) Checksum() uint32 {
	return j.result
}

func (j *Jaro) Name() string {
	return "Distance::Jaro"
}

type NGram struct {
	BaseBenchmark
	count int
	size  int
	pairs []struct {
		s1 string
		s2 string
	}
	result uint32
}

const nGramN = 4

func (n *NGram) Prepare() {
	n.count = int(n.ConfigVal("count"))
	n.size = int(n.ConfigVal("size"))
	n.pairs = generatePairStrings(n.count, n.size)
	n.result = 0
}

func (n *NGram) ngram(s1, s2 string) float64 {
	if len(s1) < nGramN || len(s2) < nGramN {
		return 0.0
	}

	bytes1 := []byte(s1)
	bytes2 := []byte(s2)

	grams1 := make(map[uint32]int, len(bytes1))

	for i := 0; i <= len(bytes1)-nGramN; i++ {
		gram := (uint32(bytes1[i]) << 24) |
			(uint32(bytes1[i+1]) << 16) |
			(uint32(bytes1[i+2]) << 8) |
			uint32(bytes1[i+3])

		grams1[gram]++
	}

	grams2 := make(map[uint32]int, len(bytes2))
	intersection := 0

	for i := 0; i <= len(bytes2)-nGramN; i++ {
		gram := (uint32(bytes2[i]) << 24) |
			(uint32(bytes2[i+1]) << 16) |
			(uint32(bytes2[i+2]) << 8) |
			uint32(bytes2[i+3])

		grams2[gram]++

		if cnt1, ok := grams1[gram]; ok && grams2[gram] <= cnt1 {
			intersection++
		}
	}

	total := len(grams1) + len(grams2)
	if total > 0 {
		return float64(intersection) / float64(total)
	}
	return 0.0
}

func (n *NGram) Run(iterationID int) {
	for _, pair := range n.pairs {
		n.result += uint32(n.ngram(pair.s1, pair.s2) * 1000)
	}
}

func (n *NGram) Checksum() uint32 {
	return n.result
}

func (n *NGram) Name() string {
	return "Distance::NGram"
}

type Words struct {
	BaseBenchmark
	words       int64
	wordLen     int64
	text        string
	checksumVal uint32
}

func (w *Words) Prepare() {
	w.words = w.ConfigVal("words")
	w.wordLen = w.ConfigVal("word_len")

	chars := []byte("abcdefghijklmnopqrstuvwxyz")
	charCount := len(chars)

	var buf bytes.Buffer
	buf.Grow(int(w.words * (w.wordLen + 1)))

	for i := int64(0); i < w.words; i++ {
		length := int(NextInt(int(w.wordLen))) + NextInt(3) + 3
		for j := 0; j < length; j++ {
			idx := NextInt(charCount)
			buf.WriteByte(chars[idx])
		}
		if i < w.words-1 {
			buf.WriteByte(' ')
		}
	}

	w.text = buf.String()
}

func (w *Words) Run(iteration_id int) {

	frequencies := make(map[string]int)

	for _, word := range strings.Fields(w.text) {
		frequencies[word]++
	}

	maxWord := ""
	maxCount := 0
	for word, count := range frequencies {
		if count > maxCount {
			maxCount = count
			maxWord = word
		}
	}

	freqSize := uint32(len(frequencies))
	wordChecksum := Checksum(maxWord)

	w.checksumVal += uint32(maxCount) + wordChecksum + freqSize
}

func (w *Words) Checksum() uint32 {
	return w.checksumVal
}

func main() {
	if len(os.Args) > 1 {
		LoadConfig(os.Args[1])
	} else {
		LoadConfig("../test.js")
	}

	if len(os.Args) > 2 {
		RunBenchmarks(os.Args[2])
	} else {
		RunBenchmarks("")
	}
}
