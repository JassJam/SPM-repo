include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
    URL https://github.com/facebook/zstd.git
    TAG v1.5.7)

set(_shared "OFF")
set(_static "ON")
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_shared "ON")
    set(_static "OFF")
endif()

spm_cmake_configure(
    SOURCE_DIR source/build/cmake
    OPTIONS
    "-DZSTD_BUILD_SHARED=${_shared}"
    "-DZSTD_BUILD_STATIC=${_static}"
    -DZSTD_BUILD_PROGRAMS=OFF
    -DZSTD_BUILD_TESTS=OFF
    -DZSTD_LEGACY_SUPPORT=OFF)

spm_cmake_build()

spm_create_target(NAME zstd)
