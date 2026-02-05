# Package

version       = "1.0.0"
author        = "Your Name"
description   = "Benchmarks suite in Nim"
license       = "MIT"

srcDir = "src"
bin = @["benchmarks"]

requires "nim >= 2.0.0"
requires "jsony"
requires "integers"
