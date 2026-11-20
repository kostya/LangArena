/* The codecs aklomp/base64 compiles, which its Makefile writes to this file
   from its *_CFLAGS variables. These are the codecs LangArena's C entry
   builds (c/Makefile): on x86-64 every one but AVX-512, each compiled for
   its own instruction set by its vendor/base64_*.c wrapper; on AArch64
   NEON64, which the architecture always has. codec_choose.c picks one at
   run time from what the processor supports. */
#if defined(__x86_64__)
#define HAVE_AVX512 0
#define HAVE_AVX2   1
#define HAVE_NEON32 0
#define HAVE_NEON64 0
#define HAVE_SSSE3  1
#define HAVE_SSE41  1
#define HAVE_SSE42  1
#define HAVE_AVX    1
#elif defined(__aarch64__)
#define HAVE_AVX512 0
#define HAVE_AVX2   0
#define HAVE_NEON32 0
#define HAVE_NEON64 1
#define HAVE_SSSE3  0
#define HAVE_SSE41  0
#define HAVE_SSE42  0
#define HAVE_AVX    0
#else
#define HAVE_AVX512 0
#define HAVE_AVX2   0
#define HAVE_NEON32 0
#define HAVE_NEON64 0
#define HAVE_SSSE3  0
#define HAVE_SSE41  0
#define HAVE_SSE42  0
#define HAVE_AVX    0
#endif
