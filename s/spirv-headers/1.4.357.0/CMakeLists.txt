include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_git_clone(
	URL https://github.com/KhronosGroup/SPIRV-Headers.git
	TAG vulkan-sdk-1.4.357.0
)

spm_cmake_configure(
	OPTIONS
		"-DSPIRV_HEADERS_ENABLE_INSTALL=ON"
		"-DSPIRV_HEADERS_ENABLE_TESTS=OFF"
)
spm_cmake_build()

spm_create_target_from_pkgconfig(
    NAME spirv-headers
    MODULE SPIRV-Headers
)
