/* aklomp/base64's avx2 codec, compiled for avx2 as its Makefile's
   -mavx2 would. Only codec_choose.c calls it, on a processor that has
   avx2. The intrinsic headers come first, so the target applies to the
   codec's own functions only. */
#if defined(__x86_64__)
#include <immintrin.h>
#pragma clang attribute push(__attribute__((target("avx2"))), apply_to = function)
#endif
#include "base64/lib/arch/avx2/codec.c"
#if defined(__x86_64__)
#pragma clang attribute pop
#endif
