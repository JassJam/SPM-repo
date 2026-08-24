include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/KhronosGroup/SPIRV-Cross.git
	TAG vulkan-sdk-1.4.357.0
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

spm_cmake_configure(
	OPTIONS
		"-DSPIRV_CROSS_SHARED=${_shared_build}"
		"-DSPIRV_CROSS_ENABLE_TESTS=OFF"
)
spm_cmake_build()

spm_create_target(
    NAME spirv-cross
)
