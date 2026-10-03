include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
    URL https://github.com/nghttp2/nghttp2.git
    TAG v1.70.0)

spm_apply_patch(
    PATCHES
    patches/nghttp2_shared.patch
)

set(_shared "OFF")
set(_static "ON")
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_shared "ON")
    set(_static "OFF")
endif()

spm_cmake_configure(
    OPTIONS
    "-DBUILD_SHARED_LIBS=${_shared}"
    "-DBUILD_STATIC_LIBS=${_static}"
    -DBUILD_TESTING=OFF
    -DENABLE_LIB_ONLY=ON
    -DENABLE_HTTP3=OFF
    -DENABLE_EXAMPLES=OFF
    -DENABLE_APP=OFF
    -DENABLE_DOC=OFF)

spm_cmake_build()

spm_create_target(NAME nghttp2 OUT_TARGET_NAME _nghttp2_target)

if(_static STREQUAL "ON")
    target_compile_definitions(${_nghttp2_target} INTERFACE NGHTTP2_STATICLIB)
endif()