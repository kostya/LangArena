package main

import (
	"bytes"
	"fmt"
)

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
		ci := 2.0*float64(y)/float64(h) - 1.0
		for x := 0; x < w; x++ {
			zr, zi, tr, ti := 0.0, 0.0, 0.0, 0.0
			cr := 2.0*float64(x)/float64(w) - 1.5

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
