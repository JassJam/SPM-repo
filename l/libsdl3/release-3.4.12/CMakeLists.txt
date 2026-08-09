include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/libsdl-org/SDL.git
	TAG release-3.4.12
)

spm_cmake_configure(
	OPTIONS
	"-DSDL_INSTALL=ON"
    "-DSDL_TEST_LIBRARY=OFF"
)
spm_cmake_build()

spm_create_target(
    NAME SDL3
)
