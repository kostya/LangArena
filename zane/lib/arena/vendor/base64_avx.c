/* aklomp/base64's avx codec, compiled for avx as its Makefile's
   -mavx would. Only codec_choose.c calls it, on a processor that has
   avx. The intrinsic headers come first, so the target applies to the
   codec's own functions only. */
#if defined(__x86_64__)
#include <immintrin.h>
#pragma clang attribute push(__attribute__((target("avx"))), apply_to = function)
#endif
#include "base64/lib/arch/avx/codec.c"
#if defined(__x86_64__)
#pragma clang attribute pop
#endif
