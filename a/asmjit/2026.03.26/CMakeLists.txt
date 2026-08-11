include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/asmjit/asmjit.git
	TAG 0bd5787b54b575ed94bf32ac452153b34385c514
)

spm_cmake_configure(
	OPTIONS
	"-DASSIMP_INSTALL=ON"
    "-DASSIMP_WARNINGS_AS_ERRORS=OFF"
    "-DASSIMP_BUILD_TESTS=OFF"
)
spm_cmake_build()

spm_create_target_from_pkgconfig(
    NAME assimp
    MODULE assimp
)
