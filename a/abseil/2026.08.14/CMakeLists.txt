include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/abseil/abseil-cpp.git
	TAG 9655f546c336b2df271e83dc223cbbc4d4d7aca5 # Aug 14, 2026
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

spm_cmake_configure(
	OPTIONS
	"-DABSL_ENABLE_INSTALL=ON"
	"-DBUILD_SHARED_LIBS=${_shared_build}"
)
spm_cmake_build()

spm_create_target(
    NAME abseil
)
