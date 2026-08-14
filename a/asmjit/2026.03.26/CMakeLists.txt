include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/asmjit/asmjit.git
	TAG 0bd5787b54b575ed94bf32ac452153b34385c514
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

spm_cmake_configure(
	OPTIONS
	"-DBUILD_SHARED_LIBS=${_shared_build}"
)
spm_cmake_build()

spm_create_target(
    NAME asmjit
)
