include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/lief-project/LIEF.git
	TAG 5416ff2e2fcda29924c2f868a7249b4318359c41
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

spm_cmake_configure(
	OPTIONS
	"-DLIEF_INSTALL=ON"
	"-DBUILD_SHARED_LIBS=${_shared_build}"
)
spm_cmake_build()

spm_create_target(NAME LIEF)
