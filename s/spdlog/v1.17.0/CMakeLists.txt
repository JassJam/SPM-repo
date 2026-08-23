include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/gabime/spdlog.git
	TAG v1.17.0
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

set(_deps "")
if(NOT SPDLOG_USE_STD_FORMAT)
    spm_requires(NAME fmt VERSION 12.2.0)
	list(APPEND _deps fmt::fmt)
endif()

spm_cmake_configure(
	OPTIONS
		"-DSPDLOG_INSTALL=ON"
		"-DSPDLOG_SYSTEM_INCLUDES=ON"
		"-DSPDLOG_INSTALL=ON"
		"-DSPDLOG_BUILD_SHARED=${_shared_build}"
	DEPENDENCIES ${_deps}
)
spm_cmake_build()

spm_create_target_from_pkgconfig(
    NAME spdlog
    MODULE spdlog
	DEPENDENCIES ${_deps}
)
