CXX = g++

CXXFLAGS_DEBUG = -Wall -Wextra -g -O0 -DDEBUG
DEPS_CXXFLAGS_DEBUG = -g -O0 -DDEBUG

CXXFLAGS_PROD = -Wall -Wextra -Wpedantic -Werror=return-type -Werror=address \
                -O2 -DNDEBUG -fstack-protector-strong -fno-omit-frame-pointer 
DEPS_CXXFLAGS_PROD = -O2 -DNDEBUG
LDFLAGS_PROD_LINUX = -Wl,-z,relro,-z,now -Wl,--gc-sections
LDFLAGS_PROD_MACOS =

CXXFLAGS_FAST = -Wall -Wextra \
                -O3 -march=native -mtune=native -DNDEBUG -pipe \
                -fstack-protector -ftree-vectorize -funroll-loops 
DEPS_CXXFLAGS_FAST = -O3 -march=native -DNDEBUG
LDFLAGS_FAST = -flto=thin
LDFLAGS_FAST_LINUX = -Wl,-O1 -Wl,--gc-sections
LDFLAGS_FAST_MACOS = -Wl,-dead_strip

CXXFLAGS_UNSAFE = -Wall \
                  -O3 -march=native -DNDEBUG -pipe \
                  -fno-stack-protector -fomit-frame-pointer -ffast-math \
                  -fvisibility=hidden \
                  -fno-common -fstrict-overflow -fno-trapping-math
DEPS_CXXFLAGS_UNSAFE = -O3 -ffast-math -march=native -DNDEBUG -Wno-nan-infinity-disabled
LDFLAGS_UNSAFE = -flto=full
LDFLAGS_UNSAFE_LINUX = -Wl,-O3 -Wl,--strip-all
LDFLAGS_UNSAFE_MACOS = -Wl,-dead_strip -Wl,-S

PGO_PROFILE = $(shell pwd)/target/pgo/merged.profdata

CXXFLAGS_PGO_CLANG_GEN = -Wall -Wextra -O2 -DNDEBUG -fprofile-instr-generate -Wno-newline-eof
DEPS_CXXFLAGS_PGO_CLANG_GEN = -O2 -DNDEBUG -fprofile-instr-generate
LDFLAGS_PGO_CLANG_GEN = -fprofile-instr-generate

CXXFLAGS_PGO_CLANG = -Wall -Wextra -O2 -DNDEBUG -fprofile-instr-use=$(PGO_PROFILE) -Wno-newline-eof
DEPS_CXXFLAGS_PGO_CLANG = -O2 -DNDEBUG -fprofile-instr-use=$(PGO_PROFILE)
LDFLAGS_PGO_CLANG = -fprofile-instr-use=$(PGO_PROFILE)

PGO_GCC_DIR = $(shell pwd)/target/pgo-gcc-gen

CXXFLAGS_PGO_GCC_GEN = -Wall -Wextra -O2 -DNDEBUG -fprofile-generate -Wno-newline-eof
DEPS_CXXFLAGS_PGO_GCC_GEN = -O2 -DNDEBUG -fprofile-generate
LDFLAGS_PGO_GCC_GEN = -fprofile-generate

CXXFLAGS_PGO_GCC = -Wall -Wextra -O2 -DNDEBUG -fprofile-use -fprofile-correction -fprofile-dir=$(PGO_GCC_DIR) -Wno-newline-eof
DEPS_CXXFLAGS_PGO_GCC = -O2 -DNDEBUG -fprofile-use -fprofile-correction -fprofile-dir=$(PGO_GCC_DIR)
LDFLAGS_PGO_GCC = -fprofile-use -fprofile-correction -fprofile-dir=$(PGO_GCC_DIR)

CXXFLAGS_COMMON = -Isrc -Ideps -Ideps/base64/include -Ideps/simdjson -I/opt/homebrew/include -std=c++20 -Wno-nullability-extension -Wno-nullability-completeness
LDFLAGS_BASE = -lpthread -lre2 -L/opt/homebrew/lib

MODE ?= debug
ARCH = $(shell uname -m)
UNAME_S = $(shell uname -s)

ifeq ($(UNAME_S),Linux)
    LDFLAGS_OS_PROD = $(LDFLAGS_PROD_LINUX)
    LDFLAGS_OS_FAST = $(LDFLAGS_FAST_LINUX)
    LDFLAGS_OS_UNSAFE = $(LDFLAGS_UNSAFE_LINUX)
else ifeq ($(UNAME_S),Darwin)
    LDFLAGS_OS_PROD = $(LDFLAGS_PROD_MACOS)
    LDFLAGS_OS_FAST = $(LDFLAGS_FAST_MACOS)
    LDFLAGS_OS_UNSAFE = $(LDFLAGS_UNSAFE_MACOS)
else
    LDFLAGS_OS_PROD =
    LDFLAGS_OS_FAST =
    LDFLAGS_OS_UNSAFE =
endif

ifeq ($(MODE), prod)
    CXXFLAGS_MODE = $(CXXFLAGS_PROD)
    LDFLAGS_OS = $(LDFLAGS_OS_PROD)
    LDFLAGS_EXTRA =
    BUILD_DIR = target/prod
    DEPS_DIR = target/deps/prod
    DEPS_CXXFLAGS = $(DEPS_CXXFLAGS_PROD)
else ifeq ($(MODE), fast)
    CXXFLAGS_MODE = $(CXXFLAGS_FAST)
    LDFLAGS_OS = $(LDFLAGS_OS_FAST)
    LDFLAGS_EXTRA = $(LDFLAGS_FAST)
    BUILD_DIR = target/fast
    DEPS_DIR = target/deps/fast
    DEPS_CXXFLAGS = $(DEPS_CXXFLAGS_FAST)
else ifeq ($(MODE), unsafe)
    CXXFLAGS_MODE = $(CXXFLAGS_UNSAFE)
    LDFLAGS_OS = $(LDFLAGS_OS_UNSAFE)
    LDFLAGS_EXTRA = $(LDFLAGS_UNSAFE)
    BUILD_DIR = target/unsafe
    DEPS_DIR = target/deps/unsafe
    DEPS_CXXFLAGS = $(DEPS_CXXFLAGS_UNSAFE)
else ifeq ($(MODE), pgo-clang-gen)
    CXXFLAGS_MODE = $(CXXFLAGS_PGO_CLANG_GEN)
    LDFLAGS_OS =
    LDFLAGS_EXTRA = $(LDFLAGS_PGO_CLANG_GEN)
    BUILD_DIR = target/pgo-clang-gen
    DEPS_DIR = target/deps/pgo-clang-gen
    DEPS_CXXFLAGS = $(DEPS_CXXFLAGS_PGO_CLANG_GEN)
else ifeq ($(MODE), pgo-clang)
    CXXFLAGS_MODE = $(CXXFLAGS_PGO_CLANG)
    LDFLAGS_OS =
    LDFLAGS_EXTRA = $(LDFLAGS_PGO_CLANG)
    BUILD_DIR = target/pgo-clang
    DEPS_DIR = target/deps/pgo-clang
    DEPS_CXXFLAGS = $(DEPS_CXXFLAGS_PGO_CLANG)
else ifeq ($(MODE), pgo-gcc-gen)
    CXXFLAGS_MODE = $(CXXFLAGS_PGO_GCC_GEN)
    LDFLAGS_OS =
    LDFLAGS_EXTRA = $(LDFLAGS_PGO_GCC_GEN)
    BUILD_DIR = target/pgo-gcc-gen
    DEPS_DIR = target/deps/pgo-gcc-gen
    DEPS_CXXFLAGS = $(DEPS_CXXFLAGS_PGO_GCC_GEN)
else ifeq ($(MODE), pgo-gcc)
    CXXFLAGS_MODE = $(CXXFLAGS_PGO_GCC)
    LDFLAGS_OS =
    LDFLAGS_EXTRA = $(LDFLAGS_PGO_GCC)
    BUILD_DIR = target/pgo-gcc
    DEPS_DIR = target/deps/pgo-gcc
    DEPS_CXXFLAGS = $(DEPS_CXXFLAGS_PGO_GCC)
else
    CXXFLAGS_MODE = $(CXXFLAGS_DEBUG)
    LDFLAGS_OS =
    LDFLAGS_EXTRA =
    BUILD_DIR = target/debug
    DEPS_DIR = target/deps/debug
    DEPS_CXXFLAGS = $(DEPS_CXXFLAGS_DEBUG)
endif

CXXFLAGS = $(CXXFLAGS_COMMON) $(CXXFLAGS_MODE)
LDFLAGS = $(LDFLAGS_BASE) $(LDFLAGS_OS) $(LDFLAGS_EXTRA)

SRC_DIR = src
SRCS = $(wildcard $(SRC_DIR)/*.cpp)

MAIN_OBJ = $(BUILD_DIR)/main.o
OBJS = $(patsubst $(SRC_DIR)/%.cpp, $(BUILD_DIR)/$(SRC_DIR)/%.o, $(SRCS))

DEPS_OBJS = $(DEPS_DIR)/simdjson.o $(DEPS_DIR)/libbase64.o

TARGET = $(BUILD_DIR)/benchmark

all: $(TARGET)

deps/simdjson:
	@echo "Downloading simdjson..."
	mkdir -p deps/simdjson
	wget -q https://github.com/simdjson/simdjson/releases/download/v5.1.1/simdjson.h -O deps/simdjson/simdjson.h
	wget -q https://github.com/simdjson/simdjson/releases/download/v5.1.1/simdjson.cpp -O deps/simdjson/simdjson.cpp

deps/base64:
	@echo "Cloning base64..."
	git clone https://github.com/aklomp/base64.git $@

deps/lazycsv.hpp:
	@echo "Downloading lazycsv..."
	wget -q https://raw.githubusercontent.com/ashtum/lazycsv/refs/heads/master/include/lazycsv.hpp -O deps/lazycsv.hpp

deps: deps/simdjson deps/base64 deps/lazycsv.hpp

$(DEPS_DIR):
	mkdir -p $@

$(DEPS_DIR)/simdjson.o: deps/simdjson | $(DEPS_DIR)
	@echo "Building simdjson with $(DEPS_CXXFLAGS)..."
	cd deps/simdjson && $(CXX) $(DEPS_CXXFLAGS) -std=c++20 -c simdjson.cpp && cd -
	cp deps/simdjson/simdjson.o $@

$(DEPS_DIR)/libbase64.o: deps/base64 | $(DEPS_DIR)
	@echo "Building base64 with $(DEPS_CXXFLAGS)..."
	cd deps/base64 && \
	make clean && \
	if [ "$(ARCH)" = "x86_64" ]; then \
		AVX2_CFLAGS=-mavx2 SSSE3_CFLAGS=-mssse3 SSE41_CFLAGS=-msse4.1 SSE42_CFLAGS=-msse4.2 AVX_CFLAGS=-mavx \
		CFLAGS="$(DEPS_CXXFLAGS)" make -i lib/libbase64.o; \
	elif [ "$(ARCH)" = "arm64" ] || [ "$(ARCH)" = "aarch64" ]; then \
		CFLAGS="-arch arm64 $(DEPS_CXXFLAGS)" NEON64_CFLAGS=" " make -i lib/libbase64.o; \
	else \
		CFLAGS="$(DEPS_CXXFLAGS)" make -i lib/libbase64.o; \
	fi && \
	cd - && \
	cp deps/base64/lib/libbase64.o $@

$(BUILD_DIR) $(BUILD_DIR)/$(SRC_DIR):
	mkdir -p $@

$(BUILD_DIR)/main.o: main.cpp | $(BUILD_DIR) deps
	@echo "Compiling main.cpp..."
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/$(SRC_DIR)/%.o: $(SRC_DIR)/%.cpp | $(BUILD_DIR)/$(SRC_DIR) deps
	@echo "Compiling $<..."
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(TARGET): $(OBJS) $(MAIN_OBJ) $(DEPS_OBJS)
	@echo "Linking $(TARGET)..."
	$(CXX) $^ -o $@ $(LDFLAGS)

pgo-clang-gen:
	$(MAKE) MODE=pgo-clang-gen

pgo-clang:
	rm -rf target/pgo-clang
	@mkdir -p target/pgo
	@if [ -f "default.profraw" ]; then \
		llvm-profdata merge -o target/pgo/merged.profdata default.profraw; \
	fi
	$(MAKE) MODE=pgo-clang

pgo-gcc-gen:
	$(MAKE) MODE=pgo-gcc-gen

pgo-gcc:
	rm -rf target/pgo-gcc
	$(MAKE) MODE=pgo-gcc

clean:
	rm -rf target
	cd deps/base64 && make clean 2>/dev/null || true

clean-pgo:
	rm -rf target/pgo default.profraw *.gcda *.gcno

distclean: clean clean-pgo
	rm -rf deps

clean-debug:
	rm -rf target/debug target/deps/debug

clean-prod:
	rm -rf target/prod target/deps/prod

clean-fast:
	rm -rf target/fast target/deps/fast

clean-unsafe:
	rm -rf target/unsafe target/deps/unsafe

clean-pgo-clang-gen:
	rm -rf target/pgo-clang-gen target/deps/pgo-clang-gen

clean-pgo-clang:
	rm -rf target/pgo-clang target/deps/pgo-clang

clean-pgo-gcc-gen:
	rm -rf target/pgo-gcc-gen target/deps/pgo-gcc-gen

clean-pgo-gcc:
	rm -rf target/pgo-gcc target/deps/pgo-gcc

CLANG_FORMAT_STYLE = {InsertNewlineAtEOF: true, BasedOnStyle: LLVM, IndentWidth: 2}

format:
	@echo "Formatting source files..."
	@find src -name "*.cpp" -o -name "*.hpp" | xargs clang-format -i --style="$(CLANG_FORMAT_STYLE)"
	@clang-format -i --style="$(CLANG_FORMAT_STYLE)" main.cpp

debug:
	$(MAKE) MODE=debug

prod:
	$(MAKE) MODE=prod

fast:
	$(MAKE) MODE=fast

unsafe:
	$(MAKE) MODE=unsafe

info:
	@echo "Mode:        $(MODE)"
	@echo "OS:          $(UNAME_S)"
	@echo "Arch:        $(ARCH)"
	@echo "Compiler:    $(shell $(CXX) --version | head -1)"
	@echo "Build dir:   $(BUILD_DIR)"
	@echo "Deps dir:    $(DEPS_DIR)"
	@echo "Target:      $(TARGET)"
	@echo "CXXFLAGS:    $(CXXFLAGS)"
	@echo "Deps CXXFLAGS: $(DEPS_CXXFLAGS)"
	@echo "LDFLAGS:     $(LDFLAGS)"

help:
	@echo "Usage: make [MODE=<mode>] [target]"
	@echo ""
	@echo "Modes:"
	@echo "  debug         - debugging build (default)"
	@echo "  prod          - production build with hardening"
	@echo "  fast          - optimized for current CPU"
	@echo "  unsafe        - maximum speed, no safety"
	@echo "  pgo-clang-gen - Clang PGO instrumented build"
	@echo "  pgo-clang     - Clang PGO optimized build"
	@echo "  pgo-gcc-gen   - GCC PGO instrumented build"
	@echo "  pgo-gcc       - GCC PGO optimized build"
	@echo ""
	@echo "Targets:"
	@echo "  all           - build project"
	@echo "  clean         - remove built files"
	@echo "  distclean     - remove everything including deps"
	@echo "  format        - format source files"
	@echo "  info          - show build configuration"
	@echo "  pgo-clang-gen - build Clang instrumented binary"
	@echo "  pgo-clang     - build Clang optimized binary + merge profile"
	@echo "  pgo-gcc-gen   - build GCC instrumented binary"
	@echo "  pgo-gcc       - build GCC optimized binary"

.PHONY: all deps clean distclean format info help
.PHONY: debug prod fast unsafe
.PHONY: pgo-clang-gen pgo-clang pgo-gcc-gen pgo-gcc
.PHONY: clean-debug clean-prod clean-fast clean-unsafe
.PHONY: clean-pgo-clang-gen clean-pgo-clang clean-pgo-gcc-gen clean-pgo-gcc clean-pgo
