# Sampling profiler

`perf` cannot open counters in the cloud container, so this samples the PC
on SIGPROF from an LD_PRELOAD library and names each sample's function with
`nm`. A POSIX timer on `CLOCK_MONOTONIC` sends the signal every `SAMPLER_US`
microseconds (default 50). That is elapsed time, not CPU time. A sample
records the PC only when the signal is handled, which needs the process on
the CPU, and timer signals that pile up while it is off the CPU merge into
one. Off-CPU time is not measured, and descheduling skews the sample counts,
so run the program pinned and alone.

    gcc -O2 -shared -fPIC sampler.c -o sampler.so
    SAMPLER_OUT=out.txt LD_PRELOAD=$PWD/sampler.so BIN run.js TEST
    python3 symbolize.py out.txt 20

libc's internal functions have no symbols, so its memcpy, memset and
malloc show under the nearest exported name (`__nss_database_lookup`).
