include(${CMAKE_CURRENT_LIST_DIR}/spm-recipe.cmake)

spm_requires(
    NAME vulkan-headers
    VERSION 1.4.357.0
)

spm_git_clone(
	URL https://github.com/zeux/volk.git
	TAG vulkan-sdk-1.4.357.0
)

spm_cmake_configure(
	OPTIONS
	"-DVOLK_INSTALL=ON"
	"-DVOLK_PULL_IN_VULKAN=ON"
    DEPENDENCIES vulkan-headers::vulkan-headers
)
spm_cmake_build()

spm_create_target(
    NAME volk
    DEPENDENCIES vulkan-headers::vulkan-headers
)
