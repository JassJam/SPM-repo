include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/SanderMertens/flecs.git
	TAG v4.1.6
)

spm_cmake_configure()
spm_cmake_build()

spm_create_target(
    NAME flecs
    MODULE flecs
)
