include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/madler/zlib.git
	TAG v1.3.2
)

spm_apply_patch(
	PATCHES
	patches/int64-x86-port.patch
)

spm_cmake_configure(
	OPTIONS
	"-DZLIB_INSTALL=ON"
)
spm_cmake_build()

spm_create_target(
    NAME zlib
)