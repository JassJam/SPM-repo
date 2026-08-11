include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/abseil/abseil-cpp.git
	TAG 20260526.0
)

spm_cmake_configure(
	OPTIONS
	"-ABSL_ENABLE_INSTALL=ON"
)
spm_cmake_build()

spm_create_target(
    NAME abseil
    MODULE abseil
)
