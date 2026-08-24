include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/KhronosGroup/glslang.git
	TAG vulkan-sdk-1.4.357.0
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

spm_cmake_configure(
    OPTIONS
		"-DENABLE_CTEST=OFF"
		"-DGLSLANG_TESTS=OFF"
		"-DBUILD_EXTERNAL=OFF"
		"-DENABLE_PCH=OFF"
		"-DENABLE_OPT=OFF"
		"-DBUILD_SHARED_LIBS=${_shared_build}"
)
spm_cmake_build()

spm_create_target(
    NAME glslang
)
