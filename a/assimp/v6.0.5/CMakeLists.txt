include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/assimp/assimp.git
	TAG v6.0.5
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
