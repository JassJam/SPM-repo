# SPM - Simple Package Manager

SPM is a small CMake package manager. It builds dependencies as isolated,
out-of-tree CMake projects, installs the result into a local binary cache,
and exposes them as normal CMake targets. Each dependency is only built
once per cmake configuration; after that it's just imported from the cache.

It is not a registry of prebuilt binaries you download. It's a system for
building and caching binaries yourself, from recipes that live in this
repository.

## Requirements

- CMake 3.21+
- git (used for source fetching and for the `git+` registry mode)
- a normal C/C++ toolchain

## Using a package

```cmake
include(spm.cmake)

spm_require_package(
    NAME    spdlog
    VERSION 1.14.1
)

target_link_libraries(app PRIVATE spdlog::spdlog)
```

All you need is `spm.cmake`. `spm_require_package()` resolves the recipe,
builds it if it isn't already cached, and makes the resulting target(s)
available.

### Common options

```cmake
spm_require_package(
    NAME        spdlog
    VERSION     1.14.1

    SHARED                      # build shared instead of static (default)
    RUN_TESTS                   # run the recipe's own test suite before caching
    FORCE                       # ignore any existing cache entry, rebuild

    CONFIGS
        "SPDLOG_NO_EXCEPTIONS=ON"

    GIT_TAG     v1.14.1         # override the recipe's default source pin
    IMPORT_NAME spdlog          # only needed if it differs from NAME
)
```

### Where packages come from

By default SPM looks in `repositories/` in this repo. If a version isn't
there, it resolves from `SPM_REGISTRY`, which can be:

- a local or mounted directory.
- `git+https://...` or `git+ssh://...` (sparse partial clone of just that
  one version folder, not the whole repo)
- a plain `https://` URL serving `<letter>/<name>/<version>.tar.gz`

```cmake
set(SPM_REGISTRY "git+https://github.com/you/spm-registry.git" CACHE STRING "" FORCE)
```

Can be overridden per package with `REGISTRY` / `REGISTRY_REF` / `HEADERS` in `spm_require_package`.

## Writing a recipe

A recipe is a normal, self-contained CMake project. Nothing in it is
special except that it includes `spm.cmake` and calls `spm_fetch_source()`
to get its upstream source.

`repositories/s/spdlog/1.14.1/CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.21)
project(spdlog_pkg)
include(${SPM_ROOT}/spm.cmake)

# optional require
# spm_require_package(NAME fmt VERSION 11.0.2)

spm_fetch_source(
    GIT_URL https://github.com/gabime/spdlog.git
    GIT_TAG v1.14.1
)

set(SPDLOG_INSTALL      ON                   CACHE BOOL "" FORCE)
set(SPDLOG_BUILD_SHARED ${BUILD_SHARED_LIBS} CACHE BOOL "" FORCE)

add_subdirectory(${SPM_PKG_SOURCE_DIR} src)
```

`spm_fetch_source()` also accepts `URL` + `HASH` for a plain download
instead of a git clone, and an optional `PATCHES` list to be applied.

### Recipes layout

```
spm.cmake                          the whole system, one file
repositories/<l>/<name>/<version>/ recipes (source of truth)
cache/<l>/<name>/<hash>/           built, installed binaries (generated, not committed)
```

`<l>` is the lowercase first letter of the package name, e.g. `s/spdlog/1.14.1/`.

### When the generic import doesn't work

After building, SPM tries `find_package(<name> CONFIG)` against the cache
dir, then falls back to a generic "one library file" search. This fails
for packages whose real CMake package name differs from their recipe name,
or that expose many component targets with no single unified one (Abseil,
Boost, ...).

To resolve this:

- `Import.cmake` next to the recipe's `CMakeLists.txt` — arbitrary CMake
  code, run in the consumer's own process, with `SPM_IMPORT_NAME` /
  `SPM_IMPORT_VERSION` / `SPM_IMPORT_CACHE_DIR` / `SPM_IMPORT_SHARED`
  available. Use this for anything non-trivial.
- `IMPORT_NAME` argument for `spm_require_package` — for a plain rename, e.g. the `abseil` recipe
  installing as CMake package `absl`.

### Declaring a recipe unsupported on some platform

Optional `Support.cmake` next to the recipe, run in the consumer's own
process (so `WIN32` / `ANDROID` / `EMSCRIPTEN` / etc. reflect the real
target):

```cmake
if(WIN32)
    set(SPM_UNSUPPORTED_REASON "upstream build is POSIX-only")
endif()
```

If set, `spm_require_package()` fails with that message instead of
attempting the build.
