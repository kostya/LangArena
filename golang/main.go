package main

import (
	"bytes"
	"container/heap"
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
		&Pidigits{BaseBenchmark: BaseBenchmark{className: "Pidigits"}},
		&Binarytrees{BaseBenchmark: BaseBenchmark{className: "Binarytrees"}},
		&BrainfuckArray{BaseBenchmark: BaseBenchmark{className: "BrainfuckArray"}},
		&BrainfuckRecursion{BaseBenchmark: BaseBenchmark{className: "BrainfuckRecursion"}},
		&Fannkuchredux{BaseBenchmark: BaseBenchmark{className: "Fannkuchredux"}},
		&Fasta{BaseBenchmark: BaseBenchmark{className: "Fasta"}},
		&Knuckeotide{BaseBenchmark: BaseBenchmark{className: "Knuckeotide"}},
		&Mandelbrot{BaseBenchmark: BaseBenchmark{className: "Mandelbrot"}},
		&Matmul1T{BaseBenchmark: BaseBenchmark{className: "Matmul1T"}},
		&Matmul4T{BaseBenchmark: BaseBenchmark{className: "Matmul4T"}},
		&Matmul8T{BaseBenchmark: BaseBenchmark{className: "Matmul8T"}},
		&Matmul16T{BaseBenchmark: BaseBenchmark{className: "Matmul16T"}},
		&Nbody{BaseBenchmark: BaseBenchmark{className: "Nbody"}},
		&RegexDna{BaseBenchmark: BaseBenchmark{className: "RegexDna"}},
		&Revcomp{BaseBenchmark: BaseBenchmark{className: "Revcomp"}},
		&Spectralnorm{BaseBenchmark: BaseBenchmark{className: "Spectralnorm"}},
		&Base64Encode{BaseBenchmark: BaseBenchmark{className: "Base64Encode"}},
		&Base64Decode{BaseBenchmark: BaseBenchmark{className: "Base64Decode"}},
		&JsonGenerate{BaseBenchmark: BaseBenchmark{className: "JsonGenerate"}},
		&JsonParseDom{BaseBenchmark: BaseBenchmark{className: "JsonParseDom"}},
		&JsonParseMapping{BaseBenchmark: BaseBenchmark{className: "JsonParseMapping"}},
		&Primes{BaseBenchmark: BaseBenchmark{className: "Primes"}},
		&Noise{BaseBenchmark: BaseBenchmark{className: "Noise"}},
		&TextRaytracer{BaseBenchmark: BaseBenchmark{className: "TextRaytracer"}},
		&NeuralNet{BaseBenchmark: BaseBenchmark{className: "NeuralNet"}},
		&SortQuick{BaseBenchmark: BaseBenchmark{className: "SortQuick"}},
		&SortMerge{BaseBenchmark: BaseBenchmark{className: "SortMerge"}},
		&SortSelf{BaseBenchmark: BaseBenchmark{className: "SortSelf"}},
		&GraphPathBFS{BaseBenchmark: BaseBenchmark{className: "GraphPathBFS"}},
		&GraphPathDFS{BaseBenchmark: BaseBenchmark{className: "GraphPathDFS"}},
		&GraphPathDijkstra{BaseBenchmark: BaseBenchmark{className: "GraphPathDijkstra"}},
		&BufferHashSHA256{BaseBenchmark: BaseBenchmark{className: "BufferHashSHA256"}},
		&BufferHashCRC32{BaseBenchmark: BaseBenchmark{className: "BufferHashCRC32"}},
		&CacheSimulation{BaseBenchmark: BaseBenchmark{className: "CacheSimulation"}},
		&CalculatorAst{BaseBenchmark: BaseBenchmark{className: "CalculatorAst"}},
		&CalculatorInterpreter{BaseBenchmark: BaseBenchmark{className: "CalculatorInterpreter"}},
		&GameOfLife{BaseBenchmark: BaseBenchmark{className: "GameOfLife"}},
		&MazeGenerator{BaseBenchmark: BaseBenchmark{className: "MazeGenerator"}},
		&AStarPathfinder{BaseBenchmark: BaseBenchmark{className: "AStarPathfinder"}},
		&BWTHuffEncode{BaseBenchmark: BaseBenchmark{className: "BWTHuffEncode"}},
		&BWTHuffDecode{BaseBenchmark: BaseBenchmark{className: "BWTHuffDecode"}},
	}

	for _, bench := range allBenches {
		className := strings.Split(fmt.Sprintf("%T", bench), ".")[1]

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

type TreeNode struct {
	left  *TreeNode
	right *TreeNode
	item  int
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
	BaseBenchmark
	n      int64
	result uint32
}

func (b *Binarytrees) Prepare() {
	b.n = b.ConfigVal("depth")
}

func (b *Binarytrees) Run(iteration_id int) {
	minDepth := 4
	maxDepth := minDepth + 2
	if int(b.n) > maxDepth {
		maxDepth = int(b.n)
	}
	stretchDepth := maxDepth + 1

	b.result += uint32(NewTreeNode(0, stretchDepth).Check())

	for depth := minDepth; depth <= maxDepth; depth += 2 {
		iterations := 1 << (maxDepth - depth + minDepth)
		for i := 1; i <= iterations; i++ {
			b.result += uint32(NewTreeNode(i, depth).Check())
			b.result += uint32(NewTreeNode(-i, depth).Check())
		}
	}
}

func (b *Binarytrees) Checksum() uint32 {
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
	return "BrainfuckArray"
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
	return "BrainfuckRecursion"
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
	for i := range perm1 {
		perm1[i] = i
	}
	perm := [32]int{}
	count := [32]int{}
	maxFlipsCount := 0
	permCount := 0
	checksum := 0
	r := n

	for {
		for r > 1 {
			count[r-1] = r
			r--
		}

		copy(perm[:], perm1[:])
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
	f := &Fasta{BaseBenchmark: BaseBenchmark{className: "Knuckeotide"}}
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

type Matmul1T struct {
	BaseBenchmark
	n      int64
	result uint32
}

func (m *Matmul1T) Prepare() {
	m.n = m.ConfigVal("n")
}

func (m *Matmul1T) matgen(n int) [][]float64 {
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

func (m *Matmul1T) matmul(a, b [][]float64) [][]float64 {
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

func (m *Matmul1T) Run(iteration_id int) {
	a := m.matgen(int(m.n))
	b := m.matgen(int(m.n))
	c := m.matmul(a, b)
	m.result += ChecksumFloat64(c[int(m.n)>>1][int(m.n)>>1])
}

func (m *Matmul1T) Checksum() uint32 {
	return m.result
}

type Matmul4T struct {
	BaseBenchmark
	n      int64
	result uint32
}

func (m *Matmul4T) Prepare() {
	m.n = m.ConfigVal("n")
}

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

	bT := make([][]float64, size)
	for i := range bT {
		bT[i] = make([]float64, size)
		for j := 0; j < size; j++ {
			bT[i][j] = b[j][i]
		}
	}

	c := make([][]float64, size)
	for i := range c {
		c[i] = make([]float64, size)
	}

	runtime.GOMAXPROCS(4)

	var wg sync.WaitGroup
	numWorkers := 4
	workCh := make(chan int, size)

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

	for i := 0; i < size; i++ {
		workCh <- i
	}
	close(workCh)

	wg.Wait()
	return c
}

func (m *Matmul4T) Run(iteration_id int) {
	a := m.matgen(int(m.n))
	b := m.matgen(int(m.n))
	c := m.matmulParallel(a, b)
	m.result += ChecksumFloat64(c[int(m.n)>>1][int(m.n)>>1])
}

func (m *Matmul4T) Checksum() uint32 {
	return m.result
}

type Matmul8T struct {
	BaseBenchmark
	n      int64
	result uint32
}

func (m *Matmul8T) Prepare() {
	m.n = m.ConfigVal("n")
}

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

	bT := make([][]float64, size)
	for i := range bT {
		bT[i] = make([]float64, size)
		for j := 0; j < size; j++ {
			bT[i][j] = b[j][i]
		}
	}

	c := make([][]float64, size)
	for i := range c {
		c[i] = make([]float64, size)
	}

	runtime.GOMAXPROCS(8)

	var wg sync.WaitGroup
	numWorkers := 8
	workCh := make(chan int, size)

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

	for i := 0; i < size; i++ {
		workCh <- i
	}
	close(workCh)

	wg.Wait()
	return c
}

func (m *Matmul8T) Run(iteration_id int) {
	a := m.matgen(int(m.n))
	b := m.matgen(int(m.n))
	c := m.matmulParallel(a, b)
	m.result += ChecksumFloat64(c[int(m.n)>>1][int(m.n)>>1])
}

func (m *Matmul8T) Checksum() uint32 {
	return m.result
}

type Matmul16T struct {
	BaseBenchmark
	n      int64
	result uint32
}

func (m *Matmul16T) Prepare() {
	m.n = m.ConfigVal("n")
}

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

	bT := make([][]float64, size)
	for i := range bT {
		bT[i] = make([]float64, size)
		for j := 0; j < size; j++ {
			bT[i][j] = b[j][i]
		}
	}

	c := make([][]float64, size)
	for i := range c {
		c[i] = make([]float64, size)
	}

	runtime.GOMAXPROCS(16)

	var wg sync.WaitGroup
	numWorkers := 16
	workCh := make(chan int, size)

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

	for i := 0; i < size; i++ {
		workCh <- i
	}
	close(workCh)

	wg.Wait()
	return c
}

func (m *Matmul16T) Run(iteration_id int) {
	a := m.matgen(int(m.n))
	b := m.matgen(int(m.n))
	c := m.matmulParallel(a, b)
	m.result += ChecksumFloat64(c[int(m.n)>>1][int(m.n)>>1])
}

func (m *Matmul16T) Checksum() uint32 {
	return m.result
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
	nbodies := len(n.body)
	dt := 0.01

	i := 0
	for i < nbodies {
		b := n.body[i]
		b.MoveFromI(n.body, nbodies, dt, i+1)
		i++
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
	f := &Fasta{BaseBenchmark: BaseBenchmark{className: "RegexDna"}}
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
	f := &Fasta{BaseBenchmark: BaseBenchmark{className: "Revcomp"}}
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
	str    string
	str2   string
	result uint32
}

func (b *Base64Encode) Prepare() {
	b.n = b.ConfigVal("size")
	b.str = strings.Repeat("a", int(b.n))
}

func (b *Base64Encode) Run(iteration_id int) {
	b.str2 = base64.StdEncoding.EncodeToString([]byte(b.str))
	b.result += uint32(len(b.str2))
}

func (b *Base64Encode) Checksum() uint32 {
	resultStr := fmt.Sprintf("encode %s... to %s...: %d",
		b.str[:min(4, len(b.str))],
		b.str2[:min(4, len(b.str2))],
		b.result)
	return Checksum(resultStr)
}

type Base64Decode struct {
	BaseBenchmark
	n      int64
	str2   string
	str3   string
	result uint32
}

func (b *Base64Decode) Prepare() {
	b.n = b.ConfigVal("size")
	str := strings.Repeat("a", int(b.n))
	b.str2 = base64.StdEncoding.EncodeToString([]byte(str))
}

func (b *Base64Decode) Run(iteration_id int) {
	decoded, _ := base64.StdEncoding.DecodeString(b.str2)
	b.str3 = string(decoded)
	b.result += uint32(len(b.str3))
}

func (b *Base64Decode) Checksum() uint32 {
	resultStr := fmt.Sprintf("decode %s... to %s...: %d",
		b.str2[:min(4, len(b.str2))],
		b.str3[:min(4, len(b.str3))],
		b.result)
	return Checksum(resultStr)
}

type Node struct {
	children [10]*Node
	terminal bool
}

type Primes struct {
	BaseBenchmark
	n      int64
	prefix int64
	result uint32
}

func (p *Primes) Prepare() {
	p.n = p.ConfigVal("limit")
	p.prefix = p.ConfigVal("prefix")
	p.result = 5432
}

func generatePrimes(limit int) []int {
	if limit < 2 {
		return nil
	}

	isPrime := make([]byte, limit+1)
	for i := 2; i <= limit; i++ {
		isPrime[i] = 1
	}

	sqrtLimit := int(math.Sqrt(float64(limit)))

	for p := 2; p <= sqrtLimit; p++ {
		if isPrime[p] == 1 {
			for multiple := p * p; multiple <= limit; multiple += p {
				isPrime[multiple] = 0
			}
		}
	}

	estimatedCount := 0
	if limit > 1000 {
		estimatedCount = int(float64(limit) / (math.Log(float64(limit)) - 1.1))
	}
	if estimatedCount < 1000 {
		estimatedCount = 1000
	}

	primes := make([]int, 0, estimatedCount)

	if limit >= 2 {
		primes = append(primes, 2)
	}

	for p := 3; p <= limit; p += 2 {
		if isPrime[p] == 1 {
			primes = append(primes, p)
		}
	}

	return primes
}

func buildTrie(primes []int) *Node {
	root := &Node{}
	digits := make([]byte, 0, 12)

	for _, prime := range primes {
		node := root
		digits = digits[:0]
		temp := prime
		for temp > 0 {
			digits = append(digits, byte('0'+(temp%10)))
			temp /= 10
		}

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

func findWithPrefix(trie *Node, prefix int) []int {
	node := trie
	prefixDigits := make([]int, 0, 12)
	prefixValue := 0
	temp := prefix

	for temp > 0 {
		prefixDigits = append(prefixDigits, temp%10)
		temp /= 10
	}

	for i := len(prefixDigits) - 1; i >= 0; i-- {
		digit := prefixDigits[i]
		prefixValue = prefixValue*10 + digit
		if node.children[digit] == nil {
			return nil
		}
		node = node.children[digit]
	}

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

		for digit := 0; digit < 10; digit++ {
			if child := current.node.children[digit]; child != nil {
				queue = append(queue, queueItem{
					node:   child,
					number: current.number*10 + digit,
				})
			}
		}
	}

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

func (p *Primes) Run(iteration_id int) {
	primes := generatePrimes(int(p.n))
	trie := buildTrie(primes)
	results := findWithPrefix(trie, int(p.prefix))
	p.result += uint32(len(results))

	for _, r := range results {
		p.result += uint32(r)
	}
}

func (p *Primes) Checksum() uint32 {
	return p.result
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
	text   bytes.Buffer
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

	data, _ := json.Marshal(resp)
	j.text.Write(data)

	if len(data) >= 15 && string(data[:15]) == "{\"coordinates\":" {
		j.result++
	}
}

func (j *JsonGenerate) Checksum() uint32 {
	return j.result
}

type JsonParseDom struct {
	BaseBenchmark
	text   string
	result uint32
}

func (j *JsonParseDom) Prepare() {
	gen := &JsonGenerate{BaseBenchmark: BaseBenchmark{className: "JsonParseDom"}}
	gen.n = j.ConfigVal("coords")
	gen.Prepare()
	gen.Run(0)
	j.text = gen.text.String()
}

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

func (j *JsonParseDom) Run(iteration_id int) {
	x, y, z := j.calc(j.text)
	j.result += ChecksumFloat64(x) + ChecksumFloat64(y) + ChecksumFloat64(z)
}

func (j *JsonParseDom) Checksum() uint32 {
	return j.result
}

type JsonParseMapping struct {
	BaseBenchmark
	text   string
	result uint32
}

func (j *JsonParseMapping) Prepare() {
	gen := &JsonGenerate{BaseBenchmark: BaseBenchmark{className: "JsonParseMapping"}}
	gen.n = j.ConfigVal("coords")
	gen.Prepare()
	gen.Run(0)
	j.text = gen.text.String()
}

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

func (j *JsonParseMapping) Run(iteration_id int) {
	x, y, z := j.calc(j.text)
	j.result += ChecksumFloat64(x) + ChecksumFloat64(y) + ChecksumFloat64(z)
}

func (j *JsonParseMapping) Checksum() uint32 {
	return j.result
}

type Vec2 struct {
	X, Y float64
}

type Noise2DContext struct {
	rgradients   []Vec2
	permutations []int
	size         int
}

func NewNoise2DContext(size int) *Noise2DContext {
	ctx := &Noise2DContext{
		rgradients:   make([]Vec2, size),
		permutations: make([]int, size),
		size:         size,
	}

	for i := range ctx.rgradients {
		v := NextFloat(math.Pi * 2.0)
		ctx.rgradients[i] = Vec2{math.Cos(v), math.Sin(v)}
	}

	for i := range ctx.permutations {
		ctx.permutations[i] = i
	}

	for i := 0; i < size; i++ {
		a := NextInt(size)
		b := NextInt(size)
		ctx.permutations[a], ctx.permutations[b] = ctx.permutations[b], ctx.permutations[a]
	}

	return ctx
}

func (n *Noise2DContext) GetGradient(x, y int) Vec2 {
	idx := n.permutations[x&(n.size-1)] + n.permutations[y&(n.size-1)]
	return n.rgradients[idx&(n.size-1)]
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
	BaseBenchmark
	size   int64
	result uint32
	n2d    *Noise2DContext
}

func (n *Noise) Prepare() {
	n.size = n.ConfigVal("size")
	n.n2d = NewNoise2DContext(int(n.size))
}

func (n *Noise) Run(iteration_id int) {
	SYM := []rune{' ', '░', '▒', '▓', '█', '█'}

	yOffset := float64(iteration_id * 128)

	size := int(n.size)
	var sum uint32 = n.result

	for y := 0; y < size; y++ {

		yCoord := float64(y) + yOffset

		for x := 0; x < size; x++ {
			v := n.n2d.Get(float64(x)*0.1, yCoord*0.1)*0.5 + 0.5
			idx := int(v / 0.2)
			if idx >= len(SYM) {
				idx = len(SYM) - 1
			}
			sum += uint32(SYM[idx])
		}
	}

	n.result = sum
}

func (n *Noise) Checksum() uint32 {
	return n.result
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

func (n *NeuralNet) Prepare() {

	n.xorNet = NewNeuralNetwork(2, 10, 1)
	n.res = make([]float64, 0, 4)
}

func (n *NeuralNet) Run(iteration_id int) {

	n.xorNet.Train([]float64{0, 0}, []float64{0})
	n.xorNet.Train([]float64{1, 0}, []float64{1})
	n.xorNet.Train([]float64{0, 1}, []float64{1})
	n.xorNet.Train([]float64{1, 1}, []float64{0})
}

func (n *NeuralNet) Checksum() uint32 {

	n.xorNet.FeedForward([]float64{0, 0})
	outputs1 := n.xorNet.CurrentOutputs()

	n.xorNet.FeedForward([]float64{0, 1})
	outputs2 := n.xorNet.CurrentOutputs()

	n.xorNet.FeedForward([]float64{1, 0})
	outputs3 := n.xorNet.CurrentOutputs()

	n.xorNet.FeedForward([]float64{1, 1})
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

type GraphPathBFS struct {
	BaseBenchmark
	n_pairs int64
	graph   *Graph
	pairs   [][2]int
	result  uint32
}

func (g *GraphPathBFS) Prepare() {
	g.n_pairs = g.ConfigVal("pairs")
	vertices := int(g.ConfigVal("vertices"))
	components := max(10, vertices/10000)
	g.graph = NewGraph(vertices, components)
	g.graph.GenerateRandom()
	g.pairs = g.generatePairs(int(g.n_pairs))
}

func (g *GraphPathBFS) generatePairs(n int) [][2]int {
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
	for i := 0; i < len(g.pairs); i += 1 {
		length := g.bfsShortestPath(g.pairs[i][0], g.pairs[i][1])
		g.result += uint32(length)
	}
}

func (g *GraphPathBFS) Checksum() uint32 {
	return g.result
}

type GraphPathDFS struct {
	BaseBenchmark
	n_pairs int64
	graph   *Graph
	pairs   [][2]int
	result  uint32
}

func (g *GraphPathDFS) Prepare() {
	g.n_pairs = g.ConfigVal("pairs")
	vertices := int(g.ConfigVal("vertices"))
	components := max(10, vertices/10000)
	g.graph = NewGraph(vertices, components)
	g.graph.GenerateRandom()
	g.pairs = g.generatePairs(int(g.n_pairs))
}

func (g *GraphPathDFS) generatePairs(n int) [][2]int {
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
	for i := 0; i < len(g.pairs); i += 1 {
		length := g.dfsFindPath(g.pairs[i][0], g.pairs[i][1])
		g.result += uint32(length)
	}
}

func (g *GraphPathDFS) Checksum() uint32 {
	return g.result
}

type GraphPathDijkstra struct {
	BaseBenchmark
	n_pairs int64
	graph   *Graph
	pairs   [][2]int
	result  uint32
}

func (g *GraphPathDijkstra) Prepare() {
	g.n_pairs = g.ConfigVal("pairs")
	vertices := int(g.ConfigVal("vertices"))
	components := max(10, vertices/10000)
	g.graph = NewGraph(vertices, components)
	g.graph.GenerateRandom()
	g.pairs = g.generatePairs(int(g.n_pairs))
}

func (g *GraphPathDijkstra) generatePairs(n int) [][2]int {
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

func (g *GraphPathDijkstra) Run(iteration_id int) {
	for i := 0; i < len(g.pairs); i += 1 {
		length := g.dijkstraShortestPath(g.pairs[i][0], g.pairs[i][1])
		g.result += uint32(length)
	}
}

func (g *GraphPathDijkstra) Checksum() uint32 {
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
	key := fmt.Sprintf("item_%d", NextInt(int(c.ConfigVal("values"))))
	if _, ok := c.cache.Get(key); ok {
		c.hits += 1
		c.cache.Put(key, fmt.Sprintf("updated_%d", iteration_id))
	} else {
		c.misses += 1
		c.cache.Put(key, fmt.Sprintf("new_%d", iteration_id))
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
	astBench := &CalculatorAst{BaseBenchmark: BaseBenchmark{className: "CalculatorInterpreter"}}
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

type Cell uint8

const (
	Dead Cell = iota
	Alive
)

type Grid struct {
	width  int
	height int
	cells  []Cell
	buffer []Cell
}

func NewGrid(width, height int) *Grid {
	size := width * height
	return &Grid{
		width:  width,
		height: height,
		cells:  make([]Cell, size),
		buffer: make([]Cell, size),
	}
}

func (g *Grid) idx(x, y int) int {
	return y*g.width + x
}

func (g *Grid) countNeighbors(x, y int, cells []Cell) int {

	yPrev := y - 1
	if yPrev < 0 {
		yPrev = g.height - 1
	}
	yNext := y + 1
	if yNext >= g.height {
		yNext = 0
	}
	xPrev := x - 1
	if xPrev < 0 {
		xPrev = g.width - 1
	}
	xNext := x + 1
	if xNext >= g.width {
		xNext = 0
	}

	count := 0

	idx := yPrev * g.width
	if cells[idx+xPrev] == Alive {
		count++
	}
	if cells[idx+x] == Alive {
		count++
	}
	if cells[idx+xNext] == Alive {
		count++
	}

	idx = y * g.width
	if cells[idx+xPrev] == Alive {
		count++
	}
	if cells[idx+xNext] == Alive {
		count++
	}

	idx = yNext * g.width
	if cells[idx+xPrev] == Alive {
		count++
	}
	if cells[idx+x] == Alive {
		count++
	}
	if cells[idx+xNext] == Alive {
		count++
	}

	return count
}

func (g *Grid) nextGeneration() *Grid {
	width := g.width
	height := g.height

	cells := g.cells
	buffer := g.buffer

	for y := 0; y < height; y++ {
		yIdx := y * width

		for x := 0; x < width; x++ {
			idx := yIdx + x

			neighbors := g.countNeighbors(x, y, cells)

			current := cells[idx]
			var nextState Cell = Dead

			if current == Alive {
				if neighbors == 2 || neighbors == 3 {
					nextState = Alive
				}
			} else if neighbors == 3 {
				nextState = Alive
			}

			buffer[idx] = nextState
		}
	}

	return &Grid{
		width:  width,
		height: height,
		cells:  buffer,
		buffer: cells,
	}
}

func (g *Grid) computeHash() uint32 {
	const (
		FNV_OFFSET_BASIS uint32 = 2166136261
		FNV_PRIME        uint32 = 16777619
	)

	hash := FNV_OFFSET_BASIS
	cells := g.cells

	for i := 0; i < len(cells); i++ {
		alive := uint32(0)
		if cells[i] == Alive {
			alive = 1
		}
		hash = (hash ^ alive) * FNV_PRIME
	}

	return hash
}

type GameOfLife struct {
	BaseBenchmark
	width  int
	height int
	grid   *Grid
}

func (g *GameOfLife) Prepare() {
	g.width = int(g.ConfigVal("w"))
	g.height = int(g.ConfigVal("h"))
	g.grid = NewGrid(g.width, g.height)

	cells := g.grid.cells
	width := g.width

	for y := 0; y < g.height; y++ {
		yIdx := y * width
		for x := 0; x < width; x++ {
			if NextFloat(1.0) < 0.1 {
				cells[yIdx+x] = Alive
			}
		}
	}
}

func (g *GameOfLife) Run(iteration_id int) {
	g.grid = g.grid.nextGeneration()
}

func (g *GameOfLife) Checksum() uint32 {
	return g.grid.computeHash()
}

type PCell int

const (
	Wall PCell = iota
	Path
)

type Maze struct {
	width  int
	height int
	cells  [][]PCell
}

func NewMaze(width, height int) *Maze {
	if width < 5 {
		width = 5
	}
	if height < 5 {
		height = 5
	}

	cells := make([][]PCell, height)
	for y := 0; y < height; y++ {
		cells[y] = make([]PCell, width)
		for x := 0; x < width; x++ {
			cells[y][x] = Wall
		}
	}

	return &Maze{width, height, cells}
}

func (m *Maze) set(x, y int, cell PCell) {
	m.cells[y][x] = cell
}

func (m *Maze) get(x, y int) PCell {
	return m.cells[y][x]
}

func (m *Maze) add_random_paths() {
	num_extra_paths := (m.width * m.height) / 20

	for i := 0; i < num_extra_paths; i++ {
		x := 1 + NextInt(m.width-2)
		y := 1 + NextInt(m.height-2)

		if m.get(x, y) == Wall &&
			m.get(x-1, y) == Wall &&
			m.get(x+1, y) == Wall &&
			m.get(x, y-1) == Wall &&
			m.get(x, y+1) == Wall {
			m.set(x, y, Path)
		}
	}
}

func (m *Maze) is_connected_impl(startX, startY, goalX, goalY int) bool {
	if startX >= m.width || startY >= m.height ||
		goalX >= m.width || goalY >= m.height {
		return false
	}

	visited := make([][]bool, m.height)
	for i := range visited {
		visited[i] = make([]bool, m.width)
	}

	type Point struct{ x, y int }
	queue := []Point{{startX, startY}}
	visited[startY][startX] = true

	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]
		x, y := current.x, current.y

		if x == goalX && y == goalY {
			return true
		}

		if y > 0 && m.get(x, y-1) == Path && !visited[y-1][x] {
			visited[y-1][x] = true
			queue = append(queue, Point{x, y - 1})
		}

		if x+1 < m.width && m.get(x+1, y) == Path && !visited[y][x+1] {
			visited[y][x+1] = true
			queue = append(queue, Point{x + 1, y})
		}

		if y+1 < m.height && m.get(x, y+1) == Path && !visited[y+1][x] {
			visited[y+1][x] = true
			queue = append(queue, Point{x, y + 1})
		}

		if x > 0 && m.get(x-1, y) == Path && !visited[y][x-1] {
			visited[y][x-1] = true
			queue = append(queue, Point{x - 1, y})
		}
	}

	return false
}

func (m *Maze) is_connected(startX, startY, goalX, goalY int) bool {
	return m.is_connected_impl(startX, startY, goalX, goalY)
}

func (m *Maze) divide(x1, y1, x2, y2 int) {
	width := x2 - x1
	height := y2 - y1

	if width < 2 || height < 2 {
		return
	}

	width_for_wall := max(width-2, 0)
	height_for_wall := max(height-2, 0)
	width_for_hole := max(width-1, 0)
	height_for_hole := max(height-1, 0)

	if width_for_wall == 0 || height_for_wall == 0 ||
		width_for_hole == 0 || height_for_hole == 0 {
		return
	}

	if width > height {
		wall_range := max(width_for_wall/2, 1)
		wall_offset := 0
		if wall_range > 0 {
			wall_offset = NextInt(wall_range) * 2
		}
		wallX := x1 + 2 + wall_offset

		hole_range := max(height_for_hole/2, 1)
		hole_offset := 0
		if hole_range > 0 {
			hole_offset = NextInt(hole_range) * 2
		}
		holeY := y1 + 1 + hole_offset

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
		wall_range := max(height_for_wall/2, 1)
		wall_offset := 0
		if wall_range > 0 {
			wall_offset = NextInt(wall_range) * 2
		}
		wallY := y1 + 2 + wall_offset

		hole_range := max(width_for_hole/2, 1)
		hole_offset := 0
		if hole_range > 0 {
			hole_offset = NextInt(hole_range) * 2
		}
		holeX := x1 + 1 + hole_offset

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

func (m *Maze) generate() {
	if m.width < 5 || m.height < 5 {
		for x := 0; x < m.width; x++ {
			m.set(x, m.height/2, Path)
		}
		return
	}

	m.divide(0, 0, m.width-1, m.height-1)
	m.add_random_paths()
}

func (m *Maze) toBoolGrid() [][]bool {
	result := make([][]bool, m.height)
	for y := 0; y < m.height; y++ {
		row := make([]bool, m.width)
		for x := 0; x < m.width; x++ {
			row[x] = (m.get(x, y) == Path)
		}
		result[y] = row
	}
	return result
}

func generateWalkableMaze(width, height int) [][]bool {
	m := NewMaze(width, height)
	m.generate()

	startX, startY := 1, 1
	goalX, goalY := width-2, height-2

	if !m.is_connected(startX, startY, goalX, goalY) {

		for x := 0; x < width; x++ {
			for y := 0; y < height; y++ {
				if x == 1 || y == 1 || x == width-2 || y == height-2 {
					m.set(x, y, Path)
				}
			}
		}
	}

	return m.toBoolGrid()
}

type MazeGenerator struct {
	BaseBenchmark
	width    int
	height   int
	boolGrid [][]bool
}

func (m *MazeGenerator) Prepare() {
	m.width = int(m.ConfigVal("w"))
	m.height = int(m.ConfigVal("h"))
}

func (m *MazeGenerator) grid_checksum(grid [][]bool) uint32 {
	hasher := uint32(2166136261)
	prime := uint32(16777619)

	for i := 0; i < len(grid); i++ {
		row := grid[i]
		for j := 0; j < len(row); j++ {
			if row[j] {
				j_squared := uint32(j * j)
				hasher = (hasher ^ j_squared) * prime
			}
		}
	}
	return hasher
}

func (m *MazeGenerator) Run(iteration_id int) {
	m.boolGrid = generateWalkableMaze(m.width, m.height)
}

func (m *MazeGenerator) Checksum() uint32 {
	return m.grid_checksum(m.boolGrid)
}

type AStarPathfinder struct {
	BaseBenchmark
	startX, startY int
	goalX, goalY   int
	width, height  int
	mazeGrid       [][]bool
	result         uint32

	gScoresCache  []int
	cameFromCache []int

	directions [4][2]int
}

func (a *AStarPathfinder) distance(aX, aY, bX, bY int) int {

	dx := aX - bX
	dy := aY - bY
	if dx < 0 {
		dx = -dx
	}
	if dy < 0 {
		dy = -dy
	}
	return dx + dy
}

type AStarNode struct {
	X, Y   int
	fScore int
	index  int
}

type PriorityQueue struct {
	nodes []*AStarNode
}

func NewPriorityQueue(capacity int) *PriorityQueue {
	return &PriorityQueue{
		nodes: make([]*AStarNode, 0, capacity),
	}
}

func (pq *PriorityQueue) Len() int { return len(pq.nodes) }
func (pq *PriorityQueue) Less(i, j int) bool {

	if pq.nodes[i].fScore != pq.nodes[j].fScore {
		return pq.nodes[i].fScore < pq.nodes[j].fScore
	}
	if pq.nodes[i].Y != pq.nodes[j].Y {
		return pq.nodes[i].Y < pq.nodes[j].Y
	}
	return pq.nodes[i].X < pq.nodes[j].X
}
func (pq *PriorityQueue) Swap(i, j int) {
	pq.nodes[i], pq.nodes[j] = pq.nodes[j], pq.nodes[i]
	pq.nodes[i].index = i
	pq.nodes[j].index = j
}
func (pq *PriorityQueue) Push(x interface{}) {
	node := x.(*AStarNode)
	node.index = len(pq.nodes)
	pq.nodes = append(pq.nodes, node)
}
func (pq *PriorityQueue) Pop() interface{} {
	n := len(pq.nodes)
	node := pq.nodes[n-1]
	node.index = -1
	pq.nodes = pq.nodes[:n-1]
	return node
}

func (a *AStarPathfinder) packCoords(x, y int) int {
	return y*a.width + x
}

func (a *AStarPathfinder) unpackCoords(packed int) (int, int) {
	return packed % a.width, packed / a.width
}

func (a *AStarPathfinder) Prepare() {
	a.width = int(a.ConfigVal("w"))
	a.height = int(a.ConfigVal("h"))
	a.startX = 1
	a.startY = 1
	a.goalX = a.width - 2
	a.goalY = a.height - 2
	a.mazeGrid = generateWalkableMaze(a.width, a.height)

	size := a.width * a.height
	a.gScoresCache = make([]int, size)
	a.cameFromCache = make([]int, size)

	a.directions = [4][2]int{{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
}

func (a *AStarPathfinder) findPath() ([][2]int, int) {
	grid := a.mazeGrid
	width := a.width
	height := a.height

	gScores := a.gScoresCache
	cameFrom := a.cameFromCache

	const maxInt32 = math.MaxInt32
	for i := range gScores {
		gScores[i] = maxInt32
	}

	const minusOne = -1
	for i := range cameFrom {
		cameFrom[i] = minusOne
	}

	pq := NewPriorityQueue(width * height)
	heap.Init(pq)

	startIdx := a.packCoords(a.startX, a.startY)
	gScores[startIdx] = 0
	heap.Push(pq, &AStarNode{
		X:      a.startX,
		Y:      a.startY,
		fScore: a.distance(a.startX, a.startY, a.goalX, a.goalY),
	})

	directions := a.directions
	nodesExplored := 0

	maxPathLen := width + height
	path := make([][2]int, 0, maxPathLen)

	for pq.Len() > 0 {
		current := heap.Pop(pq).(*AStarNode)
		nodesExplored++

		if current.X == a.goalX && current.Y == a.goalY {

			path = path[:0]
			x, y := current.X, current.Y

			for x != a.startX || y != a.startY {
				path = append(path, [2]int{x, y})
				idx := a.packCoords(x, y)
				packed := cameFrom[idx]
				if packed == -1 {
					break
				}
				x, y = a.unpackCoords(packed)
			}

			path = append(path, [2]int{a.startX, a.startY})

			for i, j := 0, len(path)-1; i < j; i, j = i+1, j-1 {
				path[i], path[j] = path[j], path[i]
			}

			return path, nodesExplored
		}

		currentIdx := a.packCoords(current.X, current.Y)
		currentG := gScores[currentIdx]

		for _, dir := range directions {
			nx, ny := current.X+dir[0], current.Y+dir[1]

			if nx < 0 || nx >= width || ny < 0 || ny >= height {
				continue
			}
			if !grid[ny][nx] {
				continue
			}

			tentativeG := currentG + 1000
			neighborIdx := a.packCoords(nx, ny)

			if tentativeG < gScores[neighborIdx] {

				cameFrom[neighborIdx] = currentIdx
				gScores[neighborIdx] = tentativeG

				fScore := tentativeG + a.distance(nx, ny, a.goalX, a.goalY)
				heap.Push(pq, &AStarNode{
					X:      nx,
					Y:      ny,
					fScore: fScore,
				})
			}
		}
	}

	return nil, nodesExplored
}

func (a *AStarPathfinder) Run(iteration_id int) {
	path, nodesExplored := a.findPath()

	var localResult uint32 = 0

	if path != nil {
		localResult = uint32(len(path))
	}

	localResult = (localResult << 5) + uint32(nodesExplored)

	a.result += localResult
}

func (a *AStarPathfinder) Checksum() uint32 {
	return a.result
}

type CompressionBWTResult struct {
	transformed []byte
	originalIdx int
}

func compressionBWTTransform(input []byte) CompressionBWTResult {
	n := len(input)
	if n == 0 {
		return CompressionBWTResult{[]byte{}, 0}
	}

	doubled := make([]byte, n*2)
	copy(doubled, input)
	copy(doubled[n:], input)

	sa := make([]int, n)
	for i := 0; i < n; i++ {
		sa[i] = i
	}

	buckets := make([][]int, 256)
	for _, idx := range sa {
		firstChar := input[idx]
		buckets[firstChar] = append(buckets[firstChar], idx)
	}

	pos := 0
	for b := 0; b < 256; b++ {
		for _, idx := range buckets[b] {
			sa[pos] = idx
			pos++
		}
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

			pairs := make([]struct{ a, b int }, n)
			for i := 0; i < n; i++ {
				pairs[i] = struct{ a, b int }{
					a: rank[i],
					b: rank[(i+k)%n],
				}
			}

			sort.Slice(sa, func(i, j int) bool {
				pi := pairs[sa[i]]
				pj := pairs[sa[j]]
				if pi.a != pj.a {
					return pi.a < pj.a
				}
				return pi.b < pj.b
			})

			newRank := make([]int, n)
			newRank[sa[0]] = 0
			for i := 1; i < n; i++ {
				prevPair := pairs[sa[i-1]]
				currPair := pairs[sa[i]]
				newRank[sa[i]] = newRank[sa[i-1]]
				if prevPair != currPair {
					newRank[sa[i]]++
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

	return CompressionBWTResult{transformed, originalIdx}
}

func compressionBWTInverse(bwtResult CompressionBWTResult) []byte {
	bwt := bwtResult.transformed
	n := len(bwt)

	if n == 0 {
		return []byte{}
	}

	counts := make([]int, 256)
	for _, b := range bwt {
		counts[b]++
	}

	positions := make([]int, 256)
	total := 0
	for i := 0; i < 256; i++ {
		positions[i] = total
		total += counts[i]
	}

	next := make([]int, n)
	tempCounts := make([]int, 256)

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

type CompressionHuffmanNode struct {
	frequency int
	byteVal   byte
	isLeaf    bool
	left      *CompressionHuffmanNode
	right     *CompressionHuffmanNode
	index     int
}

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

type CompressionHuffmanCodes struct {
	codeLengths [256]int
	codes       [256]int
}

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

type CompressionEncodedResult struct {
	data     []byte
	bitCount int
}

func huffmanEncodeCompression(data []byte, huffmanCodes *CompressionHuffmanCodes) CompressionEncodedResult {
	result := make([]byte, len(data)*2)
	currentByte := byte(0)
	bitPos := 0
	byteIndex := 0
	totalBits := 0

	for _, b := range data {
		idx := int(b)
		code := huffmanCodes.codes[idx]
		length := huffmanCodes.codeLengths[idx]

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

	if bitPos > 0 {
		result[byteIndex] = currentByte
		byteIndex++
	}

	return CompressionEncodedResult{result[:byteIndex], totalBits}
}

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

type CompressionCompressedData struct {
	bwtResult        CompressionBWTResult
	frequencies      []int
	encodedBits      []byte
	originalBitCount int
}

func compressData(data []byte) CompressionCompressedData {
	bwtResult := compressionBWTTransform(data)

	frequencies := make([]int, 256)
	for _, b := range bwtResult.transformed {
		frequencies[b]++
	}

	huffmanTree := buildCompressionHuffmanTree(frequencies)

	var huffmanCodes CompressionHuffmanCodes
	buildCompressionHuffmanCodes(huffmanTree, 0, 0, &huffmanCodes)

	encoded := huffmanEncodeCompression(bwtResult.transformed, &huffmanCodes)

	return CompressionCompressedData{
		bwtResult:        bwtResult,
		frequencies:      frequencies,
		encodedBits:      encoded.data,
		originalBitCount: encoded.bitCount,
	}
}

func decompressData(compressed CompressionCompressedData) []byte {
	huffmanTree := buildCompressionHuffmanTree(compressed.frequencies)

	decoded := huffmanDecodeCompression(
		compressed.encodedBits,
		huffmanTree,
		compressed.originalBitCount,
	)

	bwtResult := CompressionBWTResult{
		transformed: decoded,
		originalIdx: compressed.bwtResult.originalIdx,
	}

	return compressionBWTInverse(bwtResult)
}

type BWTHuffEncode struct {
	BaseBenchmark
	size     int64
	result   uint32
	testData []byte
}

func (c *BWTHuffEncode) generateTestData(size int64) []byte {
	pattern := []byte("ABRACADABRA")
	data := make([]byte, size)

	for i := int64(0); i < size; i++ {
		data[i] = pattern[i%int64(len(pattern))]
	}

	return data
}

func (c *BWTHuffEncode) Prepare() {
	c.size = c.ConfigVal("size")
	c.testData = c.generateTestData(c.size)
}

func (c *BWTHuffEncode) Run(iteration_id int) {
	compressed := compressData(c.testData)
	c.result += uint32(len(compressed.encodedBits))
}

func (c *BWTHuffEncode) Checksum() uint32 {
	return c.result
}

type BWTHuffDecode struct {
	BaseBenchmark
	size         int64
	result       uint32
	testData     []byte
	compressed   CompressionCompressedData
	decompressed []byte
}

func (d *BWTHuffDecode) Prepare() {
	d.size = d.ConfigVal("size")

	pattern := []byte("ABRACADABRA")
	d.testData = make([]byte, d.size)
	for i := int64(0); i < d.size; i++ {
		d.testData[i] = pattern[i%int64(len(pattern))]
	}

	d.compressed = compressData(d.testData)
}

func (d *BWTHuffDecode) Run(iteration_id int) {
	d.decompressed = decompressData(d.compressed)
	d.result += uint32(len(d.decompressed))
}

func (d *BWTHuffDecode) Checksum() uint32 {
	v := d.result
	if bytes.Equal(d.decompressed, d.testData) {
		v += 1000000
	}
	return v
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