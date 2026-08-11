include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/microsoft/mimalloc.git
	TAG v3.3.2
)

spm_apply_patch(
	PATCHES
	patches/mimalloc-multiconfig-obj.patch
)

spm_cmake_configure(
	OPTIONS
	"-DMI_BUILD_TESTS=OFF"
	"-DMI_INSTALL_TOPLEVEL=ON"
)
spm_cmake_build()

spm_create_target_from_pkgconfig(
    NAME mimalloc
    MODULE mimalloc
)
