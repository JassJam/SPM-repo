include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/gabime/spdlog.git
	TAG v1.17.0
)

spm_cmake_configure(
	OPTIONS
	"-DSPDLOG_INSTALL=ON"
	"-DSPDLOG_SYSTEM_INCLUDES=ON"
    "-DSPDLOG_INSTALL=ON"
)
spm_cmake_build()

spm_create_target_from_pkgconfig(
    NAME spdlog
    MODULE spdlog
)
