import std/[os, times]
import config, benchmark

import benchmarks/pidigits
import benchmarks/binarytrees
import benchmarks/brainfuckarray
import benchmarks/brainfuckrecursion
import benchmarks/fannkuchredux
import benchmarks/fasta
import benchmarks/knuckeotide
import benchmarks/mandelbrot
import benchmarks/matmul1t
import benchmarks/matmul_threads
import benchmarks/nbody
import benchmarks/regexdna
import benchmarks/revcomp
import benchmarks/spectralnorm
import benchmarks/base64encode
import benchmarks/base64decode
import benchmarks/jsongenerate
import benchmarks/jsonparsedom
import benchmarks/jsonparsemapping
import benchmarks/primes
import benchmarks/noise
import benchmarks/textraytracer
import benchmarks/neuralnet
import benchmarks/sortquick
import benchmarks/sortmerge
import benchmarks/sortself
import benchmarks/graphpath
import benchmarks/bufferhashsha256
import benchmarks/bufferhashcrc32
import benchmarks/cachesimulation
import benchmarks/calculatorast
import benchmarks/calculatorinterpreter
import benchmarks/gameoflife
import benchmarks/mazegenerator
import benchmarks/astarpathfinder
import benchmarks/bwthuffencode
import benchmarks/bwthuffdecode

proc main() =
  let now = (epochTime() * 1000).int64
  echo "start: ", now

  if paramCount() > 0:
    loadConfig(paramStr(1))
  else:
    loadConfig()

  if paramCount() > 1:
    all(paramStr(2))
  else:
    all()

  let markerFile = open("/tmp/recompile_marker", fmWrite)
  markerFile.write("RECOMPILE_MARKER_0")
  markerFile.close()

when isMainModule:
  main()
