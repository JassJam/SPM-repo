include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
    URL https://github.com/c-ares/c-ares.git
    TAG v1.34.8)

set(_shared "OFF")
set(_static "ON")
if(NOT SPM_BUILD_SHARED_LIBS STREQUAL "" AND SPM_BUILD_SHARED_LIBS)
    set(_shared "ON")
    set(_static "OFF")
endif()

spm_cmake_configure(
    OPTIONS
    "-DBUILD_SHARED_LIBS=${_shared}"
    "-DCARES_STATIC=${_static}"
    "-DCARES_SHARED=${_shared}"
    -DCARES_BUILD_TESTS=OFF
    -DCARES_BUILD_TOOLS=OFF)

spm_cmake_build()

spm_create_target(NAME cares OUT_TARGET_NAME _cares_target)

if(WIN32)
    target_link_libraries(${_cares_target} INTERFACE ws2_32 iphlpapi)
endif()
if(_static STREQUAL "ON")
    target_compile_definitions(${_cares_target} INTERFACE CARES_STATICLIB)
endif()
