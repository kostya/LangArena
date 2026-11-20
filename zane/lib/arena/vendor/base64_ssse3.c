/* aklomp/base64's ssse3 codec, compiled for ssse3 as its Makefile's
   -mssse3 would. Only codec_choose.c calls it, on a processor that has
   ssse3. The intrinsic headers come first, so the target applies to the
   codec's own functions only. */
#if defined(__x86_64__)
#include <immintrin.h>
#pragma clang attribute push(__attribute__((target("ssse3"))), apply_to = function)
#endif
#include "base64/lib/arch/ssse3/codec.c"
#if defined(__x86_64__)
#pragma clang attribute pop
#endif
