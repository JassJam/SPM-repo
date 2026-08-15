include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

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

spm_cmake_configure(
    OPTIONS
        "-DDILIGENT_NO_FORMAT_VALIDATION=ON"
)

spm_cmake_build()

spm_create_target(
    NAME DiligentEngine
    OUT_TARGET_NAME _target_name
)

set(_defines_file "${CMAKE_CURRENT_SOURCE_DIR}/build/defines.txt")
file(STRINGS "${_defines_file}" defines)
foreach(define IN LISTS defines)
    target_compile_definitions(${_target_name} INTERFACE ${define})
endforeach()

if(SPM_BUILD_SHARED_LIBS)
    target_compile_definitions(${_target_name} INTERFACE ENGINE_DLL=1)
endif()