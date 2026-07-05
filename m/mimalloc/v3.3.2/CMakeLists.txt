cmake_minimum_required(VERSION 3.21)
project(mimalloc_pkg)
include(${SPM_ROOT}/spm.cmake)

spm_fetch_source(GIT_URL https://github.com/microsoft/mimalloc.git GIT_TAG v3.3.2)

set(MI_SECURE            OFF CACHE BOOL "Use security mitigations (like meta data guard pages, allocation randomization, double-free mitigation, and free-list corruption detection)" FORCE)
set(MI_SECURE_FULL       OFF CACHE BOOL "Use full security mitigations including guard pages at the end of each mimalloc page (may be expensive)" FORCE)
set(MI_OVERRIDE          OFF CACHE BOOL "Override the standard malloc interface (i.e. define entry points for 'malloc', 'free', etc)" FORCE)
set(MI_XMALLOC           OFF CACHE BOOL "Enable abort() call on memory allocation failure by default" FORCE)
set(MI_SHOW_ERRORS       OFF CACHE BOOL "Show error and warning messages by default (only enabled by default in DEBUG mode)" FORCE)
set(MI_GUARDED           OFF CACHE BOOL "Build with guard pages behind certain object allocations (enabled by default in a debug build)" FORCE)
set(MI_USE_CXX           OFF CACHE BOOL "Use the C++ compiler to compile the library (instead of the C compiler)" FORCE)
set(MI_OPT_ARCH          OFF CACHE BOOL "Only for optimized builds: turn on architecture specific optimizations (for x64: '-march=haswell;-mavx2' (2013), for arm64: '-march=armv8.1-a' (2016))" FORCE)
set(MI_OPT_SIMD          OFF CACHE BOOL "Use SIMD instructions (requires MI_OPT_ARCH to be enabled)" FORCE)

set(MI_DEBUG             OFF CACHE BOOL "Enable assertion checks (enabled by default in a debug build)" FORCE)
set(MI_DEBUG_INTERNAL    OFF CACHE BOOL "Enable assertion and internal invariant checks (enabled by default in a debug build)" FORCE)
set(MI_DEBUG_FULL        OFF CACHE BOOL "Enable assertion checks and expensive internal heap invariant checking" FORCE)

set(MI_DEBUG_TSAN        OFF CACHE BOOL "Build with thread sanitizer (needs clang)" FORCE)
set(MI_DEBUG_UBSAN       OFF CACHE BOOL "Build with undefined-behavior sanitizer (needs clang++)" FORCE)
set(MI_TRACK_VALGRIND    OFF CACHE BOOL "Compile with Valgrind support (adds a small overhead)" FORCE)
set(MI_TRACK_ASAN        OFF CACHE BOOL "Compile with address sanitizer support (adds a small overhead)" FORCE)
set(MI_TRACK_ETW         OFF CACHE BOOL "Compile with Windows event tracing (ETW) support (adds a small overhead)" FORCE)

set(MI_BUILD_SHARED      ${BUILD_SHARED_LIBS} CACHE BOOL "Build shared library" FORCE)
set(MI_BUILD_STATIC      NOT ${BUILD_SHARED_LIBS} CACHE BOOL "Build static library" FORCE)
set(MI_BUILD_OBJECT      ON CACHE BOOL "Build object library" FORCE)
set(MI_BUILD_TESTS       OFF CACHE BOOL "Build test executables" FORCE)

set(MI_OSX_INTERPOSE     OFF CACHE BOOL "Use interpose to override standard malloc on macOS" FORCE)
set(MI_OSX_ZONE          OFF CACHE BOOL "Use malloc zone to override standard malloc on macOS" FORCE)
set(MI_WIN_REDIRECT      OFF CACHE BOOL "Use redirection module ('mimalloc-redirect') on Windows if compiling mimalloc as a DLL" FORCE)
set(MI_WIN_DIRECT_TLS    OFF CACHE BOOL "Use only direct TLS slots on Windows to avoid extra tests in the malloc fast path (only works if the program uses less than 64 TlsAlloc'd slots in total)" FORCE)
set(MI_LOCAL_DYNAMIC_TLS OFF CACHE BOOL "Use local-dynamic-tls, a slightly slower but dlopen-compatible thread local storage mechanism (Unix)" FORCE)
set(MI_LIBC_MUSL         OFF CACHE BOOL "Enable this when linking with musl libc" FORCE)

set(MI_PADDING           OFF CACHE BOOL "Enable padding to detect heap block overflow (always on in DEBUG or SECURE mode, or with Valgrind/ASAN)" FORCE)
set(MI_SKIP_COLLECT_ON_EXIT OFF CACHE BOOL "Skip collecting memory on program exit" FORCE)
set(MI_NO_PADDING        OFF CACHE BOOL "Force no use of padding even in DEBUG mode etc." FORCE)
set(MI_INSTALL_TOPLEVEL  OFF CACHE BOOL "Install directly into $CMAKE_INSTALL_PREFIX instead of PREFIX/lib/mimalloc-version" FORCE)
set(MI_NO_THP            OFF CACHE BOOL "Disable transparent huge pages support on Linux/Android for the mimalloc process only" FORCE)
set(MI_EXTRA_CPPDEFS     "" CACHE STRING "Extra pre-processor definitions (use as `-DMI_EXTRA_CPPDEFS=\"opt1=val1;opt2=val2\"`)" FORCE)
set(MI_SEE_ASM           OFF CACHE BOOL "Generate assembly files" FORCE)

# negated options for vcpkg features
set(MI_NO_USE_CXX        OFF CACHE BOOL "Use plain C compilation (has priority over MI_USE_CXX)" FORCE)
set(MI_NO_OPT_ARCH       OFF CACHE BOOL "Do not use architecture specific optimizations (like '-march=armv8.1-a' for example) (has priority over MI_OPT_ARCH)" FORCE)

# experimental
set(MI_WIN_INIT_USE_RAW_DLLMAIN OFF CACHE BOOL "Use the raw DLL main entry point for mimalloc initialization; can be more robust but can also lead to link errors with other libraries" FORCE)
set(MI_WIN_INIT_USE_TLS_DLLMAIN OFF CACHE BOOL "Use legacy TLS entries with DllMain for mimalloc initialization" FORCE)

# deprecated options
set(MI_WIN_USE_FLS       OFF CACHE BOOL "Use Fiber local storage on Windows to detect thread termination (deprecated)" FORCE)
set(MI_CHECK_FULL        OFF CACHE BOOL "Use full internal invariant checking in DEBUG mode (deprecated, use MI_DEBUG_FULL instead)" FORCE)
set(MI_USE_LIBATOMIC     OFF CACHE BOOL "Explicitly link with -latomic (on older systems) (deprecated and detected automatically)" FORCE)

add_subdirectory(${SPM_PKG_SOURCE_DIR} src)
