/* aklomp/base64's sse41 codec, compiled for sse4.1 as its Makefile's
   -msse4.1 would. Only codec_choose.c calls it, on a processor that has
   sse4.1. The intrinsic headers come first, so the target applies to the
   codec's own functions only. */
#if defined(__x86_64__)
#include <immintrin.h>
#pragma clang attribute push(__attribute__((target("sse4.1"))), apply_to = function)
#endif
#include "base64/lib/arch/sse41/codec.c"
#if defined(__x86_64__)
#pragma clang attribute pop
#endif
