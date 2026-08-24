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

Alternatively, you may use a yaml file to load dependencies.

```cmake
include(spm-yaml.cmake)

spm_require_packages_from_yaml(
    FILE <path>
)

target_link_libraries(app PRIVATE spdlog::spdlog)
```

### Common options

```yaml
packages:
  - name: boost
    version: 1.92.0
    import_name: boost
    registry: ./registry
    git_url: https://github.com/boostorg/boost.git
    git_tag: boost-1.92.0
    options:
      - BOOST_ENABLE_MPI=OFF
      - BOOST_ENABLE_PYTHON=OFF
    force: true
    shared: false
```

Or in cmake file

```cmake
spm_require_package(
    NAME boost
    VERSION 1.92.0
    IMPORT_NAME boost
    REGISTRY ./registry
    GIT_URL https://github.com/boostorg/boost.git
    GIT_TAG boost-1.92.0
    OPTIONS BOOST_ENABLE_MPI=OFF BOOST_ENABLE_PYTHON=OFF
    FORCE
    SHARED
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

Can be overridden per package with `REGISTRY` / `REGISTRY_REF` / `HEADERS` in `spm_require_package*`.

## Writing a recipe

A recipe is a normal, self-contained CMake project. Nothing in it is
special except that it includes `spm-recipe.cmake` and calls `spm_fetch_source()`
to get its upstream source.

`repositories/s/spdlog/1.14.1/CMakeLists.txt`:

```cmake
include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

# Download the recipe
# spm_git_clone(...)

# Configure and build the recipe
# spm_cmake_configure(...)
# spm_cmake_build(...)

# Create a target out of it 
# spm_create_target_from_pkgconfig(...)
# spm_create_target(...)

```

`spm_fetch_source()` also accepts `URL` + `HASH` for a plain download
instead of a git clone, and an optional `PATCHES` list to be applied.

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
