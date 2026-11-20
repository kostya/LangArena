/* aklomp/base64's sse42 codec, compiled for sse4.2 as its Makefile's
   -msse4.2 would. Only codec_choose.c calls it, on a processor that has
   sse4.2. The intrinsic headers come first, so the target applies to the
   codec's own functions only. */
#if defined(__x86_64__)
#include <immintrin.h>
#pragma clang attribute push(__attribute__((target("sse4.2"))), apply_to = function)
#endif
#include "base64/lib/arch/sse42/codec.c"
#if defined(__x86_64__)
#pragma clang attribute pop
#endif
