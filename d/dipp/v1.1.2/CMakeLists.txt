include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/JassJam/dipp.git
	TAG v1.1.2
)

spm_cmake_configure()
spm_cmake_build()

spm_create_target(
    NAME dipp
)
