include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/libjpeg-turbo/libjpeg-turbo.git
	TAG 3.2.0
)

spm_cmake_configure()
spm_cmake_build()

spm_create_target(
    NAME libjpeg
)
