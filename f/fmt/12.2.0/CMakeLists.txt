include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/fmtlib/fmt.git
	TAG 12.2.0
)

spm_apply_patch(
	PATCHES
	patches/u128-x86-backport.patch
)

spm_cmake_configure(
	OPTIONS
	"-DFMT_INSTALL=ON"
    "-DFMT_TEST=OFF"
)
spm_cmake_build()

spm_create_target_from_pkgconfig(
    NAME fmt
	MODULE fmt
    OUT_TARGET_NAME _target_name
)

if(SPM_BUILD_SHARED_LIBS)
    target_compile_definitions(${_target_name} INTERFACE FMT_LIB_EXPORT=1)
endif()

if(FMT_UNICODE)
	target_compile_options(main PRIVATE "$<$<C_COMPILER_ID:MSVC>:/utf-8>")
	target_compile_options(main PRIVATE "$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")
endif()
