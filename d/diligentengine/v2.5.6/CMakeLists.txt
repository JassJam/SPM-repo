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

set(_cfg_options)
set(_build_dir b)
spm_cmake_configure(
    BUILD_DIR ${_build_dir}
    OPTIONS
)
spm_cmake_build(BUILD_DIR ${_build_dir})

spm_create_target(
    NAME DiligentEngine
	OUT_TARGET_NAME _target_name
	OPTIONS
	"DILIGENT_NO_FORMAT_VALIDATION=OFF"
)

file(STRINGS ${CMAKE_CURRENT_SOURCE_DIR}/${_build_dir}/defines.txt defines)
foreach(define IN LISTS defines)
    target_compile_definitions(${_target_name} INTERFACE ${define})
endforeach()
