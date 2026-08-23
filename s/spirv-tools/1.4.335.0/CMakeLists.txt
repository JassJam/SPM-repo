include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/KhronosGroup/SPIRV-Tools.git
	TAG vulkan-sdk-1.4.335.0
)

spm_git_clone(
	URL https://github.com/KhronosGroup/SPIRV-Headers.git
	TAG vulkan-sdk-1.4.335.0
	DESTINATION spirv-headers-src
)

set(_shared_build "OFF")
if(SPM_BUILD_SHARED_LIBS)
	set(_shared_build "ON")
endif()

spm_cmake_configure(
	OPTIONS
	"-DSPIRV_SKIP_TESTS=ON"
	"-DSPIRV_WERROR=OFF"
	"-DBUILD_SHARED_LIBS=${_shared_build}"
	"-DSPIRV-Headers_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/spirv-headers-src"
)
spm_cmake_build()

spm_create_target_from_pkgconfig(
	NAME spirv-tools
	MODULE SPIRV-Tools
)