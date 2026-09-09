package main

import (
	"runtime"
	"sync"
)

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
	rowsPerThread := (n + numThreads - 1) / numThreads

	for w := 0; w < numThreads; w++ {
		wg.Add(1)
		go func(threadID int) {
			defer wg.Done()
			startRow := threadID * rowsPerThread
			endRow := startRow + rowsPerThread
			if endRow > n || threadID == numThreads-1 {
				endRow = n
			}

			for i := startRow; i < endRow; i++ {
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
		}(w)
	}

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
