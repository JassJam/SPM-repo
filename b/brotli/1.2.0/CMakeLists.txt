include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
    URL https://github.com/google/brotli.git
    TAG v1.2.0)

set(_shared "OFF")
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_shared "ON")
endif()

spm_cmake_configure(
    OPTIONS
    "-DBUILD_SHARED_LIBS=${_shared}"
    -DBROTLI_DISABLE_TESTS=ON
    -DBROTLI_BUNDLED_MODE=OFF)

spm_cmake_build()

if(_shared)
    spm_create_target(NAME brotli)
else()
    if(MSVC)
        spm_create_target(
            NAME brotli
            STATIC_LIBS "brotlidec.lib" "brotlienc.lib" "brotlicommon.lib")
    else()
        spm_create_target(
            NAME brotli
            STATIC_LIBS "libbrotlidec.a" "libbrotlienc.a" "libbrotlicommon.a")
    endif()
endif()
