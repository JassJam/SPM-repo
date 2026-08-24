include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

if(NOT DILIGENT_NO_VULKAN)
    set(DILIGENT_NO_VULKAN OFF)
endif()
if(NOT DILIGENT_NO_ARCHIVER)
    set(DILIGENT_NO_ARCHIVER OFF)
endif()
if(NOT DILIGENT_NO_OPENGL)
    set(DILIGENT_NO_OPENGL OFF)
endif()
if(NOT DILIGENT_NO_HLSL)
    set(DILIGENT_NO_HLSL OFF)
endif()

spm_git_clone(
    URL https://github.com/DiligentGraphics/DiligentEngine.git
    TAG v2.5.6
)

spm_apply_patch(
    PATCHES
        patches/glslang-cstdint.patch
        patches/no-clang-format.patch
        patches/export-defines.patch
)

set(_deps "")

spm_requires(NAME spirv-cross VERSION 1.4.357.0)
list(APPEND _deps spirv-cross::spirv-cross)

if(NOT DILIGENT_NO_VULKAN)
    spm_requires(NAME volk VERSION 1.4.357.0)
    spm_requires(NAME vulkan-headers VERSION 1.4.357.0)
    list(APPEND _deps volk::volk vulkan-headers::vulkan-headers)
endif()
if(NOT DILIGENT_NO_VULKAN OR (NOT DILIGENT_NO_ARCHIVER AND NOT DILIGENT_NO_OPENGL))
    spm_requires(NAME spirv-headers VERSION 1.4.357.0)
    list(APPEND _deps spirv-headers::spirv-headers)
endif()
if(NOT DILIGENT_NO_HLSL OR NOT DILIGENT_NO_ARCHIVER OR NOT DILIGENT_NO_OPENGL)
    spm_requires(NAME glslang VERSION 1.4.357.0)
    spm_requires(NAME spirv-tools VERSION 1.4.357.0)
    list(APPEND _deps glslang::glslang spirv-tools::spirv-tools)
endif()

spm_cmake_configure(
    OPTIONS
        "-DDILIGENT_NO_FORMAT_VALIDATION=ON"
        "-DDILIGENT_NO_VULKAN=${DILIGENT_NO_VULKAN}"
        "-DDILIGENT_NO_ARCHIVER=${DILIGENT_NO_ARCHIVER}"
        "-DDILIGENT_NO_OPENGL=${DILIGENT_NO_OPENGL}"
        "-DDILIGENT_NO_HLSL=${DILIGENT_NO_HLSL}"
    DEPENDENCIES ${_deps}
)

spm_cmake_build()

spm_create_target(
    NAME diligentengine
    OUT_TARGET_NAME _target_name
    DEPENDENCIES ${_deps}
)

set(_defines_file "${CMAKE_CURRENT_SOURCE_DIR}/build/defines.txt")
file(STRINGS "${_defines_file}" defines)
foreach(define IN LISTS defines)
    target_compile_definitions(${_target_name} INTERFACE ${define})
endforeach()

if(SPM_BUILD_SHARED_LIBS)
    target_compile_definitions(${_target_name} INTERFACE ENGINE_DLL=1)
endif()
